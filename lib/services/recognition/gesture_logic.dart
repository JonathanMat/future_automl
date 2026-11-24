import '../../models/game_rules.dart';
import '../../models/gesture_reading.dart';
import '../../utils/gesture_constants.dart';

/// Decides the gesture of one frame.
///
/// MediaPipe classifies each hand on its own, so "shield" (two hands) would
/// come out as two separate gestures. Two hands whose wrists are closer than
/// [shieldDistance] therefore count as shield. Otherwise the best label of
/// all hands wins, ignoring scores below [minScore]; nothing left is "none".
({String label, double score}) getGesture(
  List<HandReading> hands, {
  double shieldDistance = GestureConstants.shieldDistance,
  double minScore = GestureConstants.minScore,
}) {
  if (hands.length == 2 &&
      hands[0].wristDistanceTo(hands[1]) < shieldDistance) {
    final score = (hands[0].score + hands[1].score) / 2;
    return (label: GestureConstants.shield, score: score);
  }

  HandReading? best;
  for (final hand in hands) {
    if (hand.score < minScore) continue;
    if (best == null || hand.score > best.score) best = hand;
  }
  if (best == null) return (label: GestureConstants.none, score: 0);
  return (label: best.label, score: best.score);
}

/// Stops flickering: a gesture only counts after [stableFrames] identical
/// frames in a row. Until then the previous stable gesture stays.
class GestureStabilizer {
  GestureStabilizer({this.stableFrames = GestureConstants.stableFrames});

  final int stableFrames;

  String _candidate = GestureConstants.none;
  int _streak = 0;
  String _stable = GestureConstants.none;

  String get stable => _stable;
  int get streak => _streak;

  /// Adds one frame's gesture and returns the stable gesture.
  String add(String gesture) {
    if (gesture == _candidate) {
      _streak++;
    } else {
      _candidate = gesture;
      _streak = 1;
    }
    if (_streak >= stableFrames) _stable = _candidate;
    return _stable;
  }

  void reset() {
    _candidate = GestureConstants.none;
    _streak = 0;
    _stable = GestureConstants.none;
  }
}

/// Model label → spell. "none" and unknown labels give null.
Spell? spellForLabel(String label) => switch (label) {
  GestureConstants.fire => Spell.vuur,
  GestureConstants.ice => Spell.ijs,
  GestureConstants.lightning => Spell.bliksem,
  GestureConstants.shield => Spell.schild,
  _ => null,
};
