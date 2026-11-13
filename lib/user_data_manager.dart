// References
// https://firebase.google.com/docs/firestore/query-data/aggregation-queries#dart

// import packages and libraries
import 'package:flutter/material.dart';
import 'account_identity.dart';
import 'badges.dart';
import 'badge_announcement.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'game_catalog.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:vpn_connection_detector/vpn_connection_detector.dart';
import 'package:detect_fake_location/detect_fake_location.dart';
import 'dart:math';
import 'remote_config_service.dart';

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
  GameData(text: "Space Explorers", imagePath: 'assets/icons/alien_icon.png'),
  GameData(text: "Constellation Quest", imagePath: 'assets/icons/alien_icon.png'),
];

class SessionData {
  final DateTime startTime;
  final DateTime endTime;
  final String game;
  final int? pointsCollected;
  final double? distanceTraveled;
  final double? averageUploadSpeed;
  final double? averageDownloadSpeed;
  final double? radiusGyration;
  List<dynamic>? sessionDataPoints;
  final bool? isVPN;
  final bool? isFakeLocation;

  SessionData({required this.startTime, required this.endTime, required this.game, this.pointsCollected,
    this.distanceTraveled, this.sessionDataPoints, this.averageDownloadSpeed,
  this.averageUploadSpeed, this.radiusGyration, this.isFakeLocation, this.isVPN});

  factory SessionData.fromFirestore(firestore.DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // the session document stores each measurement; the session's averages come from those
    double? average(String key) {
      final speeds = ((data['collected_measurements'] as List?) ?? [])
          .whereType<Map>()
          .map((m) => m[key])
          .whereType<num>()
          .toList();
      return speeds.isEmpty ? null : speeds.reduce((a, b) => a + b) / speeds.length;
    }

    return SessionData(
      averageDownloadSpeed: average('download_speed'),
      averageUploadSpeed: average('upload_speed'),
      startTime: (data['start_time'] as firestore.Timestamp?)?.toDate() ?? DateTime.now(),
      endTime: (data['end_time'] as firestore.Timestamp?)?.toDate() ?? DateTime.now(),
      game: data['game'] ?? 'Unknown',
      distanceTraveled: (data['session_distance'] as num?)?.toDouble() ?? 0.0,
      pointsCollected: (data['collected_measurements'] as List?)?.length ?? 0,
      isVPN: data['vpn_used'] as bool? ?? false,
      isFakeLocation: false, // Placeholder as it's not in the sessions doc yet
    );
  }
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
  final String session_id;

  DataPoint({required this.point, required this.timestamp, required this.uploadSpeed,
    required this.downloadSpeed, required this.latency, required this.gamePlayed,
    required this.isVPN, required this.isFakeLocation, required this.session_id});

  factory DataPoint.fromFirestore(firestore.DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // Handle different location formats (GeoPoint vs lat/long fields)
    double lat = 0.0;
    double lng = 0.0;
    
    if (data['location'] is firestore.GeoPoint) {
      lat = (data['location'] as firestore.GeoPoint).latitude;
      lng = (data['location'] as firestore.GeoPoint).longitude;
    } else {
      lat = (data['latitude'] as num?)?.toDouble() ?? 0.0;
      lng = (data['longitude'] as num?)?.toDouble() ?? 0.0;
    }

    return DataPoint(
      point: LatLng(lat, lng),
      timestamp: (data['timestamp'] as firestore.Timestamp?)?.toDate() ?? DateTime.now(),
      uploadSpeed: (data['upload_speed'] as num? ?? data['uploadSpeed'] as num?)?.toDouble() ?? 0.0,
      downloadSpeed: (data['download_speed'] as num? ?? data['downloadSpeed'] as num?)?.toDouble() ?? 0.0,
      latency: (data['latency'] as num?)?.toDouble() ?? 0.0,
      gamePlayed: data['game'] as String? ?? data['gamePlayed'] as String? ?? 'Unknown',
      isVPN: data['vpn_used'] as bool? ?? false,
      isFakeLocation: data['isFakeLocation'] as bool? ?? false,
      session_id: data['session_id'] as String? ?? 'Unknown',
    );
  }
}

// data type for tracking location
class LocationPoint {
  final double longitude;
  final double latitude;

  LocationPoint({required this.longitude, required this.latitude});
}

class UserDataProvider extends ChangeNotifier {

