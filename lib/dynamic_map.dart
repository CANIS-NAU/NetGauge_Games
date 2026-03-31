import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:flutter/material.dart';
import 'package:internet_measurement_games_app/home.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import 'dart:async'; // needed for StreamSubscription
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'user_data_manager.dart';
import 'activity_logs.dart';
import 'package:get_it/get_it.dart';
import 'package:provider/provider.dart';

// Data Point Class
class DataPoint {
  final LatLng point;
  final DateTime timestamp;
  final double uploadSpeed;
  final double downloadSpeed;
  final double latency;
  final String gamePlayed;
  final String email;

  DataPoint({required this.point, required this.timestamp, required this.uploadSpeed,
    required this.downloadSpeed, required this.latency, required this.gamePlayed, required this.email});

  factory DataPoint.fromFirestore(firestore.DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // Support both GeoPoint objects AND separate lat/long fields
    double lat = 0.0;
    double lng = 0.0;
    
    if (data['location'] is firestore.GeoPoint) {
      lat = (data['location'] as firestore.GeoPoint).latitude;
      lng = (data['location'] as firestore.GeoPoint).longitude;
    } else if (data['geopoint'] is firestore.GeoPoint) {
      lat = (data['geopoint'] as firestore.GeoPoint).latitude;
      lng = (data['geopoint'] as firestore.GeoPoint).longitude;
    } else {
      lat = (data['latitude'] as num?)?.toDouble() ?? 0.0;
      lng = (data['longitude'] as num?)?.toDouble() ?? 0.0;
    }

    return DataPoint(
      point: LatLng(lat, lng),
      timestamp: (data['timestamp'] as firestore.Timestamp?)?.toDate() ?? DateTime.now(),
      uploadSpeed: (data['upload_speed'] as num? ?? data['uploadSpeed'] as num?)?.toDouble() ?? 0.0,
      downloadSpeed: (data['download_speed'] as num? ?? data['downloadSpeed'] as num?)?.toDouble() ?? 0.0,
      latency: (data['latency'] as num?)?.toDouble() ?? 0.0,
      gamePlayed: data['game'] as String? ?? data['gamePlayed'] as String? ?? 'Unknown',
      email: data['email'] as String? ?? 'Unknown',
    );
  }
}

// radius-based stream for gathering points from firestore
final GeoCollectionReference<Map<String, dynamic>> geoCollection =
GeoCollectionReference(firestore.FirebaseFirestore.instance.collection('data_points'));

// Filtered stream to only show current user's points
Stream<List<firestore.DocumentSnapshot>> getPointsStream(LatLng center, double radiusKm, String userEmail) {
  return geoCollection.subscribeWithin(
    center: GeoFirePoint(firestore.GeoPoint(center.latitude, center.longitude)),
    radiusInKm: radiusKm,
    field: 'location',       
    geopointFrom: (data) => (data['location'] ?? data['geopoint']) as firestore.GeoPoint,
  );
}

// Establishing the DynamicMap class, which creates it's own state
class DynamicMap extends StatefulWidget {
  const DynamicMap({Key? key}) : super(key: key);

  @override
  State<DynamicMap> createState() => _DynamicMapState();
}

// Establishing the map state
class _DynamicMapState extends State<DynamicMap> {
  final List<DataPoint> _displayedPoints = [];
  late MapController _mapController;
  late StreamSubscription _streamSubscription;
  bool _mapReady = false;
  final List<DataPoint> _pendingPoints = [];

