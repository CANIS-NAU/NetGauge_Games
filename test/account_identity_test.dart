import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:internet_measurement_games_app/account_identity.dart';

class _FakeUser implements User {
  _FakeUser({this.email, required this.uid, this.isAnonymous = false});

  @override
  final String? email;
  @override
  final String uid;
  @override
  final bool isAnonymous;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('a signed-in account is identified by its email', () {
    final user = _FakeUser(email: 'player@example.com', uid: 'abc123');
    expect(accountIdFor(user), 'player@example.com');
    expect(isGuest(user), isFalse);
  });

  test('a guest has no email and is identified by a guest ID', () {
    final user = _FakeUser(uid: 'abc123', isAnonymous: true);
    expect(accountIdFor(user), 'guest_abc123');
    expect(isGuest(user), isTrue);
  });

  test('nobody signed in gives an empty ID', () {
    expect(accountIdFor(null), '');
    expect(isGuest(null), isFalse);
  });
}
