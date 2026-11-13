import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:flutter/material.dart';
import 'package:internet_measurement_games_app/home.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_heatmap/flutter_map_heatmap.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import 'dart:async'; // needed for StreamSubscription
import 'user_data_manager.dart';
import 'public_measurements.dart';
import 'location_service.dart';
import 'h3_grid.dart';
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

  DataPoint(
      {required this.point,
      required this.timestamp,
      required this.uploadSpeed,
      required this.downloadSpeed,
      required this.latency,
      required this.gamePlayed,
      required this.email});

  factory DataPoint.fromFirestore(firestore.DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // SAFELY handle both int and double from Firestore
    final lat = (data['latitude'] as num? ?? 0.0).toDouble();
    final lng = (data['longitude'] as num? ?? 0.0).toDouble();

    return DataPoint(
      point: LatLng(lat, lng),
      timestamp: (data['timestamp'] as firestore.Timestamp?)?.toDate() ??
          DateTime.now(),
      uploadSpeed:
          (data['upload_speed'] as num? ?? data['uploadSpeed'] as num? ?? 0.0)
              .toDouble(),
      downloadSpeed: (data['download_speed'] as num? ??
              data['downloadSpeed'] as num? ??
              0.0)
          .toDouble(),
      latency: (data['latency'] as num? ?? 0.0).toDouble(),
      gamePlayed:
          data['game'] as String? ?? data['gamePlayed'] as String? ?? 'Unknown',
      email: data['email'] as String? ?? 'Unknown',
    );
  }
}

