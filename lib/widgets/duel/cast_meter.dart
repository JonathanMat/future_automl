import 'package:flutter/material.dart';

import '../../models/game_rules.dart';
import '../../models/spell_info.dart';
import '../../models/spell_prediction.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/gesture_constants.dart';
import '../../utils/extensions.dart';
import '../generic/progress_bar.dart';
import '../generic/spell_orb.dart';

/// Bottom bar on your own feed: the recognised spell, its confidence
/// against MIN_SCORE and how many frames in a row it has been the same.
class CastMeter extends StatelessWidget {
  const CastMeter({
    super.key,
    required this.prediction,
    required this.holdProgress,
    required this.recognitionAvailable,
    required this.castSpell,
    required this.canCast,
  });

  final SpellPrediction prediction;
  final double holdProgress;
  final bool recognitionAvailable;

  /// The spell you already cast this round, if any.
  final Spell? castSpell;
  final bool canCast;

  static final _thresholdText =
      'Min. ${GestureConstants.minScore.percent} · '
      '${GestureConstants.stableFrames} frames stabiel';

  @override
  Widget build(BuildContext context) {
    final cast = castSpell;
    final spell = cast ?? prediction.spell;
    final confidence = cast != null ? 1.0 : prediction.confidence;

    final String title;
    final String subtitle;
    if (cast != null) {
      title = cast.label.toUpperCase();
      subtitle = 'Gecast!';
    } else if (!recognitionAvailable) {
      title = canCast ? 'TIK EEN SPREUK' : 'KLAAR?';
      subtitle = 'Geen model geladen · tik op een kaart';
    } else if (spell == null) {
      title = 'GEEN GEBAAR';
      subtitle = _thresholdText;
    } else {
      title = spell.label.toUpperCase();
      subtitle = _thresholdText;
    }

    final accent = spell?.color ?? AppColors.textMuted;
    final frames = (holdProgress * GestureConstants.stableFrames).round();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xD90A0818),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: Row(
        children: [
          if (spell != null)
            SpellOrb(spell: spell, size: 42)
          else
            Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                color: AppColors.track,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.back_hand_outlined,
                color: AppColors.textMuted,
                size: 20,
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: AppTextStyles.display(17),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (recognitionAvailable || cast != null)
                      Text(
                        confidence.percent,
                        style: AppTextStyles.display(
                          17,
                          color: spell == null
                              ? AppColors.textMuted
                              : AppColors.orangeText,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                ProgressBar(
                  value: confidence,
                  height: 10,
                  marker: GestureConstants.minScore,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color.lerp(accent, Colors.white, 0.4)!,
                      accent,
                      Color.lerp(accent, Colors.black, 0.15)!,
                    ],
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: AppTextStyles.body(
                    11,
                    weight: FontWeight.w800,
                    color: AppColors.textFeed,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _HoldRing(
            progress: cast != null ? 1 : holdProgress,
            label: cast != null
                ? '${GestureConstants.stableFrames}/${GestureConstants.stableFrames}'
                : '$frames/${GestureConstants.stableFrames}',
          ),
        ],
      ),
    );
  }
}

class _HoldRing extends StatelessWidget {
  const _HoldRing({required this.progress, required this.label});

  final double progress;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label frames hetzelfde gebaar',
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: 46,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.expand(
              child: CircularProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                strokeWidth: 5,
                color: AppColors.gold,
                backgroundColor: AppColors.track,
                strokeCap: StrokeCap.butt,
              ),
            ),
            Text(
              label,
              style: AppTextStyles.display(12, color: AppColors.goldLight),
            ),
          ],
        ),
      ),
    );
  }
}