  Map<String, dynamic>? _userData;
  bool _isLoading = false;
  Map<String, bool>? _seenMessages;
  List<DataPoint> _collectedMeasurements = [];
  List<SessionData> _collectedSessions = [];

  Map<String, dynamic>? get userData => _userData;
  bool get isLoading => _isLoading;
  // true when using the app as a guest (anonymous sign-in, no account)
  bool get isGuestUser => isGuest(FirebaseAuth.instance.currentUser);
  int get measurementsTaken => _userData?['totalPointsCollected'] ?? 0;
  String get uid => _userData?['uid'] ?? '';
  // Falls back to the signed-in account's ID (email, or a guest ID) while the user document has not loaded,
  // so anything that needs it as a Firestore document ID never gets an empty string.
  String get email {
    final fromDocument = _userData?['email'];
    if (fromDocument is String && fromDocument.isNotEmpty) return fromDocument;
    return accountIdFor(FirebaseAuth.instance.currentUser);
  }

  bool get getDemographicStatus => (_userData?['demographicsSurveyTaken'] as bool?) ?? false;

  // whether this person (account or guest) has already seen the welcome pop-up
  bool get welcomeSeen => (_userData?['welcomeSeen'] as bool?) ?? false;
  
  String get phone => _userData?['phone'] ?? '1111111111';

  double get totalDistanceTraveled => (_userData?['totalDistanceTraveled'] as num?)?.toDouble() ?? 0.0;
  int get totalPointsCollected => (_userData?['totalPointsCollected'] as num?)?.toInt() ?? 0;
  int get totalLocationPointsMeasured => (_userData?['totalLocationPointsMeasured'] as num?)?.toInt() ?? 0;
  double get totalRadiusGyration => (_userData?['totalRadiusGyration'] as num?)?.toDouble() ?? 0.0;

  // the badges stored on this account (see badges.dart)
  Set<String> get earnedBadgeIds => storedBadgeIds(_userData?['earnedBadges']);

  // what the badge rules are worked out from
  BadgeStats get badgeStats => BadgeStats(
        totalMeasurements: totalPointsCollected,
        totalDistanceMeters: totalDistanceTraveled,
        sessions: _collectedSessions
            .map((s) => PlayedSession(game: s.game, endTime: s.endTime, averageDownload: s.averageDownloadSpeed))
            .toList(),
      );

  bool _awardingBadges = false;

  // Stores any badges the player has now earned but does not have yet, on their account, and returns them so the app
  // can announce them. Badges are only ever added, never removed. Guests have no statistics page, so they get none.
  // After a game, pass refreshSessions so the session that just ended is counted.
  Future<List<AppBadge>> awardNewBadges({bool refreshSessions = false}) async {
    if (_userData == null || isGuestUser || _awardingBadges) return [];
    _awardingBadges = true;
    try {
      if (refreshSessions) {
        _collectedSessions = await fetchSessionData();
        _userData!['totalPointsCollected'] = _collectedSessions.fold<int>(0, (sum, s) => sum + (s.pointsCollected ?? 0));
      }

      final newBadges = badgesToAward(badgeStats, earnedBadgeIds);
      if (newBadges.isEmpty) return [];

      // a dotted path adds just these badges, leaving the ones already stored alone
      await FirebaseFirestore.instance
          .collection('userAccountData')
          .doc(email)
          .update({for (final b in newBadges) 'earnedBadges.${b.id}': FieldValue.serverTimestamp()});

      final stored = Map<String, dynamic>.from((_userData!['earnedBadges'] as Map?) ?? {});
      for (final b in newBadges) {
        stored[b.id] = Timestamp.now();
      }
      _userData!['earnedBadges'] = stored;
      notifyListeners();

      debugPrint('[BADGES] Awarded: ${newBadges.map((b) => b.id).join(', ')}');
      return newBadges;
    } catch (e) {
      debugPrint('[BADGES] Could not award badges: $e');
      return [];
    } finally {
      _awardingBadges = false;
    }
  }

  List<dynamic> get dataPoints => _userData?['dataPoints'] ?? [];
  List<DataPoint> get collectedMeasurements => _collectedMeasurements;
  List<SessionData> get collectedSessions => _collectedSessions;

  // Inside UserDataProvider class in user_data_manager.dart
  bool get vpnStatus => (_userData?['isVPN'] as bool?) ?? false;

