import 'package:flutter/material.dart';
import 'dart:math';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_heatmap/flutter_map_heatmap.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:internet_measurement_games_app/location_service.dart';
import 'package:internet_measurement_games_app/session_manager.dart';

final double pinchZoomThreshold = 40.0;
class TimedWeightedLatLng {
  final LatLng point;
  final double intensity;
  final DateTime timestamp;

  TimedWeightedLatLng(this.point, this.intensity, this.timestamp);

  /// Converts to a WeightedLatLng with adjusted intensity
    WeightedLatLng toWeighted({required DateTime now}) {
    final age = now.difference(timestamp).inDays;

    if (age > 120) {
      return WeightedLatLng(point, 0.0); // faded out
    } else {
      final fadeFactor = max(0.3, 1.0 - (age / 120.0)); // linear fade
      return WeightedLatLng(point, intensity * fadeFactor.clamp(0.3, 1.0));
    }
  }
}

final List<TimedWeightedLatLng> heatmapData = [
  
    /* 
    TimedWeightedLatLng(LatLng(35.1983, -111.6513), 1.0, DateTime.now().subtract(const Duration(days: 10))),
    TimedWeightedLatLng(LatLng(35.1990, -111.6500), 1.0, DateTime.now().subtract(const Duration(days: 10))),
    TimedWeightedLatLng(LatLng(35.1970, -111.6520), 1.0, DateTime.now().subtract(const Duration(days: 10))),
    TimedWeightedLatLng(LatLng(35.2001, -111.6495), 1.0, DateTime.now().subtract(const Duration(days: 10))),
    TimedWeightedLatLng(LatLng(35.1965, -111.6535), 1.0, DateTime.now().subtract(const Duration(days: 10))),
    TimedWeightedLatLng(LatLng(35.1988, -111.6487), 1.0, DateTime.now().subtract(const Duration(days: 10))),
    TimedWeightedLatLng(LatLng(35.1957, -111.6550), 1.0, DateTime.now().subtract(const Duration(days: 10))),
    TimedWeightedLatLng(LatLng(35.2010, -111.6478), 1.0, DateTime.now().subtract(const Duration(days: 10))),
    TimedWeightedLatLng(LatLng(35.1995, -111.6542), 1.0, DateTime.now().subtract(const Duration(days: 10))),
    TimedWeightedLatLng(LatLng(35.1978, -111.6498), 1.0, DateTime.now().subtract(const Duration(days: 10))),
    TimedWeightedLatLng(LatLng(35.1960, -111.6515), 0.9, DateTime.now().subtract(const Duration(days: 10))),
    TimedWeightedLatLng(LatLng(35.2005, -111.6527), 1.0, DateTime.now().subtract(const Duration(days: 10))),
    TimedWeightedLatLng(LatLng(35.1980, -111.6555), 1.0, DateTime.now().subtract(const Duration(days: 10))),
    TimedWeightedLatLng(LatLng(35.1950, -111.6505), 1.0, DateTime.now().subtract(const Duration(days: 10))),
    TimedWeightedLatLng(LatLng(35.2015, -111.6533), 0.8, DateTime.now().subtract(const Duration(days: 10))),
    TimedWeightedLatLng(LatLng(35.1973, -111.6489), 0.6, DateTime.now().subtract(const Duration(days: 10))),
    TimedWeightedLatLng(LatLng(35.1992, -111.6510), 0.9, DateTime.now().subtract(const Duration(days: 10))),
    TimedWeightedLatLng(LatLng(35.1967, -111.6547), 0.7, DateTime.now().subtract(const Duration(days: 10))),
    TimedWeightedLatLng(LatLng(35.1985, -111.6493), 0.5, DateTime.now().subtract(const Duration(days: 10))),
    TimedWeightedLatLng(LatLng(35.2000, -111.6508), 0.8, DateTime.now().subtract(const Duration(days: 10))),
    TimedWeightedLatLng(LatLng(35.1989, -111.6510), 1.0, DateTime.now().subtract(const Duration(days: 5))),
    TimedWeightedLatLng(LatLng(35.1991, -111.6502), 0.9, DateTime.now().subtract(const Duration(days: 15))),
    TimedWeightedLatLng(LatLng(35.1975, -111.6525), 0.8, DateTime.now().subtract(const Duration(days: 25))),
    TimedWeightedLatLng(LatLng(35.2003, -111.6489), 0.7, DateTime.now().subtract(const Duration(days: 35))),
    TimedWeightedLatLng(LatLng(35.1968, -111.6541), 0.6, DateTime.now().subtract(const Duration(days: 45))),
    TimedWeightedLatLng(LatLng(35.1982, -111.6479), 0.5, DateTime.now().subtract(const Duration(days: 55))),
    TimedWeightedLatLng(LatLng(35.1959, -111.6556), 0.4, DateTime.now().subtract(const Duration(days: 65))),
    TimedWeightedLatLng(LatLng(35.2012, -111.6471), 0.3, DateTime.now().subtract(const Duration(days: 75))),
    TimedWeightedLatLng(LatLng(35.1993, -111.6548), 0.2, DateTime.now().subtract(const Duration(days: 85))),
    TimedWeightedLatLng(LatLng(35.1976, -111.6501), 0.1, DateTime.now().subtract(const Duration(days: 89))),
    TimedWeightedLatLng(LatLng(35.1962, -111.6518), 1.0, DateTime.now().subtract(const Duration(days: 3))),
    TimedWeightedLatLng(LatLng(35.2006, -111.6523), 0.9, DateTime.now().subtract(const Duration(days: 7))),
    TimedWeightedLatLng(LatLng(35.1981, -111.6552), 0.8, DateTime.now().subtract(const Duration(days: 14))),
    TimedWeightedLatLng(LatLng(35.1951, -111.6503), 0.7, DateTime.now().subtract(const Duration(days: 22))),
    TimedWeightedLatLng(LatLng(35.2016, -111.6531), 0.6, DateTime.now().subtract(const Duration(days: 31))),
    TimedWeightedLatLng(LatLng(35.1974, -111.6488), 0.5, DateTime.now().subtract(const Duration(days: 48))),
    TimedWeightedLatLng(LatLng(35.1991, -111.6512), 0.4, DateTime.now().subtract(const Duration(days: 59))),
    TimedWeightedLatLng(LatLng(35.1966, -111.6545), 0.3, DateTime.now().subtract(const Duration(days: 67))),
    TimedWeightedLatLng(LatLng(35.1984, -111.6490), 0.2, DateTime.now().subtract(const Duration(days: 74))),
    TimedWeightedLatLng(LatLng(35.2002, -111.6506), 0.1, DateTime.now().subtract(const Duration(days: 88))),
    TimedWeightedLatLng(LatLng(35.1993, -111.6521), 0.9, DateTime.now().subtract(const Duration(days: 0))),
    TimedWeightedLatLng(LatLng(35.1975, -111.6532), 0.8, DateTime.now().subtract(const Duration(days: 5))),
    TimedWeightedLatLng(LatLng(35.1988, -111.6540), 0.7, DateTime.now().subtract(const Duration(days: 10))),
    TimedWeightedLatLng(LatLng(35.2002, -111.6507), 1.0, DateTime.now().subtract(const Duration(days: 15))),
    TimedWeightedLatLng(LatLng(35.2011, -111.6519), 0.6, DateTime.now().subtract(const Duration(days: 20))),
    TimedWeightedLatLng(LatLng(35.1980, -111.6485), 0.5, DateTime.now().subtract(const Duration(days: 25))),
    TimedWeightedLatLng(LatLng(35.1968, -111.6549), 0.9, DateTime.now().subtract(const Duration(days: 30))),
    TimedWeightedLatLng(LatLng(35.2020, -111.6503), 1.0, DateTime.now().subtract(const Duration(days: 35))),
    TimedWeightedLatLng(LatLng(35.1997, -111.6481), 0.4, DateTime.now().subtract(const Duration(days: 45))),
    TimedWeightedLatLng(LatLng(35.2008, -111.6537), 0.8, DateTime.now().subtract(const Duration(days: 60))),
    TimedWeightedLatLng(LatLng(35.1972, -111.6492), 0.7, DateTime.now().subtract(const Duration(days: 75))),
    TimedWeightedLatLng(LatLng(35.1959, -111.6525), 0.3, DateTime.now().subtract(const Duration(days: 90))),
    TimedWeightedLatLng(LatLng(35.1986, -111.6558), 0.6, DateTime.now().subtract(const Duration(days: 100))),
    TimedWeightedLatLng(LatLng(35.2017, -111.6479), 0.5, DateTime.now().subtract(const Duration(days: 110))),
    TimedWeightedLatLng(LatLng(35.1999, -111.6499), 0.2, DateTime.now().subtract(const Duration(days: 120))),
    TimedWeightedLatLng(LatLng(35.2003, -111.6512), 0.9, DateTime.now().subtract(Duration(days: 2))),
    TimedWeightedLatLng(LatLng(35.1987, -111.6501), 0.7, DateTime.now().subtract(Duration(days: 8))),
    TimedWeightedLatLng(LatLng(35.1998, -111.6525), 1.0, DateTime.now().subtract(Duration(days: 14))),
    TimedWeightedLatLng(LatLng(35.1973, -111.6538), 0.6, DateTime.now().subtract(Duration(days: 25))),
    TimedWeightedLatLng(LatLng(35.2011, -111.6493), 0.8, DateTime.now().subtract(Duration(days: 32))),
    TimedWeightedLatLng(LatLng(35.1969, -111.6518), 0.5, DateTime.now().subtract(Duration(days: 41))),
    TimedWeightedLatLng(LatLng(35.2022, -111.6485), 0.9, DateTime.now().subtract(Duration(days: 55))),
    TimedWeightedLatLng(LatLng(35.2009, -111.6540), 1.0, DateTime.now().subtract(Duration(days: 66))),
    TimedWeightedLatLng(LatLng(35.1984, -111.6497), 0.4, DateTime.now().subtract(Duration(days: 78))),
    TimedWeightedLatLng(LatLng(35.1990, -111.6479), 0.3, DateTime.now().subtract(Duration(days: 89))),
    TimedWeightedLatLng(LatLng(35.1958, -111.6530), 0.2, DateTime.now().subtract(Duration(days: 95))),
    TimedWeightedLatLng(LatLng(35.2013, -111.6552), 0.6, DateTime.now().subtract(Duration(days: 105))),
    TimedWeightedLatLng(LatLng(35.1979, -111.6483), 0.7, DateTime.now().subtract(Duration(days: 112))),
    TimedWeightedLatLng(LatLng(35.1981, -111.6509), 0.5, DateTime.now().subtract(Duration(days: 120))),
    TimedWeightedLatLng(LatLng(35.1994, -111.6533), 0.9, DateTime.now().subtract(Duration(days: 0))), 
   */
  ];

