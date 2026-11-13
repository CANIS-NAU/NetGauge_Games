// Community statistics: high-level data about everyone's shared measurements within 50 miles of the user.
// Shows a heat map of how many measurements were collected where, and the most frequently played game nearby.
// Only the anonymized public_measurements collection is used (no emails, sessions or other private data).

// Import libraries, packages, and pages
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_heatmap/flutter_map_heatmap.dart';
import 'package:latlong2/latlong.dart';
import 'community_stats.dart';
import 'h3_grid.dart';
import 'location_service.dart';
import 'public_measurements.dart';
import 'public_sessions.dart';
import 'account_identity.dart';
import 'package:firebase_auth/firebase_auth.dart';

// where the map starts if the user's location is not available (Flagstaff, AZ)
const LatLng _fallbackCenter = LatLng(35.1983, -111.6513);

// at most this many measurements, and this many plays, are read for the area
const int _maxMeasurements = 5000;

// few to many measurements; the heat map colors, matching the legend
final Map<double, MaterialColor> _densityGradient = {
  0.25: Colors.blue,
  0.5: Colors.cyan,
  0.7: Colors.lime,
  0.85: Colors.orange,
  1.0: Colors.red,
};

// what the page shows: the area, and the statistics for it
class CommunityData {
  final LatLng center;
  final bool usingFallbackLocation;
  final CommunityStats stats;

  const CommunityData({required this.center, required this.usingFallbackLocation, required this.stats});
}

// Finds the user and reads everything shared within 50 miles of them from the anonymized collection.
Future<CommunityData> loadCommunityData() async {
  const radiusMeters = communityRadiusMiles * milesToMeters;

  // 1. where is the user
  LatLng center;
  bool fallback = false;
  try {
    final loc = await determineLocationData().timeout(const Duration(seconds: 10));
    center = LatLng(loc.position.latitude, loc.position.longitude);
  } catch (e) {
    debugPrint('[COMMUNITY_STATS] Location unavailable, using the default area: $e');
    center = _fallbackCenter;
    fallback = true;
  }

  // 2. the user's own earlier plays are added to the shared plays once, so they count too (does nothing after that)
  await PublicSessions.backfillOwn(accountIdFor(FirebaseAuth.instance.currentUser));

  // 3. everything shared in that area: one range query on latitude per collection, then exact distances are
  //    checked here
  final band = latitudeBandFor(center, radiusMeters);
  Future<QuerySnapshot<Map<String, dynamic>>> inBand(String collection) => FirebaseFirestore.instance
      .collection(collection)
      .where('latitude', isGreaterThanOrEqualTo: band.min)
      .where('latitude', isLessThanOrEqualTo: band.max)
      .limit(_maxMeasurements)
      .get();

  final results = await Future.wait([inBand(PublicMeasurements.collectionName), inBand(PublicSessions.collectionName)]);

  final measurements = results[0].docs.map((doc) => CommunityPoint.fromMap(doc.data())).whereType<CommunityPoint>();
  final plays = results[1].docs.map((doc) => PlayPoint.fromMap(doc.data())).whereType<PlayPoint>();

  return CommunityData(
    center: center,
    usingFallbackLocation: fallback,
    stats: computeCommunityStats(measurements, plays, center, radiusMeters),
  );
}

// Declare class
class CommunityStatistics extends StatefulWidget {
  // where the data comes from; only tests pass their own
  final Future<CommunityData> Function()? loader;

  const CommunityStatistics({super.key, this.loader});

  @override
  State<CommunityStatistics> createState() => _CommunityStatisticsState();
}

class _CommunityStatisticsState extends State<CommunityStatistics> {
  static const double _radiusMeters = communityRadiusMiles * milesToMeters;

