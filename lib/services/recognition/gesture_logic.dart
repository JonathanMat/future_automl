import '../../models/game_rules.dart';
import '../../models/gesture_reading.dart';
import '../../utils/gesture_constants.dart';

/// Decides the gesture of one frame.
///
/// MediaPipe classifies each hand on its own, so "shield" (two hands) comes
/// out as two separate gestures, often "fire" twice. Two hands that both
/// make a real gesture (not "none", at least [minScore]) with their wrists
/// closer than [shieldDistance] therefore count as shield. Otherwise the
/// best real gesture of all hands wins, ignoring scores below [minScore]
/// and idle ("none") hands; nothing left is "none".
({String label, double score}) getGesture(
  List<HandReading> hands, {
  double shieldDistance = GestureConstants.shieldDistance,
  double minScore = GestureConstants.minScore,
}) {
  bool active(HandReading h) =>
      h.label != GestureConstants.none && h.score >= minScore;
  if (hands.length == 2 &&
      active(hands[0]) &&
      active(hands[1]) &&
      hands[0].wristDistanceTo(hands[1]) < shieldDistance) {
    final score = (hands[0].score + hands[1].score) / 2;
    return (label: GestureConstants.shield, score: score);
  }

  // A hand making a real gesture beats a hand doing nothing, even when
  // the model is surer about the idle one ("none" 95% vs "fire" 90%).
  HandReading? best;
  for (final hand in hands) {
    if (!active(hand)) continue;
    if (best == null || hand.score > best.score) best = hand;
  }
  if (best == null) return (label: GestureConstants.none, score: 0);
  return (label: best.label, score: best.score);
}

/// Stops flickering: a gesture only counts after [stableFrames] identical
/// frames. Until then the previous stable gesture stays.
///
/// Up to [maxMisses] frames in a row may disagree (the model loses the hand
/// for a moment) without the count starting over; those frames are
/// ignored.
class GestureStabilizer {
  GestureStabilizer({
    this.stableFrames = GestureConstants.stableFrames,
    this.maxMisses = GestureConstants.maxMissedFrames,
  });

  final int stableFrames;
  final int maxMisses;

  String _candidate = GestureConstants.none;
  int _streak = 0;
  int _misses = 0;
  String _stable = GestureConstants.none;

  String get stable => _stable;

  /// The gesture being counted (may not be stable yet).
  String get candidate => _candidate;
  int get streak => _streak;

  /// Adds one frame's gesture and returns the stable gesture.
  String add(String gesture) {
    if (gesture == _candidate) {
      _streak++;
      _misses = 0;
    } else if (_candidate != GestureConstants.none && _misses < maxMisses) {
      // A blip: ignore it and keep counting the gesture we had.
      _misses++;
    } else {
      _candidate = gesture;
      _streak = 1;
      _misses = 0;
    }
    if (_streak >= stableFrames) _stable = _candidate;
    return _stable;
  }

  void reset() {
    _candidate = GestureConstants.none;
    _streak = 0;
    _misses = 0;
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