// Filtered stream to only show current user's points
Stream<List<firestore.DocumentSnapshot>> getPointsStream(
    LatLng center, double radiusKm, GeoCollectionReference geoCollection) {
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

// which measurement the heat map is showing
enum SpeedMetric { download, upload }

// whose measurements the map shows
enum DataScope { mine, all }

// the "all measurements" view reads at most this many anonymized documents
const int _maxAllMeasurements = 5000;

// in the "all measurements" view, pins only appear at or above this zoom level
const double _allPinsMinZoom = 15.0;

// speeds at or above this (in Mbps) are drawn as the fastest color
const double _referenceSpeedMbps = 100.0;
// measurements are averaged within grid cells of this size (in degrees, roughly 30 m)
const double _gridSizeDegrees = 0.0003;

// slow (red) to fast (green); heat map intensity is the speed relative to _referenceSpeedMbps
final Map<double, MaterialColor> _speedGradient = {
  0.25: Colors.red,
  0.55: Colors.orange,
  0.85: Colors.lime,
  1.0: Colors.green,
};

// Establishing the DynamicMap class, which creates it's own state
class DynamicMap extends StatefulWidget {
  const DynamicMap({Key? key}) : super(key: key);

  @override
  State<DynamicMap> createState() => _DynamicMapState();
}

// Establishing the map state
class _DynamicMapState extends State<DynamicMap> {
  final MapController _mapController = MapController();
  StreamSubscription? _streamSubscription;
  List<DataPoint> _points = [];
  SpeedMetric _metric = SpeedMetric.download;
  DataScope _scope = DataScope.mine;
  // whether the map is zoomed in far enough to show pins in the "all measurements" view
  bool _zoomedInForPins = false;
  // changes whenever the data or metric changes, which forces the heat map layer to redraw
  int _revision = 0;
  // the H3 hexagon grid view (null grid means the H3 library could not be loaded)
  H3Grid? _h3Grid;
  bool _showH3 = false;
  List<H3Sample> _h3Samples = [];
  int? _h3Resolution;

  @override
  void initState() {
    super.initState();
    H3Grid.tryLoad().then((grid) {
      if (mounted) setState(() => _h3Grid = grid);
    });

    // Use a post-frame callback to ensure context is available for Provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initDataStream();
    });
  }

  void _initDataStream() {
    final userData = Provider.of<UserDataProvider>(context, listen: false);

    if (userData.email.isEmpty) {
      debugPrint("MAPS ERROR: User email is empty.");
      return;
    }

    // make sure this user's older measurements are also in the shared collection (a no-op after the first time)
    PublicMeasurements.backfillOwn(userData.email);

    // switching scope replaces the previous subscription
    _streamSubscription?.cancel();

    final firestore.Query<Map<String, dynamic>> query = _scope == DataScope.mine
        ? firestore.FirebaseFirestore.instance
            .collection('measurements')
            .doc(userData.email)
            .collection('collected_measurements')
        // anonymized copies of everyone's measurements (results and coarse location only), kept up to date
        // by the publishAnonymizedMeasurement Cloud Function
        : firestore.FirebaseFirestore.instance
            .collection('public_measurements')
            .limit(_maxAllMeasurements);

    _streamSubscription = query.snapshots().listen(
      (snapshot) {
        debugPrint(
            "[DYNAMIC_MAP]: Received ${snapshot.docs.length} documents (${_scope.name}).");

        // measurements taken without location access have no coordinates, so they cannot be placed on the map
        final points = snapshot.docs
            .where((doc) {
              final data = doc.data();
              return data['latitude'] is num && data['longitude'] is num;
            })
            .map((doc) => DataPoint.fromFirestore(doc))
            .toList();

        if (!mounted) return;
        setState(() {
          _points = points;
          _h3Samples = points
              .map((p) => H3Sample(location: p.point, downloadSpeed: p.downloadSpeed, uploadSpeed: p.uploadSpeed))
              .toList();
          _revision++;
        });
      },
      onError: (e) {
        debugPrint("STREAM ERROR IN MAP: $e");
        if (!mounted || _scope == DataScope.mine) return;
        // most likely the security rules do not allow reading public_measurements
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Could not load all measurements. Showing yours instead.')),
        );
        setState(() => _scope = DataScope.mine);
        _initDataStream();
      },
    );
  }

  // moves the map to the user's location, if it can be determined
  Future<void> _centerOnUser() async {
    try {
      final loc = await determineLocationData();
      if (!mounted) return;
      _mapController.move(
          LatLng(loc.position.latitude, loc.position.longitude), 15);
    } catch (e) {
      debugPrint("[DYNAMIC_MAP]: Could not center on user: $e");
    }
  }

  double _speedOf(DataPoint dp) =>
      _metric == SpeedMetric.download ? dp.downloadSpeed : dp.uploadSpeed;

  // Averages the speeds within each grid cell so many measurements in one spot do not stack up and
  // look faster than they are (the heat map adds overlapping intensities together).
  List<WeightedLatLng> _buildHeatData() {
    final cells = <String, List<DataPoint>>{};
    for (final dp in _points) {
      final key =
          '${(dp.point.latitude / _gridSizeDegrees).round()},${(dp.point.longitude / _gridSizeDegrees).round()}';
      cells.putIfAbsent(key, () => []).add(dp);
    }

    return cells.values.map((cell) {
      final avgSpeed = cell.map(_speedOf).reduce((a, b) => a + b) / cell.length;
      final lat = cell.map((dp) => dp.point.latitude).reduce((a, b) => a + b) /
          cell.length;
      final lng = cell.map((dp) => dp.point.longitude).reduce((a, b) => a + b) /
          cell.length;
      // keep a small minimum so very slow areas are still visible
      final intensity = (avgSpeed / _referenceSpeedMbps).clamp(0.05, 1.0);
      return WeightedLatLng(LatLng(lat, lng), intensity);
    }).toList();
  }

  // shows the results of one measurement
  void _showMeasurement(DataPoint point, String email) {
    loggingService.logEvent('User clicked on geo-point: $point', email: email);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 40.0,
        title: const Text('Measurement'),
        backgroundColor: Colors.white,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // other people's measurements are anonymized, so only the user's own show the game played
            if (_scope == DataScope.mine) Text('Game Played: ${point.gamePlayed}'),
            Text('Download: ${point.downloadSpeed.toStringAsFixed(2)} Mbps'),
            Text('Upload: ${point.uploadSpeed.toStringAsFixed(2)} Mbps'),
            Text('Latency: ${point.latency.toStringAsFixed(0)} ms'),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  // one tappable pin per measurement, drawn on top of the heat map
  List<Marker> _buildPins(String email) {
    return _points.map((dp) => Marker(
      point: dp.point,
      width: 40,
      height: 40,
      // the tip of the pin sits on the measurement location
      alignment: Alignment.topCenter,
      child: GestureDetector(
        onTap: () => _showMeasurement(dp, email),
        child: const Icon(Icons.location_on, color: Colors.deepPurple, size: 40),
      ),
    )).toList();
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userData = Provider.of<UserDataProvider>(context, listen: false);
    final heatData = _buildHeatData();
    final metricLabel = _metric == SpeedMetric.download ? 'Download' : 'Upload';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.home),
          onPressed: () => Navigator.pushReplacement(context,
              MaterialPageRoute(builder: (context) => const HomePage())),
        ),
        centerTitle: true,
        title: const Text('Map',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 25)),
        backgroundColor: const Color(0xFF440154),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(35.1861, -111.6583),
              initialZoom: 13,
              onMapReady: _centerOnUser,
              onPositionChanged: (position, hasGesture) {
                final zoomedIn = (position.zoom ?? 0) >= _allPinsMinZoom;
                // only rebuild when the zoom crosses the threshold, not on every pan or pinch
                if (zoomedIn != _zoomedInForPins) setState(() => _zoomedInForPins = zoomedIn);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                userAgentPackageName: 'com.pht.netgauge',
              ),
              if (!_showH3 && heatData.isNotEmpty)
                HeatMapLayer(
                  key: ValueKey('$_metric-$_revision'),
                  heatMapDataSource: InMemoryHeatMapDataSource(data: heatData),
                  heatMapOptions: HeatMapOptions(
                    gradient: _speedGradient,
                    minOpacity: 0.5,
                    radius: 40.0,
                  ),
                ),
              // H3 view: one hexagon per area, colored by the average speed of the measurements inside it
              if (_showH3 && _h3Grid != null)
                H3OverlayLayer(
                  grid: _h3Grid!,
                  samples: _h3Samples,
                  gradient: _speedGradient,
                  styleKey: _metric,
                  intensityOf: (cell, maxCount) {
                    final speed = _metric == SpeedMetric.download ? cell.averageDownload : cell.averageUpload;
                    return (speed / _referenceSpeedMbps).clamp(0.05, 1.0);
                  },
                  onResolutionChanged: (r) => setState(() => _h3Resolution = r),
                ),
              // the user's own measurements always get pins; everyone's only when zoomed in, to keep the map readable
              if (_points.isNotEmpty && (_scope == DataScope.mine || _zoomedInForPins))
                MarkerLayer(markers: _buildPins(userData.email)),
            ],
          ),
          // choose whose measurements and which speed the heat map shows
          Positioned(
            top: 12,
            left: 0,
            right: 0,
            child: Column(
              children: [
                SegmentedButton<DataScope>(
                  style:
                      SegmentedButton.styleFrom(backgroundColor: Colors.white),
                  segments: const [
                    ButtonSegment(
                        value: DataScope.mine,
                        label: Text('My Measurements'),
                        icon: Icon(Icons.person)),
                    ButtonSegment(
                        value: DataScope.all,
                        label: Text('All Measurements'),
                        icon: Icon(Icons.public)),
                  ],
                  selected: {_scope},
                  onSelectionChanged: (selection) {
                    setState(() => _scope = selection.first);
                    _initDataStream();
                  },
                ),
                const SizedBox(height: 8),
                SegmentedButton<SpeedMetric>(
                  style:
                      SegmentedButton.styleFrom(backgroundColor: Colors.white),
                  segments: const [
                    ButtonSegment(
                        value: SpeedMetric.download,
                        label: Text('Download'),
                        icon: Icon(Icons.download)),
                    ButtonSegment(
                        value: SpeedMetric.upload,
                        label: Text('Upload'),
                        icon: Icon(Icons.upload)),
                  ],
                  selected: {_metric},
                  onSelectionChanged: (selection) => setState(() {
                    _metric = selection.first;
                    _revision++;
                  }),
                ),
                const SizedBox(height: 8),
                // switches the heat map for the H3 hexagon grid
                FilterChip(
                  backgroundColor: Colors.white,
                  selectedColor: Colors.deepPurple.shade100,
                  avatar: const Icon(Icons.hexagon_outlined),
                  label: const Text('H3 Grid'),
                  selected: _showH3,
                  onSelected: (on) {
                    if (on && _h3Grid == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('The H3 grid is not available on this device.')),
                      );
                      return;
                    }
                    setState(() => _showH3 = on);
                  },
                ),
              ],
            ),
          ),
          // legend
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _points.isEmpty
                        ? 'No measurements with a location yet'
                        : '$metricLabel speed (${_points.length} ${_scope == DataScope.mine ? 'of your' : 'total'} measurements)',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (_showH3 && _h3Resolution != null)
                    Text(
                      'H3 hexagons, ${h3EdgeLabel(_h3Resolution!)} per side; zoom in for smaller ones',
                      style: const TextStyle(fontSize: 12),
                    ),
                  const SizedBox(height: 8),
                  Container(
                    height: 12,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      gradient: const LinearGradient(
                        colors: [
                          Colors.red,
                          Colors.orange,
                          Colors.lime,
                          Colors.green
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('0 Mbps (slow)',
                          style: TextStyle(fontSize: 12)),
                      Text('${_referenceSpeedMbps.toInt()}+ Mbps (fast)',
                          style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
