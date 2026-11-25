/// Settings for the face effects (MediaPipe Face Landmarker). Tune them here.
abstract final class FaceConstants {
  /// Google's official Face Landmarker bundle (float16, version 1).
  static const modelAsset = 'assets/models/face_landmarker.task';

  /// Faces found with less confidence are ignored (effects then play on
  /// the whole camera instead). A bit low: while casting, a hand often
  /// covers part of the face.
  static const minConfidence = 0.4;

  /// Turns (clockwise degrees) tried until a face is found: some phones
  /// capture the front camera sideways.
  static const rotationsToTry = [0, 270, 90];

  /// Give up on one search after this long.
  static const timeout = Duration(seconds: 3);

  /// Draw every landmark as a dot in the killcam, to check that the face
  /// effects sit exactly on the face.
  static const debug = false;
}
