// The pop-up shown when someone logs in or enters guest mode with location turned off, telling them they will
// not get the full experience (games and measurements are tied to where the player is).
//
// To change what it says, edit the text constants below.

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

// TODO: replace this placeholder text with the real message.
const String locationNoticeTitle = 'Location is turned off';
const String locationNoticeBody =
    'This is placeholder text. Without location turned on, you will not get the full NetGauge experience.\n\n'
    'Explain here what stops working without location (for example, games that depend on where you are, and '
    'measurements that appear on the map), and how to turn it on.';

// why location is not available
enum LocationIssue {
  // location services are switched off on the phone
  servicesDisabled,
  // the app has not been given permission (the user said no)
  permissionDenied,
  // the user said no and chose not to be asked again, so only the phone's settings can change it
  permissionBlocked,
}

// Checks whether the app can use the phone's location. Returns null if it can (or if the check itself fails, in
// which case nobody should be nagged). A brand-new user has not been asked for permission yet, so they are asked
// here first, and only get the pop-up if they decline.
Future<LocationIssue?> checkLocationIssue() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return LocationIssue.servicesDisabled;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    switch (permission) {
      case LocationPermission.denied:
        return LocationIssue.permissionDenied;
      case LocationPermission.deniedForever:
        return LocationIssue.permissionBlocked;
      default:
        return null;
    }
  } catch (e) {
    debugPrint('[LOCATION_NOTICE] Could not check location: $e');
    return null;
  }
}

// what the main button says and does, for each reason
String _actionLabel(LocationIssue issue) {
  switch (issue) {
    case LocationIssue.servicesDisabled:
      return 'Open Location Settings';
    case LocationIssue.permissionDenied:
      return 'Allow Location';
    case LocationIssue.permissionBlocked:
      return 'Open App Settings';
  }
}

Future<void> _defaultAction(LocationIssue issue) async {
  try {
    switch (issue) {
      case LocationIssue.servicesDisabled:
        await Geolocator.openLocationSettings();
      case LocationIssue.permissionDenied:
        await Geolocator.requestPermission();
      case LocationIssue.permissionBlocked:
        await Geolocator.openAppSettings();
    }
  } catch (e) {
    debugPrint('[LOCATION_NOTICE] Could not open location settings: $e');
  }
}

// Shows the pop-up and completes when it is closed. [onFix] is what the main button does; tests pass their own.
Future<void> showLocationNotice(
  BuildContext context,
  LocationIssue issue, {
  Future<void> Function(LocationIssue issue)? onFix,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(Icons.location_off, size: 40),
      title: const Text(locationNoticeTitle, textAlign: TextAlign.center),
      content: const SingleChildScrollView(child: Text(locationNoticeBody)),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Continue Without Location'),
        ),
        FilledButton(
          onPressed: () {
            // close first, then send the user to where they can fix it
            Navigator.of(dialogContext).pop();
            (onFix ?? _defaultAction)(issue);
          },
          child: Text(_actionLabel(issue)),
        ),
      ],
    ),
  );
}