  List<GameData> get favoriteGames {
    if (_userData == null) {
      return [];
    }

    final rawFavorites = _userData!['favoriteGames'];
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

    final rawFavorites = _userData!['favoriteGames'];
    List<dynamic> currentFavorites = (rawFavorites is List) 
        ? List.from(rawFavorites) 
        : ['Zombie Apocalypse', 'Soul Seeker'];

    if (currentFavorites.contains(gameName)) {
      currentFavorites.remove(gameName);
    } else {
      currentFavorites.add(gameName);
    }

    _userData!['favoriteGames'] = currentFavorites;
    notifyListeners();

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('userAccountData')
            .doc(accountIdFor(user))
            .update({'favoriteGames': currentFavorites});
        debugPrint('Favorites updated in Firestore');
      }
    } catch (e) {
      debugPrint('Error updating favorites: $e');
    }
  }

  Future<List<DataPoint>> fetchCollectedMeasurements() async {
    final email = accountIdFor(FirebaseAuth.instance.currentUser);
    if (email.isEmpty) return [];

    final snapshot_collected_points = await FirebaseFirestore.instance
        .collection('measurements')
        .doc(email)
        .collection('collected_measurements')
        .get();

    return snapshot_collected_points.docs.map((doc) => DataPoint.fromFirestore(doc)).toList();
  }

  Future<List<SessionData>> fetchSessionData() async {
    final email = accountIdFor(FirebaseAuth.instance.currentUser);
    if (email.isEmpty) return [];

    final sessionSnapshot = await FirebaseFirestore.instance
        .collection('measurements')
        .doc(email)
        .collection('sessions')
        .get();

    return sessionSnapshot.docs.map((doc) => SessionData.fromFirestore(doc)).toList();
  }

  void updateTotalPointsCollected(int numPoints, String userEmail) {
    if (_userData == null) return;

    int currentPointsCount = totalPointsCollected;
    int newPointsCount = currentPointsCount + numPoints;

    // Correctly update the internal map using bracket notation
    _userData!['totalPointsCollected'] = newPointsCount;

    // Tell the UI to rebuild
    notifyListeners();

    // Sync with Firestore
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      FirebaseFirestore.instance
          .collection('userAccountData')
          .doc(userEmail)
          .update({'totalPointsCollected': newPointsCount});
    }
  }

  void updateDistanceTraveled(double addedDistance, String userEmail) {
    if (_userData == null) return;

    double currentDist = totalDistanceTraveled;
    double updatedDist = currentDist + addedDistance;

    // Correctly update the internal map using bracket notation
    _userData!['totalDistanceTraveled'] = updatedDist;

    // Tell the UI to rebuild
    notifyListeners();

    // Sync with Firestore
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      FirebaseFirestore.instance
          .collection('userAccountData')
          .doc(userEmail)
          .update({'totalDistanceTraveled': updatedDist});
    }
  }

  Future<void> updateTotalLocationPoints(int pointCount, String email) async {
    // Pull existing totals
    int currentNum = totalLocationPointsMeasured;

    if (currentNum + pointCount == 0) return;

    int newNum = currentNum + pointCount;

    _userData!['totalLocationPointsMeasured'] = newNum;
    notifyListeners();

    // Sync with Firestore
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      FirebaseFirestore.instance
          .collection('userAccountData')
          .doc(email)
          .update({'totalLocationPointsMeasured': newNum});
    }
  }

  Future<void> updateRadiusGyration(double sessionRg, int pointCount, String email) async {
    // Pull existing totals
    double currentRg = totalRadiusGyration;         // existing stored Rg
    int currentCount = totalLocationPointsMeasured;      // total points across all sessions

    if (currentCount + pointCount == 0) return;

    // Weighted RMS combination
    double newRg = sqrt(
        ((currentCount * currentRg * currentRg) + (pointCount * sessionRg * sessionRg)) /
            (currentCount + pointCount)
    );

    _userData!['totalRadiusGyration'] = newRg;
    notifyListeners();

    // Sync with Firestore
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      FirebaseFirestore.instance
          .collection('userAccountData')
          .doc(email)
          .update({'totalRadiusGyration': totalRadiusGyration});
    }
  }

  // Remembers that the welcome pop-up has been shown, so it only appears once per account or guest.
  Future<void> markWelcomeSeen() async {
    _userData?['welcomeSeen'] = true;
    notifyListeners();

    try {
      final id = accountIdFor(FirebaseAuth.instance.currentUser);
      if (id.isEmpty) return;
      // merge, so this works even if the profile document is missing some fields
      await FirebaseFirestore.instance
          .collection('userAccountData')
          .doc(id)
          .set({'welcomeSeen': true}, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error saving that the welcome pop-up was seen: $e');
    }
  }

  Future<void> setDemographicStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('userAccountData')
            .doc(accountIdFor(user))
            .update({'demographicsSurveyTaken': true});

        if (_userData != null) {
          _userData!['demographicsSurveyTaken'] = true;
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
          .collection('userAccountData')
          .doc(accountIdFor(user))
          .get();

      if (doc.exists) {
        _userData = doc.data() as Map<String, dynamic>;

        // 2. Now that we know it exists, update the measurement count
        _collectedSessions = await fetchSessionData();
        final totalPoints = _collectedSessions.fold<int>(0, (sum, s) => sum + (s.pointsCollected ?? 0));
        await FirebaseFirestore.instance
            .collection('userAccountData')
            .doc(accountIdFor(user))
            .update({'totalPointsCollected': totalPoints});
        _userData?['totalPointsCollected'] = totalPoints;

        // players who already have history get their badges now
        announceBadges(await awardNewBadges());

        /*bool vpn = await checkVPN();
        bool fake = await checkFakeLocation();
        await FirebaseFirestore.instance.collection('userData').doc(user.uid).update({
          'isVPN': vpn,
          'isFakeLocation': fake,
        });

        _userData?['isVPN'] = vpn;
        _userData?['isFakeLocation'] = fake;*/

        final onboardingQuery = await FirebaseFirestore.instance
            .collection('ABC_Onboarding')
            .doc('user')
            .collection('user')
            .where('email', isEqualTo: accountIdFor(user))
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

        debugPrint("Data loaded for: ${accountIdFor(user)}. Measurements found: ${_collectedMeasurements.length}");
      } else {
        debugPrint("No document found for UID: ${accountIdFor(user)}, creating one...");
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
        .where('email', isEqualTo: accountIdFor(user))
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
        .collection('userAccountData')
        .doc(accountIdFor(user))
        .set({
      'uid': user.uid,
      'email': accountIdFor(user),
      'isGuest': isGuest(user),
      'demographicsSurveyTaken' : false,
      'totalPointsCollected': 0,
      'totalDistanceTraveled': 0.0,
      'dataPoints': [],
      'radGyration': [0],
      'favoriteGames': ['Zombie Apocalypse', 'Soul Seeker'],
      'createdAt': FieldValue.serverTimestamp(),
      //'isVPN' : vpn,
      //'isFakeLocation' : fake,
    }, SetOptions(merge: true));
  }

  Future<void> createOnboardingDocument(User user) async {
    await FirebaseFirestore.instance
        .collection('ABC_Onboarding')
        .doc('user')
        .collection('user')
        .add({
      'email': accountIdFor(user),
      'messages_seen': {
        "control_message": false,
        "play_message": false,
        "utility_message": false,
      }
    });
  }

  String get remoteSurveyDocId => RemoteConfigService().surveyDocId;

  // Add these getters
  DateTime? get lastSurveyShown {
    final ts = _userData?['lastSurveyShown'];
    if (ts is Timestamp) return ts.toDate();
    return null;
  }

  int get surveyCooldownDays => RemoteConfigService().getInt('survey_cooldown_days');

// Call this after a survey is submitted
  Future<void> recordSurveyShown(String userEmail) async {
    final now = DateTime.now();
    _userData?['lastSurveyShown'] = Timestamp.fromDate(now);
    notifyListeners();

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('userAccountData')
          .doc(userEmail)
          .update({'lastSurveyShown': FieldValue.serverTimestamp()});
    }
  }

  String get lastSeenSurveyToken => _userData?['lastSeenSurveyToken'] ?? '';

  bool get shouldShowSurvey {
    final rc = RemoteConfigService();
    final activeToken = rc.surveyTriggerToken;

    // No active survey pushed
    if (activeToken.isEmpty) return false;

    // User has already responded to this wave
    if (lastSeenSurveyToken == activeToken) return false;

    return true;
  }

// Call this when the user submits or dismisses the survey
  Future<void> recordSurveyToken(String userEmail) async {
    final token = RemoteConfigService().surveyTriggerToken;
    _userData?['lastSeenSurveyToken'] = token;
    notifyListeners();

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('userAccountData')
          .doc(userEmail)
          .update({'lastSeenSurveyToken': token});
    }
  }

  void clearData() {
    _userData = null;
    _seenMessages = null;
    notifyListeners();
    debugPrint('User data cleared');
  }
}
