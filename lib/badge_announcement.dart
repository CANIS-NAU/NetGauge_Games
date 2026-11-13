// Tells the player when they earn a badge. Badges can be earned when a game ends or when the app loads the account,
// where there is no screen to attach a message to, so the message goes through the app-wide messenger.

import 'package:flutter/material.dart';
import 'badges.dart';

// set on the MaterialApp in main.dart
final GlobalKey<ScaffoldMessengerState> appMessengerKey = GlobalKey<ScaffoldMessengerState>();

// the message for newly earned badges, or null if there are none
String? badgeAnnouncementText(List<AppBadge> newBadges) {
  if (newBadges.isEmpty) return null;
  if (newBadges.length == 1) return 'Badge earned: ${newBadges.first.name}!';
  return '${newBadges.length} badges earned: ${newBadges.map((b) => b.name).join(', ')}!';
}

void announceBadges(List<AppBadge> newBadges) {
  final text = badgeAnnouncementText(newBadges);
  if (text == null) return;
  appMessengerKey.currentState?.showSnackBar(
    SnackBar(content: Text(text), duration: const Duration(seconds: 4)),
  );
}
