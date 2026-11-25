import 'package:flutter/material.dart';

import '../../models/badge.dart';
import '../../models/player_profile.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../badges/badge_medal.dart';

/// Your latest badges on the home screen; tap to see them all.
class BadgeShelf extends StatelessWidget {
  const BadgeShelf({super.key, required this.profile, required this.onOpen});

  final PlayerProfile profile;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final earned = [
      for (final b in allBadges)
        if (profile.hasBadge(b.id)) b,
    ]..sort((a, b) => profile.badges[b.id]!.compareTo(profile.badges[a.id]!));
    // Nothing yet: show what is there to win.
    final shown = earned.isEmpty
        ? allBadges.take(4).toList()
        : earned.take(4).toList();

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('BADGES', style: AppTextStyles.overline()),
                  const SizedBox(height: 4),
                  Text(
                    '${earned.length}/${allBadges.length}',
                    style: AppTextStyles.display(22, color: AppColors.gold),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    for (final b in shown)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: BadgeMedal(
                          badge: b,
                          size: 40,
                          unlocked: profile.hasBadge(b.id),
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
