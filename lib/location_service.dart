import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_compass/flutter_compass.dart';

// stores a single piece of location data
class LocationData {
  final Position position;
  final double? heading;

  LocationData({required this.position, this.heading});
}

// class that makes a single location stream available for subscription by multiple functions
class LocationDispatcher {
  static final Stream<Position> _positionStream = 
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).asBroadcastStream(); // enables multiple listeners

  static Stream<Position> get stream => _positionStream;
}

// used to acquire the most recent coordinate position of the device
Future<LocationData> determineLocationData() async
{
  // Check if Location Services are enabled
  bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled)
  {
    return Future.error('Location services are disabled globally. Please enable them.');
  }

  // check the level of location permissions available to the app
  LocationPermission permission = await Geolocator.checkPermission();
  // denied = user hasn't granted permission
  // deniedForever = user hasn't granted permission and has blocked the app from asking
  // whileInUse = only while the app is open
  // always = always available

  // If permission hasn't been granted, ask for it
  if(permission == LocationPermission.denied)
  {
    permission = await Geolocator.requestPermission();

    // If permission is denied again
    if(permission == LocationPermission.denied)
    {
      return Future.error('This application requires location permission to function.');
    }

  }

  // If permission is permantently denied, we simply can't ask again.
  if (permission == LocationPermission.deniedForever)
  {
    return Future.error('Location permissions are permanently denied. Please adjust app permissions in settings if you would like to change this.');
  }

  // Grab the current position
  Position position = await Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));

  // get the current heading
  double? heading;
  try {
    CompassEvent compassEvent = await FlutterCompass.events!.first;
    heading = compassEvent.heading;
  } catch (e) {
    heading = null; // Device doesn have a compass sensor
  }

  return LocationData(position: position, heading: heading);
}