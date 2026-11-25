import 'game_rules.dart';
import 'gesture_reading.dart';

/// One output of the gesture model for one camera frame.
class SpellPrediction {
  const SpellPrediction({
    required this.spell,
    required this.confidence,
    this.stability = 0,
    this.frame,
    this.candidate,
  });

  /// The stable spell, or null for "no gesture". With MediaPipe this only
  /// changes after `GestureConstants.stableFrames` identical frames.
  final Spell? spell;

  /// 0.0 – 1.0, score of this frame's gesture.
  final double confidence;

  /// 0–1: how far the current gesture is towards counting as stable.
  final double stability;

  /// Raw details for the debug overlay. Null without a model.
  final GestureFrame? frame;

  /// The gesture being counted towards stable right now, if it is a spell.
  final Spell? candidate;

  /// True when [spell] may be cast.
  bool get isStable => spell != null && stability >= 1;

  static const none = SpellPrediction(spell: null, confidence: 0);
}
