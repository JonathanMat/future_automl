/// Settings for the MediaPipe gesture recognition. Tune them here.
abstract final class GestureConstants {
  /// Max distance between the two wrists (landmark 0 of each hand), in
  /// normalised image coordinates (0–1), for two hands to count as
  /// "shield". Raise it if shield is missed, lower it if two separate hands
  /// turn into shield. The debug overlay shows the live distance.
  static const shieldDistance = 0.25; // SHIELD_DISTANCE

  /// Hand gestures with a lower score are ignored.
  static const minScore = 0.6; // MIN_SCORE

  /// A gesture only counts after this many identical frames in a row.
  static const stableFrames = 5; // STABLE_FRAMES

  /// Show the debug overlay (hands, label + score per hand, wrist distance,
  /// final gesture) on your own camera during the duel.
  static const debug = false; // DEBUG

  /// How many hands MediaPipe looks for.
  static const numHands = 2;

  /// The model, bundled as a Flutter asset.
  static const modelAsset = 'assets/models/gesture_recognizer.task';

  // Labels of the trained model.
  static const fire = 'fire';
  static const ice = 'ice';
  static const lightning = 'lightning';
  static const shield = 'shield';
  static const none = 'none';
}
