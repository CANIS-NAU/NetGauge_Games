// this file will include all on-boarding code and A/B/C testing code
// Reference: https://dev.to/faidterence/unlock-your-apps-potential-master-ab-testing-in-flutter-with-firebase-remote-config-2ci6

// import libraries
import 'package:internet_measurement_games_app/home.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'user_data_manager.dart';
import 'activity_logs.dart';
import 'package:provider/provider.dart';
import 'package:get_it/get_it.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';

// setting up global var for activity logging
final loggingService = GetIt.instance<LoggingService>();

// class def
class OnBoardingType {
  final String onboarding_header;
  final String onboarding_main_message;
  final String onboarding_secondary_message;
  final String onboarding_experiment;

  OnBoardingType({required this.onboarding_header, required this.onboarding_main_message,
    required this.onboarding_secondary_message, required this.onboarding_experiment});
}

// Note to self--I am going to start with one on-boarding message. Then, add A/B/C testing code.
Widget gameCatalogPreview() {

  return const MaterialApp(
    home: HomePage(),
  );
}

// ... imports and OnBoardingType class remain the same ...

Future<void> showCustomOnBoardingPopup(BuildContext context) async {
  // setting up firebase remote config connections
  final remoteConfig = FirebaseRemoteConfig.instance;

  // 1. Set defaults (used if fetch fails or keys aren't in console)
  await remoteConfig.setDefaults(const {
    "onboarding_header": "Welcome to NetGauge!",
    "onboarding_main_message": "Our goal is to collect internet measurements, "
        "so that we can highlight areas that need improved broadband infrastructure.",
    "onboarding_secondary_message": "Each time you play a game in the app, "
        "you will collect internet measurements. Each of these games involve moving around outside.",
    "onboarding_experiment": "control",
  });

  await remoteConfig.setConfigSettings(RemoteConfigSettings(
    fetchTimeout: const Duration(minutes: 1),
    minimumFetchInterval: const Duration(hours: 1),
  ));

  // 2. Fetch and activate the latest values from the server
  await remoteConfig.fetchAndActivate();

  // 3. Retrieve the values using the getString method
  final OnBoardingType onboardingData = OnBoardingType(
    onboarding_header: remoteConfig.getString('onboarding_header'),
    onboarding_main_message: remoteConfig.getString('onboarding_main_message'),
    onboarding_secondary_message: remoteConfig.getString('onboarding_secondary_message'),
    onboarding_experiment: remoteConfig.getString('onboarding_experiment'),
  );

  final userData = Provider.of<UserDataProvider>(context, listen: false);

  // 4. Log the event using the retrieved experiment value
  loggingService.logEvent(
      'Showing on-boarding message for ${onboardingData.onboarding_experiment}',
      phone: userData.phone
  );

  String header = onboardingData.onboarding_header;
  String mainMessage = onboardingData.onboarding_main_message;
  String secondaryMessage = onboardingData.onboarding_secondary_message;
  String? imagePath;

  return showDialog(
    context: context,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, dialogSetState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            title: Text(header),
            content: SingleChildScrollView( // Added scroll view for safety
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (imagePath != null) ...[
                    Image.asset(imagePath, height: 100, width: 100),
                    const SizedBox(height: 16),
                  ],
                  Text(mainMessage),
                  const SizedBox(height: 8),
                  Text(secondaryMessage),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Got it!"),
              ),
            ],
          );
        },
      );
    },
  );
}