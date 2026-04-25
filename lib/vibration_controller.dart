import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:vibration/vibration.dart';
import 'location_service.dart';
import 'session_manager.dart';
import 'package:flutter/material.dart';
import 'user_data_manager.dart';

// controls incremental vibration in games that require searching for POIs

// Vibration controller is started from within the game by posting a 'startVibrationService'
// message. It may also be stopped/cleared in the game files, but is also stopped whenever
// the player closes a game.

  class VibrationController {
    static StreamSubscription<Position>? _locationSub;
    static Timer? _vibrationTimer;

    static void start() {
      // If no POIS are set, don't do anything
      if (SessionManager.poiList.isEmpty) {
        debugPrint("[VIBRATION_CONTROLLER] No POIs detected. Using backup vibration controller.");
        startNoPOIs();
      }else{
        debugPrint("[VIBRATION_CONTROLLER] Vibration manager started");
      }

      // subscribe to location stream
      _locationSub = LocationDispatcher.stream.listen((Position position) async {
        // If no game is set or the poi list ends up empty, terminate vibration
        if(SessionManager.currentGame == null) {
          stop();
          return;
        }

        // get POI nearest the player current position
        final nearest = SessionManager.getNearestPOI(position);
        // handle failure to grab the location
        if (nearest == null) return;

        // compute the distance between the the player pos and the nearest poi
        final distance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          nearest.latitude!,
          nearest.longitude!
        );

        // determine delay between vibration pulses based on distance to nearest poi
        final delay = _getDelayForDistance(distance);

        // terminate vibration if player is too far from any poi
        if(delay == null) {
          _vibrationTimer?.cancel();
          return;
        }

        // reset vibration timer
        _vibrationTimer?.cancel();
        _vibrationTimer = Timer.periodic(delay, (_) async {
          if(await Vibration.hasVibrator()) {
            Vibration.vibrate(duration: 100);
          }
        });
      });

      debugPrint("[VIBRATION_CONTROLLER] VibrationController started");
    }

    static void startNoPOIs() {
      _locationSub = LocationDispatcher.stream.listen((Position position) async {
        // If no game is set
        // TODO: This is getting called when games are played because they for some reason are listed as null. Fix.
        if(SessionManager.currentGame == null) {
          stop();
          return;
        }

        // get current distance traveled
        LocationPoint firstTracked = SessionManager.sessionLocationPoints[0];
        LocationPoint mostRecentTracked = SessionManager.sessionLocationPoints.last;
        double currentDist = Geolocator.distanceBetween(firstTracked.latitude, firstTracked.longitude,
            mostRecentTracked.latitude, mostRecentTracked.longitude);

        // handle failure to grab the current distance traveled
        if (currentDist == null) return;

        // TODO: Increase this for actual deployment, keeping small for testing
        const distance = 5.0;

        // determine delay between vibration pulses based on distance to nearest poi
        final delay = _getDelayForDistance(distance);

        // terminate vibration if player is too far from any poi
        if(delay == null) {
          _vibrationTimer?.cancel();
          return;
        }

        // reset vibration timer
        _vibrationTimer?.cancel();
        _vibrationTimer = Timer.periodic(delay, (_) async {
          if(await Vibration.hasVibrator()) {
            Vibration.vibrate(duration: 100);
          }
        });
      });
    }

    // function to stop the vibration service
    static void stop() {
      // close stream
      _locationSub?.cancel();
      _locationSub = null;

      // terminate timer
      _vibrationTimer?.cancel();
      _vibrationTimer = null;

      debugPrint("[VIBRATION_CONTROLLER] VibrationController stopped");
    }

    // handles determining delay between vibration pulses based on distance
    static Duration? _getDelayForDistance(double distanceMeters) {
      // pulse every 250ms if within 7 meters
      if(distanceMeters <= 7) return const Duration(milliseconds: 250);
      // pulse every 500ms if within 15 meters
      if(distanceMeters <= 15) return const Duration(milliseconds: 500);
      // pulse every 1000ms if within 23 meters
      if(distanceMeters <= 23) return const Duration(milliseconds: 1000);
      // pulse every 2000ms if within 30 meters
      if(distanceMeters <= 30) return const Duration(milliseconds: 2000);
      // don't vibrate if beyond 30 meters
      return null;
    }
  }