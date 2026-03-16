// this file will include all on-boarding code and A/B/C testing code
// Reference: https://dev.to/faidterence/unlock-your-apps-potential-master-ab-testing-in-flutter-with-firebase-remote-config-2ci6

// import libraries
import 'dart:convert';
//import 'package:firebase_auth/firebase_auth.dart';
import 'package:internet_measurement_games_app/home.dart';

import 'mapping.dart';
import 'package:flutter/material.dart';
import 'package:internet_measurement_games_app/location_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'session_manager.dart';
import 'location_logger.dart';
import 'vibration_controller.dart';
import 'likert_form.dart';
import 'dart:async';
import 'ndt7_service.dart';
import 'package:latlong2/latlong.dart';
import 'poi_generator.dart';
import 'speed_test_page.dart';
import 'profile.dart';
import 'user_data_manager.dart';
import 'activity_logs.dart';
import 'package:flutter/material.dart';
import 'widgets/buttons.dart';
import 'game_catalog.dart';
import 'user_data_manager.dart';
import 'package:provider/provider.dart';
import 'dashboard.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'dynamic_map.dart';
import 'information.dart';
import 'community_statistics.dart';
import 'settings.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'activity_logs.dart';
import 'package:get_it/get_it.dart';

final loggingService = GetIt.instance<LoggingService>();

// class definitation
class OnBoardingType {
  final String header;
  final String main_message;
  final String secondary_message;
  final String experiment;

  OnBoardingType({required this.header, required this.main_message, required this.secondary_message, required this.experiment});
}

// Note to self--I am going to start with one on-boarding message. Then, add A/B/C testing code.
Widget gameCatalogPreview() {
  return const MaterialApp(
    home: HomePage(),
  );
}

Future<void> showCustomPopup(BuildContext context, OnBoardingType type) {
  final userData = Provider.of<UserDataProvider>(context, listen: false);
  loggingService.logEvent('Showing on-boarding message for ${type.experiment}', phone: userData.phone);
  String header = type.header;
  String main_message = type.main_message;
  String secondary_message = type.secondary_message;
  String? imagePath;


  return showDialog(
    context: context,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, dialogSetState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            title: Text(header),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (imagePath != null) ...[
                  Image.asset(imagePath, height: 100, width: 100),
                  const SizedBox(height: 16),
                ],
                Text(main_message),
                Text(secondary_message),
              ],
            ),
          );
        },
      );
    },
  );
}