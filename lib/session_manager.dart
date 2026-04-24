// References
// https://firebase.google.com/docs/firestore/query-data/aggregation-queries#dart

// importing libraries and packages
import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';
import 'flutter_bridge.dart';
import 'poi_generator.dart';
import 'user_data_manager.dart';
import 'package:uuid/uuid.dart';

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

 /* // stores the nickname of the current player
  static void setPlayerName(String name){
    _playerName = name;
    debugPrint('[SESSION_MANAGER] Player name set to $_playerName');
  }*/
  // TODO: Calculates distance traveled between collected locations
  static Future<void> calculateLocationDistance() async {

  }

  // updates current game when game is started
  static void startGame(String gameTitle){
    _currentGame = gameTitle;
    setSessionId();
    debugPrint('[SESSION_MANAGER] Game started: $_currentGame');
  }

  // updates current game to null when game is closed
  static Future<void> endGame() async {
    debugPrint('[SESSION_MANAGER] Game ending: $_currentGame');

    // Trigger the WebView's session recording logic if the bridge is plugged in
    await onWebViewClose?.call();

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
}