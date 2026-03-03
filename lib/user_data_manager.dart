import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'game_catalog.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;

final List<GameData> games = [
  GameData(text: "Measure Internet", icon: Icons.wifi),
  GameData(text: "Space Explorers", icon: Icons.settings),
  GameData(text: "Scavenger Hunt", icon: Icons.location_pin),
  GameData(text: "Zombie Apocalypse", imagePath: 'assets/icons/zombie_outline.png'),
  GameData(text: "Soul Seeker", imagePath: 'assets/icons/soul_icon.png'),
  GameData(text: "Dragon Slayer", imagePath: 'assets/icons/dragon_outline.png'),
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

  SessionData({required this.date, required this.game, this.pointsCollected,
    this.distanceTraveled, this.sessionDataPoints, this.averageDownloadSpeed,
  this.averageUploadSpeed, this.radiusGyration});
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

  DataPoint({required this.point, required this.timestamp, required this.uploadSpeed,
    required this.downloadSpeed, required this.latency, required this.gamePlayed});

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
  String get phone => _userData?['phone'] ?? '1111111111';
  int get distanceTraveled => _userData?['distanceTraveled'] ?? 0;
  int get totalRadiusGyration => _userData?['totalRadiusGyration'] ?? 0;
  List<dynamic> get dataPoints => _userData?['dataPoints'] ?? [];

  // This is the new getter replacing the old function
  List<GameData> get favoriteGames {
    if (_userData == null) {
      return [];
    }

    List<GameData> favoritesList = [];
    final rawFavorites = _userData!['favorite_games'];
    
    // Add a strict type check to avoid the Map vs List crash
    List<dynamic> favoriteNames;
    if (rawFavorites is List) {
      favoriteNames = rawFavorites;
    } else {
      // Fallback if data is missing or malformed in DB
      favoriteNames = ['Zombie Apocalypse', 'Soul Seeker'];
    }

    for (var name in favoriteNames) {
      for (var game in games) {
        if (game.text == name) {
          favoritesList.add(game);
        }
      }
    }
    return favoritesList;
  }

  // Method to add/remove a game from favorites in Firestore
  Future<void> toggleFavorite(String gameName) async {
    if (_userData == null) return;

    // Use current list or default if it has never been modified
    final rawFavorites = _userData!['favorite_games'];
    List<dynamic> currentFavorites = (rawFavorites is List) 
        ? List.from(rawFavorites) 
        : ['Zombie Apocalypse', 'Soul Seeker'];

    if (currentFavorites.contains(gameName)) {
      currentFavorites.remove(gameName);
    } else {
      currentFavorites.add(gameName);
    }

    // Update local state immediately for UI responsiveness
    _userData!['favorite_games'] = currentFavorites;
    notifyListeners();

    // Update Firestore
    try {
      await FirebaseFirestore.instance
          .collection('userData')
          .doc(uid)
          .update({'favorite_games': currentFavorites});
      print('Favorites updated in Firestore');
    } catch (e) {
      print('Error updating favorites: $e');
    }
  }

  // Fetch data for the currently logged-in user
  Future<void> fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    print('Fetching data for user: ${user.email} (${user.uid})');

    _isLoading = true;
    notifyListeners();

    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('userData')
          .doc(user.uid) // Use the Auth UID directly!
          .get();

      if (doc.exists) {
        _userData = doc.data() as Map<String, dynamic>;
        print('Data loaded:');
        print('   Email: ${_userData?['email']}');
        print('   Measurements: ${_userData?['measurementsTaken']}');
        print('   Favorite Games: ${_userData?['favorite_games']}');
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
      'favorite_games': ['Zombie Apocalypse', 'Soul Seeker'],
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  void clearData() {
    _userData = null;
    notifyListeners();
    print('User data cleared');
  }

}
