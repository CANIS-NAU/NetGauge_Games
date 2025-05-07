import 'location_service.dart';
import 'session_manager.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';

// class that manages logging of persistent location data to firestore
class LocationLogger {
  static int _writeCount = 0;

  static void start() {
    LocationDispatcher.stream.listen((Position pos) async {
      _writeCount++;

      // only writing every 5th location update and only if a game is being played and a player has been declared
      if (_writeCount % 5 == 0 && (SessionManager.currentGame != null && SessionManager.playerName != null)) {
        await FirebaseFirestore.instance
          .collection('Movement Data')
          .doc(SessionManager.sessionId)
          .collection('LocationData')
          .add({
            'latitude': pos.latitude,
            'longitude': pos.longitude,
            'datetime': DateTime.now().toIso8601String(),
            'game': SessionManager.currentGame,
            'player': SessionManager.playerName,
          });
        debugPrint("[LOCATION_LOGGER] Location Logged");
      } else {
        debugPrint("[LOCATION_LOGGER] Skipped Location Logging");
      }
    });
  }
}