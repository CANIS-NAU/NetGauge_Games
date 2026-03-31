// References
// https://firebase.google.com/docs/firestore/query-data/aggregation-queries#dart

// import packages and libraries
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

final List<GameData> games = [
  GameData(text: "Measure Internet", icon: Icons.wifi),
  GameData(text: "Scavenger Hunt", icon: Icons.location_pin),
  GameData(text: "Zombie Apocalypse", imagePath: 'assets/icons/zombie_outline.png'),
  GameData(text: "Soul Seeker", imagePath: 'assets/icons/soul_icon.png'),
  GameData(text: "Dragon Slayer", imagePath: 'assets/icons/dragon_outline.png'),
];

class SessionData {
  final DateTime date;
  final String game;
  final int? pointsCollected;
  final double? distanceTraveled;
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
    final GeoPoint geopoint = data['location'] as GeoPoint;
    final double lat = geopoint.latitude;
    final double lng = geopoint.longitude;

    return DataPoint(
      point: LatLng(lat, lng),
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
  Map<String, bool>? _seenMessages;

  Map<String, dynamic>? get userData => _userData;
  bool get isLoading => _isLoading;
  int get measurementsTaken => _userData?['measurementsTaken'] ?? 0;
  String get uid => _userData?['uid'] ?? '';
  String get email => _userData?['email'] ?? '';

  bool get getDemographicStatus => (_userData?['demographics_taken'] as bool?) ?? false;
  
  String get phone => _userData?['phone'] ?? '1111111111';
  double get distanceTraveled => _userData?['distanceTraveled'] ?? 0;
  int get totalRadiusGyration => _userData?['totalRadiusGyration'] ?? 0;
  List<dynamic> get dataPoints => _userData?['dataPoints'] ?? [];

  List<GameData> get favoriteGames {
    if (_userData == null) {
      return [];
    }

    final rawFavorites = _userData!['favorite_games'];
    List<dynamic> favoriteNames;
    
    if (rawFavorites is List) {
      favoriteNames = rawFavorites;
    } else {
      favoriteNames = ['Zombie Apocalypse', 'Soul Seeker'];
    }

    List<GameData> favoritesList = [];
    for (var name in favoriteNames) {
      for (var game in games) {
        if (game.text == name) {
          favoritesList.add(game);
        }
      }
    }
    return favoritesList;
  }

  Future<void> toggleFavorite(String gameName) async {
    if (_userData == null) {
      debugPrint("[USER_DATA_MANAGER]: Cannot toggle favorite, _userData is null.");
      return;
    }

    final rawFavorites = _userData!['favorite_games'];
    List<dynamic> currentFavorites = (rawFavorites is List) 
        ? List.from(rawFavorites) 
        : ['Zombie Apocalypse', 'Soul Seeker'];

    if (currentFavorites.contains(gameName)) {
      currentFavorites.remove(gameName);
    } else {
      currentFavorites.add(gameName);
    }

    _userData!['favorite_games'] = currentFavorites;
    notifyListeners();

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('userData')
            .doc(user.uid)
            .update({'favorite_games': currentFavorites});
        debugPrint('Favorites updated in Firestore');
      }
    } catch (e) {
      debugPrint('Error updating favorites: $e');
    }
  }

  Future<List<DataPoint>> fetchCollectedMeasurements() async {
    final email = FirebaseAuth.instance.currentUser?.email;
    if (email == null) return [];

    final snapshot_collected_points = await FirebaseFirestore.instance
        .collection('measurements')
        .doc(email)
        .collection('collected_measurements')
        .get();

    return snapshot_collected_points.docs.map((doc) => DataPoint.fromFirestore(doc)).toList();
  }

  Future<void> setDemographicStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('userData')
            .doc(user.uid)
            .update({'demographics_taken': true});

        if (_userData != null) {
          _userData!['demographics_taken'] = true;
        }

        notifyListeners();
        debugPrint('Demographic survey status updated successfully');
      }
    } catch (e) {
      debugPrint('Error updating demographic survey status: $e');
    }
  }

  Future<void> fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('userData')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        _userData = doc.data() as Map<String, dynamic>;

        List<DataPoint> collectedMeasurements = await fetchCollectedMeasurements();
        await FirebaseFirestore.instance
            .collection('userData')
            .doc(user.uid)
            .update({'measurementsTaken': collectedMeasurements.length});
        
        _userData?['measurementsTaken'] = collectedMeasurements.length;

        bool vpn = await checkVPN();
        bool fake = await checkFakeLocation();
        await FirebaseFirestore.instance.collection('userData').doc(user.uid).update({
          'isVPN': vpn,
          'isFakeLocation': fake,
        });

        _userData?['isVPN'] = vpn;
        _userData?['isFakeLocation'] = fake;

        final onboardingQuery = await FirebaseFirestore.instance
            .collection('ABC_Onboarding')
            .doc('user')
            .collection('user')
            .where('email', isEqualTo: user.email)
            .limit(1)
            .get();

        if (onboardingQuery.docs.isNotEmpty) {
          final rawSeen = onboardingQuery.docs.first.data()['messages_seen'];
          if (rawSeen is Map) {
            _seenMessages = rawSeen.map((k, v) => MapEntry(k.toString(), v as bool));
          }
        } else {
          await createOnboardingDocument(user);
        }

        debugPrint("Data loaded for: ${user.email}");
      } else {
        debugPrint("No document found for UID: ${user.uid}, creating one...");
        await createUserDocument(user);
        await fetchUserData();
      }
    } catch (e) {
      debugPrint('Error fetching user data: $e');
    }
    
    _isLoading = false;
    notifyListeners();
  }

  Map<String, bool> get seenMessages {
    return _seenMessages ?? {
      "control_message": false,
      "play_message": false,
      "utility_message": false,
    };
  }

  Future<void> updateOnboardingStatus(String experiment, context) async {
    debugPrint("[USER_DATA_MANAGER]: Updating onboarding status for $experiment to true.");

    // if _seenMessages is null, initialize
    _seenMessages ??= {
      "control_message": false,
      "play_message": false,
      "utility_message": false,
    };

    _seenMessages![experiment] = true;
    notifyListeners();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final onboardingQuery = await FirebaseFirestore.instance
        .collection('ABC_Onboarding')
        .doc('user')
        .collection('user')
        .where('email', isEqualTo: user.email)
        .limit(1)
        .get();

    if(onboardingQuery.docs.isNotEmpty) {
      await onboardingQuery.docs.first.reference.update({
        'messages_seen.$experiment': true,
      });
    }
  }

  Future<void> createUserDocument(User user) async {
    bool vpn = await checkVPN();
    bool fake = await checkFakeLocation();

    await FirebaseFirestore.instance
        .collection('userData')
        .doc(user.uid)
        .set({
      'uid': user.uid,
      'email': user.email,
      'demographics_taken' : false,
      'measurementsTaken': 0,
      'distanceTraveled': 0.0,
      'dataPoints': [],
      'radGyration': [0],
      'favorite_games': ['Zombie Apocalypse', 'Soul Seeker'],
      'createdAt': FieldValue.serverTimestamp(),
      'isVPN' : vpn,
      'isFakeLocation' : fake,
    }, SetOptions(merge: true));
  }

  Future<void> createOnboardingDocument(User user) async {
    await FirebaseFirestore.instance
        .collection('ABC_Onboarding')
        .doc('user')
        .collection('user')
        .add({
      'email': user.email,
      'messages_seen': {
        "control_message": false,
        "play_message": false,
        "utility_message": false,
      }
    });
  }

  void clearData() {
    _userData = null;
    _seenMessages = null;
    notifyListeners();
    debugPrint('User data cleared');
  }
}
