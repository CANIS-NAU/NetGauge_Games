import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_heatmap/flutter_map_heatmap.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:internet_measurement_games_app/location_service.dart';
import 'package:internet_measurement_games_app/session_manager.dart';

final List<WeightedLatLng> heatmapData = [
    WeightedLatLng(LatLng(35.1983, -111.6513), 1.0),
    WeightedLatLng(LatLng(35.1990, -111.6500), 0.8),
    WeightedLatLng(LatLng(35.1970, -111.6520), 0.6),
    WeightedLatLng(LatLng(35.2001, -111.6495), 0.9),
    WeightedLatLng(LatLng(35.1965, -111.6535), 0.7),
    WeightedLatLng(LatLng(35.1988, -111.6487), 0.5),
    WeightedLatLng(LatLng(35.1957, -111.6550), 0.6),
    WeightedLatLng(LatLng(35.2010, -111.6478), 0.4),
    WeightedLatLng(LatLng(35.1995, -111.6542), 0.7),
    WeightedLatLng(LatLng(35.1978, -111.6498), 0.8),
    WeightedLatLng(LatLng(35.1960, -111.6515), 0.9),
    WeightedLatLng(LatLng(35.2005, -111.6527), 0.5),
    WeightedLatLng(LatLng(35.1980, -111.6555), 0.6),
    WeightedLatLng(LatLng(35.1950, -111.6505), 0.7),
    WeightedLatLng(LatLng(35.2015, -111.6533), 0.8),
    WeightedLatLng(LatLng(35.1973, -111.6489), 0.6),
    WeightedLatLng(LatLng(35.1992, -111.6510), 0.9),
    WeightedLatLng(LatLng(35.1967, -111.6547), 0.7),
    WeightedLatLng(LatLng(35.1985, -111.6493), 0.5),
    WeightedLatLng(LatLng(35.2000, -111.6508), 0.8),
  ];

  final List<Map<double, MaterialColor>> gradients = [
    {
      0.0: Colors.blue,
      0.5: Colors.green,
      1.0: Colors.red,
    }
  ];

class MapPage extends StatefulWidget {
  final List<WeightedLatLng> data;
  final List<Map<double, MaterialColor>> gradients;
  final int index;
  final Stream<void> rebuildStream;

  const MapPage({
    Key? key,
    required this.data,
    required this.gradients,
    required this.index,
    required this.rebuildStream,
  }) : super(key: key);

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  @override
  void initState() {
    super.initState();
    _logMapViewEvent();
  }

  Future<void> _logMapViewEvent() async {
    final loc = await determineLocationData();
    final nickname = SessionManager.playerName;
    final sessionId = SessionManager.sessionId;

    final mapViewLog = {
      'event': 'Viewed Map',
      'latitude': loc.position.latitude,
      'longitude': loc.position.longitude,
      'nickname': nickname,
      'sessionID': sessionId,
      'timestamp': FieldValue.serverTimestamp(),
    };

    try {
      await FirebaseFirestore.instance
          .collection('Movement Data')
          .doc(sessionId)
          .collection('CheckData')
          .add(mapViewLog);
      debugPrint('[MAP_PAGE] Map view log added to Firestore.');
    } catch (e) {
      debugPrint('[MAP_PAGE] Error logging map view: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Flagstaff Map Data')),
      body: FlutterMap(
        options: MapOptions(
          center: LatLng(35.1983, -111.6513),
          zoom: 13.0,
        ),
        children: [
          TileLayer(
            urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
          ),
          if (widget.data.isNotEmpty)
            HeatMapLayer(
              heatMapDataSource: InMemoryHeatMapDataSource(
                data: widget.data,
              ),
              heatMapOptions: HeatMapOptions(
                gradient: widget.gradients[widget.index],
                minOpacity: 0.1,
              ),
              reset: widget.rebuildStream,
            ),
        ],
      ),
    );
  }
}