import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:internet_measurement_games_app/login_page.dart';

void main() {
  Future<void> openLogin(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginPage()));
  }

  testWidgets('login page offers a Forgot password link that opens the reset dialog', (tester) async {
    await openLogin(tester);

    expect(find.text('Forgot password?'), findsOneWidget);
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();

    expect(find.text('Reset Password'), findsOneWidget);
    expect(find.text('Send Reset Link'), findsOneWidget);
  });

  testWidgets('the reset dialog starts from the email already typed on the login form', (tester) async {
    await openLogin(tester);

    await tester.enterText(find.byType(TextField).first, 'player@example.com');
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(TextField, 'player@example.com'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('sending without an email asks for one and does not call Firebase', (tester) async {
    await openLogin(tester);

    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send Reset Link'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter your email.'), findsOneWidget);
  });

  testWidgets('login page offers Continue as Guest', (tester) async {
    await openLogin(tester);

    expect(find.text('Continue as Guest'), findsOneWidget);
  });

  testWidgets('Cancel closes the dialog', (tester) async {
    await openLogin(tester);

    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Reset Password'), findsNothing);
  });
}
