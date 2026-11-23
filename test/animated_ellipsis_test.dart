import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:internet_measurement_games_app/widgets/animated_ellipsis.dart';

// the three parts the widget draws: the text, the dots showing so far, and the dots still to come (invisible)
// Flutter wraps the widget's own span in an outer one, so look one level down
TextSpan ownSpan(WidgetTester tester) {
  final rich = tester.widget<RichText>(
    find.descendant(of: find.byType(AnimatedEllipsis), matching: find.byType(RichText)),
  );
  return (rich.text as TextSpan).children!.single as TextSpan;
}

List<TextSpan> parts(WidgetTester tester) => ownSpan(tester).children!.cast<TextSpan>();

// what the player can see right now
String shown(WidgetTester tester) {
  final p = parts(tester);
  return '${p[0].text}${p[1].text}';
}

Future<void> show(WidgetTester tester, {bool reduceMotion = false, Widget? child}) {
  return tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Scaffold(body: Center(child: child ?? const AnimatedEllipsis('Testing'))),
      ),
    ),
  );
}

void main() {
  testWidgets('shows the dots one at a time, then starts over', (tester) async {
    await show(tester);
    expect(shown(tester), 'Testing'); // no dots yet

    await tester.pump(const Duration(milliseconds: 450));
    expect(shown(tester), 'Testing.');

    await tester.pump(const Duration(milliseconds: 400));
    expect(shown(tester), 'Testing..');

    await tester.pump(const Duration(milliseconds: 400));
    expect(shown(tester), 'Testing...');

    await tester.pump(const Duration(milliseconds: 400));
    expect(shown(tester), 'Testing'); // round again

    await tester.pump(const Duration(milliseconds: 450));
    expect(shown(tester), 'Testing.');
  });

  testWidgets('keeps going for as long as the player waits', (tester) async {
    await show(tester);
    final seen = <String>{};
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 200));
      seen.add(shown(tester));
    }
    expect(seen, {'Testing', 'Testing.', 'Testing..', 'Testing...'});
  });

  testWidgets('does not jump around: the width is the same whichever dots are showing', (tester) async {
    await show(tester);
    final widths = <double>{};
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 250));
      widths.add(tester.getSize(find.byType(AnimatedEllipsis)).width);
      // visible and invisible dots always add up to all of them
      expect(parts(tester).map((p) => p.text).join(), 'Testing...');
    }
    expect(widths.length, 1);
  });

  testWidgets('the dots still to come are invisible, not removed', (tester) async {
    await show(tester);
    await tester.pump(const Duration(milliseconds: 450)); // one dot showing
    final p = parts(tester);
    expect(p[1].text, '.');
    expect(p[2].text, '..');
    expect(p[2].style!.color, Colors.transparent);
  });

  testWidgets('with reduce motion on, shows all the dots at once and does not animate', (tester) async {
    await show(tester, reduceMotion: true);
    expect(shown(tester), 'Testing...');

    await tester.pump(const Duration(seconds: 2));
    expect(shown(tester), 'Testing...');
    // nothing is scheduled to keep running, so this finishes straight away instead of timing out
    await tester.pumpAndSettle();
  });

  testWidgets('a screen reader hears "Testing", not the dots being typed out', (tester) async {
    final handle = tester.ensureSemantics();
    await show(tester);

    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 400));
      final label = tester.getSemantics(find.byType(AnimatedEllipsis)).label;
      expect(label, 'Testing');
    }
    handle.dispose();
  });

  testWidgets('can use other text and a different number of dots', (tester) async {
    await show(tester, child: const AnimatedEllipsis('Loading', dots: 2, stepDuration: Duration(milliseconds: 100)));
    expect(shown(tester), 'Loading');

    await tester.pump(const Duration(milliseconds: 120));
    expect(shown(tester), 'Loading.');

    await tester.pump(const Duration(milliseconds: 100));
    expect(shown(tester), 'Loading..');
    expect(parts(tester).map((p) => p.text).join(), 'Loading..');
  });

  testWidgets('uses the style it is given', (tester) async {
    await show(
      tester,
      child: const AnimatedEllipsis('Testing', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
    );
    expect(ownSpan(tester).style!.fontSize, 20);
    expect(ownSpan(tester).style!.fontWeight, FontWeight.bold);
  });

  testWidgets('stops cleanly when it is replaced by the result', (tester) async {
    await show(tester);
    await tester.pump(const Duration(milliseconds: 500));

    // the measurement finishes and the page shows the number instead
    await show(tester, child: const Text('52.30 Mbps'));
    await tester.pumpAndSettle();

    expect(find.byType(AnimatedEllipsis), findsNothing);
    expect(find.text('52.30 Mbps'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
