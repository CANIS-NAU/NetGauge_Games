import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'homepage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'user_data_manager.dart';
import 'game_catalog.dart';

final List<GameData> favorite_games = [
  GameData(text: "Zombie Apocalypse", imagePath: 'assets/icons/zombie_outline.png'),
  GameData(text: "Soul Seeker", imagePath: 'assets/icons/soul_icon.png'),
];

// Data pulled from provider gets stored as SessionData items for player history
class SessionData {
  final DateTime date;
  final GameData game;
  /*
  pointsCollected, sessionDataPoints, and distanceTraveled will not be required,
  in the event that someone starts a game and closes it before collecting measurements, moving
  around, etc.
   */
  final int? pointsCollected;
  final int? distanceTraveled;
  List<dynamic>? sessionDataPoints;

  SessionData({required this.date, required this.game, this.pointsCollected,
    this.distanceTraveled, this.sessionDataPoints});
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
    }, SetOptions(merge: true));
  }

  void clearData() {
    _userData = null;
    notifyListeners();
    print('🗑️ User data cleared');
  }

}