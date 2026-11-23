// Anonymized record of each time a game was played, used for the community statistics ("most frequently played
// game in your area"). One public_sessions document is written per play, holding only which game it was, roughly
// where it started and when. The user's email, session contents, measurements and VPN status are never copied.
//
// The document is keyed by the play's session ID, so saving the same play twice never counts it twice.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

class PublicSessions {
  static const String collectionName = 'public_sessions';
  static const String _backfillBoxName = 'public_sessions_backfill';

  // 4 decimal places is roughly 11 m, the same coarseness as shared measurements
  static double _round(double value) => (value * 1e4).round() / 1e4;

  // Builds the anonymized record from a saved session's data (what is stored in measurements/{id}/sessions),
  // or returns null if it cannot be placed on a map or has no game.
  static Map<String, dynamic>? anonymize(Map<String, dynamic> session) {
    final game = session['game'];
    if (game is! String || game.isEmpty) return null;

    // where the play started: its first recorded location
    final points = session['location_points'];
    if (points is! List || points.isEmpty) return null;
    final first = points.first;
    if (first is! Map) return null;
    final lat = first['latitude'];
    final lng = first['longitude'];
    if (lat is! num || lng is! num) return null;

    final started = session['start_time'];
    return {
      'game': game,
      'latitude': _round(lat.toDouble()),
      'longitude': _round(lng.toDouble()),
      if (started is Timestamp) 'timestamp': started,
      if (started is DateTime) 'timestamp': Timestamp.fromDate(started),
    };
  }

  // Writes the record for one play unless it is already there. Never throws: the player's own session is already
  // saved, so a failure here (e.g. offline) must not affect it.
  static Future<void> publish(Map<String, dynamic> session) async {
    final record = anonymize(session);
    final sessionId = session['session_id'];
    if (record == null || sessionId is! String || sessionId.isEmpty) return;

    try {
      final ref = FirebaseFirestore.instance.collection(collectionName).doc(sessionId);
      // the rules only let a record be created once, so skip plays that are already counted
      if ((await ref.get()).exists) return;
      await ref.set(record);
    } catch (e) {
      debugPrint('[PUBLIC_SESSIONS] Could not publish $sessionId: $e');
    }
  }

  // One-time copy of a user's earlier plays, from before this feature existed. Remembered per device, per user.
  static Future<void> backfillOwn(String email) async {
    if (email.isEmpty) return;
    try {
      final box = await Hive.openBox(_backfillBoxName);
      if (box.get(email) == true) return;

      final mine = await FirebaseFirestore.instance
          .collection('measurements')
          .doc(email)
          .collection('sessions')
          .get();

      for (final doc in mine.docs) {
        final data = doc.data();
        // old documents all carry their session ID; fall back to the document ID if one does not
        await publish({...data, 'session_id': data['session_id'] is String ? data['session_id'] : doc.id});
      }

      await box.put(email, true);
      debugPrint('[PUBLIC_SESSIONS] Backfilled ${mine.size} plays.');
    } catch (e) {
      // try again the next time
      debugPrint('[PUBLIC_SESSIONS] Backfill failed: $e');
    }
  }
}
