import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/player_tag.dart';
import '../generic/avatar_tile.dart';
import '../generic/player_name.dart';

/// One ranked player: "4 · L · Lotte · 11W · 6V · 65%".
class LeaderboardRow extends StatelessWidget {
  const LeaderboardRow({
    super.key,
    required this.rank,
    required this.name,
    this.tag,
    required this.wins,
    required this.losses,
    this.isMe = false,
    this.onTap,
  });

  final int rank;
  final String name;
  final String? tag;
  final int wins;
  final int losses;
  final bool isMe;

  /// Opens the player's profile.
  final VoidCallback? onTap;

  int get _rate {
    final games = wins + losses;
    return games == 0 ? 0 : (wins * 100 / games).round();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          'Plaats $rank: ${PlayerTag.withName(name, tag)}'
          '${isMe ? ' (jij)' : ''}, '
          '$wins gewonnen, $losses verloren, $_rate procent',
      excludeSemantics: true,
      button: onTap != null,
      onTap: onTap,
      child: Material(
        color: isMe
            ? AppColors.purple.withValues(alpha: 0.16)
            : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isMe
                ? AppColors.violet.withValues(alpha: 0.6)
                : const Color(0x0AFFFFFF),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: 54,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Text(
                    '$rank',
                    style: AppTextStyles.display(
                      16,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                AvatarTile(name: name, size: 34),
                const SizedBox(width: 12),
                Expanded(
                  child: PlayerName(
                    name: name,
                    tag: tag,
                    suffix: isMe ? ' (jij)' : '',
                    style: AppTextStyles.body(15, weight: FontWeight.w900),
                  ),
                ),
                Text('${wins}W · ${losses}V', style: AppTextStyles.caption()),
                SizedBox(
                  width: 50,
                  child: Text(
                    '$_rate%',
                    textAlign: TextAlign.right,
                    style: AppTextStyles.display(16, color: AppColors.gold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
