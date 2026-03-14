import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'game_catalog.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:vpn_connection_detector/vpn_connection_detector.dart';
import 'package:detect_fake_location/detect_fake_location.dart';

// security things
Future<bool> checkVPN() async {
  bool isVpnConnected = await VpnConnectionDetector.isVpnActive();
  return isVpnConnected;
}

Future<bool> checkFakeLocation() async {
  bool isFakeLocation = await DetectFakeLocation().detectFakeLocation();
  return isFakeLocation;
}

final List<GameData> favorite_games = [
  GameData(text: "Zombie Apocalypse", imagePath: 'assets/icons/zombie_outline.png'),
  GameData(text: "Soul Seeker", imagePath: 'assets/icons/soul_icon.png'),
];

// Data pulled from provider gets stored as SessionData items for player history
class SessionData {
  final DateTime date;
  final String game;
  /*
  pointsCollected, sessionDataPoints, and distanceTraveled will not be required,
  in the event that someone starts a game and closes it before collecting measurements, moving
  around, etc.
   */
  final int? pointsCollected;
  final int? distanceTraveled;
  final double? averageUploadSpeed;
  final double? averageDownloadSpeed;
  final double? radiusGyration;
  List<dynamic>? sessionDataPoints;
  final bool? isVPN;
  final bool? isFakeLocation;

  SessionData({required this.date, required this.game, this.pointsCollected,
    this.distanceTraveled, this.sessionDataPoints, this.averageDownloadSpeed,
  this.averageUploadSpeed, this.radiusGyration, this.isFakeLocation, this.isVPN});
}

// radius-based stream for gathering points from firestore
final GeoCollectionReference<Map<String, dynamic>> geoCollection =
GeoCollectionReference(firestore.FirebaseFirestore.instance.collection('data_points'));

Stream<List<firestore.DocumentSnapshot>> getPointsStream(LatLng center, double radiusKm) {
  return geoCollection.subscribeWithin(
    center: GeoFirePoint(firestore.GeoPoint(center.latitude, center.longitude)),
    radiusInKm: radiusKm,
    field: 'location',
    geopointFrom: (data) => data['location']['geopoint'] as firestore.GeoPoint,
  );
}

// Data Point Class
class DataPoint {
  final LatLng point;
  final DateTime timestamp;
  final double uploadSpeed;
  final double downloadSpeed;
  final double latency;
  final String gamePlayed;
  final bool isVPN;
  final bool isFakeLocation;

  DataPoint({required this.point, required this.timestamp, required this.uploadSpeed,
    required this.downloadSpeed, required this.latency, required this.gamePlayed,
    required this.isVPN, required this.isFakeLocation});

  factory DataPoint.fromFirestore(firestore.DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final firestore.GeoPoint geoPoint = data['location']['geopoint'] as firestore.GeoPoint;

    return DataPoint(
      point: LatLng(geoPoint.latitude, geoPoint.longitude),
      timestamp: (data['timestamp'] as firestore.Timestamp).toDate(),
      uploadSpeed: (data['uploadSpeed'] as num?)?.toDouble() ?? 0.0,
      downloadSpeed: (data['downloadSpeed'] as num?)?.toDouble() ?? 0.0,
      latency: (data['latency'] as num?)?.toDouble() ?? 0.0,
      gamePlayed: data['gamePlayed'] as String? ?? 'Unknown',
      isVPN: data['isVPN'] as bool? ?? false,
      isFakeLocation: data['isFakeLocation'] as bool? ?? false,
    );
  }
}

class UserDataProvider extends ChangeNotifier {
  Map<String, dynamic>? _userData;
  bool _isLoading = false;

  Map<String, dynamic>? get userData => _userData;
  bool get isLoading => _isLoading;

  int get measurementsTaken => _userData?['measurementsTaken'] ?? 0;
  String get uid => _userData?['uid'] ?? '';
  String get email => _userData?['email'] ?? '';
  int get distanceTraveled => _userData?['distanceTraveled'] ?? 0;
  int get totalRadiusGyration => _userData?['totalRadiusGyration'] ?? 0;
  List<dynamic> get dataPoints => _userData?['dataPoints'] ?? [];

  // Fetch data for the currently logged-in user
  Future<void> fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    print('🔍 Fetching data for user: ${user.email} (${user.uid})');

    _isLoading = true;
    notifyListeners();

    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('userData')
          .doc(user.uid) // Use the Auth UID directly!
          .get();

      if (doc.exists) {
        _userData = doc.data() as Map<String, dynamic>;
        
        // Update security status in Firebase every time the app loads data
        bool vpn = await checkVPN();
        bool fake = await checkFakeLocation();
        await FirebaseFirestore.instance.collection('userData').doc(user.uid).update({
          'isVPN': vpn,
          'isFakeLocation': fake,
        });
        // Update local map as well
        _userData?['isVPN'] = vpn;
        _userData?['isFakeLocation'] = fake;

        print('Data loaded:');
        print('   Email: ${_userData?['email']}');
        print('   Measurements: ${_userData?['measurementsTaken']}');
      } else {
        print('No document found, creating one...');
        // Create document if it doesn't exist
        await createUserDocument(user);
        await fetchUserData(); // Try again
      }
    } catch (e) {
      print('Error: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  // Helper method to create user document
  Future<void> createUserDocument(User user) async {
    bool vpn = await checkVPN();
    bool fake = await checkFakeLocation();

    await FirebaseFirestore.instance
        .collection('userData')
        .doc(user.uid)
        .set({
      'uid': user.uid,
      'email': user.email,
      'measurementsTaken': 0,
      'distanceTraveled': 0,
      'dataPoints': [],
      'radGyration': [0],
      'createdAt': FieldValue.serverTimestamp(),
      'isVPN' : vpn,
      'isFakeLocation' : fake,
    }, SetOptions(merge: true));
  }

  void clearData() {
    _userData = null;
    notifyListeners();
  }

}
