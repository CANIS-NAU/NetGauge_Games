// Holds the user's light/dark mode choice and remembers it on this device.

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ThemeController extends ChangeNotifier {
  static const String _boxName = 'app_settings';
  static const String _key = 'themeMode';

  // The mode used until the user picks one. Light matches how the app has always looked.
  static const ThemeMode defaultMode = ThemeMode.light;

  ThemeMode _mode;
  final Box? _box;

  ThemeController._(this._mode, this._box);

  // For tests and previews: starts in the given mode and does not save anything.
  ThemeController.inMemory([ThemeMode mode = defaultMode])
      : _mode = mode,
        _box = null;

  // Reads the saved choice. Hive must already be initialized (the logging service does that at startup).
  static Future<ThemeController> load() async {
    try {
      final box = await Hive.openBox(_boxName);
      return ThemeController._(parse(box.get(_key)), box);
    } catch (e) {
      debugPrint('[THEME] Could not read the saved theme: $e');
      return ThemeController._(defaultMode, null);
    }
  }

  ThemeMode get mode => _mode;

  static ThemeMode parse(Object? saved) {
    switch (saved) {
      case 'system':
        return ThemeMode.system;
      case 'dark':
        return ThemeMode.dark;
      case 'light':
        return ThemeMode.light;
      default:
        return defaultMode;
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
    try {
      await _box?.put(_key, mode.name);
    } catch (e) {
      debugPrint('[THEME] Could not save the theme: $e');
    }
  }
}
