import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:internet_measurement_games_app/badge_announcement.dart';
import 'package:internet_measurement_games_app/badge_library.dart';
import 'package:internet_measurement_games_app/badges.dart';

PlayedSession played(String game, {DateTime? end, double? download}) =>
    PlayedSession(game: game, endTime: end ?? DateTime(2026, 1, 1, 12), averageDownload: download);

BadgeStats stats({int measurements = 0, double meters = 0, List<PlayedSession> sessions = const []}) =>
    BadgeStats(totalMeasurements: measurements, totalDistanceMeters: meters, sessions: sessions);

AppBadge badge(String id) => allBadges.firstWhere((b) => b.id == id);

void main() {
  group('badge rules', () {
    test('a new player has earned nothing', () {
      expect(badgesToAward(stats(), {}), isEmpty);
    });

    test('badge ids are unique', () {
      expect(allBadges.map((b) => b.id).toSet().length, allBadges.length);
    });

    test('First Steps after one session', () {
      expect(badge('first_steps').isEarnedBy(stats(sessions: [played('Zombie')])), isTrue);
    });

    test('measurement badges unlock at their totals', () {
      expect(badge('data_collector').isEarnedBy(stats(measurements: 9)), isFalse);
      expect(badge('data_collector').isEarnedBy(stats(measurements: 10)), isTrue);
      expect(badge('data_hoarder').isEarnedBy(stats(measurements: 99)), isFalse);
      expect(badge('data_hoarder').isEarnedBy(stats(measurements: 100)), isTrue);
    });

    test('distance badges use meters', () {
      expect(badge('explorer').isEarnedBy(stats(meters: 999)), isFalse);
      expect(badge('explorer').isEarnedBy(stats(meters: 1000)), isTrue);
      expect(badge('trailblazer').isEarnedBy(stats(meters: 10000)), isTrue);
    });

    test('Game Sampler counts different games, not the speed test or repeats', () {
      final s = stats(sessions: [
        played('Zombie'),
        played('Zombie'),
        played('Speedtest'),
        played('Mystery'),
      ]);
      expect(s.differentGames, 2);
      expect(badge('game_sampler').isEarnedBy(s), isFalse);
      expect(badge('game_sampler').isEarnedBy(stats(sessions: [played('A'), played('B'), played('C')])), isTrue);
    });

    test('Speed Tester recognizes every name the speed test has been saved under', () {
      for (final name in ['Measure Internet', 'Speedtest', 'Speed Tester']) {
        expect(badge('speed_tester').isEarnedBy(stats(sessions: [played(name)])), isTrue, reason: name);
      }
      expect(badge('speed_tester').isEarnedBy(stats(sessions: [played('Zombie')])), isFalse);
    });

    test('Back Again counts different calendar days', () {
      final sameDay = stats(sessions: [
        played('A', end: DateTime(2026, 1, 1, 8)),
        played('A', end: DateTime(2026, 1, 1, 20)),
        played('A', end: DateTime(2026, 1, 2)),
      ]);
      expect(sameDay.differentDays, 2);
      expect(badge('back_again').isEarnedBy(sameDay), isFalse);

      final threeDays = stats(sessions: [
        for (var d = 1; d <= 3; d++) played('A', end: DateTime(2026, 1, d)),
      ]);
      expect(badge('back_again').isEarnedBy(threeDays), isTrue);
    });

    test('Regular Player needs 10 sessions', () {
      expect(badge('regular_player').isEarnedBy(stats(sessions: List.generate(9, (_) => played('A')))), isFalse);
      expect(badge('regular_player').isEarnedBy(stats(sessions: List.generate(10, (_) => played('A')))), isTrue);
    });

    test('Need for Speed uses the best session, and sessions without speeds are fine', () {
      final slow = stats(sessions: [played('A', download: 40), played('B')]);
      expect(slow.bestAverageDownload, 40);
      expect(badge('need_for_speed').isEarnedBy(slow), isFalse);
      expect(badge('need_for_speed').isEarnedBy(stats(sessions: [played('A', download: 120)])), isTrue);
    });

    test('progress fraction is clamped and labeled', () {
      final b = badge('data_collector');
      expect(b.fractionFor(stats(measurements: 5)), 0.5);
      expect(b.fractionFor(stats(measurements: 500)), 1.0);
      expect(b.progressLabel(b.progressOf(stats(measurements: 4))), '4 of 10 measurements');
    });
  });

  group('stored badges', () {
    test('storedBadgeIds reads the keys of the earnedBadges map', () {
      expect(storedBadgeIds({'first_steps': 1, 'explorer': 2}), {'first_steps', 'explorer'});
    });

    test('a missing or malformed field means nothing is stored', () {
      expect(storedBadgeIds(null), isEmpty);
      expect(storedBadgeIds('nope'), isEmpty);
      expect(storedBadgeIds([1, 2]), isEmpty);
    });

    test('badgesToAward gives only badges earned now and not already stored', () {
      final s = stats(measurements: 12, sessions: [played('Zombie')]);
      expect(badgesToAward(s, {}).map((b) => b.id), ['first_steps', 'data_collector']);
      expect(badgesToAward(s, {'first_steps'}).map((b) => b.id), ['data_collector']);
      expect(badgesToAward(s, {'first_steps', 'data_collector'}), isEmpty);
    });

    test('a stored badge stays earned even when the numbers no longer reach it', () {
      expect(isBadgeEarned(badge('data_hoarder'), stats(), {'data_hoarder'}), isTrue);
      expect(isBadgeEarned(badge('data_hoarder'), stats(), {}), isFalse);
      expect(earnedBadgeCount(stats(), {'data_hoarder', 'explorer'}), 2);
    });

    test('a stored badge never needs to be awarded again', () {
      expect(badgesToAward(stats(measurements: 500), allBadges.map((b) => b.id).toSet()), isEmpty);
    });
  });

  group('announcements', () {
    test('no new badges means no message', () {
      expect(badgeAnnouncementText([]), isNull);
    });

    test('one badge names it', () {
      expect(badgeAnnouncementText([badge('explorer')]), 'Badge earned: Explorer!');
    });

    test('several badges are counted and named', () {
      expect(badgeAnnouncementText([badge('explorer'), badge('first_steps')]),
          '2 badges earned: Explorer, First Steps!');
    });

    testWidgets('announceBadges shows the message through the app messenger', (tester) async {
      await tester.pumpWidget(MaterialApp(
        scaffoldMessengerKey: appMessengerKey,
        home: const Scaffold(body: SizedBox()),
      ));

      announceBadges([badge('explorer')]);
      await tester.pump();

      expect(find.text('Badge earned: Explorer!'), findsOneWidget);
    });

    test('announcing with no app on screen does nothing', () {
      expect(() => announceBadges([badge('explorer')]), returnsNormally);
    });
  });

  group('badge library page', () {
    // 12 measurements earns Data Collector only
    final oneBadge = stats(measurements: 12);

    Future<void> pump(WidgetTester tester, {void Function(String)? onOpened, Set<String> stored = const {}}) {
      return tester.pumpWidget(MaterialApp(
        home: BadgeLibraryPage(stats: oneBadge, storedIds: stored, onBadgeOpened: onOpened),
      ));
    }

    testWidgets('shows every badge and how many are earned', (tester) async {
      await pump(tester);
      expect(find.text('1 of ${allBadges.length} badges earned'), findsOneWidget);
      expect(find.byType(BadgeTile), findsWidgets);
      expect(find.text('Data Collector'), findsOneWidget);
    });

    testWidgets('unearned badges are grayed out with a lock; earned ones are not', (tester) async {
      await pump(tester);

      final earnedTile = tester.widget<BadgeTile>(find.widgetWithText(BadgeTile, 'Data Collector'));
      final lockedTile = tester.widget<BadgeTile>(find.widgetWithText(BadgeTile, 'First Steps'));
      expect(earnedTile.earned, isTrue);
      expect(lockedTile.earned, isFalse);

      expect(find.descendant(of: find.widgetWithText(BadgeTile, 'First Steps'), matching: find.byIcon(Icons.lock)),
          findsOneWidget);
      expect(find.descendant(of: find.widgetWithText(BadgeTile, 'Data Collector'), matching: find.byIcon(Icons.lock)),
          findsNothing);
    });

    testWidgets('tapping an unearned badge shows its description and progress', (tester) async {
      final opened = <String>[];
      await pump(tester, onOpened: opened.add);

      await tester.tap(find.text('Data Hoarder'));
      await tester.pumpAndSettle();

      expect(find.text('Collect 100 internet measurements while you play.'), findsOneWidget);
      expect(find.text('Not earned yet'), findsOneWidget);
      expect(find.text('12 of 100 measurements'), findsOneWidget);
      expect(opened, ['data_hoarder']);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Not earned yet'), findsNothing);
    });

    testWidgets('tapping an earned badge says it is earned', (tester) async {
      await pump(tester);

      await tester.tap(find.text('Data Collector'));
      await tester.pumpAndSettle();

      expect(find.text('Collect 10 internet measurements while you play.'), findsOneWidget);
      expect(find.text('Earned!'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('a badge stored on the account shows as earned even if the numbers no longer reach it', (tester) async {
      await pump(tester, stored: {'explorer'});

      expect(find.text('2 of ${allBadges.length} badges earned'), findsOneWidget);
      expect(tester.widget<BadgeTile>(find.widgetWithText(BadgeTile, 'Explorer')).earned, isTrue);

      await tester.ensureVisible(find.text('Explorer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Explorer'));
      await tester.pumpAndSettle();
      expect(find.text('Earned!'), findsOneWidget);
    });
  });
}
