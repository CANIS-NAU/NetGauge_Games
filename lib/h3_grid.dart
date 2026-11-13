// H3 hexagonal grid overlay for the maps.
// H3 (from Uber) divides the world into hexagons at several sizes ("resolutions"). Every measurement falls into
// exactly one hexagon at a given resolution, so measurements can be summarized per hexagon (how many there are,
// their average speeds) and drawn on the map as a grid.
// The hexagon math (which cell holds a point, where its corners are) comes from the h3_flutter package; everything
// else here (grouping, resolution choice, colors) is plain Dart so it can be tested without the native library.

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:h3_flutter/h3_flutter.dart';
import 'package:latlong2/latlong.dart';

const int minH3Resolution = 4;
const int maxH3Resolution = 10;

// Average hexagon edge length in kilometers for resolutions 0 to 10 (from the H3 documentation).
const List<double> _edgeKm = [1107.7, 418.7, 158.2, 59.8, 22.6, 8.54, 3.23, 1.22, 0.461, 0.174, 0.0659];

// The resolution to use at a map zoom level, so hexagons stay about the same size on screen (roughly 20 to 60
// pixels per edge): zoomed far out gives big hexagons, zoomed in gives small ones.
int h3ResolutionForZoom(double zoom, {int maxResolution = maxH3Resolution}) {
  final resolution = (zoom - 5).floor();
  if (resolution < minH3Resolution) return minH3Resolution;
  if (resolution > maxResolution) return maxResolution;
  return resolution;
}

// e.g. "about 460 m" or "about 3.2 km", the edge length of a hexagon at this resolution
String h3EdgeLabel(int resolution) {
  final km = _edgeKm[resolution.clamp(0, _edgeKm.length - 1)];
  if (km < 1) return 'about ${(km * 1000).round()} m';
  return 'about ${km >= 10 ? km.round() : km.toStringAsFixed(1)} km';
}

// Looks up the color for a position (0 to 1) along a gradient, blending between the two nearest stops.
Color gradientColorAt(Map<double, Color> gradient, double t) {
  final stops = gradient.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
  if (t <= stops.first.key) return stops.first.value;
  if (t >= stops.last.key) return stops.last.value;
  for (var i = 1; i < stops.length; i++) {
    if (t <= stops[i].key) {
      final before = stops[i - 1];
      final after = stops[i];
      final blend = (t - before.key) / (after.key - before.key);
      return Color.lerp(before.value, after.value, blend)!;
    }
  }
  return stops.last.value;
}

// one measurement, reduced to what the grid needs
class H3Sample {
  final LatLng location;
  final double downloadSpeed;
  final double uploadSpeed;
  const H3Sample({required this.location, required this.downloadSpeed, required this.uploadSpeed});
}

// one hexagon and a summary of the measurements inside it
class H3Cell {
  final BigInt index;
  final List<LatLng> boundary;
  final int count;
  final double averageDownload;
  final double averageUpload;

  const H3Cell({
    required this.index,
    required this.boundary,
    required this.count,
    required this.averageDownload,
    required this.averageUpload,
  });
}

// Talks to the H3 library.
class H3Grid {
  final H3 _h3;
  final Map<BigInt, List<LatLng>> _boundaries = {};

  H3Grid(this._h3);

  // Loads the native H3 library. Returns null if it is not available on this device, so the app keeps working
  // without the grid.
  static Future<H3Grid?> tryLoad() async {
    try {
      final grid = H3Grid(await const H3Factory().load());
      // loading can succeed and the first real call still fail, so check that it works now rather than while drawing
      grid.cellOf(const LatLng(0, 0), minH3Resolution);
      return grid;
    } catch (e) {
      debugPrint('[H3] Could not load the H3 library: $e');
      return null;
    }
  }

  // the hexagon that contains this point
  BigInt cellOf(LatLng point, int resolution) =>
      _h3.geoToCell(GeoCoord(lat: point.latitude, lon: point.longitude), resolution);

  // every hexagon whose center is within radiusMeters of the center point (used to find hexagons with nothing in them)
  List<BigInt> cellsWithin(LatLng center, double radiusMeters, int resolution) {
    final edgeMeters = _edgeKm[resolution.clamp(0, _edgeKm.length - 1)] * 1000;
    // neighboring hexagon centers are about 1.73 edges apart; one extra ring covers the rim
    final rings = (radiusMeters / (edgeMeters * 1.7)).ceil() + 1;
    const distance = Distance();
    return _h3
        .gridDisk(cellOf(center, resolution), rings)
        .where((cell) => distance(center, _centerOf(cell)) <= radiusMeters)
        .toList();
  }

  LatLng _centerOf(BigInt cell) {
    final c = _h3.cellToGeo(cell);
    return LatLng(c.lat, c.lon);
  }