  @override
  void initState() {
    super.initState();

    _mapController = MapController(
      initPosition: GeoPoint(latitude: 35.1861, longitude: -111.6583),
    );

    final userData = Provider.of<UserDataProvider>(context, listen: false);
    const LatLng center = LatLng(35.1861, -111.6583);
    const double radiusKm = 5000.0; // Large radius for testing

    _streamSubscription = getPointsStream(center, radiusKm, userData.email).listen((docs) async {
      debugPrint("[DYNAMIC_MAP]: Received ${docs.length} documents from Firestore.");
      
      final points = docs
          .map((doc) => DataPoint.fromFirestore(doc))
          .toList();

      debugPrint("[DYNAMIC_MAP]: Processed ${points.length} points.");

      if (!_mapReady) {
        _pendingPoints.clear();
        _pendingPoints.addAll(points);
        return;
      }
      await _updateMapMarkers(points);
    });
  }

  Future<void> _updateMapMarkers(List<DataPoint> points) async {
    // Correctly remove old markers using the list of points
    if (_displayedPoints.isNotEmpty) {
      try {
        await _mapController.removeMarkers(
          _displayedPoints.map((dp) => GeoPoint(latitude: dp.point.latitude, longitude: dp.point.longitude)).toList(),
        );
      } catch (e) {
        debugPrint("[DYNAMIC_MAP]: Error removing markers: $e");
      }
    }
    
    _displayedPoints.clear();

    for (final dp in points) {
      _displayedPoints.add(dp);
      await _mapController.addMarker(
        GeoPoint(latitude: dp.point.latitude, longitude: dp.point.longitude),
        markerIcon: const MarkerIcon(
          icon: Icon(Icons.location_on, color: Colors.red, size: 48),
        ),
      );
    }
    debugPrint("[DYNAMIC_MAP]: Added ${_displayedPoints.length} markers to the map.");
  }

  @override
  void dispose() {
    _streamSubscription.cancel();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userData = Provider.of<UserDataProvider>(context, listen: false);
    
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.home),
          onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomePage())),
        ),
        centerTitle: true,
        title: const Text('Map', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 25)),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: OSMFlutter(
        controller: _mapController,
        onMapIsReady: (isReady) async {
          if (isReady) {
            debugPrint("[DYNAMIC_MAP]: Map is ready.");
            setState(() => _mapReady = true);
            if (_pendingPoints.isNotEmpty) {
              await _updateMapMarkers(_pendingPoints);
            }
          }
        },
        osmOption: OSMOption(
          userTrackingOption: const UserTrackingOption(enableTracking: true, unFollowUser: false),
          zoomOption: const ZoomOption(initZoom: 8, minZoomLevel: 3, maxZoomLevel: 19, stepZoom: 1.0),
          userLocationMarker: UserLocationMaker(
            personMarker: const MarkerIcon(icon: Icon(Icons.location_history_rounded, color: Colors.red, size: 48)),
            directionArrowMarker: const MarkerIcon(icon: Icon(Icons.double_arrow, size: 48)),
          ),
          roadConfiguration: const RoadOption(roadColor: Colors.yellowAccent),
        ),
        onGeoPointClicked: (point) {
          try {
            final clickedDp = _displayedPoints.firstWhere(
              (dp) => dp.point.latitude == point.latitude && dp.point.longitude == point.longitude,
            );

            showDialog(
              context: context,
              builder: (context) => PointerInterceptor(
                child: AlertDialog(
                  title: const Text('Measurement Details'),
                  content: SingleChildScrollView(
                    child: ListBody(
                      children: <Widget>[
                        Text('Game: ${clickedDp.gamePlayed}'),
                        const SizedBox(height: 8),
                        Text('Download: ${clickedDp.downloadSpeed.toStringAsFixed(2)} Mbps'),
                        Text('Upload: ${clickedDp.uploadSpeed.toStringAsFixed(2)} Mbps'),
                        Text('Latency: ${clickedDp.latency.toStringAsFixed(0)} ms'),
                        const SizedBox(height: 8),
                        Text('Timestamp: ${clickedDp.timestamp.toLocal()}'),
                        Text('User: ${clickedDp.email}'),
                      ],
                    ),
                  ),
                  actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
                ),
              ),
            );
          } catch (e) {
             debugPrint('Could not find data for point: $e');
          }
        },
      ),
    );
  }
}
