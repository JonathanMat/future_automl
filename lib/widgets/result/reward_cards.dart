import 'package:flutter/material.dart';

import '../../models/player_profile.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/constants.dart';
import '../generic/progress_bar.dart';

/// "+120 XP" with the level bar, and the win streak: "🔥 3 OP RIJ" after
/// a win, "Reeks verbroken" after a loss that ended one.
class RewardCards extends StatelessWidget {
  const RewardCards({
    super.key,
    required this.profile,
    required this.xpGained,
    required this.won,
    this.brokenStreak = 0,
  });

  /// The profile after this game was recorded.
  final PlayerProfile profile;
  final int xpGained;
  final bool won;

  /// After a loss: the streak it ended (0 when there was none).
  final int brokenStreak;

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
            child: _StreakCard(
              won: won,
              streak: profile.streak,
              best: profile.stats.bestStreak,
              broken: brokenStreak,
            ),
          ),
        ],
      ),
    );
  }
}

/// The win streak after this duel.
class _StreakCard extends StatelessWidget {
  const _StreakCard({
    required this.won,
    required this.streak,
    required this.best,
    required this.broken,
  });

  final bool won;
  final int streak;
  final int best;
  final int broken;

  /// From here on the flame glows.
  static const _long = 3;

  @override
  Widget build(BuildContext context) {
    final String title;
    final String line;
    final String? note;
    if (won) {
      title = '$streak OP RIJ';
      line = switch (streak) {
        1 => 'Nieuwe reeks gestart',
        >= 5 => 'In vuur en vlam!',
        >= _long => 'Lange reeks!',
        _ => 'Zo doorgaan!',
      };
      note = streak > 1 && streak >= best
          ? 'Je beste reeks ooit'
          : best > 1
          ? 'Beste: $best op rij'
          : null;
    } else if (broken > 1) {
      title = 'REEKS VERBROKEN';
      line = 'Je reeks van $broken op rij is voorbij';
      note = best > 1 ? 'Beste: $best op rij' : null;
    } else {
      title = 'GEEN REEKS';
      line = 'Win het volgende duel om een reeks te starten';
      note = best > 1 ? 'Beste: $best op rij' : null;
    }
    final hot = won && streak >= _long;
    final color = won ? AppColors.orangeText : AppColors.redSoft;

    return Semantics(
      label: won
          ? 'Reeks: $streak op rij. $line'
          : broken > 1
          ? 'Reeks verbroken: $broken op rij is voorbij'
          : 'Geen reeks. $line',
      excludeSemantics: true,
      child: _Card(
        borderColor: color.withValues(alpha: hot ? 0.7 : 0.35),
        glow: hot ? AppColors.orangeText : null,
        children: [
          Row(
            children: [
              Icon(
                won
                    ? Icons.local_fire_department_rounded
                    : Icons.local_fire_department_outlined,
                size: hot ? 30 : 26,
                color: won ? color : AppColors.textMuted,
                shadows: hot
                    ? const [Shadow(color: AppColors.gold, blurRadius: 14)]
                    : null,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    maxLines: 1,
                    style: AppTextStyles.display(26, color: color),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(line, style: AppTextStyles.body(13, color: AppColors.textSoft)),
          if (note != null) ...[
            const SizedBox(height: 2),
            Text(note, style: AppTextStyles.caption()),
          ],
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.borderColor, required this.children, this.glow});

  final Color borderColor;
  final List<Widget> children;

  /// A soft glow around the card, e.g. for a long streak.
  final Color? glow;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          if (glow != null)
            BoxShadow(color: glow!.withValues(alpha: 0.25), blurRadius: 18),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}
