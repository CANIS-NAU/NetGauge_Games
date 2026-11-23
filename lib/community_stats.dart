// Number crunching for the community statistics page: which shared measurements and plays are near a point, how
// many measurements there are and how they cluster on the map, and which game was played most often.
// Kept free of Firebase and widgets so it can be tested on its own.

import 'dart:math';
import 'package:latlong2/latlong.dart';

const double milesToMeters = 1609.344;
const double communityRadiusMiles = 50;

// The speed test is a game like any other. Earlier versions recorded it under a few different names, so they are
// all counted under the name players see.
const String speedTestGameName = 'Measure Internet';
const Set<String> _speedTestNames = {'Speedtest', 'Speed Tester', 'Measure Internet'};

String canonicalGameName(String name) => _speedTestNames.contains(name) ? speedTestGameName : name;

// roughly 2 km: measurements closer together than this are counted as the same spot on the density map
const double densityCellDegrees = 0.02;

// one anonymized measurement from public_measurements
class CommunityPoint {
  final LatLng location;
  final double downloadSpeed;
  final double uploadSpeed;

  CommunityPoint({required this.location, required this.downloadSpeed, required this.uploadSpeed});

  // returns null if the data has no usable location
  static CommunityPoint? fromMap(Map<String, dynamic> data) {
    final lat = data['latitude'];
    final lng = data['longitude'];
    if (lat is! num || lng is! num) return null;
    final download = data['download_speed'];
    final upload = data['upload_speed'];
    return CommunityPoint(
      location: LatLng(lat.toDouble(), lng.toDouble()),
      downloadSpeed: download is num ? download.toDouble() : 0,
      uploadSpeed: upload is num ? upload.toDouble() : 0,
    );
  }
}

// one anonymized play of a game, from public_sessions
class PlayPoint {
  final LatLng location;
  final String game;

  PlayPoint({required this.location, required this.game});

  // returns null if the data has no usable location or game
  static PlayPoint? fromMap(Map<String, dynamic> data) {
    final lat = data['latitude'];
    final lng = data['longitude'];
    final game = data['game'];
    if (lat is! num || lng is! num || game is! String || game.isEmpty) return null;
    return PlayPoint(location: LatLng(lat.toDouble(), lng.toDouble()), game: canonicalGameName(game));
  }
}

class GameCount {
  final String name;
  final int count;
  const GameCount(this.name, this.count);
}

class CommunityStats {
  final List<CommunityPoint> points; // shared measurements in the area
  final int totalPlays; // games played in the area
  final List<GameCount> topGames; // most played first, by number of plays
  final double? averageDownload;
  final double? averageUpload;

  const CommunityStats({
    required this.points,
    required this.totalPlays,
    required this.topGames,
    required this.averageDownload,
    required this.averageUpload,
  });

  int get total => points.length;
  GameCount? get mostPlayedGame => topGames.isEmpty ? null : topGames.first;
}

// the span of latitudes that could contain anything within radiusMeters of the center; used to ask Firestore for
// a narrow slice of the data (one range query), after which exact distances are checked on the device
class LatitudeBand {
  final double min;
  final double max;
  const LatitudeBand(this.min, this.max);
}

LatitudeBand latitudeBandFor(LatLng center, double radiusMeters) {
  // one degree of latitude is about 111.32 km everywhere
  final degrees = radiusMeters / 111320.0;
  return LatitudeBand(center.latitude - degrees, center.latitude + degrees);
}

// Keeps what is within radiusMeters of the center and summarizes it: measurements give the counts, averages and
// density map; plays give the most frequently played game (how often a game was played, not how many measurements
// it collected).
CommunityStats computeCommunityStats(
  Iterable<CommunityPoint> measurements,
  Iterable<PlayPoint> plays,
  LatLng center,
  double radiusMeters,
) {
  const distance = Distance();
  final nearbyMeasurements = measurements.where((p) => distance(center, p.location) <= radiusMeters).toList();
  final nearbyPlays = plays.where((p) => distance(center, p.location) <= radiusMeters).toList();

  final gameCounts = <String, int>{};
  for (final play in nearbyPlays) {
    gameCounts[play.game] = (gameCounts[play.game] ?? 0) + 1;
  }
  final topGames = gameCounts.entries.map((e) => GameCount(e.key, e.value)).toList()
    ..sort((a, b) {
      final byCount = b.count.compareTo(a.count);
      return byCount != 0 ? byCount : a.name.compareTo(b.name);
    });

  double? average(double Function(CommunityPoint) pick) => nearbyMeasurements.isEmpty
      ? null
      : nearbyMeasurements.map(pick).reduce((a, b) => a + b) / nearbyMeasurements.length;

  return CommunityStats(
    points: nearbyMeasurements,
    totalPlays: nearbyPlays.length,
    topGames: topGames,
    averageDownload: average((p) => p.downloadSpeed),
    averageUpload: average((p) => p.uploadSpeed),
  );
}

// a spot on the density map and how busy it is compared with the busiest spot (0 to 1)
class DensityCell {
  final LatLng location;
  final int count;
  final double intensity;
  const DensityCell(this.location, this.count, this.intensity);
}

// Groups points into cells of about 2 km and rates each by how many measurements it holds relative to the busiest
// cell. One entry per cell keeps the map readable no matter how many measurements there are.
List<DensityCell> buildDensityCells(Iterable<CommunityPoint> points) {
  final sums = <String, _CellSum>{};
  for (final p in points) {
    final key = '${(p.location.latitude / densityCellDegrees).round()},${(p.location.longitude / densityCellDegrees).round()}';
    final cell = sums.putIfAbsent(key, () => _CellSum());
    cell.count++;
    cell.latSum += p.location.latitude;
    cell.lngSum += p.location.longitude;
  }
  if (sums.isEmpty) return [];

  final busiest = sums.values.map((c) => c.count).reduce(max);
  return sums.values
      .map((c) => DensityCell(
            LatLng(c.latSum / c.count, c.lngSum / c.count),
            c.count,
            // keep a floor so the quietest spots are still visible
            (c.count / busiest).clamp(0.15, 1.0),
          ))
      .toList();
}

class _CellSum {
  int count = 0;
  double latSum = 0;
  double lngSum = 0;
}
