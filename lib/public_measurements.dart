// Anonymized copies of measurements that every user's map can show.
//
// Each measurement a user saves is also written to public_measurements with only the internet results, a
// coarsened location and when it was collected. The user's email, game, session ID and VPN status are never
// copied, and the copy gets no link back to the private document (it is just keyed by the same random ID).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

class PublicMeasurements {
  static const String collectionName = 'public_measurements';
  static const String _backfillBoxName = 'public_measurements_backfill';

  // 4 decimal places is roughly 11 m: enough for a heat map without pinpointing a doorstep
  static double _round(double value) => (value * 1e4).round() / 1e4;

  // Builds the anonymized copy, or returns null if the measurement has no usable location
  // (e.g. location services were off), since it could not be shown on a map anyway.
  static Map<String, dynamic>? anonymize(Map<String, dynamic> data) {
    final lat = data['latitude'];
    final lng = data['longitude'];
    if (lat is! num || lng is! num) return null;

    return {
      'latitude': _round(lat.toDouble()),
      'longitude': _round(lng.toDouble()),
      'download_speed': data['download_speed'] is num ? data['download_speed'] : 0,
      'upload_speed': data['upload_speed'] is num ? data['upload_speed'] : 0,
      'latency': data['latency'] is num ? data['latency'] : 0,
      if (data['jitter'] is num) 'jitter': data['jitter'],
      // When it was collected. A measurement being saved right now carries a "server timestamp" placeholder,
      // so the copy gets the server's time too; older measurements already hold their real time.
      if (data['timestamp'] is Timestamp) 'timestamp': data['timestamp'],
      if (data['timestamp'] is FieldValue) 'timestamp': FieldValue.serverTimestamp(),
    };
  }

  // Writes the anonymized copy of one measurement. Never throws: the user's own measurement is already saved,
  // so a failure here (e.g. offline) must not affect it.
  static Future<void> publish(String docId, Map<String, dynamic> data) async {
    final copy = anonymize(data);
    if (copy == null) return;
    try {
      await FirebaseFirestore.instance.collection(collectionName).doc(docId).set(copy);
    } catch (e) {
      debugPrint('[PUBLIC_MEASUREMENTS] Could not publish $docId: $e');
    }
  }

  // One-time copy of a user's measurements saved before this feature existed. The rules only let a document be
  // created once, so ones already copied are skipped. Remembered per device, per user.
  static Future<void> backfillOwn(String email) async {
    if (email.isEmpty) return;
    try {
      final box = await Hive.openBox(_backfillBoxName);
      if (box.get(email) == true) return;

      final firestore = FirebaseFirestore.instance;
      final mine = await firestore
          .collection('measurements')
          .doc(email)
          .collection('collected_measurements')
          .get();

      int copied = 0;
      for (final doc in mine.docs) {
        final copy = anonymize(doc.data());
        if (copy == null) continue;
        final publicRef = firestore.collection(collectionName).doc(doc.id);
        if ((await publicRef.get()).exists) continue;
        await publicRef.set(copy);
        copied++;
      }

      await box.put(email, true);
      debugPrint('[PUBLIC_MEASUREMENTS] Backfilled $copied of ${mine.size} measurements.');
    } catch (e) {
      // try again the next time the map opens
      debugPrint('[PUBLIC_MEASUREMENTS] Backfill failed: $e');
    }
  }
}
