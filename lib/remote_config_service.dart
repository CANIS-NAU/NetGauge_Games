import 'package:firebase_remote_config/firebase_remote_config.dart';
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
      minimumFetchInterval: const Duration(hours: 1), // lower during dev
    ));

    // Defaults if fetch fails
    await _remoteConfig.setDefaults({
      'show_survey': false,
      'survey_doc_id': 'METUX',
    });

    // A failed fetch (no internet, DNS trouble, Firebase unreachable) must not stop the app from starting.
    // The defaults above, or the last values that were fetched, are used until a fetch works.
    try {
      await _remoteConfig.fetchAndActivate();
    } catch (e) {
      debugPrint('[REMOTE CONFIG] Could not fetch new values, using defaults/cached ones: $e');
    }
  }
  String get surveyTriggerToken => _remoteConfig.getString('survey_trigger_token');
  bool get showSurvey => _remoteConfig.getBool('show_survey');
  String get surveyDocId => _remoteConfig.getString('survey_doc_id');
  int getInt(String key) => _remoteConfig.getInt(key);
}