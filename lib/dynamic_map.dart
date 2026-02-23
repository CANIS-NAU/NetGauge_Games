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

// Data Point Class
class DataPoint {
  final LatLng point;
  final DateTime timestamp;
  final double uploadSpeed;
  final double downloadSpeed;
  final double latency;
  final String gamePlayed;

  DataPoint({required this.point, required this.timestamp, required this.uploadSpeed,
    required this.downloadSpeed, required this.latency, required this.gamePlayed});

  factory DataPoint.fromFirestore(firestore.DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final firestore.GeoPoint geoPoint = data['location']['geopoint'] as firestore.GeoPoint;

    return DataPoint(
      point: LatLng(geoPoint.latitude, geoPoint.longitude),
      timestamp: (data['timestamp'] as firestore.Timestamp).toDate(),
      uploadSpeed: (data['uploadSpeed'] as num?)?.toDouble() ?? 0.0,
      downloadSpeed: (data['downloadSpeed'] as num?)?.toDouble() ?? 0.0,
      latency: (data['latency'] as num?)?.toDouble() ?? 0.0,
      gamePlayed: data['gamePlayed'] as String? ?? 'Unknown',
    );
  }
}

// radius-based stream for gathering points from firestore
final GeoCollectionReference<Map<String, dynamic>> geoCollection =
GeoCollectionReference(firestore.FirebaseFirestore.instance.collection('data_points'));

Stream<List<firestore.DocumentSnapshot>> getPointsStream(LatLng center, double radiusKm) {
  return geoCollection.subscribeWithin(
    center: GeoFirePoint(firestore.GeoPoint(center.latitude, center.longitude)),
    radiusInKm: radiusKm,
    field: 'location',
    geopointFrom: (data) => data['location']['geopoint'] as firestore.GeoPoint,
  );
}

class DynamicMap extends StatefulWidget {
  const DynamicMap({Key? key}) : super(key: key);

  @override
  State<DynamicMap> createState() => _DynamicMapState();
}

class _DynamicMapState extends State<DynamicMap> {
  late MapController _mapController;           // moved here from OSMFlutter
  late StreamSubscription _streamSubscription; // new

  @override
  void initState() {
    super.initState();

    // initialize the controller
    _mapController = MapController(
      initPosition: GeoPoint(latitude: 35.1861, longitude: -111.6583),
    );

    // define the center and radius for your query
    final LatLng center = LatLng(35.1861, -111.6583);
    final double radiusKm = 10.0; // adjust as needed

    // subscribe to the stream and store the subscription
    _streamSubscription = getPointsStream(center, radiusKm).listen((docs) async {
      final points = docs.map((doc) => DataPoint.fromFirestore(doc)).toList();
      final existingPoints = await _mapController.geopoints;
      await _mapController.removeMarkers(existingPoints);
      for (final dp in points) {
        await _mapController.addMarker(
          GeoPoint(latitude: dp.point.latitude, longitude: dp.point.longitude),
          markerIcon: const MarkerIcon(
            icon: Icon(Icons.location_pin, color: Colors.red, size: 48),
          ),
        );
      }
    });
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
        controller: _mapController, // now using the state-level controller
        /*mapIsReady: (isReady) async {
          // markers are only added once the map confirms it's ready
          if (!isReady) return;
        },*/
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
      ),
    );
  }
}