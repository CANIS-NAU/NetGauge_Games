// Badges (achievements) players can earn. Each badge is worked out from data the app already keeps (measurement
// totals, distance and the list of past sessions), so nothing extra is stored: a badge is earned as soon as the
// numbers say so, and players who already have history get their badges right away.
// Kept free of Firebase and widgets (apart from icons and colors) so it can be tested on its own.

import 'package:flutter/material.dart';
import 'community_stats.dart';

// what the badges are worked out from
class BadgeStats {
  final int totalMeasurements;
  final double totalDistanceMeters;
  final List<PlayedSession> sessions;

  const BadgeStats({
    required this.totalMeasurements,
    required this.totalDistanceMeters,
    required this.sessions,
  });

  // the speed test is not counted as a "game" for the variety badge
  int get differentGames => sessions
      .map((s) => canonicalGameName(s.game))
      .where((name) => name != speedTestGameName)
      .toSet()
      .length;

  int get speedTests => sessions.where((s) => canonicalGameName(s.game) == speedTestGameName).length;

  int get differentDays => sessions.map((s) => DateTime(s.endTime.year, s.endTime.month, s.endTime.day)).toSet().length;

  double get bestAverageDownload =>
      sessions.map((s) => s.averageDownload ?? 0).fold(0.0, (best, speed) => speed > best ? speed : best);
}

// the few things about one finished session that badges look at
class PlayedSession {
  final String game;
  final DateTime endTime;
  final double? averageDownload;

  const PlayedSession({required this.game, required this.endTime, this.averageDownload});
}

class AppBadge {
  final String id;
  final String name;
  // shown when the badge is tapped; says how to earn it
  final String description;
  final IconData icon;
  final Color color;
  // how far along the player is, in the unit of [target] (for example measurements or meters)
  final double Function(BadgeStats stats) progressOf;
  final double target;
  // how progress is written, e.g. "4 of 10 measurements"
  final String Function(double progress) progressLabel;

  const AppBadge({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.progressOf,
    required this.target,
    required this.progressLabel,
  });

  bool isEarnedBy(BadgeStats stats) => progressOf(stats) >= target;

  // 0 to 1, for the progress bar
  double fractionFor(BadgeStats stats) => (progressOf(stats) / target).clamp(0.0, 1.0);
}

// All the badges, in the order they are shown.
final List<AppBadge> allBadges = [
  AppBadge(
    id: 'first_steps',
    name: 'First Steps',
    description: 'Finish your first game session.',
    icon: Icons.flag,
    color: Colors.teal,
    target: 1,
    progressOf: (s) => s.sessions.length.toDouble(),
    progressLabel: (p) => '${p.floor()} of 1 session',
  ),
  AppBadge(
    id: 'data_collector',
    name: 'Data Collector',
    description: 'Collect 10 internet measurements while you play.',
    icon: Icons.speed,
    color: Colors.blue,
    target: 10,
    progressOf: (s) => s.totalMeasurements.toDouble(),
    progressLabel: (p) => '${p.floor()} of 10 measurements',
  ),
  AppBadge(
    id: 'data_hoarder',
    name: 'Data Hoarder',
    description: 'Collect 100 internet measurements while you play.',
    icon: Icons.storage,
    color: Colors.indigo,
    target: 100,
    progressOf: (s) => s.totalMeasurements.toDouble(),
    progressLabel: (p) => '${p.floor()} of 100 measurements',
  ),
  AppBadge(
    id: 'explorer',
    name: 'Explorer',
    description: 'Travel a total of 1 kilometer while playing.',
    icon: Icons.explore,
    color: Colors.green,
    target: 1000,
    progressOf: (s) => s.totalDistanceMeters,
    progressLabel: (p) => '${(p / 1000).toStringAsFixed(2)} of 1 km',
  ),
  AppBadge(
    id: 'trailblazer',
    name: 'Trailblazer',
    description: 'Travel a total of 10 kilometers while playing.',
    icon: Icons.terrain,
    color: Colors.brown,
    target: 10000,
    progressOf: (s) => s.totalDistanceMeters,
    progressLabel: (p) => '${(p / 1000).toStringAsFixed(2)} of 10 km',
  ),
  AppBadge(
    id: 'game_sampler',
    name: 'Game Sampler',
    description: 'Play 3 different games.',
    icon: Icons.videogame_asset,
    color: Colors.purple,
    target: 3,
    progressOf: (s) => s.differentGames.toDouble(),
    progressLabel: (p) => '${p.floor()} of 3 different games',
  ),
  AppBadge(
    id: 'speed_tester',
    name: 'Speed Tester',
    description: 'Run the Measure Internet speed test.',
    icon: Icons.network_check,
    color: Colors.orange,
    target: 1,
    progressOf: (s) => s.speedTests.toDouble(),
    progressLabel: (p) => '${p.floor()} of 1 speed test',
  ),
  AppBadge(
    id: 'back_again',
    name: 'Back Again',
    description: 'Play on 3 different days.',
    icon: Icons.calendar_month,
    color: Colors.pink,
    target: 3,
    progressOf: (s) => s.differentDays.toDouble(),
    progressLabel: (p) => '${p.floor()} of 3 days',
  ),
  AppBadge(
    id: 'regular_player',
    name: 'Regular Player',
    description: 'Finish 10 game sessions.',
    icon: Icons.emoji_events,
    color: Colors.amber,
    target: 10,
    progressOf: (s) => s.sessions.length.toDouble(),
    progressLabel: (p) => '${p.floor()} of 10 sessions',
  ),
  AppBadge(
    id: 'need_for_speed',
    name: 'Need for Speed',
    description: 'Have a session where your average download speed was at least 100 Mbps.',
    icon: Icons.bolt,
    color: Colors.red,
    target: 100,
    progressOf: (s) => s.bestAverageDownload,
    progressLabel: (p) => 'Best so far: ${p.toStringAsFixed(0)} of 100 Mbps',
  ),
];


// The badge ids stored on the player's account (userAccountData/{id}.earnedBadges, a map of badge id to the time
// it was earned). A missing or malformed field counts as nothing earned yet.
Set<String> storedBadgeIds(Object? raw) => raw is Map ? raw.keys.map((k) => k.toString()).toSet() : <String>{};

// A badge counts as earned if its rule says so now, or if it was earned before and stored. Stored badges stay
// earned even if the numbers later change, which badges about other players' actions will need.
bool isBadgeEarned(AppBadge badge, BadgeStats stats, Set<String> stored) =>
    stored.contains(badge.id) || badge.isEarnedBy(stats);

int earnedBadgeCount(BadgeStats stats, Set<String> stored) =>
    allBadges.where((b) => isBadgeEarned(b, stats, stored)).length;

// The badges to store now: earned by the numbers but not stored yet.
List<AppBadge> badgesToAward(BadgeStats stats, Set<String> stored) =>
    allBadges.where((b) => !stored.contains(b.id) && b.isEarnedBy(stats)).toList();
