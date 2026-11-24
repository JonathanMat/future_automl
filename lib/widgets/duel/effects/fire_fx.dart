import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'fx_core.dart';

/// Fire built from hundreds of small flame sprites: each one rises, grows
/// and cools from white-yellow to orange, red and smoke. They are drawn
/// added on top of each other, so where many overlap the fire turns
/// white-hot, like real flames.
///
/// All sprites of one kind go out in a single `drawAtlas` call, which keeps
/// this cheap on phones.
abstract final class FlameSprites {
  static ui.Image? _flame;
  static ui.Image? _puff;

  /// Soft teardrop flame, white, pointing up. Its hot spot (where it is
  /// placed and turned around) is [flameAnchor].
  static ui.Image get flame => _flame ??= _bakeFlame();

  /// Soft round puff, white: glow and smoke.
  static ui.Image get puff => _puff ??= _bakePuff();

  static const _w = 72.0, _h = 168.0;
  static const flameAnchor = Offset(_w / 2, _h * .78);
  static const puffAnchor = Offset(32, 32);

  static ui.Image _bakeFlame() {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final path = Path()
      ..moveTo(_w / 2, 6)
      ..cubicTo(_w * .62, _h * .32, _w * .98, _h * .62, _w * .86, _h * .84)
      ..arcToPoint(
        const Offset(_w * .14, _h * .84),
        radius: const Radius.circular(_w * .4),
      )
      ..cubicTo(_w * .02, _h * .62, _w * .38, _h * .32, _w / 2, 6)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.radial(
          flameAnchor,
          _h * .66,
          [
            Colors.white,
            Colors.white.withValues(alpha: .8),
            Colors.white.withValues(alpha: .3),
            Colors.white.withValues(alpha: 0),
          ],
          [0, .3, .65, 1],
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    final picture = recorder.endRecording();
    final image = picture.toImageSync(_w.toInt(), _h.toInt());
    picture.dispose();
    return image;
  }

  static ui.Image _bakePuff() {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawCircle(
      puffAnchor,
      32,
      Paint()
        ..shader = ui.Gradient.radial(
          puffAnchor,
          32,
          [
            Colors.white,
            Colors.white.withValues(alpha: .5),
            Colors.white.withValues(alpha: 0),
          ],
          [0, .45, 1],
        ),
    );
    final picture = recorder.endRecording();
    final image = picture.toImageSync(64, 64);
    picture.dispose();
    return image;
  }
}

/// Collects sprites and draws them in one call.
class SpriteBatch {
  SpriteBatch.flames()
    : image = FlameSprites.flame,
      anchor = FlameSprites.flameAnchor;
  SpriteBatch.puffs()
    : image = FlameSprites.puff,
      anchor = FlameSprites.puffAnchor;

  final ui.Image image;
  final Offset anchor;
  final _transforms = <RSTransform>[];
  final _colors = <Color>[];

  bool get isEmpty => _transforms.isEmpty;

  /// [size] is the sprite's width in logical pixels; [rotation] turns its
  /// tip away from straight up (radians, clockwise).
  void add(Offset p, double size, double rotation, Color color) {
    if (size <= .5 || color.a <= .01) return;
    _transforms.add(
      RSTransform.fromComponents(
        rotation: rotation,
        scale: size / image.width,
        anchorX: anchor.dx,
        anchorY: anchor.dy,
        translateX: p.dx,
        translateY: p.dy,
      ),
    );
    _colors.add(color);
  }

  /// [additive]: overlapping sprites brighten each other (fire, glow);
  /// otherwise they stack normally (smoke).
  void draw(Canvas canvas, {bool additive = true}) {
    if (isEmpty) return;
    final src = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    canvas.drawAtlas(
      image,
      _transforms,
      List.filled(_transforms.length, src),
      _colors,
      BlendMode.modulate,
      null,
      Paint()
        ..blendMode = additive ? BlendMode.plus : BlendMode.srcOver
        ..filterQuality = FilterQuality.low,
    );
  }
}

/// Colour of a flame over its life, 0 = just born (white-hot), 1 = gone.
Color fireColor(double f, [double alpha = 1]) {
  const stops = [
    (0.0, Color(0x00FFF6D8)),
    (.06, Color(0xF2FFF0B8)),
    (.25, Color(0xE6FFC04A)),
    (.5, Color(0xBFFF7A22)),
    (.75, Color(0x73D8381A)),
    (1.0, Color(0x007A1408)),
  ];
  final x = clamp01(f);
  for (var i = 1; i < stops.length; i++) {
    final (b, cb) = stops[i];
    final (a, ca) = stops[i - 1];
    if (x <= b) {
      final c = Color.lerp(ca, cb, (x - a) / (b - a))!;
      return alpha == 1 ? c : c.withValues(alpha: c.a * alpha);
    }
  }
  return stops.last.$2;
}

const smokeColor = Color(0xFF2A2024);

/// Flame size over its life: grows quickly, then thins out.
double flameSize(double base, double f) =>
    base * (.55 + .9 * f) * (1 - .55 * f * f);

/// Turn a sprite so its tip points along [velocity] (flames stream away
/// from where they come from).
double tipAngle(Offset velocity) => atan2(velocity.dx, -velocity.dy);

/// One flame that is born at [born] and then drifts.
class FlameBit {
  FlameBit({
    required this.born,
    required this.velocity,
    required this.life,
    required this.size,
    required this.jitter,
    required this.wobble,
  });

  final double born;
  final Offset velocity;
  final double life;
  final double size;

  /// Offset from its origin at birth.
  final Offset jitter;

  /// Phase for the side-to-side flicker.
  final double wobble;

  /// Where it is [age] seconds after birth, from [origin]: flames speed up
  /// as they rise (hot air) and sway a little.
  Offset at(Offset origin, double age) =>
      origin +
      jitter +
      velocity * age +
      Offset(sin(age * 14 + wobble) * 5, -55 * age * age);
}
