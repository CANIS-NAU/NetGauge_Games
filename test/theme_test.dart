import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:internet_measurement_games_app/app_theme.dart';
import 'package:internet_measurement_games_app/theme_controller.dart';
import 'package:provider/provider.dart';

void main() {
  group('ThemeController', () {
    test('starts in light mode, which is how the app has always looked', () {
      expect(ThemeController.inMemory().mode, ThemeMode.light);
    });

    test('reads saved choices, and falls back to the default for anything else', () {
      expect(ThemeController.parse('system'), ThemeMode.system);
      expect(ThemeController.parse('light'), ThemeMode.light);
      expect(ThemeController.parse('dark'), ThemeMode.dark);
      expect(ThemeController.parse(null), ThemeController.defaultMode);
      expect(ThemeController.parse('purple'), ThemeController.defaultMode);
    });

    test('changing the mode tells listeners, and choosing the same mode again does not', () async {
      final controller = ThemeController.inMemory();
      var notified = 0;
      controller.addListener(() => notified++);

      await controller.setMode(ThemeMode.dark);
      expect(controller.mode, ThemeMode.dark);
      expect(notified, 1);

      await controller.setMode(ThemeMode.dark);
      expect(notified, 1);
    });

    test('the choice is remembered after the app restarts', () async {
      final dir = Directory.systemTemp.createTempSync('theme_test');
      addTearDown(() async {
        await Hive.close();
        dir.deleteSync(recursive: true);
      });
      Hive.init(dir.path);

      final first = await ThemeController.load();
      expect(first.mode, ThemeMode.light);
      await first.setMode(ThemeMode.dark);

      await Hive.close(); // "restart"
      final second = await ThemeController.load();
      expect(second.mode, ThemeMode.dark);
    });
  });

  group('the app follows the chosen mode', () {
    Future<Brightness> brightnessFor(WidgetTester tester, ThemeMode mode, {Brightness system = Brightness.light}) async {
      tester.platformDispatcher.platformBrightnessTestValue = system;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      late Brightness result;
      await tester.pumpWidget(
        ChangeNotifierProvider(
          key: UniqueKey(), // a fresh controller each time this is called in one test
          create: (_) => ThemeController.inMemory(mode),
          child: Builder(
            builder: (context) => MaterialApp(
              theme: lightTheme,
              darkTheme: darkTheme,
              themeMode: context.watch<ThemeController>().mode,
              home: Builder(builder: (context) {
                result = Theme.of(context).brightness;
                return const SizedBox();
              }),
            ),
          ),
        ),
      );
      return result;
    }

    testWidgets('Light and Dark ignore the phone setting', (tester) async {
      expect(await brightnessFor(tester, ThemeMode.light, system: Brightness.dark), Brightness.light);
      expect(await brightnessFor(tester, ThemeMode.dark, system: Brightness.light), Brightness.dark);
    });

    testWidgets('System follows the phone setting', (tester) async {
      expect(await brightnessFor(tester, ThemeMode.system, system: Brightness.dark), Brightness.dark);
      expect(await brightnessFor(tester, ThemeMode.system, system: Brightness.light), Brightness.light);
    });

    testWidgets('switching modes updates a running app', (tester) async {
      final controller = ThemeController.inMemory(ThemeMode.light);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: controller,
          child: Builder(
            builder: (context) => MaterialApp(
              theme: lightTheme,
              darkTheme: darkTheme,
              themeMode: context.watch<ThemeController>().mode,
              home: Builder(
                builder: (context) => Text(context.isDarkMode ? 'dark' : 'light'),
              ),
            ),
          ),
        ),
      );
      expect(find.text('light'), findsOneWidget);

      await controller.setMode(ThemeMode.dark);
      await tester.pumpAndSettle(); // the theme change animates
      expect(find.text('dark'), findsOneWidget);
    });
  });

  group('paper and ink colors', () {
    Future<(Color paper, Color ink)> colorsIn(WidgetTester tester, ThemeData theme) async {
      late Color paper;
      late Color ink;
      await tester.pumpWidget(MaterialApp(
        theme: theme,
        home: Builder(builder: (context) {
          paper = context.paperColor;
          ink = context.inkColor;
          return const SizedBox();
        }),
      ));
      return (paper, ink);
    }

    testWidgets('light mode keeps the original white boxes with black text', (tester) async {
      final (paper, ink) = await colorsIn(tester, lightTheme);
      expect(paper, Colors.white);
      expect(ink, Colors.black);
    });

    testWidgets('dark mode uses a dark box with light text, so text stays readable', (tester) async {
      final (paper, ink) = await colorsIn(tester, darkTheme);
      expect(paper.computeLuminance(), lessThan(0.1));
      expect(ink.computeLuminance(), greaterThan(0.6));
    });
  });
}
