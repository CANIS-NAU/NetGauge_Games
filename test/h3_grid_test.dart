import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:h3_flutter/h3_flutter.dart';
import 'package:internet_measurement_games_app/h3_grid.dart';
import 'package:latlong2/latlong.dart';

// Stands in for the native H3 library (which cannot run in tests): "cells" are 0.1 degree squares.
class FakeH3 implements H3 {
  static const double size = 0.1;

  // cell id = row * 100000 + column, both offset to stay positive
  BigInt _id(int row, int col) => BigInt.from((row + 2000) * 100000 + (col + 2000));
  (int, int) _rowCol(BigInt id) {
    final n = id.toInt();
    return (n ~/ 100000 - 2000, n % 100000 - 2000);
  }

  @override
  BigInt geoToCell(GeoCoord c, int resolution) => _id((c.lat / size).floor(), (c.lon / size).floor());

  @override
  GeoCoord cellToGeo(BigInt cell) {
    final (r, c) = _rowCol(cell);
    return GeoCoord(lat: (r + 0.5) * size, lon: (c + 0.5) * size);
  }

  @override
  List<GeoCoord> cellToBoundary(BigInt cell) {
    final (r, c) = _rowCol(cell);
    return [
      GeoCoord(lat: r * size, lon: c * size),
      GeoCoord(lat: r * size, lon: (c + 1) * size),
      GeoCoord(lat: (r + 1) * size, lon: (c + 1) * size),
      GeoCoord(lat: (r + 1) * size, lon: c * size),
    ];
  }

