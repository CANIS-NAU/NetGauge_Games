import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';

// used to track data that needs to be accessible across files/functions
class SessionManager {
  static String? _sessionId;
  //static String? _playerName;
  static String? _currentGame; 
  static List<Map<String, double>> _poiList = [];

  static String? get sessionId => _sessionId;
 // static String? get playerName => _playerName;
  static String? get currentGame => _currentGame;
  static List<Map<String, double>> get poiList => _poiList;

  // sets the session ID
  static void setSessionId(String id) {
    _sessionId = id;
  }

 /* // stores the nickname of the current player
  static void setPlayerName(String name){
    _playerName = name;
    debugPrint('[SESSION_MANAGER] Player name set to $_playerName');
  }*/

  // updates current game when game is started
  static void startGame(String gameTitle){
    _currentGame = gameTitle;
    debugPrint('[SESSION_MANAGER] Game started: $_currentGame');
  }

  // updates current game to null when game is closed
  static void endGame(){
    debugPrint('[SESSION_MANAGER] Game ended: $_currentGame');
    _currentGame = null;
  }

  // sets the poi list for games that use them
  static void setPOIs(List<Map<String, double>> pois){
    _poiList = pois;
  }

  // function to identify which POI in the list is closest to the user
  static Map<String, double>? getNearestPOI(Position userPos)
  {
    if (_poiList.isEmpty)
    {
      return null;
    }

    return _poiList.reduce((closest, current){
      final distToCurrent = Geolocator.distanceBetween(
        userPos.latitude,
        userPos.longitude,
        current['latitude']!,
        current['longitude']!,
      );
      final distToClosest = Geolocator.distanceBetween(
        userPos.latitude,
        userPos.longitude,
        closest['latitude']!,
        closest['longitude']!,
      );

      debugPrint("[SESSION_MANAGER] Nearest POI: $closest");

      return distToCurrent < distToClosest ? current : closest;
    });
  }  
}