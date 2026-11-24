import 'package:flutter/material.dart';

import '../../models/player_profile.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/constants.dart';
import '../generic/progress_bar.dart';

/// "+120 XP" with the level bar, and "+1 WIN" with the streak.
class RewardCards extends StatelessWidget {
  const RewardCards({
    super.key,
    required this.profile,
    required this.xpGained,
    required this.won,
  });

  /// The profile after this game was recorded.
  final PlayerProfile profile;
  final int xpGained;
  final bool won;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _Card(
              borderColor: AppColors.violet.withValues(alpha: 0.4),
              children: [
                Text(
                  '+$xpGained XP',
                  style: AppTextStyles.display(26, color: AppColors.lavender),
                ),
                const SizedBox(height: 10),
                ProgressBar(value: profile.levelProgress),
                const SizedBox(height: 6),
                Text(
                  'LVL ${profile.level} · ${profile.xpInLevel}/${AppConstants.xpPerLevel}',
                  style: AppTextStyles.caption(),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _Card(
              borderColor: (won ? AppColors.green : AppColors.redSoft)
                  .withValues(alpha: 0.35),
              children: [
                Text(
                  won ? '+1 WIN' : '+1 DUEL',
                  style: AppTextStyles.display(
                    26,
                    color: won ? AppColors.green : AppColors.redSoft,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '${profile.wins} overwinningen',
                  style: AppTextStyles.body(13, color: AppColors.textSoft),
                ),
                const SizedBox(height: 2),
                Text(
                  won ? 'Reeks: ${profile.streak} op rij' : 'Reeks verbroken',
                  style: AppTextStyles.caption(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.borderColor, required this.children});

  final Color borderColor;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}
