import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'game_catalog.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';
import 'package:provider/provider.dart';
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
  GameData(text: "Space Explorers", icon: Icons.settings),
  GameData(text: "Scavenger Hunt", icon: Icons.location_pin),
  GameData(text: "Zombie Apocalypse", imagePath: 'assets/icons/zombie_outline.png'),
  GameData(text: "Soul Seeker", imagePath: 'assets/icons/soul_icon.png'),
  GameData(text: "Dragon Slayer", imagePath: 'assets/icons/dragon_outline.png'),
];

class SessionData {
  final DateTime date;
  final String game;
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

  // FIX 1: This now gets populated by the new fetch logic below
  Map<String, bool>? _seenMessages;

  Map<String, dynamic>? get userData => _userData;
  bool get isLoading => _isLoading;

  int get measurementsTaken => _userData?['measurementsTaken'] ?? 0;
  String get uid => _userData?['uid'] ?? '';
  String get email => _userData?['email'] ?? '';
  String get phone => _userData?['phone'] ?? '1111111111';
  int get distanceTraveled => _userData?['distanceTraveled'] ?? 0;
  int get totalRadiusGyration => _userData?['totalRadiusGyration'] ?? 0;
  List<dynamic> get dataPoints => _userData?['dataPoints'] ?? [];

  // FIX 2: Getter now just returns _seenMessages with a safe fallback
  Map<String, bool> get seenMessages {
    return _seenMessages ?? {
      "control_message": false,
      "play_message": false,
      "utility_message": false,
    };
  }

  List<GameData> get favoriteGames {
    if (_userData == null) return [];

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
    if (_userData == null) return;

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
      await FirebaseFirestore.instance
          .collection('userData')
          .doc(uid)
          .update({'favorite_games': currentFavorites});
      print('Favorites updated in Firestore');
    } catch (e) {
      print('Error updating favorites: $e');
    }
  }

  // TODO: This never actually updates because we are working with a COPY of the seenMessages map, not the real one
  // needs to be fixed
  Future<void> updateOnboardingStatus(String experiment, context) async {
    debugPrint("[USER_DATA_MANAGER]: Updating onboarding status for $experiment to true.");

    // if _seenMessages is null, initialize
    _seenMessages ??= {
      "control_message": false,
      "play_message": false,
      "utility_message": false,
    };

    _seenMessages![experiment] = true;

    final onboardingQuery = await FirebaseFirestore.instance
        .collection('ABC_Onboarding')
        .doc('user')                          // the subcollection parent doc
        .collection('user')                   // the subcollection itself
        .where('email', isEqualTo: this.email)
        .limit(1)
        .get();

    if(onboardingQuery.docs.isNotEmpty) {
      await onboardingQuery.docs.first.reference.update({
        'messages_seen.$experiment': true,   // dot notation updates just this key
      });
    }
    notifyListeners();
  }

  Future<void> fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    print('🔍 Fetching data for user: ${user.email} (${user.uid})');

    _isLoading = true;
    notifyListeners();

    try {
      // Existing userData fetch — unchanged
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('userData')
          .doc(user.uid)
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
        await createUserDocument(user);
        await fetchUserData();
        return;
      }

      // FIX 3: New fetch for ABC_Onboarding — queries by email
      final onboardingQuery = await FirebaseFirestore.instance
          .collection('ABC_Onboarding')
          .doc('user')                          // the subcollection parent doc
          .collection('user')                   // the subcollection itself
          .where('email', isEqualTo: user.email)
          .limit(1)
          .get();

      if (onboardingQuery.docs.isNotEmpty) {
        final onboardingData = onboardingQuery.docs.first.data();

        // Safely cast the messages_seen map from Firestore
        final rawSeen = onboardingData['messages_seen'];
        if (rawSeen is Map) {
          _seenMessages = rawSeen.map(
                  (key, value) => MapEntry(key.toString(), value as bool)
          );
        }
        print('Onboarding data loaded: $_seenMessages');
      } else {
        // User has no onboarding doc yet — create one
        print('No onboarding document found, creating one...');
        await createOnboardingDocument(user);
      }

    } catch (e) {
      print('Error: $e');
    }

    _isLoading = false;
    notifyListeners();
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
      'measurementsTaken': 0,
      'distanceTraveled': 0,
      'dataPoints': [],
      'radGyration': [0],
      'favorite_games': ['Zombie Apocalypse', 'Soul Seeker'],
      'createdAt': FieldValue.serverTimestamp(),
      'isVPN' : vpn,
      'isFakeLocation' : fake,
    }, SetOptions(merge: true));
  }

  // FIX 4: New helper to create an onboarding doc for new users
  Future<void> createOnboardingDocument(User user) async {
    await FirebaseFirestore.instance
        .collection('ABC_Onboarding')
        .doc('user')
        .collection('user')
        .add({
      'email': user.email,
      'messages_seen': {
        'control_message': false,
        'play_message': false,
        'utility_message': false,
      },
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Set local state to match
    _seenMessages = {
      'control_message': false,
      'play_message': false,
      'utility_message': false,
    };
  }

  // FIX 5: New method to mark a message as seen — call this after dialog is dismissed
  Future<void> markMessageAsSeen(String messageId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Update local state immediately for UI responsiveness
    _seenMessages = {
      ...seenMessages,
      messageId: true,
    };
    notifyListeners();

    // Find the user's onboarding doc and update it
    try {
      final onboardingQuery = await FirebaseFirestore.instance
          .collection('ABC_Onboarding')
          .doc('user')
          .collection('user')
          .where('email', isEqualTo: user.email)
          .limit(1)
          .get();

      if (onboardingQuery.docs.isNotEmpty) {
        await onboardingQuery.docs.first.reference.update({
          'messages_seen.$messageId': true,   // dot notation updates just this key
        });
        print('Marked $messageId as seen');
      }
    } catch (e) {
      print('Error marking message as seen: $e');
    }
  }

  void clearData() {
    _userData = null;
    _seenMessages = null;    // FIX 6: clear this on logout too
    notifyListeners();
  }
}
