// How the app identifies the person using it.
//
// Most of the app keys data (user profile, measurements, survey answers, logs) by the user's email address.
// Guests sign in anonymously and have no email, so they are identified by "guest_" plus their Firebase user ID
// instead. Everything that needs an ID for the signed-in person should go through accountIdFor.

import 'package:firebase_auth/firebase_auth.dart';

const String guestIdPrefix = 'guest_';

// The ID to use for this user's data: their email, or a guest ID if they have no email. Empty if nobody is signed in.
String accountIdFor(User? user) {
  if (user == null) return '';
  final email = user.email;
  if (email != null && email.isNotEmpty) return email;
  return '$guestIdPrefix${user.uid}';
}

// True if the user is using the app as a guest, without an account.
bool isGuest(User? user) => user?.isAnonymous ?? false;
