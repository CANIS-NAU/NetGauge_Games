// The app's light and dark themes, and two colors that screens use for "paper" (boxes and cards) and "ink"
// (text and outlines drawn on that paper) so they work in both modes.

import 'package:flutter/material.dart';

// The light theme is Flutter's default, which is what the app has always used.
final ThemeData lightTheme = ThemeData();

final ThemeData darkTheme = ThemeData(brightness: Brightness.dark);

extension AppColors on BuildContext {
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  // background of boxes and cards: white in light mode, a raised dark gray in dark mode
  Color get paperColor => isDarkMode ? Theme.of(this).colorScheme.surfaceContainerHigh : Colors.white;

  // text and outlines on paper: black in light mode, near-white in dark mode
  Color get inkColor => isDarkMode ? Theme.of(this).colorScheme.onSurface : Colors.black;
}
