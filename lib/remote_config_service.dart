import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

class RemoteConfigService {
  static final RemoteConfigService _instance = RemoteConfigService._internal();
  factory RemoteConfigService() => _instance;
  RemoteConfigService._internal();

  final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;

  Future<void> initialize() async {
    debugPrint('[REMOTE CONFIG] initialize() called');
    await _remoteConfig.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(seconds: 10),
      // debug builds fetch every time so a new message can be tested right away; real users at most hourly
      minimumFetchInterval: kDebugMode ? Duration.zero : const Duration(hours: 1),
    ));

    // Defaults if fetch fails
    await _remoteConfig.setDefaults({
      'show_survey': false,
      'survey_doc_id': 'METUX',
      // pop-up message for players (JSON, see announcements.dart). Empty means no message.
      'announcement': '',
    });

    // A failed fetch (no internet, DNS trouble, Firebase unreachable) must not stop the app from starting.
    // The defaults above, or the last values that were fetched, are used until a fetch works.
    try {
      await _remoteConfig.fetchAndActivate();
    } catch (e) {
      debugPrint('[REMOTE CONFIG] Could not fetch new values, using defaults/cached ones: $e');
    }
  }
  // the pop-up message JSON (see announcements.dart); empty when there is none
  String get announcementJson => _remoteConfig.getString('announcement');

  // Asks for new values and activates them. Never throws; Remote Config itself limits how often it really fetches.
  Future<void> refresh() async {
    try {
      await _remoteConfig.fetchAndActivate();
    } catch (e) {
      debugPrint('[REMOTE CONFIG] Refresh failed, keeping current values: $e');
    }
  }

  String get surveyTriggerToken => _remoteConfig.getString('survey_trigger_token');
  bool get showSurvey => _remoteConfig.getBool('show_survey');
  String get surveyDocId => _remoteConfig.getString('survey_doc_id');
  int getInt(String key) => _remoteConfig.getInt(key);
}