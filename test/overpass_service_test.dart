import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:internet_measurement_games_app/poi_generator.dart';

// the player stands here (Flagstaff)
const userLat = 35.1983;
const userLng = -111.6513;

// about 111 m per 0.001 degrees of latitude
Map<String, dynamic> node(int id, double lat, double lng, [String name = 'Place']) =>
    {'type': 'node', 'id': id, 'lat': lat, 'lon': lng, 'tags': {'name': name, 'amenity': 'cafe'}};

Map<String, dynamic> areaWithCenter(int id, double lat, double lng, String name) =>
    {'type': 'way', 'id': id, 'center': {'lat': lat, 'lon': lng}, 'tags': {'name': name, 'leisure': 'park'}};

Map<String, dynamic> noPosition(int id, String name) => {'type': 'relation', 'id': id, 'tags': {'name': name}};

http.Client serving(List<Map<String, dynamic>> elements, {List<String>? queries}) => MockClient((request) async {
      queries?.add(Uri.splitQueryString(request.body)['data']!);
      return http.Response(jsonEncode({'elements': elements}), 200);
    });

Future<List<PointOfInterest>> nearest(http.Client Function() client, {int limit = 5, double radius = 500}) {
  return http.runWithClient(
    () => OverpassService().fetchNearestPOIs(latitude: userLat, longitude: userLng, radius: radius, limit: limit),
    client,
  );
}

void main() {
  group('the search', () {
    test('looks around the player for named places in the POI categories', () async {
      final queries = <String>[];
      await nearest(() => serving([node(1, userLat + 0.001, userLng)], queries: queries));

      final query = queries.first;
      expect(query, contains('around:500.0,$userLat,$userLng'));
      for (final key in OverpassService.defaultPoiKeys) {
        expect(query, contains('nwr["$key"]["name"](around:500.0'));
      }
    });

    test('no longer matches every named thing, such as roads, bus routes and boundaries', () async {
      final queries = <String>[];
      await nearest(() => serving([], queries: queries));

      // the old query was a bare name filter, which matched anything with a name
      expect(queries.first, isNot(contains('nwr["name"]')));
      expect(queries.first, isNot(contains('highway')));
      expect(queries.first, isNot(contains('route')));
    });

    test('asks for a pool much bigger than the number wanted, so the nearest place is not missed', () async {
      final queries = <String>[];
      await nearest(() => serving([], queries: queries), limit: 5);

      expect(queries.first, contains('out center ${OverpassService.poolSizeFor(5)};'));
      expect(OverpassService.poolSizeFor(5), greaterThanOrEqualTo(100));
      expect(OverpassService.poolSizeFor(5), greaterThan(5 * 2)); // it used to be limit * 2
    });

    test('a specific search still uses the exact filter it was given', () async {
      final queries = <String>[];
      await http.runWithClient(
        () => OverpassService().fetchNearestPOIs(
          latitude: userLat, longitude: userLng, radius: 300, amenityType: 'cafe', limit: 3),
        () => serving([], queries: queries),
      );
      expect(queries.first, contains('nwr["amenity"="cafe"](around:300.0'));
    });
  });

  group('the results', () {
    test('are sorted nearest first and trimmed to the number wanted', () async {
      final elements = [for (var i = 0; i < 12; i++) node(i, userLat + 0.0003 * (12 - i), userLng, 'P$i')];
      final pois = await nearest(() => serving(elements), limit: 5);

      expect(pois.length, 5);
      final distances = pois.map((p) => p.distanceFromOrigin!).toList();
      expect(distances, orderedEquals([...distances]..sort()));
      expect(pois.first.name, 'P11'); // the closest of the twelve
    });

    test('the nearest place is found even when it is not first in what the server returns', () async {
      // 30 places in an order that is not by distance, with the closest (P0) last
      final elements = [for (var i = 29; i >= 0; i--) node(i, userLat + 0.00012 * (i + 1), userLng, 'P$i')];
      final pois = await nearest(() => serving(elements), limit: 5);

      expect(pois.map((p) => p.name), ['P0', 'P1', 'P2', 'P3', 'P4']);
    });

    test('places whose center is beyond the radius are dropped, not offered as nearby POIs', () async {
      // a big park that touches the search area but whose center is 4 km away
      final pois = await nearest(() => serving([
            areaWithCenter(7, userLat + 0.036, userLng, 'Huge park'),
            node(8, userLat + 0.001, userLng, 'Cafe'),
          ]));

      expect(pois.map((p) => p.name), ['Cafe']);
    });

    test('a result with no position is dropped, not placed at 0, 0', () async {
      final pois = await nearest(() => serving([noPosition(9, 'Some boundary')]));
      expect(pois, isEmpty);

      final mixed = await nearest(() => serving([noPosition(9, 'Some boundary'), node(8, userLat + 0.001, userLng)]));
      expect(mixed.length, 1);
      expect(mixed.single.latitude, isNot(0.0));
    });

    test('when only unusable results come back the list is empty, which triggers the fallback', () async {
      final pois = await nearest(() => serving([
            noPosition(9, 'Some boundary'),
            areaWithCenter(7, userLat + 0.05, userLng, 'Far park'),
          ]));
      expect(pois, isEmpty);
    });

    test('places inside the radius are kept, with their distance', () async {
      final pois = await nearest(() => serving([node(1, userLat + 0.002, userLng, 'Cafe')])); // about 222 m
      expect(pois.single.distanceFromOrigin!, closeTo(222, 10));
    });

    test('the category of the place is recorded, including parks and landmarks', () async {
      final pois = await nearest(() => serving([
            {'type': 'node', 'id': 1, 'lat': userLat + 0.001, 'lon': userLng, 'tags': {'name': 'A park', 'leisure': 'park'}},
            {'type': 'node', 'id': 2, 'lat': userLat + 0.002, 'lon': userLng, 'tags': {'name': 'A statue', 'historic': 'monument'}},
          ]));
      expect(pois.map((p) => p.amenityType), ['park', 'monument']);
    });
  });

  group('servers', () {
    test('falls back to the next server when the first fails', () async {
      var calls = 0;
      final pois = await nearest(() => MockClient((request) async {
            calls++;
            if (calls == 1) return http.Response('busy', 504);
            return http.Response(jsonEncode({'elements': [node(1, userLat + 0.001, userLng)]}), 200);
          }));
      expect(calls, 2);
      expect(pois.length, 1);
    });

    test('when every server fails the error is reported to the caller', () async {
      await expectLater(nearest(() => MockClient((request) async => http.Response('no', 500))), throwsException);
    });
  });
}
