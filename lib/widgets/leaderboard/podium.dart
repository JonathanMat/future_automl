import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/game_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/player_tag.dart';
import '../generic/avatar_tile.dart';
import '../generic/player_name.dart';

/// One podium place: avatar, name, wins and a bar with the rank number.
///
/// The bar takes whatever height is left under the fixed header, so when
/// the board animates this step's height the bar grows or shrinks with it.
/// Below [headerHeight] the header slides out at the bottom (clipped).
class PodiumStep extends StatelessWidget {
  const PodiumStep({
    super.key,
    required this.entry,
    required this.rank,
    this.contentOpacity = 1,
  });

  final LeaderboardEntry entry;
  final int rank;

  /// Avatar and name fade in for players that are new on this tab.
  final double contentOpacity;

  /// Includes [_ringRoom] above the avatar: its ring is drawn 5px outside
  /// the avatar box and would otherwise be clipped.
  static const headerHeight = 112.0;
  static const _ringRoom = 8.0;
  static const barHeights = [100.0, 76.0, 58.0];
  static const width = 104.0;
  static const _rings = [AppColors.gold, AppColors.silver, AppColors.bronze];

  /// Full height of the step for [rank] 1–3.
  static double heightFor(int rank) => headerHeight + barHeights[rank - 1];

  @override
  Widget build(BuildContext context) {
    final ring = _rings[(rank - 1).clamp(0, 2)];
    return Semantics(
      label:
          'Plaats $rank: ${PlayerTag.withName(entry.name, entry.tag)}, '
          '${entry.wins} wins',
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, box) {
          final bar = math.max(0.0, box.maxHeight - headerHeight);
          return ClipRect(
            child: OverflowBox(
              alignment: Alignment.bottomCenter,
              minHeight: headerHeight + bar,
              maxHeight: headerHeight + bar,
              child: Column(
                children: [
                  SizedBox(
                    height: headerHeight,
                    child: AnimatedOpacity(
                      opacity: contentOpacity,
                      duration: const Duration(milliseconds: 300),
                      child: Column(
                        children: [
                          const SizedBox(height: _ringRoom),
                          AvatarTile(
                            name: entry.name,
                            size: 52,
                            circle: true,
                            ringColor: ring,
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 20,
                            child: PlayerName(
                              name: entry.name,
                              style: AppTextStyles.body(
                                14,
                                weight: FontWeight.w900,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          SizedBox(
                            height: 16,
                            child: Text(
                              [
                                if (entry.tag != null)
                                  PlayerTag.format(entry.tag),
                                '${entry.wins} wins',
                              ].join(' · '),
                              style: AppTextStyles.caption(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    height: bar,
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
                    child: bar > 36
                        ? Text(
                            '$rank',
                            style: AppTextStyles.display(28, color: ring),
                          )
                        : null,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
