import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:internet_measurement_games_app/welcome_onboarding.dart';

const pages = [
  OnboardingPage(icon: Icons.looks_one, title: 'First page', body: 'Body one'),
  OnboardingPage(icon: Icons.looks_two, title: 'Second page', body: 'Body two'),
  OnboardingPage(icon: Icons.looks_3, title: 'Third page', body: 'Body three'),
];

// opens the pop-up from a button, and records when it has been closed
Future<bool Function()> open(WidgetTester tester, {List<OnboardingPage> custom = pages}) async {
  var closed = false;
  await tester.binding.setSurfaceSize(const Size(411, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () async {
              await showWelcomeOnboarding(context, pages: custom);
              closed = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return () => closed;
}

void main() {
  testWidgets('opens on the first page with Next and Skip, and no Back', (tester) async {
    await open(tester);

    expect(find.text('First page'), findsOneWidget);
    expect(find.text('Body one'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    // Back takes up room but is hidden on the first page
    expect(find.byWidgetPredicate((w) => w is Visibility && !w.visible && w.child is TextButton), findsOneWidget);
  });

  testWidgets('Next and Back step through the pages', (tester) async {
    await open(tester);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Second page'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Third page'), findsOneWidget);

    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Second page'), findsOneWidget);
  });

  testWidgets('swiping moves between pages', (tester) async {
    await open(tester);

    await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('Second page'), findsOneWidget);

    await tester.fling(find.byType(PageView), const Offset(300, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('First page'), findsOneWidget);
  });

  testWidgets('the last page says Get Started, has no Skip, and Get Started closes the pop-up', (tester) async {
    final isClosed = await open(tester);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('Third page'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
    expect(find.text('Next'), findsNothing);
    // Skip is still laid out (so nothing shifts) but hidden, and a hidden button cannot be tapped
    final skipVisibility = tester.widget<Visibility>(
      find.ancestor(of: find.text('Skip'), matching: find.byType(Visibility)),
    );
    expect(skipVisibility.visible, isFalse);

    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();
    expect(find.text('Third page'), findsNothing);
    expect(isClosed(), isTrue);
  });

  testWidgets('Skip closes the pop-up from any page', (tester) async {
    final isClosed = await open(tester);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(find.text('Second page'), findsNothing);
    expect(isClosed(), isTrue);
  });

  testWidgets('tapping outside the pop-up does not close it', (tester) async {
    final isClosed = await open(tester);

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(find.text('First page'), findsOneWidget);
    expect(isClosed(), isFalse);
  });

  testWidgets('a page with long text scrolls instead of overflowing', (tester) async {
    await open(tester, custom: [
      OnboardingPage(icon: Icons.info, title: 'Long page', body: List.filled(60, 'A long sentence of text.').join(' ')),
    ]);

    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    // a single page is both the first and the last: it just offers Get Started
    expect(find.text('Get Started'), findsOneWidget);
  });

  test('the real welcome pages have content to show', () {
    expect(welcomePages, isNotEmpty);
    for (final page in welcomePages) {
      expect(page.title, isNotEmpty);
      expect(page.body, isNotEmpty);
    }
  });
}
