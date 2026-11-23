/* Pop-up messages that can be sent to players without releasing a new version of the app.
*
* The message lives in ONE Firebase Remote Config parameter named `announcement`, holding JSON. When the home
* screen opens (and when the app returns from the background) the app reads it and, if it applies to this player,
* shows it as a dialog. See ANNOUNCEMENTS_GUIDE.md for how to publish one.
*
* Example value of the `announcement` parameter:
*   {
*     "id": "2026-11-survey-thanks",
*     "title": "Thank you!",
*     "message": "Your measurements helped map coverage in your area.",
*     "button": "Got it",
*     "audience": "all",
*     "platform": "all",
*     "show": "once",
*     "start": "2026-11-20T00:00:00Z",
*     "end": "2026-12-01T00:00:00Z"
*   }
*
* Only `id` and `message` are required. A broken or empty value shows nothing and never crashes the app. */

import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'remote_config_service.dart';

enum AnnouncementAudience { all, guests, registered }

enum AnnouncementFrequency {
  // one time per device, then never again (the default)
  once,
  // every time the home screen opens or the app returns to it, until `end`
  always,
}

class Announcement {
  // change this for every new message: players who dismissed the old id will see the new one
  final String id;
  final String title;
  final String message;
  final String button;
  final AnnouncementAudience audience;
  // 'all', 'android' or 'ios'
  final String platform;
  final AnnouncementFrequency frequency;
  // the message is only shown between these times (either may be missing)
  final DateTime? start;
  final DateTime? end;

  const Announcement({
    required this.id,
    required this.message,
    this.title = '',
    this.button = 'OK',
    this.audience = AnnouncementAudience.all,
    this.platform = 'all',
    this.frequency = AnnouncementFrequency.once,
    this.start,
    this.end,
  });

  // Reads the Remote Config value. Returns null for an empty, invalid or incomplete message.
  static Announcement? parse(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final data = jsonDecode(raw);
      if (data is! Map) return null;
      String? text(String key) {
        final v = data[key];
        return v is String && v.trim().isNotEmpty ? v.trim() : null;
      }

      final id = text('id');
      final message = text('message');
      if (id == null || message == null) return null;

      DateTime? time(String key) {
        final t = text(key);
        return t == null ? null : DateTime.tryParse(t)?.toUtc();
      }

      return Announcement(
        id: id,
        message: message,
        title: text('title') ?? '',
        button: text('button') ?? 'OK',
        audience: switch (text('audience')?.toLowerCase()) {
          'guests' => AnnouncementAudience.guests,
          'registered' => AnnouncementAudience.registered,
          _ => AnnouncementAudience.all,
        },
        platform: text('platform')?.toLowerCase() ?? 'all',
        frequency: text('show')?.toLowerCase() == 'always' ? AnnouncementFrequency.always : AnnouncementFrequency.once,
        start: time('start'),
        end: time('end'),
      );
    } catch (_) {
      return null;
    }
  }

  // Whether this player should see the message now.
  bool appliesTo({
    required DateTime now,
    required bool isGuest,
    required String currentPlatform,
    required Set<String> seenIds,
  }) {
    final t = now.toUtc();
    if (start != null && t.isBefore(start!)) return false;
    if (end != null && t.isAfter(end!)) return false;
    if (platform != 'all' && platform != currentPlatform) return false;
    if (audience == AnnouncementAudience.guests && !isGuest) return false;
    if (audience == AnnouncementAudience.registered && isGuest) return false;
    if (frequency == AnnouncementFrequency.once && seenIds.contains(id)) return false;
    return true;
  }
}

class AnnouncementService {
  static const String _boxName = 'announcements_seen';
  static const String _seenKey = 'seen_ids';

  // true while a dialog is open, so two are never stacked
  static bool _showing = false;

  static Future<Set<String>> _loadSeen() async {
    try {
      final box = await Hive.openBox(_boxName);
      final saved = box.get(_seenKey);
      return saved is List ? saved.whereType<String>().toSet() : <String>{};
    } catch (e) {
      debugPrint('[ANNOUNCEMENTS] Could not read the seen list: $e');
      return <String>{};
    }
  }

  static Future<void> _markSeen(String id) async {
    try {
      final box = await Hive.openBox(_boxName);
      final seen = (await _loadSeen())..add(id);
      await box.put(_seenKey, seen.toList());
    } catch (e) {
      debugPrint('[ANNOUNCEMENTS] Could not save the seen list: $e');
    }
  }

  static String get _platformName => Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : 'other');

  // Shows the current announcement if there is one for this player. Never throws.
  // `refresh` asks Remote Config for new values first (it still respects the minimum fetch interval).
  static Future<void> maybeShow(BuildContext context, {required bool isGuest, bool refresh = false}) async {
    if (_showing) return;
    try {
      if (refresh) await RemoteConfigService().refresh();
      final announcement = Announcement.parse(RemoteConfigService().announcementJson);
      if (announcement == null) return;

      final seen = await _loadSeen();
      final applies = announcement.appliesTo(
        now: DateTime.now(),
        isGuest: isGuest,
        currentPlatform: _platformName,
        seenIds: seen,
      );
      if (!applies || !context.mounted) return;

      _showing = true;
      // remember it before showing, so a crash or force-quit never leaves a "once" message stuck on screen
      if (announcement.frequency == AnnouncementFrequency.once) await _markSeen(announcement.id);
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: announcement.title.isEmpty ? null : Text(announcement.title),
          content: SingleChildScrollView(child: Text(announcement.message)),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(announcement.button)),
          ],
        ),
      );
    } catch (e) {
      debugPrint('[ANNOUNCEMENTS] Could not show the announcement: $e');
    } finally {
      _showing = false;
    }
  }
}
