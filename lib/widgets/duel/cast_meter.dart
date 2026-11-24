import 'package:flutter/material.dart';

import '../../models/game_rules.dart';
import '../../models/spell_info.dart';
import '../../models/spell_prediction.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/extensions.dart';
import '../../utils/gesture_constants.dart';
import '../generic/progress_bar.dart';
import '../generic/spell_orb.dart';

/// Small pill in the corner of your own camera: the recognised spell, its
/// score against MIN_SCORE (the white tick on the bar) and how many frames
/// in a row it has been the same. Kept small so it doesn't cover you.
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

  static const _orb = 26.0;

  @override
  Widget build(BuildContext context) {
    final cast = castSpell;
    final spell = cast ?? prediction.spell;
    final confidence = cast != null ? 1.0 : prediction.confidence;
    final showScore = recognitionAvailable || cast != null;

    final String title;
    if (cast != null) {
      title = '${cast.label.toUpperCase()} ✓';
    } else if (!recognitionAvailable) {
      title = canCast ? 'TIK EEN SPREUK' : 'KLAAR?';
    } else {
      title = spell?.label.toUpperCase() ?? 'GEEN GEBAAR';
    }

    final accent = spell?.color ?? AppColors.textMuted;
    final frames = (holdProgress * GestureConstants.stableFrames).round();
    const total = GestureConstants.stableFrames;

    return Semantics(
      liveRegion: true,
      label: showScore
          ? '$title, ${confidence.percent}, $frames van $total frames'
          : title,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
        decoration: BoxDecoration(
          color: const Color(0xB30A0818),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.borderStrong),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (spell != null)
              SpellOrb(spell: spell, size: _orb, glow: false)
            else
              Container(
                width: _orb,
                height: _orb,
                decoration: const BoxDecoration(
                  color: AppColors.track,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.back_hand_outlined,
                  color: AppColors.textMuted,
                  size: 14,
                ),
              ),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Never wider than this: long titles shrink instead.
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 92),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(title, style: AppTextStyles.display(13)),
                  ),
                ),
                if (showScore) ...[
                  const SizedBox(height: 3),
                  SizedBox(
                    width: 66,
                    child: ProgressBar(
                      value: confidence,
                      height: 4,
                      marker: GestureConstants.minScore,
                      color: accent,
                    ),
                  ),
                ],
              ],
            ),
            if (showScore) ...[
              const SizedBox(width: 8),
              Text(
                confidence.percent,
                style: AppTextStyles.display(
                  12,
                  color: spell == null
                      ? AppColors.textMuted
                      : AppColors.orangeText,
                ),
              ),
              const SizedBox(width: 8),
              _HoldRing(
                progress: cast != null ? 1 : holdProgress,
                label: cast != null ? '$total/$total' : '$frames/$total',
              ),
            ],
          ],
        ),
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
    return SizedBox.square(
      dimension: 26,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              strokeWidth: 3,
              color: AppColors.gold,
              backgroundColor: AppColors.track,
              strokeCap: StrokeCap.butt,
            ),
          ),
          Text(
            label,
            style: AppTextStyles.display(8.5, color: AppColors.goldLight),
          ),
        ],
      ),
    );
  }
}