  LatLng? _center;
  bool _usingFallbackLocation = false;
  CommunityStats? _stats;
  List<DensityCell> _cells = [];
  // the H3 hexagon grid drawn over the map (null if the H3 library could not be loaded)
  H3Grid? _h3Grid;
  List<H3Sample> _h3Samples = [];
  int? _h3Resolution;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    H3Grid.tryLoad().then((grid) {
      if (mounted) setState(() => _h3Grid = grid);
    });
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await (widget.loader ?? loadCommunityData)();
      if (!mounted) return;
      setState(() {
        _center = data.center;
        _usingFallbackLocation = data.usingFallbackLocation;
        _stats = data.stats;
        _cells = buildDensityCells(data.stats.points);
        _h3Samples = data.stats.points
            .map((p) => H3Sample(location: p.location, downloadSpeed: p.downloadSpeed, uploadSpeed: p.uploadSpeed))
            .toList();
        _loading = false;
      });
    } catch (e) {
      debugPrint('[COMMUNITY_STATS] Could not load measurements: $e');
      if (!mounted) return;
      setState(() {
        _error = 'Could not load community data. Check your connection and try again.';
        _loading = false;
      });
    }
  }

  // the map view that just fits the whole radius
  LatLngBounds _boundsFor(LatLng center) {
    const distance = Distance();
    final north = distance.offset(center, _radiusMeters, 0);
    final east = distance.offset(center, _radiusMeters, 90);
    final south = distance.offset(center, _radiusMeters, 180);
    final west = distance.offset(center, _radiusMeters, 270);
    return LatLngBounds(LatLng(south.latitude, west.longitude), LatLng(north.latitude, east.longitude));
  }

  Widget _buildMap(LatLng center) {
    return Stack(
      children: [
        FlutterMap(
          options: MapOptions(
            initialCameraFit: CameraFit.bounds(bounds: _boundsFor(center), padding: const EdgeInsets.all(12)),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.pht.netgauge',
            ),
            if (_cells.isNotEmpty)
              HeatMapLayer(
                key: ValueKey(_cells.length),
                heatMapDataSource: InMemoryHeatMapDataSource(
                  data: _cells.map((c) => WeightedLatLng(c.location, c.intensity)).toList(),
                ),
                heatMapOptions: HeatMapOptions(
                  gradient: _densityGradient,
                  minOpacity: 0.4,
                  radius: 35.0,
                ),
              ),
            // H3 hexagons: shaded by how many measurements each holds, and gray where there are none at all.
            // Kept at a coarse size so the whole area can be checked for gaps.
            if (_h3Grid != null)
              H3OverlayLayer(
                grid: _h3Grid!,
                samples: _h3Samples,
                gradient: _densityGradient,
                maxResolution: 6,
                emptyAreaCenter: center,
                emptyAreaRadiusMeters: _radiusMeters,
                intensityOf: (cell, maxCount) => (cell.count / maxCount).clamp(0.15, 1.0),
                onResolutionChanged: (r) => setState(() => _h3Resolution = r),
              ),
            // the 50 mile area
            CircleLayer(circles: [
              CircleMarker(
                point: center,
                radius: _radiusMeters,
                useRadiusInMeter: true,
                color: Colors.transparent,
                borderColor: const Color(0xFF440154),
                borderStrokeWidth: 2,
              ),
            ]),
            // the user's position
            MarkerLayer(markers: [
              Marker(
                point: center,
                width: 28,
                height: 28,
                child: const Icon(Icons.my_location, color: Color(0xFF440154), size: 28),
              ),
            ]),
          ],
        ),
        // legend
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 10,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5),
                    gradient: const LinearGradient(
                      colors: [Colors.blue, Colors.cyan, Colors.lime, Colors.orange, Colors.red],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                // each label may wrap instead of overflowing on narrow screens or with large text sizes
                const Row(
                  children: [
                    Expanded(child: Text('Fewer measurements', style: TextStyle(fontSize: 12))),
                    Expanded(
                      child: Text('More measurements', textAlign: TextAlign.right, style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
                if (_h3Grid != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        width: 16,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.blueGrey.withValues(alpha: 0.3),
                          border: Border.all(color: Colors.blueGrey.shade700),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'No measurements'
                          '${_h3Resolution == null ? '' : ' (H3 hexagons, ${h3EdgeLabel(_h3Resolution!)} per side)'}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _statTile(String label, String value) {
    return Expanded(
      child: Card(
        elevation: 1,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummary(CommunityStats stats) {
    final mostPlayed = stats.mostPlayedGame;

    // nothing at all shared here yet
    if (stats.total == 0 && stats.totalPlays == 0) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Nothing has been shared within $communityRadiusMiles miles yet. Play a game or run the speed test to add some!',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _statTile('Measurements collected', '${stats.total}'),
              _statTile('Average download', stats.averageDownload == null ? '-' : '${stats.averageDownload!.toStringAsFixed(1)} Mbps'),
              _statTile('Average upload', stats.averageUpload == null ? '-' : '${stats.averageUpload!.toStringAsFixed(1)} Mbps'),
            ],
          ),
          const SizedBox(height: 8),
          const Text('Most frequently played game', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          if (mostPlayed == null)
            const Text('No games have been played in this area yet.')
          else ...[
            Text(mostPlayed.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF440154))),
            Text('Played ${mostPlayed.count} ${mostPlayed.count == 1 ? 'time' : 'times'}', style: const TextStyle(fontSize: 14)),
            if (stats.topGames.length > 1) ...[
              const SizedBox(height: 10),
              for (final game in stats.topGames.skip(1).take(2))
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text('${game.name}: ${game.count} ${game.count == 1 ? 'play' : 'plays'}', style: const TextStyle(fontSize: 15)),
                ),
            ],
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final center = _center;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
            'Community Statistics',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 25)
        ),
        backgroundColor: const Color(0xFF440154),
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        ElevatedButton(onPressed: _load, child: const Text('Try Again')),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    if (_usingFallbackLocation)
                      Container(
                        width: double.infinity,
                        color: Colors.amber.shade100,
                        padding: const EdgeInsets.all(8),
                        child: const Text(
                          "Your location isn't available, so this shows the Flagstaff area. Turn on location services to see your own area.",
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    Expanded(flex: 5, child: _buildMap(center!)),
                    Expanded(flex: 4, child: SingleChildScrollView(child: _buildSummary(_stats!))),
                  ],
                ),
    );
  }
}
