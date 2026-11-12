import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:internet_measurement_games_app/app_theme.dart';
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

Future<void> show(WidgetTester tester, Future<CommunityData> Function() loader, {ThemeData? theme}) async {
  // tests cannot download map tiles (every request gets a 400), which is expected here, so ignore only that
  final originalOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exception is http.ClientException) return;
    originalOnError?.call(details);
  };
  addTearDown(() => FlutterError.onError = originalOnError);

  await tester.binding.setSurfaceSize(const Size(411, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(theme: theme, home: CommunityStatistics(loader: loader)));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

// the color a piece of text is actually drawn in: its own, or the one it inherits
Color textColorOf(WidgetTester tester, Finder finder) {
  final text = tester.widget<Text>(finder);
  return text.style?.color ?? DefaultTextStyle.of(tester.element(finder)).style.color!;
}

// the background color of the closest box behind a piece of text
Color backgroundBehind(WidgetTester tester, Finder finder) {
  final box = tester.widget<Container>(find.ancestor(of: finder, matching: find.byType(Container)).first);
  return (box.decoration as BoxDecoration?)?.color ?? box.color!;
}

// how readable one color is on another: 1 is invisible, 21 is black on white, 4.5 is the usual minimum for text
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
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

  for (final entry in {'light': lightTheme, 'dark': darkTheme}.entries) {
    testWidgets('the legend, the location notice and the top game are readable in ${entry.key} mode', (tester) async {
      await show(
        tester,
        () async => data([point(35.20, -111.65)], plays: [play('Zombie Apocalypse')], fallback: true),
        theme: entry.value,
      );

      // the page's own background, which the top game's name is drawn on
      final pageBackground = entry.value.scaffoldBackgroundColor;

      for (final label in ['Fewer measurements', 'More measurements']) {
        final finder = find.text(label);
        // the legend is drawn at 90% opacity over the map, so it is blended onto the page background here
        final legend = Color.alphaBlend(backgroundBehind(tester, finder), pageBackground);
        expect(contrast(textColorOf(tester, finder), legend), greaterThanOrEqualTo(4.5), reason: label);
      }

      final notice = find.textContaining("Your location isn't available");
      expect(contrast(textColorOf(tester, notice), backgroundBehind(tester, notice)), greaterThanOrEqualTo(4.5));

      final topGame = find.text('Zombie Apocalypse');
      expect(contrast(textColorOf(tester, topGame), pageBackground), greaterThanOrEqualTo(4.5));
    });
  }

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
