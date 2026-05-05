// References
// https://firebase.google.com/docs/firestore/query-data/aggregation-queries#dart

// importing libraries and packages
import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';
import 'flutter_bridge.dart';
import 'poi_generator.dart';
import 'user_data_manager.dart';
import 'package:uuid/uuid.dart';
import 'vibration_controller.dart';
import 'user_data_manager.dart';
import 'package:dart_geohash/dart_geohash.dart';
import 'package:vpn_connection_detector/vpn_connection_detector.dart';
import 'package:detect_fake_location/detect_fake_location.dart';
import 'dart:convert';
import 'mapping.dart';
import 'package:flutter/material.dart';
import 'package:internet_measurement_games_app/location_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'session_manager.dart';
import 'vibration_controller.dart';
import 'dart:async';
import 'ndt7_service.dart';
import 'poi_generator.dart';
import 'package:provider/provider.dart';
import 'user_data_manager.dart';
import 'package:uuid/uuid.dart';
//import 'package:dart_geohash/dart_geohash.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import 'session_manager.dart';

// data type for measurements
class InternetMeasurement {
  final double uploadSpeed;
  final double downloadSpeed;
  final double jitters;
  final double latency;

  InternetMeasurement({required this.uploadSpeed, required this.downloadSpeed,
    required this.jitters, required this.latency});
}

// used to track data that needs to be accessible across files/functions
class SessionManager {
  static String? _sessionId;
  //static String? _playerName;
  static String? _currentGame;
  static List<PointOfInterest> _poiList = [];
  // TODO: Add a global list of location points
  static List<LocationPoint> sessionLocationPoints = [];
  // keeps track of when the game screen closes
  static Future<void> Function()? onWebViewClose;
  static List<InternetMeasurement> _measurements = [];
  static List<InternetMeasurement> get measurements => _measurements;
  static void addMeasurement(InternetMeasurement m) => _measurements.add(m);
  static DateTime _startTime = DateTime.now();
  static DateTime get startTime =>_startTime;
  static bool vpnStatus = false;
  static bool fakeLocationStatus = false;
  String userEmail = "";

  static String? get sessionId => _sessionId;
 // static String? get playerName => _playerName;
  static String? get currentGame => _currentGame;
  static List<PointOfInterest> get poiList => _poiList;

  // sets the session ID
  static void setSessionId() {
    // unique session ID for game
    var gameSessionID = Uuid().v4();
    _sessionId = gameSessionID;
  }

  // security things
  Future<bool> checkVPN() async {
    bool isVpnConnected = await VpnConnectionDetector.isVpnActive();
    return isVpnConnected;
  }

  Future<bool> checkFakeLocation() async {
    bool isFakeLocation = await DetectFakeLocation().detectFakeLocation();
    return isFakeLocation;
  }

  // updates current game when game is started
  static void startGame(String gameTitle){
    // make sure there is not a session unintentionally going, clear lists
    _startTime = DateTime.now();
    _measurements.clear();
    sessionLocationPoints.clear();
    _currentGame = gameTitle;
    setSessionId();
    debugPrint('[SESSION_MANAGER] Game started: $_currentGame');
  }

  // updates current game to null when game is closed
  static Future<void> endGame() async {
    debugPrint('[SESSION_MANAGER] Game ending: $_currentGame');

    // Trigger the WebView's session recording logic if the bridge is plugged in
    await onWebViewClose?.call();
    VibrationController.stop();

    _currentGame = null;
    debugPrint('[SESSION_MANAGER] Session cleared.');
  }

  // sets the poi list for games that use them
  static void setPOIs(List<PointOfInterest> pois){
    _poiList = pois;
    debugPrint("[SESSION_MANAGER]: Setting POIs. POIs are: $_poiList");
  }

  // function to identify which POI in the list is closest to the user
  static PointOfInterest? getNearestPOI(Position userPos)
  {
    if (_poiList.isEmpty)
    {
      return null;
    }

    return _poiList.reduce((closest, current){
      final distToCurrent = Geolocator.distanceBetween(
        userPos.latitude,
        userPos.longitude,
        current.latitude!,
        current.longitude!,
      );
      final distToClosest = Geolocator.distanceBetween(
        userPos.latitude,
        userPos.longitude,
        closest.latitude!,
        closest.longitude!,
      );

      debugPrint("[SESSION_MANAGER] Nearest POI: $closest");
      debugPrint("[SESSION_MANAGER] Player's distance from closest: $distToClosest");

      return distToCurrent < distToClosest ? current : closest;
    });
  }


  static Future<void> saveCurrentSession(String userEmail) async {
    VibrationController.stop();
    vpnStatus = await SessionManager().checkVPN();
    fakeLocationStatus = await SessionManager().checkFakeLocation();
    UserDataProvider provider = UserDataProvider();
    // calculate total distance traveled
    double distanceTraveled = calculateDistance(sessionLocationPoints);
    // update user data on record
    // TODO: This may need to be updated differently?
    provider.updateDistanceTraveled(distanceTraveled, userEmail);
    DateTime endTime = DateTime.now();
    debugPrint("[FLUTTER_BRIDGE] In endGameSession case.");

    debugPrint("[FLUTTER_BRIDGE] Verifying measurements were recorded: $measurements");


    // format data to send to firebase for this session
    final checkData = {
      'game': SessionManager.currentGame,
      'start_time': startTime,
      'end_time': endTime,
      'session_id': SessionManager.sessionId,
      'vpn_used' : vpnStatus,
      'session_distance': distanceTraveled,
      'collected_measurements': measurements.map((p) => {
        'upload_speed': p.uploadSpeed,
        'download_speed': p.downloadSpeed,
        'latency': p.latency,
        'jitters': p.jitters
      }).toList(),
      'location_points': sessionLocationPoints.map((p) => {
        'latitude': p.latitude,
        'longitude': p.longitude,
        'geohash': GeoFirePoint(GeoPoint(p.latitude, p.longitude)),
      }).toList(),
    };
    debugPrint("[FLUTTER_BRIDGE] Formatted data for firestore.");

    // send to firebase
    try {
      debugPrint("Attempting to write to Firestore...");
      await FirebaseFirestore.instance
          .collection('measurements')
          .doc(userEmail)
          .collection('sessions')
          .add(checkData);
      debugPrint("Write successful!");
    } catch (e) {
      debugPrint("Firestore Error: $e");
    }
  }

  /* // stores the nickname of the current player
  static void setPlayerName(String name){
    _playerName = name;
    debugPrint('[SESSION_MANAGER] Player name set to $_playerName');
  }*/
  // take all location points, calculate distance traveled
  static double calculateDistance(List<LocationPoint> pointsVisited) {
    double totalDistance = 0.0;
    for(int point = 0; point < pointsVisited.length - 1; point++) {
      double distanceBetween = Geolocator.distanceBetween(
          pointsVisited[point].latitude,
          pointsVisited[point].longitude,
          pointsVisited[point + 1].latitude,
          pointsVisited[point + 1].longitude);
      totalDistance += distanceBetween;
    }
    debugPrint("[FLUTTER_BRIDGE] Session distance traveled: $totalDistance");
    return totalDistance;
  }


}