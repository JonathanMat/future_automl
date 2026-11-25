import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../models/face_shape.dart';

/// A drawn face with landmarks in the right places, to try the face
/// effects without a camera (effects preview, tests). Real faces come from
/// the MediaPipe Face Landmarker.
abstract final class DemoFace {
  static const width = 600;
  static const height = 800;

  /// Landmarks for the drawn face, in the same layout as MediaPipe's mesh
  /// (only the points the effects use are placed; the rest sit mid-face).
  static FaceShape shape({int turns = 0}) {
    final pts = List<Offset>.filled(478, const Offset(.5, .5));
    void ring(
      List<int> idx,
      Offset c,
      double rx,
      double ry, {
      double from = -pi / 2,
    }) {
      for (var i = 0; i < idx.length; i++) {
        final a = from + i * 2 * pi / idx.length;
        pts[idx[i]] = c + Offset(cos(a) * rx, sin(a) * ry);
      }
    }

    // Face oval, clockwise from the top of the forehead.
    ring(FaceShape.ovalIndices, const Offset(.5, .5), .25, .3);
    // Eyes: A on the left of the photo, B on the right.
    ring(FaceShape.eyeAIndices, const Offset(.4, .45), .05, .022, from: pi);
    ring(FaceShape.eyeBIndices, const Offset(.6, .45), .05, .022, from: 0);
    for (var i = 0; i < 5; i++) {
      pts[FaceShape.irisA + i] = const Offset(.4, .45);
      pts[FaceShape.irisB + i] = const Offset(.6, .45);
    }
    // Brows: a slight arch above each eye.
    for (var i = 0; i < 5; i++) {
      final f = i / 4;
      final arch = .012 * sin(f * pi);
      pts[FaceShape.browAIndices[i]] = Offset(.34 + .12 * f, .395 - arch);
      pts[FaceShape.browBIndices[i]] = Offset(.54 + .12 * f, .395 - arch);
    }
    ring(FaceShape.lipsIndices, const Offset(.5, .665), .075, .03, from: pi);
    pts[FaceShape.cheekA] = const Offset(.37, .57);
    pts[FaceShape.cheekB] = const Offset(.63, .57);
    pts[FaceShape.forehead] = const Offset(.5, .31);
    pts[FaceShape.noseTip] = const Offset(.5, .57);

    // Stored as the camera would hand it over: turned back by [turns].
    final stored = [for (final p in pts) FaceShape.turn(p, (4 - turns) % 4)];
    return FaceShape(
      points: stored,
      imageWidth: turns.isOdd ? height : width,
      imageHeight: turns.isOdd ? width : height,
      turns: turns,
    );
  }

  /// A PNG of the drawn face (upright), like a camera photo.
  static Future<Uint8List> png({
    Color skin = const Color(0xFFE8B48E),
    Color hair = const Color(0xFF3B2416),
    Color shirt = const Color(0xFF7B4DF0),
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = Size(600, 800);
    final face = shape().layout(size);

    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2A3550), Color(0xFF151A2A)],
        ).createShader(Offset.zero & size),
    );
    // Shoulders.
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(300, 860), width: 620, height: 420),
      Paint()..color = shirt,
    );
    // Neck, hair behind, face.
    canvas.drawRect(
      Rect.fromCenter(center: const Offset(300, 690), width: 120, height: 120),
      Paint()..color = Color.lerp(skin, Colors.black, .12)!,
    );
    final b = face.bounds;
    canvas.drawOval(
      Rect.fromLTRB(b.left - 22, b.top - 40, b.right + 22, b.center.dy + 40),
      Paint()..color = hair,
    );
    canvas.drawPath(face.ovalPath, Paint()..color = skin);
    // Fringe.
    canvas.drawArc(
      Rect.fromLTRB(b.left - 6, b.top - 26, b.right + 6, b.top + 110),
      pi,
      pi,
      true,
      Paint()..color = hair,
    );
    for (final eye in [face.eyeA, face.eyeB]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: eye.center,
          width: eye.radius * 3.4,
          height: eye.radius * 1.6,
        ),
        Paint()..color = Colors.white,
      );
      canvas.drawCircle(
        eye.center,
        eye.radius * .62,
        Paint()..color = const Color(0xFF4A3020),
      );
      canvas.drawCircle(
        eye.center,
        eye.radius * .3,
        Paint()..color = Colors.black,
      );
    }
    final brow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..color = hair;
    for (final pts in [face.browA, face.browB]) {
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (final p in pts.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, brow);
    }
    canvas.drawLine(
      face.noseTip - const Offset(0, 70),
      face.noseTip,
      Paint()
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..color = Color.lerp(skin, Colors.black, .25)!,
    );
    canvas.drawPath(face.lipsPath, Paint()..color = const Color(0xFFC8505A));

    final image = await recorder.endRecording().toImage(600, 800);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  }
}
