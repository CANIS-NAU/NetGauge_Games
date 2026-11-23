import 'package:flutter_test/flutter_test.dart';
import 'package:internet_measurement_games_app/poi_logic.dart';
import 'package:internet_measurement_games_app/user_data_manager.dart';

LocationPoint at(double lat, double lng) => LocationPoint(latitude: lat, longitude: lng);

void main() {
  group('directionHint', () {
    test('says where the POI is relative to the way the player faces', () {
      // player facing north (0 degrees)
      expect(directionHint(0, 0), 'in front of you');
      expect(directionHint(20, 0), 'in front of you');
      expect(directionHint(340, 0), 'in front of you');
      expect(directionHint(90, 0), 'to your right');
      expect(directionHint(180, 0), 'behind you');
      expect(directionHint(270, 0), 'to your left');
    });

    test('depends on the way the player is facing, not just the compass bearing', () {
      // the POI is due east (90 degrees)
      expect(directionHint(90, 90), 'in front of you'); // facing east
      expect(directionHint(90, 180), 'to your left'); // facing south
      expect(directionHint(90, 270), 'behind you'); // facing west
      expect(directionHint(90, 0), 'to your right'); // facing north
    });

    test('handles the wrap-around at north', () {
      expect(directionHint(10, 350), 'in front of you'); // 20 degrees to the right
      expect(directionHint(350, 10), 'in front of you'); // 20 degrees to the left
      expect(directionHint(10, 340), 'to your right'); // exactly 30 degrees round, across the north wrap-around
    });

    test('the sector edges', () {
      expect(directionHint(30, 0), 'to your right');
      expect(directionHint(329.9, 0), 'to your left');
      expect(directionHint(330, 0), 'in front of you');
      expect(directionHint(150, 0), 'behind you');
      expect(directionHint(210, 0), 'to your left');
    });

    test('is never the error message the games used to get', () {
      for (var bearing = 0.0; bearing < 360; bearing += 15) {
        for (var heading = 0.0; heading < 360; heading += 45) {
          expect(directionHint(bearing, heading), isNot(contains('ERROR')));
        }
      }
    });
  });

  group('FallbackTracker (no POIs nearby, so the player moves a distance instead)', () {
    const lat = 35.0;
    const lng = -111.0;
    // 0.001 degrees of latitude is about 111 m, and the player has to move fallbackDistanceKilometers (1 km)
    const smallMove = 0.002; // about 220 m: well short
    const bigMove = 0.012; // about 1.3 km: far enough

    test('has no start until it is given one, and does not crash before then', () {
      final tracker = FallbackTracker();
      expect(tracker.start, isNull);
      // asking how far the player has moved before there is a start just makes this the start
      expect(tracker.distanceMoved(at(lat, lng)), 0);
      expect(tracker.start, isNotNull);
    });

    test('the first check only sets the starting point (it can never be a free find)', () {
      final tracker = FallbackTracker();
      expect(tracker.checkFind(at(lat, lng)), isFalse);
      expect(tracker.start!.latitude, lat);
    });

    test('a small move is not enough, a big one is', () {
      final tracker = FallbackTracker()..startFrom(at(lat, lng));
      expect(tracker.checkFind(at(lat + smallMove, lng)), isFalse);
      expect(tracker.checkFind(at(lat + bigMove, lng)), isTrue);
    });

    test('after a find the player has to move again from there', () {
      final tracker = FallbackTracker()..startFrom(at(lat, lng));
      expect(tracker.checkFind(at(lat + bigMove, lng)), isTrue);
      // standing where they just found something does not find another
      expect(tracker.checkFind(at(lat + bigMove, lng)), isFalse);
      expect(tracker.checkFind(at(lat + bigMove + smallMove, lng)), isFalse);
      expect(tracker.checkFind(at(lat + 2 * bigMove, lng)), isTrue);
    });

    test('a failed check does not move the start, so progress adds up', () {
      final tracker = FallbackTracker()..startFrom(at(lat, lng));
      expect(tracker.checkFind(at(lat + smallMove, lng)), isFalse);
      expect(tracker.start!.latitude, lat); // still measured from the original start
      expect(tracker.checkFind(at(lat + bigMove, lng)), isTrue);
    });

    test('reset forgets the last game, so a new game does not start with a free find', () {
      final tracker = FallbackTracker()..startFrom(at(lat, lng));
      tracker.reset();
      expect(tracker.start, isNull);

      // the new game begins 5 km from where the last one ended: that must not count as moving
      expect(tracker.checkFind(at(lat + 0.045, lng)), isFalse);
    });

    test('reports how far the player has moved', () {
      final tracker = FallbackTracker()..startFrom(at(lat, lng));
      expect(tracker.distanceMoved(at(lat + bigMove, lng)), closeTo(1336, 20));
    });

    test('the player has to move kilometers, not a few meters', () {
      expect(fallbackDistanceMeters, 1000);
      final tracker = FallbackTracker()..startFrom(at(lat, lng));
      expect(tracker.checkFind(at(lat + 0.0001, lng)), isFalse); // 11 m
      expect(tracker.checkFind(at(lat + 0.005, lng)), isFalse); // 550 m
      expect(tracker.checkFind(at(lat + 0.0095, lng)), isTrue); // about 1.06 km
    });
  });

  group('formatDistance', () {
    test('uses kilometers for long distances, dropping a pointless ".0"', () {
      expect(formatDistance(1000), '1 km');
      expect(formatDistance(2000), '2 km');
      expect(formatDistance(1500), '1.5 km');
      expect(formatDistance(1234), '1.2 km');
      expect(formatDistance(960), '1 km'); // would otherwise read "960 meters", which is nearly a kilometer
    });

    test('rounds medium distances to the nearest 10 meters', () {
      expect(formatDistance(750), '750 meters');
      expect(formatDistance(347), '350 meters');
      expect(formatDistance(100), '100 meters');
    });

    test('shows short distances exactly, and never as zero', () {
      expect(formatDistance(30), '30 meters');
      expect(formatDistance(2), '2 meters');
      expect(formatDistance(1), '1 meter');
      expect(formatDistance(0.4), '1 meter');
    });
  });

  group('fallbackHint', () {
    test('tells the player how much further to go', () {
      expect(fallbackHint(0), 'Keep going! You need to travel 1 km further!');
      expect(fallbackHint(250), 'Keep going! You need to travel 750 meters further!');
      expect(fallbackHint(970), 'Keep going! You need to travel 30 meters further!');
    });

    test('never says a negative or zero distance once the player has moved far enough', () {
      for (final moved in [1000.0, 1000.1, 1003.0, 1500.0, 5000.0]) {
        final hint = fallbackHint(moved);
        expect(hint, "You've moved far enough. Try searching now!");
        expect(hint, isNot(contains('-')));
        expect(hint, isNot(contains('travel')));
      }
    });

    test('just short of far enough still gives a real distance, never "0 meters"', () {
      final hint = fallbackHint(999.6);
      expect(hint, contains('1 meter'));
      expect(hint, isNot(contains('0 meters')));
    });
  });

  group('fallbackRemainingMeters', () {
    test('counts down from the full distance and stops at zero', () {
      expect(fallbackRemainingMeters(0), 1000);
      expect(fallbackRemainingMeters(250), 750);
      expect(fallbackRemainingMeters(1000), 0);
      expect(fallbackRemainingMeters(1500), 0); // never negative
    });
  });

  group('pulseDelayForDistance', () {
    test('pulses faster the closer the player is, and not at all when far', () {
      expect(pulseDelayForDistance(0), const Duration(milliseconds: 250));
      expect(pulseDelayForDistance(7), const Duration(milliseconds: 250));
      expect(pulseDelayForDistance(12), const Duration(milliseconds: 500));
      expect(pulseDelayForDistance(20), const Duration(milliseconds: 1000));
      expect(pulseDelayForDistance(28), const Duration(milliseconds: 2000));
      expect(pulseDelayForDistance(31), isNull);
      expect(pulseDelayForDistance(5000), isNull);
    });
  });

  group('vibration in the fallback follows the distance still to go', () {
    Duration? pulseAfterMoving(double metersMoved) => pulseDelayForDistance(fallbackRemainingMeters(metersMoved));

    test('silent for most of the walk, then faster and faster as the player nears the distance', () {
      expect(pulseAfterMoving(0), isNull); // 1 km to go
      expect(pulseAfterMoving(500), isNull);
      expect(pulseAfterMoving(960), isNull); // 40 m to go
      expect(pulseAfterMoving(975), const Duration(milliseconds: 2000)); // 25 m to go
      expect(pulseAfterMoving(982), const Duration(milliseconds: 1000)); // 18 m to go
      expect(pulseAfterMoving(990), const Duration(milliseconds: 500)); // 10 m to go
      expect(pulseAfterMoving(996), const Duration(milliseconds: 250)); // 4 m to go
    });

    test('pulses fastest once the player has moved far enough, until they search', () {
      expect(pulseAfterMoving(1000), const Duration(milliseconds: 250));
      expect(pulseAfterMoving(1400), const Duration(milliseconds: 250));
    });

    test('goes quiet again after a find, because progress restarts from there', () {
      final tracker = FallbackTracker()..startFrom(at(35.0, -111.0));
      final farEnough = at(35.0 + 0.012, -111.0); // about 1.3 km
      expect(pulseAfterMoving(tracker.distanceMoved(farEnough)), const Duration(milliseconds: 250));

      expect(tracker.checkFind(farEnough), isTrue); // the player searches and finds something
      expect(pulseAfterMoving(tracker.distanceMoved(farEnough)), isNull); // starting over, nothing to feel
    });
  });
}
