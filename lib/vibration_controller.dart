import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:vibration/vibration.dart';
import 'location_service.dart';
import 'poi_logic.dart';
import 'session_manager.dart';
import 'package:flutter/material.dart';
import 'user_data_manager.dart';

// controls incremental vibration in games that require searching for POIs

// Vibration controller is started from within the game by posting a 'startVibrationService'
// message. It may also be stopped/cleared in the game files, but is also stopped whenever
// the player closes a game.
//
// The phone pulses faster the closer the player gets to what they are looking for: the nearest POI, or, when
// there are no POIs nearby, the distance they still have to move (see FallbackTracker in poi_logic.dart).

  class VibrationController {
    static StreamSubscription<Position>? _locationSub;
    static Timer? _vibrationTimer;
    // how often the phone is pulsing right now (null when it is not)
    static Duration? _currentDelay;

    static void start() {
      stop();

      // Each location update decides for itself whether to follow a POI or the fallback distance, so the vibration
      // stays right if POIs turn up (or run out) after it has started.
      _locationSub = LocationDispatcher.stream.listen(_onLocation);

      debugPrint("[VIBRATION_CONTROLLER] VibrationController started");
    }

    static void _onLocation(Position position) {
      // If no game is set, terminate vibration
      if (SessionManager.currentGame == null) {
        stop();
        return;
      }

      final double distance;
      if (SessionManager.hasPois) {
        // get POI nearest the player current position
        final nearest = SessionManager.getNearestPOI(position);
        // handle failure to grab the location
        if (nearest == null) return;

        // the distance between the player and the nearest poi
        distance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          nearest.latitude,
          nearest.longitude,
        );
      } else {
        // no POIs: the distance the player still has to move (zero once they have moved far enough, which pulses
        // fastest until they search and the distance starts again)
        final here = LocationPoint(longitude: position.longitude, latitude: position.latitude);
        distance = fallbackRemainingMeters(SessionManager.fallback.distanceMoved(here));
      }

      // determine delay between vibration pulses based on how close the player is
      _setPulse(pulseDelayForDistance(distance));
    }

    // Pulses at the given rate, or stops pulsing for null. The timer is only restarted when the rate changes:
    // restarting it on every location update could keep it from ever reaching its next pulse.
    static void _setPulse(Duration? delay) {
      if (delay == _currentDelay && (delay == null || _vibrationTimer != null)) return;

      _vibrationTimer?.cancel();
      _vibrationTimer = null;
      _currentDelay = delay;
      if (delay == null) return;

      _vibrationTimer = Timer.periodic(delay, (_) async {
        if (await Vibration.hasVibrator()) {
          Vibration.vibrate(duration: 100);
        }
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
      _currentDelay = null;

      debugPrint("[VIBRATION_CONTROLLER] VibrationController stopped");
    }
  }
