import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// Tilted crown badge with "GEWONNEN!" or "VERLOREN".
class ResultHero extends StatelessWidget {
  const ResultHero({
    super.key,
    required this.won,
    required this.opponentName,
    required this.rounds,
    this.offerRematch = true,
  });

  final bool won;
  final String opponentName;
  final int rounds;

  /// False in a tournament: there is no rematch.
  final bool offerRematch;

  @override
  Widget build(BuildContext context) {
    final colors = won
        ? const [AppColors.goldNumber, AppColors.gold, Color(0xFFB86E00)]
        : const [Color(0xFFDCD5FF), Color(0xFF8B7CFF), Color(0xFF4A3BC2)];
    final titleColor = won ? AppColors.gold : AppColors.lavender;
    return Column(
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.6, end: 1),
          duration: const Duration(milliseconds: 600),
          curve: Curves.elasticOut,
          builder: (context, scale, child) =>
              Transform.scale(scale: scale, child: child),
          child: Transform.rotate(
            angle: -0.105,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(36),
                gradient: RadialGradient(
                  center: const Alignment(-0.3, -0.5),
                  radius: 0.95,
                  colors: colors,
                  stops: const [0, 0.5, 1],
                ),
                boxShadow: [
                  BoxShadow(
                    color: colors[1].withValues(alpha: 0.12),
                    spreadRadius: 8,
                  ),
                  BoxShadow(
                    color: colors[1].withValues(alpha: 0.35),
                    blurRadius: 50,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: Icon(
                won ? Icons.emoji_events_rounded : Icons.replay_rounded,
                size: 62,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Semantics(
          header: true,
          child: Text(
            won ? 'GEWONNEN!' : 'VERLOREN',
            style: AppTextStyles.display(52, color: titleColor).copyWith(
              height: 1,
              shadows: [
                Shadow(
                  color: won
                      ? AppColors.goldTitleShadow
                      : AppColors.purpleShadow,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          won
              ? 'Je versloeg $opponentName in $rounds ${rounds == 1 ? 'ronde' : 'rondes'}.'
              : '$opponentName won na $rounds ${rounds == 1 ? 'ronde' : 'rondes'}.${offerRematch ? ' Revanche?' : ''}',
          textAlign: TextAlign.center,
          style: AppTextStyles.body(
            15,
            weight: FontWeight.w700,
            color: AppColors.textSoft,
          ),
        ),
      ],
    );
  }
}
