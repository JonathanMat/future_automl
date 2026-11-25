/// Settings for the MediaPipe gesture recognition. Tune them here.
abstract final class GestureConstants {
  /// Max distance between the two wrists (landmark 0 of each hand), in
  /// normalised image coordinates (0–1), for two hands to count as
  /// "shield". Both hands must also make a real gesture (not "none"), so
  /// a hand hanging in view doesn't turn into shield. The debug overlay
  /// shows the live distance.
  ///
  /// Measured on 200 dataset photos per class: 0.25 found shield 69% and
  /// turned 12 "none" photos into shield; two active hands within 0.6
  /// found 79% with none wrong.
  static const shieldDistance = 0.6; // SHIELD_DISTANCE

  /// Hand gestures with a lower score are ignored.
  static const minScore = 0.6; // MIN_SCORE

  /// A gesture only counts after this many identical frames in a row.
  static const stableFrames = 5; // STABLE_FRAMES

  /// Frames the model may lose the gesture (or see another one) without
  /// the count starting over. Stops one bad frame from blocking a cast.
  static const maxMissedFrames = 2;

  /// In the last moments of the cast window, the gesture you are making is
  /// cast even if it isn't fully stable yet, so you don't end with nothing.
  static const lastChance = Duration(milliseconds: 350);

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
