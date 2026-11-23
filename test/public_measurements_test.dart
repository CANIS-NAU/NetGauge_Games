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

  // Guard: the public copy must never carry M-Lab test IDs or anything that links back to a person or session.
  // The expected keys match the hasOnly list for public_measurements in firestore.rules; if a field is added here,
  // that rule has to change too (and the field must be safe to show to every user).
  group('public copy privacy guard', () {
    // a record holding every field the app writes to the private measurement
    final fullRecord = <String, dynamic>{
      'game': 'Zombie Apocalypse', 'session_id': 'session-1', 'latitude': 35.198312, 'longitude': -111.651377,
      'geohash': '9w0abcd', 'download_speed': 50.5, 'upload_speed': 10, 'latency': 20, 'jitter': 1.5,
      'timestamp': 'now',
      'network': {'type': 'wifi', 'interfaces': ['wifi'], 'vpn_reported': false, 'changed_during_test': false},
      'vpn_used': false, 'mock_location': false, 'integrity_flags': <String>[],
      'mlab': {
        'download_uuid': 'ndt-download-uuid-123', 'upload_uuid': 'ndt-upload-uuid-456',
        'server': 'mlab1-lax01.mlab-oti.measurement-lab.org', 'server_city': 'Los Angeles', 'server_country': 'US',
      },
    };

    test('never contains the mlab field or any of its values', () {
      final copy = PublicMeasurements.anonymize(fullRecord)!;
      expect(copy.containsKey('mlab'), isFalse);
      final text = copy.toString();
      for (final secret in ['ndt-download-uuid-123', 'ndt-upload-uuid-456', 'mlab1-lax01', 'Los Angeles', 'uuid']) {
        expect(text.contains(secret), isFalse, reason: 'public copy leaked "$secret"');
      }
    });

    test('only has keys the public_measurements rule allows', () {
      const allowed = {
        'latitude', 'longitude', 'download_speed', 'upload_speed', 'latency', 'jitter', 'network_type', 'timestamp',
      };
      final copy = PublicMeasurements.anonymize(fullRecord)!;
      expect(allowed.containsAll(copy.keys), isTrue, reason: 'unexpected keys: ${copy.keys.toSet().difference(allowed)}');
    });

    test('carries only the connection type from the network field', () {
      final copy = PublicMeasurements.anonymize(fullRecord)!;
      expect(copy['network_type'], 'wifi');
      expect(copy.containsKey('network'), isFalse);
    });
  });
}
