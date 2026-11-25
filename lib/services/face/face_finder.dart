import 'dart:typed_data';

import '../../models/face_shape.dart';

/// Finds a face in a photo, for the face effects in the killcam.
abstract class FaceFinder {
  /// The one the app uses; [NoFaceFinder] until `main` sets the MediaPipe
  /// one (tests, previews and phones without a camera keep this).
  static FaceFinder current = const NoFaceFinder();

  /// Loads the model ahead of time, so the first search is quick. Safe to
  /// call more than once.
  Future<void> warmUp();

  /// The most prominent face in [encodedImage] (PNG or JPEG), or null when
  /// there is none or anything goes wrong. Never throws.
  Future<FaceShape?> find(Uint8List encodedImage);
}

/// Never finds a face: effects then play on the whole camera, as before.
class NoFaceFinder implements FaceFinder {
  const NoFaceFinder();

  @override
  Future<void> warmUp() async {}

  @override
  Future<FaceShape?> find(Uint8List encodedImage) async => null;
}
