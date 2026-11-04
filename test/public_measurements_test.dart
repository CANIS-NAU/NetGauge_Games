import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:internet_measurement_games_app/public_measurements.dart';

void main() {
  test('keeps only results and a rounded location', () {
    final copy = PublicMeasurements.anonymize({
      'latitude': 35.198312, 'longitude': -111.651377,
      'download_speed': 50.5, 'upload_speed': 10, 'latency': 20,
      'email': 'a@b.c', 'game': 'Zombie', 'session_id': 's', 'vpn_used': true,
      'geohash': 'x', 'timestamp': 'now',
    });
    expect(copy, {
      'latitude': 35.1983, 'longitude': -111.6514,
      'download_speed': 50.5, 'upload_speed': 10, 'latency': 20,
    });
  });

  test('includes jitter only when measured', () {
    final copy = PublicMeasurements.anonymize({
      'latitude': 35.0, 'longitude': -111.0, 'download_speed': 1, 'upload_speed': 1, 'latency': 1, 'jitter': 2.5,
    });
    expect(copy!['jitter'], 2.5);
  });

  test('keeps the time a stored measurement was collected', () {
    final collected = Timestamp.fromDate(DateTime.utc(2026, 11, 4, 12, 30));
    final copy = PublicMeasurements.anonymize({
      'latitude': 35.0, 'longitude': -111.0, 'download_speed': 1, 'upload_speed': 1, 'latency': 1,
      'timestamp': collected,
    });
    expect(copy!['timestamp'], collected);
  });

  test('uses a server timestamp for a measurement being saved now', () {
    final copy = PublicMeasurements.anonymize({
      'latitude': 35.0, 'longitude': -111.0, 'download_speed': 1, 'upload_speed': 1, 'latency': 1,
      'timestamp': FieldValue.serverTimestamp(),
    });
    expect(copy!['timestamp'], isA<FieldValue>());
  });

  test('skips measurements without a location', () {
    expect(PublicMeasurements.anonymize({'download_speed': 5, 'upload_speed': 1, 'latency': 3}), isNull);
  });
}
