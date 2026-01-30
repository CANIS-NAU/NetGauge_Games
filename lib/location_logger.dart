import 'location_service.dart';
import 'session_manager.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';
import 'poi_generator.dart';

// class that manages logging of persistent location data to firestore
class LocationLogger {
  static int _writeCount = 0;

  static void start() {
    debugPrint("[LOCATION_LOGGER] Starting location logging.");
    LocationDispatcher.stream.listen((Position pos) async {
      _writeCount++;

      //testing POI fetch
      LocationData currentPosition = await determineLocationData();
      double latitude = currentPosition.position.latitude;
      double longitude = currentPosition.position.longitude;
      double radius = 5000;
      List pointsOfInterest = await OverpassService().fetchNearestPOIs(latitude: latitude, longitude: longitude, radius: radius, limit: 3);
      debugPrint('[LOCATION_TEST]: Current Latitude is $latitude');
      debugPrint('[LOCATION_TEST]: Current Longitude is $longitude');
      debugPrint('[LOCATION_TEST]: Nearest POIs in 5km radius are $pointsOfInterest');


      debugPrint("[LOCATION_LOGGER] Location update received. Count: $_writeCount");
      debugPrint("[LOCATION_LOGGER] Current game: ${SessionManager.currentGame}");
      //debugPrint("[LOCATION_LOGGER] Player name: ${SessionManager.playerName}");
      debugPrint("[LOCATION_LOGGER] Session ID: ${SessionManager.sessionId}");

      // only writing every 5th location update and only if a game is being played and a player has been declared
      if (_writeCount % 5 == 0 && (SessionManager.currentGame != null)) {
        debugPrint("[LOCATION_LOGGER] Writing location data to Firestore...");
        
        final firestore = FirebaseFirestore.instance;
        final sessionId = SessionManager.sessionId;
        
        // First, ensure the session document exists
        await firestore
          .collection('Movement Data')
          .doc(sessionId)
          .set({
            'sessionId': sessionId,
            //'playerName': SessionManager.playerName,
            'created': DateTime.now().toIso8601String(),
          }, SetOptions(merge: true)); // merge: true prevents overwriting existing data
        
        // Then add the location data to the subcollection
        await firestore
          .collection('Movement Data')
          .doc(sessionId)
          .collection('LocationData')
          .add({
            'latitude': pos.latitude,
            'longitude': pos.longitude,
            'datetime': DateTime.now().toIso8601String(),
            'game': SessionManager.currentGame,
            //'player': SessionManager.playerName,
          });
        debugPrint("[LOCATION_LOGGER] Location Logged successfully to session: $sessionId");
      } else {
        debugPrint("[LOCATION_LOGGER] Skipped Location Logging");
        debugPrint("[LOCATION_LOGGER] Game: ${SessionManager.currentGame}");
        //debugPrint("[LOCATION_LOGGER] Name: ${SessionManager.playerName}");
        debugPrint("[LOCATION_LOGGER] Session ID: ${SessionManager.sessionId}");
      }
    });
  }
}