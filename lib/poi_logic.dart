// The rules behind finding points of interest (POIs) in the games, kept free of the WebView so they can be tested:
// what direction to point the player in, and how the "move a distance instead" fallback keeps track of progress.

import 'package:geolocator/geolocator.dart';
import 'user_data_manager.dart';

// How far the player has to move between "finds" when there are no POIs nearby, to simulate having to walk to one.
// This is the one number to change to make the fallback shorter or longer.
const double fallbackDistanceKilometers = 1;
const double fallbackDistanceMeters = fallbackDistanceKilometers * 1000;

// A distance in words a player can follow: "1.5 km", "350 meters", "30 meters".
String formatDistance(double meters) {
  if (meters >= 950) {
    // whole kilometers show without a decimal ("2 km"), others to one decimal ("1.5 km")
    final km = (meters / 1000).toStringAsFixed(1);
    return '${km.endsWith('.0') ? km.substring(0, km.length - 2) : km} km';
  }
  if (meters >= 100) {
    // nearest 10 meters: a precise number would be false precision on a phone's GPS
    return '${(meters / 10).round() * 10} meters';
  }
  final whole = meters.round() < 1 ? 1 : meters.round();
  return whole == 1 ? '1 meter' : '$whole meters';
}

// How much further the player has to go in the "move a distance" fallback, given how far they have moved since their
// last find. Never below zero: once they have moved far enough there is nothing left to go.
double fallbackRemainingMeters(double metersMoved) {
  final remaining = fallbackDistanceMeters - metersMoved;
  return remaining < 0 ? 0 : remaining;
}

// What to tell a player in the "move a distance" fallback, given how far they have moved since their last find.
// Once they have moved far enough it says so, rather than a distance that has gone to zero or below.
String fallbackHint(double metersMoved) {
  final remaining = fallbackRemainingMeters(metersMoved);
  if (remaining <= 0) return "You've moved far enough. Try searching now!";
  return 'Keep going! You need to travel ${formatDistance(remaining)} further!';
}

// How often the phone should pulse to tell the player how close they are, given the distance in meters to what they
// are looking for: the nearest POI, or (in the fallback) the distance they still have to move. Null means no
// vibration, because they are still too far away to feel anything.
Duration? pulseDelayForDistance(double distanceMeters) {
  // pulse every 250ms if within 7 meters
  if (distanceMeters <= 7) return const Duration(milliseconds: 250);
  // pulse every 500ms if within 15 meters
  if (distanceMeters <= 15) return const Duration(milliseconds: 500);
  // pulse every 1000ms if within 23 meters
  if (distanceMeters <= 23) return const Duration(milliseconds: 1000);
  // pulse every 2000ms if within 30 meters
  if (distanceMeters <= 30) return const Duration(milliseconds: 2000);
  // don't vibrate if beyond 30 meters
  return null;
}

// Turns a bearing into words, given which way the player is facing.
// [bearingToPoi] is the compass direction from the player to the POI and [heading] is where the player is facing,
// both in degrees.
String directionHint(double bearingToPoi, double heading) {
  // how far round to the right of the player's facing direction the POI is (0 to 360)
  double relativeBearing = (bearingToPoi - heading) % 360;
  if (relativeBearing < 0) relativeBearing += 360;

  if (relativeBearing >= 330 || relativeBearing < 30) return 'in front of you';
  if (relativeBearing >= 30 && relativeBearing < 150) return 'to your right';
  if (relativeBearing >= 150 && relativeBearing < 210) return 'behind you';
  return 'to your left';
}

// Keeps track of the fallback used when there are no POIs: the player must move [fallbackDistanceMeters] from
// the last place they "found" something ([fallbackDistanceKilometers]).
class FallbackTracker {
  // where progress is measured from; null until a start is known
  LocationPoint? _start;

  LocationPoint? get start => _start;

  // forget the start, e.g. when a new game begins
  void reset() => _start = null;

  // measure from here
  void startFrom(LocationPoint point) => _start = point;

  double _distanceTo(LocationPoint here) => Geolocator.distanceBetween(
        _start!.latitude,
        _start!.longitude,
        here.latitude,
        here.longitude,
      );

  // How far the player has moved since the start, in meters. If there is no start yet, the player's current
  // position becomes the start (they have not moved yet).
  double distanceMoved(LocationPoint here) {
    if (_start == null) {
      _start = here;
      return 0;
    }
    return _distanceTo(here);
  }

  // true if the player has moved far enough to "find" something; the find then becomes the new start
  bool checkFind(LocationPoint here) {
    if (_start == null) {
      // the first check has nothing to compare with, so it only sets where to measure from
      _start = here;
      return false;
    }
    // the same test the hint uses: at exactly the distance the player has moved far enough
    if (_distanceTo(here) >= fallbackDistanceMeters) {
      _start = here;
      return true;
    }
    return false;
  }
}
