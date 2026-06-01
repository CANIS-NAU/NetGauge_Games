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

    await _remoteConfig.fetchAndActivate();
  }
  String get surveyTriggerToken => _remoteConfig.getString('survey_trigger_token');
  bool get showSurvey => _remoteConfig.getBool('show_survey');
  String get surveyDocId => _remoteConfig.getString('survey_doc_id');
  int getInt(String key) => _remoteConfig.getInt(key);
}