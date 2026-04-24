import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:flutter/material.dart';
import 'package:internet_measurement_games_app/home.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import 'dart:async'; // needed for StreamSubscription
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'user_data_manager.dart';
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
    
    // SAFELY handle both int and double from Firestore
    final lat = (data['latitude'] as num? ?? 0.0).toDouble();
    final lng = (data['longitude'] as num? ?? 0.0).toDouble();

    return DataPoint(
      point: LatLng(lat, lng),
      timestamp: (data['timestamp'] as firestore.Timestamp?)?.toDate() ?? DateTime.now(),
      uploadSpeed: (data['upload_speed'] as num? ?? data['uploadSpeed'] as num? ?? 0.0).toDouble(),
      downloadSpeed: (data['download_speed'] as num? ?? data['downloadSpeed'] as num? ?? 0.0).toDouble(),
      latency: (data['latency'] as num? ?? 0.0).toDouble(),
      gamePlayed: data['game'] as String? ?? data['gamePlayed'] as String? ?? 'Unknown',
      email: data['email'] as String? ?? 'Unknown',
    );
  }
}

// Filtered stream to only show current user's points
Stream<List<firestore.DocumentSnapshot>> getPointsStream(LatLng center, double radiusKm, GeoCollectionReference geoCollection) {
  return geoCollection.subscribeWithin(
    center: GeoFirePoint(firestore.GeoPoint(center.latitude, center.longitude)),
    radiusInKm: radiusKm,
    field: 'geohash',
    geopointFrom: (data) {
      // SAFELY extract lat/lng and handle both int and double types
      final lat = (data['latitude'] as num? ?? 0.0).toDouble();
      final lng = (data['longitude'] as num? ?? 0.0).toDouble();
      return firestore.GeoPoint(lat, lng);
    },
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
  StreamSubscription? _streamSubscription;
  bool _mapReady = false;
  final List<DataPoint> _pendingPoints = [];

  @override
  void initState() {
    super.initState();

    _mapController = MapController(
      initPosition: GeoPoint(latitude: 35.1861, longitude: -111.6583),
    );

    // Use a post-frame callback to ensure context is available for Provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initDataStream();
    });
  }

  void _initDataStream() {
    final userData = Provider.of<UserDataProvider>(context, listen: false);
    const LatLng center = LatLng(35.1861, -111.6583);
    const double radiusKm = 5000.0; // Large radius for finding points

    debugPrint("MAPS: Querying email: '${userData.email}'");
    
    if (userData.email.isEmpty) {
      debugPrint("MAPS ERROR: User email is empty. Cannot load markers.");
      return;
    }

    final collectionRef = firestore.FirebaseFirestore.instance
        .collection('measurements')
        .doc(userData.email)
        .collection('collected_measurements');

    final geoCollection = GeoCollectionReference(collectionRef);

    _streamSubscription = getPointsStream(center, radiusKm, geoCollection).listen(
      (docs) async {
        debugPrint("[DYNAMIC_MAP]: Received ${docs.length} documents from Firestore.");
        
        final points = docs
            .map((doc) => DataPoint.fromFirestore(doc))
            .toList();

        if (!_mapReady) {
          _pendingPoints.clear();
          _pendingPoints.addAll(points);
          return;
        }
        await _updateMapMarkers(points);
      },
      onError: (e) {
        debugPrint("STREAM ERROR IN MAP: $e");
      }
    );
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
    _streamSubscription?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

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
              _pendingPoints.clear();
            }
          }
        },
        osmOption: const OSMOption(
          userTrackingOption: UserTrackingOption(enableTracking: true),
          zoomOption: ZoomOption(initZoom: 10),
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
                  title: Text('Measurement at ${clickedDp.gamePlayed}'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Download: ${clickedDp.downloadSpeed.toStringAsFixed(2)} Mbps'),
                      Text('Upload: ${clickedDp.uploadSpeed.toStringAsFixed(2)} Mbps'),
                      Text('Latency: ${clickedDp.latency.toStringAsFixed(0)} ms'),
                    ],
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
