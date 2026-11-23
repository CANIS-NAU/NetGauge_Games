// The badge library: every badge in a grid, in color if earned and grayed out if not. Tapping one explains it.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_theme.dart';
import 'badges.dart';
import 'user_data_manager.dart';

class BadgeLibraryPage extends StatelessWidget {
  // where the stats come from; only tests pass their own
  final BadgeStats? stats;
  // badges already stored on the account; only tests pass their own
  final Set<String>? storedIds;
  // called with the badge's id when a player opens one (the app uses this for activity logging)
  final void Function(String badgeId)? onBadgeOpened;

  const BadgeLibraryPage({super.key, this.stats, this.storedIds, this.onBadgeOpened});

  @override
  Widget build(BuildContext context) {
    final userData = stats == null || storedIds == null ? Provider.of<UserDataProvider>(context) : null;
    final badgeStats = stats ?? userData!.badgeStats;
    final stored = storedIds ?? userData!.earnedBadgeIds;
    final earned = earnedBadgeCount(badgeStats, stored);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Badge Library',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 25)),
        backgroundColor: const Color(0xFF440154),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('$earned of ${allBadges.length} badges earned',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 16,
                crossAxisSpacing: 12,
                childAspectRatio: 0.85,
              ),
              itemCount: allBadges.length,
              itemBuilder: (context, i) {
                final badge = allBadges[i];
                return BadgeTile(
                  badge: badge,
                  earned: isBadgeEarned(badge, badgeStats, stored),
                  onTap: () {
                    onBadgeOpened?.call(badge.id);
                    showBadgeDetails(context, badge, badgeStats, earned: isBadgeEarned(badge, badgeStats, stored));
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// one badge in the grid
class BadgeTile extends StatelessWidget {
  final AppBadge badge;
  final bool earned;
  final VoidCallback onTap;

  const BadgeTile({super.key, required this.badge, required this.earned, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${badge.name}, ${earned ? 'earned' : 'not earned yet'}',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            BadgeMedallion(badge: badge, earned: earned, size: 72),
            const SizedBox(height: 6),
            Text(
              badge.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: earned ? context.inkColor : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// the round badge picture: colored when earned, gray with a lock when not
class BadgeMedallion extends StatelessWidget {
  final AppBadge badge;
  final bool earned;
  final double size;

  const BadgeMedallion({super.key, required this.badge, required this.earned, required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: earned ? badge.color : Colors.grey.shade400.withValues(alpha: 0.5),
              border: Border.all(color: earned ? badge.color.withValues(alpha: 0.6) : Colors.grey, width: 3),
            ),
            child: Icon(badge.icon, size: size * 0.5, color: earned ? Colors.white : Colors.grey.shade600),
          ),
          if (!earned)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.grey.shade700),
                child: Icon(Icons.lock, size: size * 0.2, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}

// the pop-up with a badge's description, whether it is earned, and how close the player is
void showBadgeDetails(BuildContext context, AppBadge badge, BadgeStats stats, {required bool earned}) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(badge.name, textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BadgeMedallion(badge: badge, earned: earned, size: 96),
          const SizedBox(height: 16),
          Text(badge.description, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          if (earned)
            const Text('Earned!', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green))
          else ...[
            const Text('Not earned yet', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: badge.fractionFor(stats)),
            const SizedBox(height: 4),
            Text(badge.progressLabel(badge.progressOf(stats)), style: const TextStyle(fontSize: 12)),
          ],
        ],
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
    ),
  );
}
