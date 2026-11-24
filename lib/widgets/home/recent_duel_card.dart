import 'package:flutter/material.dart';

import '../../models/player_profile.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/extensions.dart';
import '../generic/avatar_tile.dart';
import '../generic/pill_badge.dart';

/// "vs Maarten · Laatste duel · 10 min geleden · WIN 3–1".
class RecentDuelCard extends StatelessWidget {
  const RecentDuelCard({super.key, required this.duel});

  final LastDuel duel;

  @override
  Widget build(BuildContext context) {
    final score = '${duel.roundsWon}–${duel.roundsLost}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          AvatarTile(name: duel.opponentName, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'vs ${duel.opponentName}',
                  style: AppTextStyles.body(14, weight: FontWeight.w900),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Laatste duel · ${duel.playedAt.timeAgo()}',
                  style: AppTextStyles.body(
                    12,
                    weight: FontWeight.w700,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          PillBadge(
            label: duel.won ? 'WIN $score' : 'VERLIES $score',
            color: duel.won ? AppColors.green : AppColors.redSoft,
          ),
        ],
      ),
    );
  }
}
