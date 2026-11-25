import 'dart:math';

/// One detected hand: its best gesture and where its wrist is.
class HandReading {
  const HandReading({
    required this.label,
    required this.score,
    required this.wristX,
    required this.wristY,
  });

  /// Best gesture label for this hand ("fire", "none"…).
  final String label;

  /// 0–1.
  final double score;

  /// Landmark 0, normalised 0–1.
  final double wristX;
  final double wristY;

  double wristDistanceTo(HandReading other) =>
      sqrt(pow(wristX - other.wristX, 2) + pow(wristY - other.wristY, 2));
}

/// Everything about one analysed frame, also used by the debug overlay.
class GestureFrame {
  const GestureFrame({
    required this.hands,
    required this.rawGesture,
    required this.rawScore,
    required this.stableGesture,
    required this.streak,
    String? candidateGesture,
  }) : candidateGesture = candidateGesture ?? rawGesture;

  static const empty = GestureFrame(
    hands: [],
    rawGesture: 'none',
    rawScore: 0,
    stableGesture: 'none',
    streak: 0,
  );

  final List<HandReading> hands;

  /// Result of `getGesture` for this frame alone.
  final String rawGesture;
  final double rawScore;

  /// The gesture after stabilisation: what the game uses.
  final String stableGesture;

  /// How many frames the gesture being counted ([candidateGesture]) has
  /// been seen, ignoring short blips.
  final int streak;

  /// The gesture being counted towards stable. Can differ from
  /// [rawGesture] for a frame or two when the model loses the hand.
  final String candidateGesture;

  /// Distance between the two wrists, or null with fewer than two hands.
  double? get wristDistance =>
      hands.length >= 2 ? hands[0].wristDistanceTo(hands[1]) : null;
}
