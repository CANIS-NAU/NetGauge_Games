// this file will include all on-boarding code and A/B/C testing code
// Reference: https://dev.to/faidterence/unlock-your-apps-potential-master-ab-testing-in-flutter-with-firebase-remote-config-2ci6

// import libraries
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
class OnBoardingType extends ChangeNotifier{
  final String onboarding_header;
  final String onboarding_main_message;
  final String onboarding_secondary_message;
  final String onboarding_experiment;

  OnBoardingType({required this.onboarding_header, required this.onboarding_main_message,
    required this.onboarding_secondary_message, required this.onboarding_experiment});
}

Future<void> showCustomOnBoardingPopup(BuildContext context) async {
  // setting up firebase remote config connections
  final remoteConfig = FirebaseRemoteConfig.instance;
  final String messageId = remoteConfig.getString('onboarding_experiment');
  final userData = Provider.of<UserDataProvider>(context, listen: false);
  // Before showing the dialog, check Firestore
  final seenMessages = userData.seenMessages; // list stored on the user
  if (seenMessages[messageId] == true) {
    debugPrint("[ONBOARDING] User has seen this message ($messageId), do not show it.");
    return; // they've seen this one, do nothing
  }

  debugPrint("[ONBOARDING] Showing user message $messageId for the first time.");
  // in condition where it's not been seen, can now be set to true
  debugPrint("[ONBOARDING] Calling updateOnboardingStatus.");
  userData.updateOnboardingStatus(messageId, context);

  try {
    debugPrint("ONBOARDING: Initializing Remote Config...");

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
      fetchTimeout: const Duration(seconds: 10), // shorter timeout for better UX
      minimumFetchInterval: Duration.zero,       // allow frequent updates for testing
    ));

    // 2. Fetch and activate the latest values from the server
    // We add a timeout to ensure the popup shows even if the network is slow
    await remoteConfig.fetchAndActivate().timeout(const Duration(seconds: 5), onTimeout: () {
      debugPrint("ACTIVITY_LOGS: ONBOARDING: Fetch timed out, using defaults.");
      /*
      Set messageID to default control setting. Doing this so we can tell Firebase
      that the user has already seen this message so they are not shown it again.
       */
      //TODO: Make sure that the default does not pop up if the user has seen it before.
      String messageID = "control_onboarding";
      return false;
    });
  } catch (e) {
    debugPrint("ACTIVITY_LOGS: ONBOARDING: Error with Remote Config: $e");
    // We don't return here; we want to proceed with default values
  }

  // 3. Retrieve the values (either from server or defaults)
  final OnBoardingType onboardingData = OnBoardingType(
    onboarding_header: remoteConfig.getString('onboarding_header'),
    onboarding_main_message: remoteConfig.getString('onboarding_main_message'),
    onboarding_secondary_message: remoteConfig.getString('onboarding_secondary_message'),
    onboarding_experiment: remoteConfig.getString('onboarding_experiment'),
  );

  //final userData = Provider.of<UserDataProvider>(context, listen: false);

  // 4. Log the event using the retrieved experiment value
  loggingService.logEvent(
      'Showing on-boarding message for ${onboardingData.onboarding_experiment}',
      email: userData.email
  );

  debugPrint("ONBOARDING: Displaying Dialog...");

  return showDialog(
    context: context,
    barrierDismissible: false, // ensure they see the message
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, dialogSetState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            title: Text(onboardingData.onboarding_header),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(onboardingData.onboarding_main_message),
                  const SizedBox(height: 12),
                  Text(onboardingData.onboarding_secondary_message),
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