//colors --> blue to orange gradient 
  final List<Map<double, MaterialColor>> gradients = [
    {
      0.0: Colors.blue,
      0.3: Colors.cyan,
      0.5: Colors.lime,
      0.7: Colors.orange,
      1.0: Colors.red,
    }
  ];

class MapPage extends StatefulWidget {
  final List<TimedWeightedLatLng> data;
  final List<Map<double, MaterialColor>> gradients;
  final int index;
  final Stream<void> rebuildStream;
  final LatLng? center;

  const MapPage({
    Key? key,
    required this.data,
    required this.gradients,
    required this.index,
    required this.rebuildStream,
    this.center,
  }) : super(key: key);

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  LatLng? _center;
  
  @override
  void initState() {
    super.initState();
    _logMapViewEvent();
    _setInitialCenter();
  }

  Future<void> _setInitialCenter() async {
  try {
    final loc = await determineLocationData();
    print("DEBUG LOCATION: ${loc.position.latitude}, ${loc.position.longitude}");

    setState(() {
      _center = LatLng(loc.position.latitude, loc.position.longitude);
    });
  } catch (e) {
    print("ERROR setting center: $e");
    setState(() {
      _center = LatLng(35.1983, -111.6513); // fallback if location fails
    });
  }
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
      appBar: AppBar(title: const Text('Measurement Map Data')),
      body: _center == null
          ? const Center(child: CircularProgressIndicator())
      : FlutterMap(
        options: MapOptions(
          // ignore: deprecated_member_use
          center: _center!,
          // ignore: deprecated_member_use
          zoom: 15.0,
          // ignore: deprecated_member_use
          pinchZoomThreshold: pinchZoomThreshold,
        ),
        children: [
          TileLayer(
            urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
            subdomains: ['a', 'b', 'c'],
            userAgentPackageName: 'com.example.internet_measurement_games_app',
            additionalOptions: {
              'User-Agent': 'NetGauge Games Testing App',
            },
          ),
          if (widget.data.isNotEmpty)
            HeatMapLayer(
              heatMapDataSource: InMemoryHeatMapDataSource(
                data: widget.data.map((t) => t.toWeighted(now: DateTime.now())).toList(),
              ),
              heatMapOptions: HeatMapOptions(
                gradient: widget.gradients[widget.index],
                minOpacity: 0.7,
                radius: 60.0,
              ),
              reset: widget.rebuildStream,
            ),
        ],
      ),
    );
  }
}