import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:flutter/material.dart';
import 'package:internet_measurement_games_app/home.dart';
import 'package:latlong2/latlong.dart';
import 'speed_test_page.dart';
import 'widgets/buttons.dart';
import 'game_catalog.dart';
import 'user_data_manager.dart';
import 'package:provider/provider.dart';
import 'dashboard.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import 'dart:async'; // needed for StreamSubscription
import 'package:pointer_interceptor/pointer_interceptor.dart';

// Establishing the DynamicMap class, which creates it's own state
class DynamicMap extends StatefulWidget {
  const DynamicMap({Key? key}) : super(key: key);

  @override
  State<DynamicMap> createState() => _DynamicMapState();
}

// Establishing the map state
class _DynamicMapState extends State<DynamicMap> {
  late MapController _mapController;
  // this is important for us to grab points from Firebase
  late StreamSubscription _streamSubscription;
  bool _mapReady = false;
  /* As points get read in from firebase, we want to make sure
  * any that come in early before the map is done rendering is not
  * lost. Therefore, we use the _pendingPoints list as a buffer.*/
  List<DataPoint> _pendingPoints = [];

  @override
  void initState() {
    super.initState();

    // initialize the controller
    _mapController = MapController(
      //Initial position set for testing.
      //TODO: Make this dynamic, have it be set to the user's current location.
      initPosition: GeoPoint(latitude: 35.1861, longitude: -111.6583),
    );

    /*
    This function delays grabbing and displaying points until the map is rendered
    so the display does not silently break.
     */
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 500));
      // checks to see if the map is ready after a brief delay before getting points
      setState(() => _mapReady = true);

      // testing with fake data points, actual code is below
      final testPoints = [
        DataPoint(
          point: LatLng(35.1861, -111.6583),
          timestamp: DateTime.now(),
          uploadSpeed: 10,
          downloadSpeed: 50,
          latency: 20,
          gamePlayed: 'Test',
        ),
        DataPoint(
          point: LatLng(35.5, -111.19),
          timestamp: DateTime.now(),
          uploadSpeed: 10,
          downloadSpeed: 50,
          latency: 20,
          gamePlayed: 'Zombie',
        ),
      ];

      await _updateMapMarkers(testPoints);

      // add back in for real data
      // first checks if points were collected
      /*if (_pendingPoints.isNotEmpty) {
        // calls function to place points, uses await because this takes a moment
        await _updateMapMarkers(_pendingPoints);
        // empties pending points so points are not re-distributed across the map
        _pendingPoints = [];
      }*/
    });

    // define the center and radius for your query
    // TODO: center should be the user's current position. Using hard-coded values for testing.
    final LatLng center = LatLng(35.1861, -111.6583);

    /*
    This is the radius for points being displayed around the given position.
    Because NetGauge will include users from multiple states, we do not want to load
    ALL points at once, that will be too much data. This makes it more constrained.
     */
    final double radiusKm = 10.0;

    // subscribe to the stream and store the subscription
    _streamSubscription = getPointsStream(center, radiusKm).listen((docs) async {
      final points = docs.map((doc) => DataPoint.fromFirestore(doc)).toList();
      if (!_mapReady) {
        // Map isn't ready yet — buffer the points for later
        _pendingPoints = points;
        return;
      }
      // start adding points to the marker layer of the map
      await _updateMapMarkers(points);
    });
  }

  Future<void> _updateMapMarkers(List<DataPoint> points) async {
    final existingPoints = await _mapController.geopoints;
    if (existingPoints.isNotEmpty) {
      // avoid adding duplicate points
      await _mapController.removeMarkers(existingPoints);
    }

    for (final dp in points) {
      await _mapController.addMarker(
        GeoPoint(latitude: dp.point.latitude, longitude: dp.point.longitude),
        markerIcon: const MarkerIcon(
          // can customize this icon
          /*TODO: Nice stretch goal would be to differentiate points collected by
          *  user versus other NetGauge users by color.*/
          icon: Icon(Icons.location_pin, color: Colors.red, size: 48),
        ),
      );
    }
  }


  @override
  void dispose() {
    _streamSubscription.cancel(); // cancel stream first
    _mapController.dispose();     // then dispose the controller
    super.dispose();              // always last
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.home),
          onPressed: () {
            Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HomePage())
            );
          },
        ),
        centerTitle: true,
        title: const Text(
            'Map',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 25)
        ),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: OSMFlutter(
        // map controller is state-level, included earlier in code
        controller: _mapController,
        osmOption: OSMOption(
          userTrackingOption: const UserTrackingOption(
            enableTracking: true,
            unFollowUser: false,
          ),
          zoomOption: const ZoomOption(
            initZoom: 8,
            minZoomLevel: 3,
            maxZoomLevel: 19,
            stepZoom: 1.0,
          ),
          userLocationMarker: UserLocationMaker(
            personMarker: const MarkerIcon(
              icon: Icon(
                Icons.location_history_rounded,
                color: Colors.red,
                size: 48,
              ),
            ),
            directionArrowMarker: const MarkerIcon(
              icon: Icon(
                Icons.double_arrow,
                size: 48,
              ),
            ),
          ),
          roadConfiguration: const RoadOption(
            roadColor: Colors.yellowAccent,
          ),
        ),
        // When a given point is clicked
        onGeoPointClicked: (point) {
          // When a marker is clicked, show a popup with PointerInterceptor
          showDialog(
            context: context,
            builder: (context) => PointerInterceptor(
              // The PointerInterceptor is crucial here for web platforms
              child: AlertDialog(
                title: Text('Internet Measurement'),
                content: Text('Location: ${point.latitude}, ${point.longitude}'),
                actions: [
                  TextButton(
                    // This button will work on web thanks to PointerInterceptor
                    onPressed: () => Navigator.pop(context),
                    child: Text('Close'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}