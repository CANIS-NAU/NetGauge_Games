import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:internet_measurement_games_app/community_stats.dart';
import 'package:internet_measurement_games_app/community_statistics.dart';
import 'package:latlong2/latlong.dart';

const flagstaff = LatLng(35.1983, -111.6513);

CommunityPoint point(double lat, double lng, {double down = 20, double up = 5}) =>
    CommunityPoint(location: LatLng(lat, lng), downloadSpeed: down, uploadSpeed: up);

PlayPoint play(String game) => PlayPoint(location: LatLng(35.20, -111.65), game: game);

CommunityData data(List<CommunityPoint> points, {List<PlayPoint> plays = const [], bool fallback = false}) =>
    CommunityData(
      center: flagstaff,
      usingFallbackLocation: fallback,
      stats: computeCommunityStats(points, plays, flagstaff, communityRadiusMiles * milesToMeters),
    );

Future<void> show(WidgetTester tester, Future<CommunityData> Function() loader) async {
  // tests cannot download map tiles (every request gets a 400), which is expected here, so ignore only that
  final originalOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exception is http.ClientException) return;
    originalOnError?.call(details);
  };
  addTearDown(() => FlutterError.onError = originalOnError);

  await tester.binding.setSurfaceSize(const Size(411, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(home: CommunityStatistics(loader: loader)));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('shows the heat map, the measurement count and the most frequently played game', (tester) async {
    await show(tester, () async => data(
          [point(35.20, -111.65), point(35.21, -111.65), point(35.22, -111.66)],
          plays: [play('Zombie Apocalypse'), play('Zombie Apocalypse'), play('Soul Seeker')],
        ));

    expect(find.text('Community Statistics'), findsOneWidget);
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.text('Fewer measurements'), findsOneWidget);
    expect(find.text('More measurements'), findsOneWidget);
    expect(find.text('Most frequently played game'), findsOneWidget);
    expect(find.text('Zombie Apocalypse'), findsOneWidget);
    expect(find.text('Played 2 times'), findsOneWidget);
    expect(find.text('Soul Seeker: 1 play'), findsOneWidget);
    expect(find.text('3'), findsOneWidget); // measurements collected
  });

  testWidgets('the speed test can be the most frequently played game', (tester) async {
    await show(tester, () async => data([], plays: [play('Measure Internet'), play('Measure Internet'), play('Soul Seeker')]));

    expect(find.text('Measure Internet'), findsOneWidget);
    expect(find.text('Played 2 times'), findsOneWidget);
  });

  testWidgets('says so when nothing has been shared nearby', (tester) async {
    await show(tester, () async => data([]));

    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.textContaining('Nothing has been shared within 50.0 miles yet'), findsOneWidget);
  });

  testWidgets('says so when there are measurements but no plays', (tester) async {
    await show(tester, () async => data([point(35.20, -111.65)]));

    expect(find.text('No games have been played in this area yet.'), findsOneWidget);
  });

  testWidgets('tells the user when their location is not available', (tester) async {
    await show(tester, () async => data([point(35.20, -111.65)], plays: [play('Soul Seeker')], fallback: true));

    expect(find.textContaining("Your location isn't available"), findsOneWidget);
  });

  testWidgets('shows an error with a retry button when the data cannot be loaded', (tester) async {
    var attempts = 0;
    await show(tester, () async {
      attempts++;
      if (attempts == 1) throw Exception('offline');
      return data([point(35.20, -111.65)], plays: [play('Soul Seeker')]);
    });

    expect(find.textContaining('Could not load community data'), findsOneWidget);

    await tester.tap(find.text('Try Again'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Soul Seeker'), findsOneWidget);
  });
}
