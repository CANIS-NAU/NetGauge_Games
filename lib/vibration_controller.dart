import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:vibration/vibration.dart';
import 'location_service.dart';
import 'session_manager.dart';

// controls incremental vibration in games that require searching for POIs

  class VibrationController {
    static StreamSubscription<Position>? _locationSub;
    static Timer? _vibrationTimer;

    static void start() {
      // If no POIS are set, don't do anything
      if (SessionManager.poiList.isEmpty) {
        print("No POIs detected. VibrationController not started");
        return;
      }

      // subscribe to location stream
      _locationSub = LocationDispatcher.stream.listen((Position position) async {
        // If no game is set or the poi list ends up empty, terminate vibration
        if(SessionManager.currentGame == null || SessionManager.poiList.isEmpty) {
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
          nearest['latitude']!,
          nearest['longitude']!
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
          if(await Vibration.hasVibrator() ?? false) {
            Vibration.vibrate(duration: 100);
          }
        });
      });

      print("VibrationController started");
    }

    // function to stop the vibration service
    static void stop() {
      // close stream
      _locationSub?.cancel();
      _locationSub = null;

      // terminate timer
      _vibrationTimer?.cancel();
      _vibrationTimer = null;

      print("VibrationController stopped");
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