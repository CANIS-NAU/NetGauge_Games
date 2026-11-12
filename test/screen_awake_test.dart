import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:get_it/get_it.dart';
import 'package:internet_measurement_games_app/activity_logs.dart';
import 'package:internet_measurement_games_app/screen_awake.dart';
import 'package:internet_measurement_games_app/session_manager.dart';
import 'package:wakelock_plus_platform_interface/wakelock_plus_platform_interface.dart';

// a pretend phone that remembers whether the screen is being kept on
class FakeWakelock extends WakelockPlusPlatformInterface {
  bool keepingScreenOn = false;
  bool refuse = false;

  @override
  Future<void> toggle({required bool enable}) async {
    if (refuse) throw Exception('the phone refused');
    keepingScreenOn = enable;
  }

  @override
  Future<bool> get enabled async => keepingScreenOn;
}

// the game start and end log events; these tests are not about logging
class FakeLoggingService implements LoggingService {
  @override
  Future<void> logEvent(String name, {required String email, Map<String, dynamic>? params, String? userId}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  // one pretend phone for the whole file: the wakelock library keeps using the first one it is given
  final phone = FakeWakelock();
  WakelockPlusPlatformInterface.instance = phone;

  late Directory storage;

  // each test starts like a freshly installed app: nothing saved, so the setting is at its default
  setUp(() async {
    phone.keepingScreenOn = false;
    phone.refuse = false;
    storage = Directory.systemTemp.createTempSync('screen_awake_test');
    Hive.init(storage.path);
    await ScreenAwake.load();
    if (!GetIt.instance.isRegistered<LoggingService>()) {
      GetIt.instance.registerSingleton<LoggingService>(FakeLoggingService());
    }
  });

  tearDown(() async {
    await Hive.close();
    storage.deleteSync(recursive: true);
  });

  group('ScreenAwake', () {
    test('keeps the screen on, and lets it sleep again', () async {
      await ScreenAwake.enable();
      expect(phone.keepingScreenOn, isTrue);

      await ScreenAwake.disable();
      expect(phone.keepingScreenOn, isFalse);
    });

    test('can be repeated safely', () async {
      await ScreenAwake.enable();
      await ScreenAwake.enable();
      expect(phone.keepingScreenOn, isTrue);

      await ScreenAwake.disable();
      await ScreenAwake.disable();
      expect(phone.keepingScreenOn, isFalse);
    });

    test('never throws when the phone refuses, so a game is never stopped by it', () async {
      phone.refuse = true;
      await ScreenAwake.enable();
      await ScreenAwake.disable();
    });
  });

  group('in a game', () {
    test('the screen stays on from the moment a game starts until it ends', () async {
      expect(phone.keepingScreenOn, isFalse);

      SessionManager.startGame('Soul Seeker', 'player@example.com');
      await Future<void>.delayed(Duration.zero);
      expect(phone.keepingScreenOn, isTrue);

      await SessionManager.endGame('player@example.com');
      await Future<void>.delayed(Duration.zero);
      expect(phone.keepingScreenOn, isFalse);
    });

    test('a game that is started twice (the catalog and the game screen both do) still ends cleanly', () async {
      SessionManager.startGame('Zombie Apocalypse', 'player@example.com');
      SessionManager.startGame('Zombie Apocalypse', 'player@example.com');
      await Future<void>.delayed(Duration.zero);
      expect(phone.keepingScreenOn, isTrue);

      await SessionManager.endGame('player@example.com');
      await Future<void>.delayed(Duration.zero);
      expect(phone.keepingScreenOn, isFalse);
    });

    test('the speed test counts as a game too', () async {
      SessionManager.startGame('Measure Internet', 'player@example.com');
      await Future<void>.delayed(Duration.zero);
      expect(phone.keepingScreenOn, isTrue);

      await SessionManager.endGame('player@example.com');
      await Future<void>.delayed(Duration.zero);
      expect(phone.keepingScreenOn, isFalse);
    });

    test('playing one game after another keeps the screen on for each, and off in between', () async {
      SessionManager.startGame('Soul Seeker', 'player@example.com');
      await Future<void>.delayed(Duration.zero);
      await SessionManager.endGame('player@example.com');
      await Future<void>.delayed(Duration.zero);
      expect(phone.keepingScreenOn, isFalse);

      SessionManager.startGame('Constellation Quest', 'player@example.com');
      await Future<void>.delayed(Duration.zero);
      expect(phone.keepingScreenOn, isTrue);

      await SessionManager.endGame('player@example.com');
      await Future<void>.delayed(Duration.zero);
      expect(phone.keepingScreenOn, isFalse);
    });

    test('a phone that refuses does not stop a game from starting or ending', () async {
      phone.refuse = true;
      SessionManager.startGame('Soul Seeker', 'player@example.com');
      await SessionManager.endGame('player@example.com');
      expect(SessionManager.currentGame, isNull);
    });
  });

  group('the setting', () {
    test('is on by default', () {
      expect(ScreenAwake.defaultEnabled, isTrue);
      expect(ScreenAwake.isEnabled, isTrue);
    });

    test('when off, a game does not keep the screen on', () async {
      await ScreenAwake.setEnabled(false);

      await ScreenAwake.enable();
      expect(phone.keepingScreenOn, isFalse);

      SessionManager.startGame('Soul Seeker', 'player@example.com');
      await Future<void>.delayed(Duration.zero);
      expect(phone.keepingScreenOn, isFalse);

      await SessionManager.endGame('player@example.com');
    });

    test('turning it off lets the screen sleep right away if it was being held awake', () async {
      await ScreenAwake.enable();
      expect(phone.keepingScreenOn, isTrue);

      await ScreenAwake.setEnabled(false);
      expect(phone.keepingScreenOn, isFalse);
    });

    test('turning it back on keeps the screen awake in the next game', () async {
      await ScreenAwake.setEnabled(false);
      await ScreenAwake.setEnabled(true);

      SessionManager.startGame('Soul Seeker', 'player@example.com');
      await Future<void>.delayed(Duration.zero);
      expect(phone.keepingScreenOn, isTrue);

      await SessionManager.endGame('player@example.com');
      await Future<void>.delayed(Duration.zero);
      expect(phone.keepingScreenOn, isFalse);
    });

    test('letting the screen sleep still works when the setting is off', () async {
      await ScreenAwake.setEnabled(false);
      phone.keepingScreenOn = true; // something else is holding it awake
      await ScreenAwake.disable();
      expect(phone.keepingScreenOn, isFalse);
    });

    test('the choice is remembered after the app restarts', () async {
      await ScreenAwake.setEnabled(false);

      await Hive.close(); // "restart"
      await ScreenAwake.load();
      expect(ScreenAwake.isEnabled, isFalse);

      await ScreenAwake.setEnabled(true);
      await Hive.close();
      await ScreenAwake.load();
      expect(ScreenAwake.isEnabled, isTrue);
    });

    test('anything unreadable in storage falls back to on', () async {
      final box = await Hive.openBox('app_settings');
      await box.put('keepScreenAwakeDuringGames', 'maybe');
      await Hive.close();

      await ScreenAwake.load();
      expect(ScreenAwake.isEnabled, isTrue);
    });
  });
}