  // the six (five for the few pentagons) corners of a hexagon
  List<LatLng> boundaryOf(BigInt cell) {
    // corners never change for a cell, so they are only worked out once
    if (_boundaries.length > 20000) _boundaries.clear();
    return _boundaries.putIfAbsent(cell, () => _h3.cellToBoundary(cell).map((c) => LatLng(c.lat, c.lon)).toList());
  }
}

// Puts each sample in its hexagon at the resolution and summarizes every hexagon that has at least one.
List<H3Cell> buildH3Cells(Iterable<H3Sample> samples, H3Grid grid, int resolution) {
  final groups = <BigInt, List<H3Sample>>{};
  for (final sample in samples) {
    groups.putIfAbsent(grid.cellOf(sample.location, resolution), () => []).add(sample);
  }

  return groups.entries.map((entry) {
    final group = entry.value;
    return H3Cell(
      index: entry.key,
      boundary: grid.boundaryOf(entry.key),
      count: group.length,
      averageDownload: group.map((s) => s.downloadSpeed).reduce((a, b) => a + b) / group.length,
      averageUpload: group.map((s) => s.uploadSpeed).reduce((a, b) => a + b) / group.length,
    );
  }).toList();
}

// Draws the hexagons on a FlutterMap. The hexagon size follows the zoom level, so the grid is regrouped when the
// zoom crosses into another resolution (not on every pan).
class H3OverlayLayer extends StatefulWidget {
  final H3Grid grid;
  final List<H3Sample> samples;
  // how strongly a hexagon is colored, 0 to 1 (maxCount is the count of the busiest hexagon on screen's grid)
  final double Function(H3Cell cell, int maxCount) intensityOf;
  final Map<double, Color> gradient;
  // changes whenever intensityOf would give different answers for the same cells (for example another metric)
  final Object? styleKey;
  final double fillOpacity;
  // called when the resolution in use changes, so the page can show it
  final ValueChanged<int>? onResolutionChanged;
  // the finest resolution to use; keeps the number of hexagons manageable when empty ones are drawn
  final int maxResolution;
  // when set, hexagons within this area that hold no measurements are drawn too, in gray, so gaps stand out
  final LatLng? emptyAreaCenter;
  final double emptyAreaRadiusMeters;

  const H3OverlayLayer({
    super.key,
    required this.grid,
    required this.samples,
    required this.intensityOf,
    required this.gradient,
    this.styleKey,
    this.fillOpacity = 0.45,
    this.onResolutionChanged,
    this.maxResolution = maxH3Resolution,
    this.emptyAreaCenter,
    this.emptyAreaRadiusMeters = 0,
  });

  @override
  State<H3OverlayLayer> createState() => _H3OverlayLayerState();
}

class _H3OverlayLayerState extends State<H3OverlayLayer> {
  int? _resolution;
  List<H3Sample>? _samples;
  Object? _styleKey;
  List<Polygon> _polygons = const [];

  void _rebuildPolygons(int resolution) {
    final cells = buildH3Cells(widget.samples, widget.grid, resolution);
    final maxCount = cells.isEmpty ? 1 : cells.map((c) => c.count).reduce((a, b) => a > b ? a : b);
    _polygons = cells
        .map((cell) => Polygon(
              points: cell.boundary,
              color: gradientColorAt(widget.gradient, widget.intensityOf(cell, maxCount))
                  .withValues(alpha: widget.fillOpacity),
              borderColor: Colors.black.withValues(alpha: 0.55),
              borderStrokeWidth: 1.2,
              isFilled: true,
            ))
        .toList();

    final center = widget.emptyAreaCenter;
    if (center != null) {
      final occupied = cells.map((c) => c.index).toSet();
      for (final index in widget.grid.cellsWithin(center, widget.emptyAreaRadiusMeters, resolution)) {
        if (occupied.contains(index)) continue;
        _polygons.add(Polygon(
          points: widget.grid.boundaryOf(index),
          color: Colors.blueGrey.withValues(alpha: 0.3),
          borderColor: Colors.blueGrey.shade700.withValues(alpha: 0.7),
          borderStrokeWidth: 1.2,
          isFilled: true,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final resolution = h3ResolutionForZoom(MapCamera.of(context).zoom, maxResolution: widget.maxResolution);

    if (resolution != _resolution || !identical(widget.samples, _samples) || widget.styleKey != _styleKey) {
      final resolutionChanged = resolution != _resolution;
      _resolution = resolution;
      _samples = widget.samples;
      _styleKey = widget.styleKey;
      _rebuildPolygons(resolution);
      if (resolutionChanged && widget.onResolutionChanged != null) {
        // the page cannot be rebuilt while the map is being built
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onResolutionChanged!(resolution);
        });
      }
    }

    return PolygonLayer(polygons: _polygons);
  }
}
