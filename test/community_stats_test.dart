import 'package:flutter_test/flutter_test.dart';
import 'package:internet_measurement_games_app/community_stats.dart';
import 'package:latlong2/latlong.dart';

CommunityPoint measurement(double lat, double lng, {double down = 10, double up = 5}) =>
    CommunityPoint(location: LatLng(lat, lng), downloadSpeed: down, uploadSpeed: up);

PlayPoint play(double lat, double lng, String game) => PlayPoint(location: LatLng(lat, lng), game: game);

void main() {
  const flagstaff = LatLng(35.1983, -111.6513);
  const radius = communityRadiusMiles * milesToMeters;

  test('only measurements and plays within 50 miles are counted', () {
    final stats = computeCommunityStats(
      [
        measurement(35.20, -111.65), // in town
        measurement(35.60, -111.65), // about 28 miles north
        measurement(36.60, -111.65), // about 97 miles north
        measurement(33.45, -112.07), // Phoenix, well outside
      ],
      [
        play(35.20, -111.65, 'Soul Seeker'),
        play(33.45, -112.07, 'Soul Seeker'), // Phoenix
      ],
      flagstaff,
      radius,
    );

    expect(stats.total, 2);
    expect(stats.totalPlays, 1);
  });

  test('the most played game is the one played most often, not the one that collected the most measurements', () {
    final stats = computeCommunityStats(
      // Zombie Apocalypse was played once but collected 20 measurements; Soul Seeker was played 3 times
      [for (var i = 0; i < 20; i++) measurement(35.20, -111.65)],
      [
        play(35.20, -111.65, 'Zombie Apocalypse'),
        play(35.21, -111.65, 'Soul Seeker'),
        play(35.21, -111.65, 'Soul Seeker'),
        play(35.22, -111.65, 'Soul Seeker'),
      ],
      flagstaff,
      radius,
    );

    expect(stats.mostPlayedGame!.name, 'Soul Seeker');
    expect(stats.mostPlayedGame!.count, 3);
    expect(stats.topGames.map((g) => g.name), ['Soul Seeker', 'Zombie Apocalypse']);
  });

  test('the speed test is counted as a game, under one name however it was recorded', () {
    final stats = computeCommunityStats(
      [],
      [
        PlayPoint.fromMap({'latitude': 35.20, 'longitude': -111.65, 'game': 'Measure Internet'})!,
        PlayPoint.fromMap({'latitude': 35.20, 'longitude': -111.65, 'game': 'Speedtest'})!,
        PlayPoint.fromMap({'latitude': 35.20, 'longitude': -111.65, 'game': 'Speed Tester'})!,
        play(35.20, -111.65, 'Soul Seeker'),
        play(35.20, -111.65, 'Soul Seeker'),
      ],
      flagstaff,
      radius,
    );

    expect(stats.mostPlayedGame!.name, speedTestGameName);
    expect(stats.mostPlayedGame!.count, 3);
  });

  test('ties are broken by name so the result is stable', () {
    final stats = computeCommunityStats(
      [],
      [play(35.20, -111.65, 'Soul Seeker'), play(35.20, -111.65, 'Dragon Slayer')],
      flagstaff,
      radius,
    );
    expect(stats.topGames.map((g) => g.name), ['Dragon Slayer', 'Soul Seeker']);
  });

  test('no plays gives no most played game, even with measurements', () {
    final stats = computeCommunityStats([measurement(35.20, -111.65)], [], flagstaff, radius);
    expect(stats.mostPlayedGame, isNull);
    expect(stats.total, 1);
  });

  test('averages speeds, and has none when the area has no measurements', () {
    final stats = computeCommunityStats(
      [measurement(35.20, -111.65, down: 10, up: 2), measurement(35.20, -111.65, down: 30, up: 4)],
      [],
      flagstaff,
      radius,
    );
    expect(stats.averageDownload, 20);
    expect(stats.averageUpload, 3);

    final empty = computeCommunityStats([], [], flagstaff, radius);
    expect(empty.total, 0);
    expect(empty.averageDownload, isNull);
  });

  test('the latitude band covers the radius', () {
    final band = latitudeBandFor(flagstaff, radius);
    // 50 miles is about 0.72 degrees of latitude
    expect(band.max - flagstaff.latitude, closeTo(0.7229, 0.001));
    expect(flagstaff.latitude - band.min, closeTo(0.7229, 0.001));
  });

  test('density cells rate the busiest spot 1 and quieter spots lower', () {
    final cells = buildDensityCells([
      for (var i = 0; i < 10; i++) measurement(35.2000, -111.6500), // busy spot
      measurement(35.5000, -111.2000), // quiet spot, far away
    ]);

    expect(cells.length, 2);
    final busy = cells.firstWhere((c) => c.count == 10);
    final quiet = cells.firstWhere((c) => c.count == 1);
    expect(busy.intensity, 1.0);
    expect(quiet.intensity, closeTo(0.15, 0.0001)); // 1/10 is below the visibility floor
  });

  test('data without a location (or a game, for plays) is ignored', () {
    expect(CommunityPoint.fromMap({'download_speed': 5}), isNull);
    expect(PlayPoint.fromMap({'latitude': 35.0, 'longitude': -111.0}), isNull);
    expect(PlayPoint.fromMap({'game': 'Soul Seeker'}), isNull);
  });
}
