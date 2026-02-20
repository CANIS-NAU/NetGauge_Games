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

    // Pull the GeoPoint from Firestore
    final firestore.GeoPoint geoPoint = data['location'] as firestore.GeoPoint;

    // Convert it to LatLng right here
    final LatLng latLng = LatLng(geoPoint.latitude, geoPoint.longitude);

    return DataPoint(
      point: latLng,
      timestamp: (data['timestamp'] as firestore.Timestamp).toDate(),
      uploadSpeed: data['uploadSpeed'] as double ?? 0.0,
      downloadSpeed: data['downloadSpeed'] as double ?? 0.0,
      latency: data['latency'] as double ?? 0.0,
      gamePlayed: data['gamePlayed'] as String ?? 'Unknown',
    );
  }
}

class DynamicMap extends StatefulWidget {
  const DynamicMap({Key? key}) : super(key: key);

  @override
  State<DynamicMap> createState() => _DynamicMapState();
}

class _DynamicMapState extends State<DynamicMap> {
  @override
  void initState() {
    super.initState();
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
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 25)
        ),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body:
      OSMFlutter(
        controller: MapController(
          initPosition: GeoPoint(latitude: 47.4358055, longitude: 8.4737324),
          areaLimit: const BoundingBox(
            east: 10.4922941,
            north: 47.8084648,
            south: 45.817995,
            west: 5.9559113,
          ),
        ),
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
