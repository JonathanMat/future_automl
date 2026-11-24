import 'package:flutter/material.dart';

import '../../models/game_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/player_tag.dart';
import '../generic/avatar_tile.dart';

/// Top three, with #1 in the middle and tallest.
class Podium extends StatelessWidget {
  const Podium({super.key, required this.entries});

  /// Sorted, best first. Up to three are shown.
  final List<LeaderboardEntry> entries;

  static const _rings = [AppColors.gold, AppColors.silver, AppColors.bronze];
  static const _heights = [100.0, 76.0, 58.0];

  @override
  Widget build(BuildContext context) {
    final top = entries.take(3).toList();
    // Visual order: 2nd, 1st, 3rd.
    final order = [1, 0, 2].where((i) => i < top.length).toList();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final i in order)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: _Step(
              entry: top[i],
              rank: i + 1,
              ring: _rings[i],
              height: _heights[i],
            ),
          ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.entry,
    required this.rank,
    required this.ring,
    required this.height,
  });

  final LeaderboardEntry entry;
  final int rank;
  final Color ring;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          'Plaats $rank: ${PlayerTag.withName(entry.name, entry.tag)}, '
          '${entry.wins} wins',
      excludeSemantics: true,
      child: SizedBox(
        width: 104,
        child: Column(
          children: [
            AvatarTile(
              name: entry.name,
              size: 52,
              circle: true,
              ringColor: ring,
            ),
            const SizedBox(height: 8),
            Text(
              entry.name,
              style: AppTextStyles.body(14, weight: FontWeight.w900),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              [
                if (entry.tag != null) PlayerTag.format(entry.tag),
                '${entry.wins} wins',
              ].join(' · '),
              style: AppTextStyles.caption(),
            ),
            const SizedBox(height: 8),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: height),
              duration: Duration(milliseconds: 400 + rank * 120),
              curve: Curves.easeOutCubic,
              builder: (context, h, _) => Container(
                width: double.infinity,
                height: h,
                padding: const EdgeInsets.only(top: 8),
                alignment: Alignment.topCenter,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                    bottom: Radius.circular(6),
                  ),
                  border: Border(top: BorderSide(color: ring, width: 3)),
                ),
                child: h > 36
                    ? Text(
                        '$rank',
                        style: AppTextStyles.display(28, color: ring),
                      )
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
