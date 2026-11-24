import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';

import '../../models/gesture_reading.dart';
import '../../models/spell_prediction.dart';
import '../../utils/gesture_constants.dart';
import 'gesture_logic.dart';
import 'spell_recognizer.dart';

/// Recognises spells with the trained MediaPipe Gesture Recognizer
/// (`assets/models/gesture_recognizer.task`, labels fire, ice, lightning,
/// shield, none).
///
/// Runs with two hands in VIDEO mode. Each frame goes through [getGesture]
/// (two close wrists = shield) and a [GestureStabilizer], so the game only
/// sees a spell after it was the same for several frames.
class MediaPipeSpellRecognizer implements SpellRecognizer {
  MediaPipeSpellRecognizer({this.modelAsset = GestureConstants.modelAsset});

  final String modelAsset;

  GestureRecognizer? _recognizer;
  bool _failed = false;
  final _stabilizer = GestureStabilizer();
  final _clock = Stopwatch();
  int _lastTimestamp = -1;

  @override
  bool get isAvailable => _recognizer != null && !_failed;

  @override
  Future<void> load() async {
    if (_recognizer != null) return;
    try {
      final asset = await rootBundle.load(modelAsset);
      _recognizer = await GestureRecognizer.create(
        GestureRecognizerOptions(
          modelBytes: asset.buffer.asUint8List(
            asset.offsetInBytes,
            asset.lengthInBytes,
          ),
          numHands: GestureConstants.numHands,
          runningMode: RunningMode.video,
        ),
      );
      _clock.start();
    } catch (e) {
      // No model or no native runtime: the game falls back to tapping.
      _failed = true;
      debugPrint('MediaPipe gesture recognizer unavailable: $e');
    }
  }

  @override
  Future<SpellPrediction> predict(Uint8List pngFrame) async {
    final recognizer = _recognizer;
    if (recognizer == null) return SpellPrediction.none;

    final image = await _decode(pngFrame);
    // VIDEO mode needs strictly increasing timestamps.
    var timestamp = _clock.elapsedMilliseconds;
    if (timestamp <= _lastTimestamp) timestamp = _lastTimestamp + 1;
    _lastTimestamp = timestamp;

    final result = await recognizer.recognizeForVideo(
      image,
      timestampMilliseconds: timestamp,
    );
    return _toPrediction(result);
  }

  SpellPrediction _toPrediction(GestureRecognizerResult result) {
    final hands = <HandReading>[
      for (var i = 0; i < result.handLandmarks.length; i++)
        if (result.handLandmarks[i].isNotEmpty)
          HandReading(
            label: _topLabel(result, i),
            score: _topScore(result, i),
            wristX: result.handLandmarks[i][0].x,
            wristY: result.handLandmarks[i][0].y,
          ),
    ];

    final raw = getGesture(hands);
    final stable = _stabilizer.add(raw.label);
    final streak = _stabilizer.streak;
    final frame = GestureFrame(
      hands: hands,
      rawGesture: raw.label,
      rawScore: raw.score,
      stableGesture: stable,
      streak: streak,
    );

    final spell = spellForLabel(stable);
    // Progress of the gesture you are making now towards being stable.
    final stability = raw.label == stable && spell != null
        ? 1.0
        : (streak / GestureConstants.stableFrames).clamp(0.0, 1.0);
    return SpellPrediction(
      spell: spell,
      confidence: raw.score,
      stability: stability,
      frame: frame,
    );
  }

  String _topLabel(GestureRecognizerResult r, int hand) {
    if (hand >= r.gestures.length || r.gestures[hand].isEmpty) {
      return GestureConstants.none;
    }
    return r.gestures[hand].first.categoryName ?? GestureConstants.none;
  }

  double _topScore(GestureRecognizerResult r, int hand) {
    if (hand >= r.gestures.length || r.gestures[hand].isEmpty) return 0;
    return r.gestures[hand].first.score;
  }

  /// PNG bytes (from `captureLocalFrame`) → RGBA pixels.
  Future<VisionImage> _decode(Uint8List png) async {
    final codec = await ui.instantiateImageCodec(png);
    final frame = await codec.getNextFrame();
    final img = frame.image;
    try {
      final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      return VisionImage.fromPixels(
        pixels: data!.buffer.asUint8List(),
        width: img.width,
        height: img.height,
        format: VisionPixelFormat.rgba,
      );
    } finally {
      img.dispose();
      codec.dispose();
    }
  }

  @override
  void reset() => _stabilizer.reset();

  @override
  Future<void> dispose() async {
    await _recognizer?.dispose();
    _recognizer = null;
  }
}