  @override
  List<BigInt> gridDisk(BigInt cell, int ringSize) {
    final (r, c) = _rowCol(cell);
    return [
      for (var dr = -ringSize; dr <= ringSize; dr++)
        for (var dc = -ringSize; dc <= ringSize; dc++) _id(r + dr, c + dc),
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

H3Sample sample(double lat, double lng, {double down = 10, double up = 5}) =>
    H3Sample(location: LatLng(lat, lng), downloadSpeed: down, uploadSpeed: up);

void main() {
  group('resolution and labels', () {
    test('hexagons get smaller as the map zooms in, within limits', () {
      expect(h3ResolutionForZoom(2), minH3Resolution);
      expect(h3ResolutionForZoom(11), 6);
      expect(h3ResolutionForZoom(13), 8);
      expect(h3ResolutionForZoom(19), maxH3Resolution);
    });

    test('maxResolution caps how fine the grid gets', () {
      expect(h3ResolutionForZoom(18, maxResolution: 6), 6);
    });

    test('edge labels use meters below a kilometer and kilometers above', () {
      expect(h3EdgeLabel(8), 'about 461 m');
      expect(h3EdgeLabel(6), 'about 3.2 km');
      expect(h3EdgeLabel(4), 'about 23 km');
    });
  });

  group('gradientColorAt', () {
    final gradient = <double, Color>{0.0: Colors.red, 1.0: Colors.green};

    test('returns the end colors outside the stops', () {
      expect(gradientColorAt(gradient, -1), Colors.red);
      expect(gradientColorAt(gradient, 2), Colors.green);
    });

    test('blends between stops', () {
      expect(gradientColorAt(gradient, 0.5), Color.lerp(Colors.red, Colors.green, 0.5));
    });
  });

  group('buildH3Cells', () {
    final grid = H3Grid(FakeH3());

    test('groups samples by hexagon and averages their speeds', () {
      final cells = buildH3Cells([
        sample(0.01, 0.01, down: 10, up: 2),
        sample(0.02, 0.03, down: 30, up: 4),
        sample(0.55, 0.55, down: 100, up: 50),
      ], grid, 6);

      expect(cells.length, 2);
      final busy = cells.firstWhere((c) => c.count == 2);
      expect(busy.averageDownload, 20);
      expect(busy.averageUpload, 3);
      expect(busy.boundary.length, 4);
      expect(cells.firstWhere((c) => c.count == 1).averageDownload, 100);
    });

    test('no samples gives no cells', () {
      expect(buildH3Cells([], grid, 6), isEmpty);
    });

    test('cellsWithin only returns hexagons whose centers are inside the radius', () {
      const center = LatLng(0.05, 0.05);
      // 0.1 degrees is about 11 km, so 15 km reaches the neighbors but not two hexagons away
      final cells = grid.cellsWithin(center, 15000, 6);
      final centers = cells.map((c) => grid.boundaryOf(c)).toList();
      expect(centers.length, greaterThan(1));
      expect(centers.length, lessThan(25));
      const distance = Distance();
      for (final c in cells) {
        final b = grid.boundaryOf(c);
        final middle = LatLng((b[0].latitude + b[2].latitude) / 2, (b[0].longitude + b[2].longitude) / 2);
        expect(distance(center, middle), lessThanOrEqualTo(15000));
      }
    });
  });

  group('H3OverlayLayer', () {
    final grid = H3Grid(FakeH3());

    Future<void> pumpMap(WidgetTester tester, Widget layer, {double zoom = 11}) {
      return tester.pumpWidget(MaterialApp(
        home: SizedBox(
          width: 400,
          height: 400,
          child: FlutterMap(
            options: MapOptions(initialCenter: const LatLng(0.05, 0.05), initialZoom: zoom),
            children: [layer],
          ),
        ),
      ));
    }

    List<Polygon> polygons(WidgetTester tester) => tester.widget<PolygonLayer>(find.byType(PolygonLayer)).polygons;

    testWidgets('draws one hexagon for each area with measurements', (tester) async {
      await pumpMap(
        tester,
        H3OverlayLayer(
          grid: grid,
          samples: [sample(0.01, 0.01), sample(0.02, 0.02), sample(0.35, 0.35)],
          gradient: {0.0: Colors.blue, 1.0: Colors.red},
          intensityOf: (cell, maxCount) => cell.count / maxCount,
        ),
      );

      expect(polygons(tester).length, 2);
    });

    testWidgets('colors by intensity: the busiest hexagon gets the top color', (tester) async {
      await pumpMap(
        tester,
        H3OverlayLayer(
          grid: grid,
          samples: [sample(0.01, 0.01), sample(0.02, 0.02), sample(0.35, 0.35)],
          fillOpacity: 1,
          gradient: {0.0: Colors.blue, 1.0: Colors.red},
          intensityOf: (cell, maxCount) => cell.count / maxCount,
        ),
      );

      final colors = polygons(tester).map((p) => p.color).toSet();
      expect(colors, contains(Colors.red.withValues(alpha: 1)));
      expect(colors.length, 2);
    });

    testWidgets('empty hexagons in the area are drawn gray when an area is given', (tester) async {
      await pumpMap(
        tester,
        H3OverlayLayer(
          grid: grid,
          samples: [sample(0.05, 0.05)],
          gradient: {0.0: Colors.blue, 1.0: Colors.red},
          intensityOf: (cell, maxCount) => 1,
          emptyAreaCenter: const LatLng(0.05, 0.05),
          emptyAreaRadiusMeters: 15000,
        ),
      );

      final all = polygons(tester);
      final empty = all.where((p) => p.color == Colors.blueGrey.withValues(alpha: 0.3)).toList();
      expect(empty, isNotEmpty);
      // the hexagon that holds the measurement is not marked empty
      expect(all.length, empty.length + 1);
    });

    testWidgets('without an area, empty hexagons are not drawn', (tester) async {
      await pumpMap(
        tester,
        H3OverlayLayer(
          grid: grid,
          samples: [sample(0.05, 0.05)],
          gradient: {0.0: Colors.blue, 1.0: Colors.red},
          intensityOf: (cell, maxCount) => 1,
        ),
      );

      expect(polygons(tester).length, 1);
    });

    testWidgets('reports the resolution in use', (tester) async {
      final seen = <int>[];
      await pumpMap(
        tester,
        H3OverlayLayer(
          grid: grid,
          samples: [sample(0.05, 0.05)],
          gradient: {0.0: Colors.blue, 1.0: Colors.red},
          intensityOf: (cell, maxCount) => 1,
          onResolutionChanged: seen.add,
        ),
        zoom: 13,
      );
      await tester.pump();

      expect(seen, [8]);
    });
  });
}
