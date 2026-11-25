import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';

import '../../models/face_shape.dart';
import '../../utils/face_constants.dart';
import 'face_finder.dart';

/// Google's MediaPipe Face Landmarker (`assets/models/face_landmarker.task`,
/// the official float16 bundle): 478 landmarks for one face, in IMAGE mode.
///
/// Some phones capture the camera sideways, so when no face is found the
/// photo is also tried turned a quarter each way, and [FaceShape.turns]
/// (read from the face: chin to forehead) says how to show it upright.
class MediaPipeFaceFinder implements FaceFinder {
  MediaPipeFaceFinder({this.modelAsset = FaceConstants.modelAsset});

  final String modelAsset;

  FaceLandmarker? _task;
  Future<void>? _loading;

  @override
  Future<void> warmUp() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final asset = await rootBundle.load(modelAsset);
      _task = await FaceLandmarker.create(
        FaceLandmarkerOptions(
          modelBytes: asset.buffer.asUint8List(
            asset.offsetInBytes,
            asset.lengthInBytes,
          ),
          runningMode: RunningMode.image,
          numFaces: 1,
          minFaceDetectionConfidence: FaceConstants.minConfidence,
          minFacePresenceConfidence: FaceConstants.minConfidence,
        ),
      );
    } catch (e) {
      // No model or no native runtime: effects play without a face.
      debugPrint('MediaPipe face landmarker unavailable: $e');
    }
  }

  @override
  Future<FaceShape?> find(Uint8List encodedImage) async {
    try {
      await warmUp();
      final task = _task;
      if (task == null) return null;
      final decoded = await _decode(encodedImage);
      if (decoded == null) return null;
      for (final degrees in FaceConstants.rotationsToTry) {
        final result = await task
            .detect(decoded.image, rotationDegrees: degrees)
            .timeout(FaceConstants.timeout);
        if (result.faceLandmarks.isEmpty) continue;
        final landmarks = result.faceLandmarks.first;
        if (landmarks.length < FaceShape.minPoints) continue;
        final points = [for (final l in landmarks) ui.Offset(l.x, l.y)];
        return FaceShape(
          points: points,
          imageWidth: decoded.width,
          imageHeight: decoded.height,
          // From the face itself: the model often finds a sideways face
          // without turning, but the killcam must still show it upright.
          turns: FaceShape.uprightTurns(points, decoded.width, decoded.height),
        );
      }
      return null;
    } catch (e) {
      debugPrint('face search failed: $e');
      return null;
    }
  }

  static Future<({VisionImage image, int width, int height})?> _decode(
    Uint8List bytes,
  ) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final img = frame.image;
    try {
      final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null) return null;
      return (
        image: VisionImage.fromPixels(
          pixels: data.buffer.asUint8List(),
          width: img.width,
          height: img.height,
          format: VisionPixelFormat.rgba,
        ),
        width: img.width,
        height: img.height,
      );
    } finally {
      img.dispose();
      codec.dispose();
    }
  }
}
