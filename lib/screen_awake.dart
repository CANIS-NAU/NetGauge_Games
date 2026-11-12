// Keeps the phone's screen on (so it does not dim, lock or go to sleep) while a player is in a game.
//
// Turned on when a game starts and off when it ends (see SessionManager.startGame and endGame), so the phone sleeps
// normally everywhere else in the app. Players can switch this off in Settings; it is on by default, and their
// choice is remembered on this device.
//
// All calls are safe to repeat, and none of them throws: if the phone refuses, the game simply carries on and the
// screen may sleep as it normally would.

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class ScreenAwake {
  static const String _boxName = 'app_settings';
  static const String _key = 'keepScreenAwakeDuringGames';

  // the player's choice in Settings; on until they turn it off
  static const bool defaultEnabled = true;
  static bool _enabled = defaultEnabled;
  static Box? _box;

  // whether the player wants the screen kept on during games
  static bool get isEnabled => _enabled;

  // Reads the saved choice. Hive must already be initialized (the logging service does that at startup). If the
  // saved choice cannot be read, the default (on) is used.
  static Future<void> load() async {
    try {
      _box = await Hive.openBox(_boxName);
      final saved = _box!.get(_key);
      _enabled = saved is bool ? saved : defaultEnabled;
    } catch (e) {
      debugPrint('[SCREEN_AWAKE] Could not read the saved setting: $e');
      _box = null;
      _enabled = defaultEnabled;
    }
  }

  // Changes the setting and remembers it. Turning it off also lets the screen sleep right away, in case a game
  // was somehow still holding it awake; turning it on takes effect when the next game starts.
  static Future<void> setEnabled(bool value) async {
    _enabled = value;
    try {
      await _box?.put(_key, value);
    } catch (e) {
      debugPrint('[SCREEN_AWAKE] Could not save the setting: $e');
    }
    if (!value) await disable();
  }

  // keep the screen on, if the player has not turned that off in Settings
  static Future<void> enable() async {
    if (!_enabled) return;
    try {
      await WakelockPlus.enable();
    } catch (e) {
      debugPrint('[SCREEN_AWAKE] Could not keep the screen on: $e');
    }
  }

  // let the screen sleep normally again (always, whatever the setting)
  static Future<void> disable() async {
    try {
      await WakelockPlus.disable();
    } catch (e) {
      debugPrint('[SCREEN_AWAKE] Could not let the screen sleep again: $e');
    }
  }
}
