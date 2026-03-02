import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:flutter/material.dart';
import 'package:internet_measurement_games_app/home.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import 'dart:async'; // needed for StreamSubscription
import 'package:pointer_interceptor/pointer_interceptor.dart';

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

// Dummy DataPoint list
final List<DataPoint> dummyPoints = [
  DataPoint(point: LatLng(35.1861, -111.6583), timestamp: DateTime.now(), uploadSpeed: 0.0, downloadSpeed: 0.0, latency: 0.0, gamePlayed: "Test"),
  DataPoint(point: LatLng(35.5, -111.5), timestamp: DateTime.now(), uploadSpeed: 0.0, downloadSpeed: 0.0, latency: 0.0, gamePlayed: "Test"),
  DataPoint(point: LatLng(35.25, -111.8), timestamp: DateTime.now(), uploadSpeed: 0.0, downloadSpeed: 0.0, latency: 0.0, gamePlayed: "Test"),
];

// radius-based stream for gathering points from firestore
final GeoCollectionReference<Map<String, dynamic>> geoCollection =
GeoCollectionReference(firestore.FirebaseFirestore.instance.collection('data_points'));

Stream<List<firestore.DocumentSnapshot>> getPointsStream(LatLng center, double radiusKm) {
  return geoCollection.subscribeWithin(
    center: GeoFirePoint(firestore.GeoPoint(center.latitude, center.longitude)),
    radiusInKm: radiusKm,
    field: 'location',       // the nested field name you used when writing
    geopointFrom: (data) => data['location']['geopoint'] as firestore.GeoPoint,
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
  List<DataPoint> _displayedPoints = [];
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
      initPosition: GeoPoint(latitude: 35.1861, longitude: -111.6583),
    );

    final LatLng center = LatLng(35.1861, -111.6583);
    final double radiusKm = 50.0; // Increased radius for testing

    _streamSubscription = getPointsStream(center, radiusKm).listen((docs) async {
      // Dummy points for testing
      final points = dummyPoints;

      // Uncomment to use actual points
      //final points = docs.map((doc) => DataPoint.fromFirestore(doc)).toList();
      if (!_mapReady) {
        _pendingPoints.addAll(points);
        return;
      }
      await _updateMapMarkers(points);
    });
  }

  Future<void> _updateMapMarkers(List<DataPoint> points) async {
    await _mapController.removeMarkers(
      _displayedPoints
          .map((dp) => GeoPoint(

        latitude: dp.point.latitude,
        longitude: dp.point.longitude,
      ))
          .toList(),

    );
    _displayedPoints.clear();

    for (final dp in points) {
      _displayedPoints.add(dp);

      await _mapController.addMarker(
        GeoPoint(
          latitude: dp.point.latitude,
          longitude: dp.point.longitude,
        ),
        markerIcon: const MarkerIcon(
          icon: Icon(Icons.location_pin, color: Colors.red, size: 48),
        ),
      );
    }
  }

  @override
  void dispose() {
    _streamSubscription.cancel();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    loggingService.logEvent('User is in dynamic map page.');
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
        controller: _mapController,
        onMapIsReady: (isReady) async {
          if (isReady) {
            await Future.delayed(const Duration(milliseconds: 500));

            setState(() {
              _mapReady = true;
            });

            await _updateMapMarkers(dummyPoints);
          }
        },
        osmOption: OSMOption(
          userTrackingOption: const UserTrackingOption(
            enableTracking: true,
            unFollowUser: false,
          ),
          zoomOption: const ZoomOption(
            initZoom: 5,
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
        onGeoPointClicked: (point) {
          loggingService.logEvent('Clicked on point: ${point}');
          try {
            final clickedDp = _displayedPoints.firstWhere(
                  (dp) =>
              dp.point.latitude == point.latitude &&
                  dp.point.longitude == point.longitude,
            );

            showDialog(
              context: context,
              builder: (context) => PointerInterceptor(
                child: AlertDialog(
                  title: Text('Measurement Details'),
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
                        Text('Location: (${clickedDp.point.latitude.toStringAsFixed(4)}, ${clickedDp.point.longitude.toStringAsFixed(4)})'),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
            );
          } catch (e) {
             print('Could not find data for point: $e');
          }
        },
      ),
    );
  }
}
