import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:internet_measurement_games_app/public_sessions.dart';

void main() {
  final started = DateTime.utc(2026, 11, 5, 17, 30);

  test('keeps only the game, a rounded start location and the start time', () {
    final record = PublicSessions.anonymize({
      'game': 'Soul Seeker',
      'start_time': started,
      'end_time': DateTime.utc(2026, 11, 5, 18, 0),
      'session_id': 'abc',
      'vpn_used': true,
      'session_distance': 1234.5,
      'collected_measurements': [
        {'upload_speed': 5, 'download_speed': 50, 'latency': 20, 'jitters': 1},
      ],
      'location_points': [
        {'latitude': 35.198312, 'longitude': -111.651377, 'geohash': 'x'},
        {'latitude': 35.3, 'longitude': -111.7, 'geohash': 'y'},
      ],
    });

    expect(record, {
      'game': 'Soul Seeker',
      'latitude': 35.1983,
      'longitude': -111.6514,
      'timestamp': Timestamp.fromDate(started),
    });
  });

  test('keeps the start time of an already stored session', () {
    final stored = Timestamp.fromDate(started);
    final record = PublicSessions.anonymize({
      'game': 'Soul Seeker',
      'start_time': stored,
      'location_points': [
        {'latitude': 35.0, 'longitude': -111.0},
      ],
    });
    expect(record!['timestamp'], stored);
  });

  test('a play with no location, or no game, is not shared', () {
    expect(PublicSessions.anonymize({'game': 'Soul Seeker', 'location_points': []}), isNull);
    expect(PublicSessions.anonymize({'game': 'Soul Seeker'}), isNull);
    expect(
      PublicSessions.anonymize({
        'location_points': [
          {'latitude': 35.0, 'longitude': -111.0},
        ],
      }),
      isNull,
    );
  });
}
