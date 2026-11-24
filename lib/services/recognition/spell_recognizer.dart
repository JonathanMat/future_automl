import 'dart:typed_data';

import '../../models/spell_prediction.dart';

/// Turns a camera frame into a [SpellPrediction].
///
/// The Teachable Machine model plugs in here: implement this class with
/// TensorFlow Lite (e.g. `tflite_flutter`), load the `.tflite` file and
/// labels from `assets/` in [load], and run one PNG frame per [predict].
/// Frames come from `GameBackend.captureLocalFrame()`, never from the
/// `camera` plugin (the video call owns the camera).
abstract class SpellRecognizer {
  /// False when no model is available. The duel screen then lets the
  /// player tap a spell instead.
  bool get isAvailable;

  Future<void> load();

  Future<SpellPrediction> predict(Uint8List pngFrame);

  /// Forget earlier frames, at the start of every round.
  void reset();

  Future<void> dispose();
}

/// Used until the trained model is added. Never predicts anything, so the
/// player casts by tapping a spell card.
class ManualSpellRecognizer implements SpellRecognizer {
  const ManualSpellRecognizer();

  @override
  bool get isAvailable => false;

  @override
  Future<void> load() async {}

  @override
  Future<SpellPrediction> predict(Uint8List pngFrame) async =>
      SpellPrediction.none;

  @override
  void reset() {}

  @override
  Future<void> dispose() async {}
}
