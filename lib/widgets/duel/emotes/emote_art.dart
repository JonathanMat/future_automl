import 'dart:math';

import 'package:flutter/material.dart';

import '../../../models/emote.dart';

/// An emote, drawn in the same glossy "orb" style as the spells: a round
/// face (or badge) with a darker 3D edge underneath and a highlight.
class EmoteIcon extends StatelessWidget {
  const EmoteIcon({super.key, required this.emote, this.size = 56});

  final Emote emote;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: emote.label,
    excludeSemantics: true,
    // Drawn once and reused: the pop-in animation moves, scales and fades
    // this every frame, which would otherwise repaint all the paths.
    child: RepaintBoundary(
      child: CustomPaint(
        size: Size.square(size),
        painter: EmotePainter(emote),
        // Many paths and a blur: worth keeping as a rasterised image too.
        isComplex: true,
      ),
    ),
  );
}

/// Paints [emote] in a 100 × 100 grid, scaled to the canvas.
class EmotePainter extends CustomPainter {
  const EmotePainter(this.emote);

  final Emote emote;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..scale(size.width / 100, size.height / 100);
    final style = _styles[emote]!;
    _paintOrb(canvas, style);
    switch (emote) {
      case Emote.hallo:
        _hallo(canvas, style.ink);
      case Emote.haha:
        _haha(canvas, style.ink);
      case Emote.boos:
        _boos(canvas, style.ink);
      case Emote.huilen:
        _huilen(canvas, style.ink);
      case Emote.gg:
        _gg(canvas, style.ink);
      case Emote.goedGespeeld:
        _thumbsUp(canvas, style.ink);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(EmotePainter old) => old.emote != emote;
}

// ---------------------------------------------------------------------------
// Palette
// ---------------------------------------------------------------------------

class _OrbStyle {
  const _OrbStyle(this.light, this.mid, this.dark, this.ink);

  final Color light, mid, dark;

  /// Colour of the features (eyes, mouth, outlines).
  final Color ink;
}

const _gold = _OrbStyle(
  Color(0xFFFFF0B0),
  Color(0xFFFFC93C),
  Color(0xFFD98A00),
  Color(0xFF3D2200),
);

const _styles = <Emote, _OrbStyle>{
  Emote.hallo: _gold,
  Emote.haha: _gold,
  Emote.huilen: _gold,
  Emote.boos: _OrbStyle(
    Color(0xFFFFB3A0),
    Color(0xFFF2513F),
    Color(0xFFA8182A),
    Color(0xFF4A0712),
  ),
  // Same colours as the shield orb.
  Emote.gg: _OrbStyle(
    Color(0xFFDCD5FF),
    Color(0xFF8B7CFF),
    Color(0xFF4A3BC2),
    Color(0xFF231A6B),
  ),
  Emote.goedGespeeld: _OrbStyle(
    Color(0xFFB8F5D8),
    Color(0xFF3DDC97),
    Color(0xFF1E8F5E),
    Color(0xFF0A4A2E),
  ),
};

const _white = Color(0xFFFFFFFF);
const _blush = Color(0xFFFF6F8E);
const _tearLight = Color(0xFFBDEBFF);
const _tear = Color(0xFF4FC3F7);
const _tearDark = Color(0xFF1769AA);
const _tongue = Color(0xFFFF6F7F);
const _sparkle = Color(0xFFFFE07A);

// ---------------------------------------------------------------------------
// Shared pieces
// ---------------------------------------------------------------------------

const _center = Offset(50, 48);
const _radius = 42.0;

void _paintOrb(Canvas canvas, _OrbStyle s) {
  // Soft shadow, then the darker "3D" edge, then the face. The shadow
  // stays inside the 100 × 100 box: anything outside gets cut off with a
  // hard edge when the emote fades (opacity layers clip to the widget).
  canvas.drawCircle(
    const Offset(50, 54),
    _radius - 1,
    Paint()
      ..color = const Color(0x59000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
  );
  canvas.drawCircle(const Offset(50, 52), _radius, Paint()..color = s.dark);
  canvas.drawCircle(
    _center,
    _radius,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.44),
        radius: 0.95,
        colors: [s.light, s.mid, Color.lerp(s.mid, s.dark, .55)!],
        stops: const [0, 0.5, 1],
      ).createShader(Rect.fromCircle(center: _center, radius: _radius)),
  );
  // Gloss in the top-left.
  canvas
    ..save()
    ..translate(34, 24)
    ..rotate(-0.5)
    ..drawOval(
      Rect.fromCenter(center: Offset.zero, width: 26, height: 12),
      Paint()..color = _white.withValues(alpha: .45),
    )
    ..restore();
}

Paint _stroke(Color c, double w) => Paint()
  ..color = c
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

Paint _fill(Color c) => Paint()..color = c;

/// Round eye with a white glint.
void _eye(Canvas canvas, Offset c, Color ink, {double w = 8, double h = 11}) {
  canvas.drawOval(Rect.fromCenter(center: c, width: w, height: h), _fill(ink));
  canvas.drawCircle(c + Offset(-w * .18, -h * .2), w * .2, _fill(_white));
}

void _cheeks(Canvas canvas, {double y = 60, double alpha = .35}) {
  for (final x in [25.0, 75.0]) {
    canvas.drawOval(
      Rect.fromCenter(center: Offset(x, y), width: 13, height: 7),
      Paint()
        ..color = _blush.withValues(alpha: alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );
  }
}

/// A teardrop pointing up, tip at [tip].
Path _drop(Offset tip, double size) {
  final r = size * .42;
  final c = tip + Offset(0, size - r);
  return Path()
    ..moveTo(tip.dx, tip.dy)
    ..quadraticBezierTo(c.dx + r * 1.1, c.dy - r * .2, c.dx + r, c.dy)
    ..arcTo(Rect.fromCircle(center: c, radius: r), 0, pi, false)
    ..quadraticBezierTo(c.dx - r * 1.1, c.dy - r * .2, tip.dx, tip.dy)
    ..close();
}

void _tearDrop(Canvas canvas, Offset tip, double size, double angle) {
  canvas
    ..save()
    ..translate(tip.dx, tip.dy)
    ..rotate(angle);
  final p = _drop(Offset.zero, size);
  canvas
    ..drawPath(p, _fill(_tear))
    ..drawPath(p, _stroke(_tearDark, 1.6))
    ..drawCircle(Offset(-size * .1, size * .62), size * .12, _fill(_white))
    ..restore();
}

/// Four-pointed twinkle.
void _twinkle(Canvas canvas, Offset c, double r, {Color color = _sparkle}) {
  final p = Path()..moveTo(c.dx, c.dy - r);
  for (var i = 1; i <= 4; i++) {
    final a = -pi / 2 + i * pi / 2;
    final mid = a - pi / 4;
    p.quadraticBezierTo(
      c.dx + cos(mid) * r * .18,
      c.dy + sin(mid) * r * .18,
      c.dx + cos(a) * r,
      c.dy + sin(a) * r,
    );
  }
  p.close();
  canvas
    ..drawPath(p, _fill(color))
    ..drawPath(p, _stroke(const Color(0x66000000), .8));
}

// ---------------------------------------------------------------------------
// Faces
// ---------------------------------------------------------------------------

void _hallo(Canvas canvas, Color ink) {
  _eye(canvas, const Offset(34, 41), ink);
  _eye(canvas, const Offset(57, 41), ink);
  _cheeks(canvas, y: 55);
  canvas.drawPath(
    Path()
      ..moveTo(29, 56)
      ..quadraticBezierTo(45, 72, 61, 56),
    _stroke(ink, 4.5),
  );

  // Waving hand, bottom right, tilted, with motion lines.
  canvas
    ..save()
    ..translate(80, 70)
    ..rotate(.32)
    ..scale(1.15);
  final hand = _handPath();
  canvas
    ..drawPath(hand.shift(const Offset(0, 2)), _fill(const Color(0xFFD98A00)))
    ..drawPath(
      hand,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF0B0), Color(0xFFFFC93C)],
        ).createShader(const Rect.fromLTWH(-14, -26, 28, 40)),
    )
    ..drawPath(hand, _stroke(ink, 2.2))
    // Palm crease.
    ..drawArc(
      const Rect.fromLTRB(-6, -2, 6, 8),
      .3,
      pi - .6,
      false,
      _stroke(ink, 1.4),
    );
  // Light, so they show on the face and on a dark background.
  final wave = _stroke(const Color(0xFFFFE9A8), 2.4);
  for (final r in [21.0, 27.0]) {
    canvas.drawArc(
      Rect.fromCircle(center: const Offset(0, -4), radius: r),
      -pi / 2 + .25,
      .75,
      false,
      wave,
    );
  }
  canvas.restore();
}

/// An open hand, palm towards you, fingers up. Origin = palm centre.
Path _handPath() {
  Path finger(double x, double top, double angle) {
    final r = RRect.fromRectAndRadius(
      Rect.fromLTRB(x - 3.4, top, x + 3.4, 2),
      const Radius.circular(3.4),
    );
    final p = Path()..addRRect(r);
    return p.transform((Matrix4.identity()..rotateZ(angle)).storage);
  }

  var hand = Path()
    ..addRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTRB(-11, -8, 11, 13),
        const Radius.circular(8),
      ),
    );
  for (final f in [
    finger(-7.4, -21, -.12),
    finger(-2.4, -25, -.04),
    finger(2.6, -24, .04),
    finger(7.4, -19, .13),
  ]) {
    hand = Path.combine(PathOperation.union, hand, f);
  }
  // Thumb, sticking out to the left.
  final thumb = Path()
    ..addRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTRB(-4, -3.4, 13, 3.4),
        const Radius.circular(3.4),
      ),
    );
  final placed = thumb.transform(
    (Matrix4.identity()
          ..translateByDouble(-9, 6, 0, 1)
          ..rotateZ(pi + .75))
        .storage,
  );
  return Path.combine(PathOperation.union, hand, placed);
}

void _haha(Canvas canvas, Color ink) {
  // Squeezed-shut eyes: > <
  final eye = _stroke(ink, 4.6);
  canvas
    ..drawPath(
      Path()
        ..moveTo(29, 34)
        ..lineTo(40, 41)
        ..lineTo(29, 47),
      eye,
    )
    ..drawPath(
      Path()
        ..moveTo(71, 34)
        ..lineTo(60, 41)
        ..lineTo(71, 47),
      eye,
    );
  _cheeks(canvas, y: 55, alpha: .45);

  // Wide open "D" mouth with teeth and tongue.
  final mouth = Path()
    ..moveTo(28, 55)
    ..lineTo(72, 55)
    ..quadraticBezierTo(72, 82, 50, 83)
    ..quadraticBezierTo(28, 82, 28, 55)
    ..close();
  canvas
    ..drawPath(mouth, _fill(ink))
    ..save()
    ..clipPath(mouth)
    ..drawRect(const Rect.fromLTRB(28, 55, 72, 61), _fill(_white))
    ..drawOval(const Rect.fromLTRB(37, 70, 63, 90), _fill(_tongue))
    ..restore()
    ..drawPath(mouth, _stroke(ink, 3));

  // Tears of joy flying off.
  _tearDrop(canvas, const Offset(25, 43), 13, .7);
  _tearDrop(canvas, const Offset(75, 43), 13, -.7);
}

void _boos(Canvas canvas, Color ink) {
  // Steam puffs out of the head.
  for (final (c, flip) in [
    (const Offset(14, 18), -1.0),
    (const Offset(86, 18), 1.0),
  ]) {
    final puff = Paint()..color = _white.withValues(alpha: .95);
    final edge = _stroke(const Color(0xFFB0B4C8), 1.4);
    for (final (dx, dy, r) in [
      (0.0, 0.0, 7.0),
      (5.0 * flip, -6.0, 5.5),
      (-6.0 * flip, -4.0, 4.5),
    ]) {
      canvas.drawCircle(c + Offset(dx, dy), r, edge);
    }
    for (final (dx, dy, r) in [
      (0.0, 0.0, 7.0),
      (5.0 * flip, -6.0, 5.5),
      (-6.0 * flip, -4.0, 4.5),
    ]) {
      canvas.drawCircle(c + Offset(dx, dy), r, puff);
    }
  }

  // Angry brows, eyes tucked under them.
  final brow = _stroke(ink, 5.5);
  canvas
    ..drawLine(const Offset(27, 31), const Offset(45, 39), brow)
    ..drawLine(const Offset(73, 31), const Offset(55, 39), brow);
  for (final c in [const Offset(38, 47), const Offset(62, 47)]) {
    canvas
      ..save()
      ..clipRect(Rect.fromLTRB(c.dx - 6, c.dy - 3.4, c.dx + 6, c.dy + 8))
      ..drawOval(Rect.fromCenter(center: c, width: 9, height: 10), _fill(ink))
      ..restore();
  }

  // Gritted teeth.
  final teeth = RRect.fromRectAndRadius(
    const Rect.fromLTRB(32, 59, 68, 74),
    const Radius.circular(6),
  );
  final thin = _stroke(ink, 1.8);
  canvas
    ..drawRRect(teeth, _fill(_white))
    ..save()
    ..clipRRect(teeth)
    ..drawLine(const Offset(30, 66.5), const Offset(70, 66.5), thin);
  for (final x in [41.0, 50.0, 59.0]) {
    canvas.drawLine(Offset(x, 58), Offset(x, 76), thin);
  }
  canvas
    ..restore()
    ..drawRRect(teeth, _stroke(ink, 3.2));

  // Anger mark on the forehead.
  final mark = _stroke(const Color(0xFF8A0F2A), 2.6);
  const m = Offset(70, 20);
  for (var i = 0; i < 4; i++) {
    canvas
      ..save()
      ..translate(m.dx, m.dy)
      ..rotate(i * pi / 2 + pi / 4)
      ..drawArc(
        Rect.fromCircle(center: const Offset(5.2, 0), radius: 3.2),
        pi * .6,
        pi * .8,
        false,
        mark,
      )
      ..restore();
  }
}

void _huilen(Canvas canvas, Color ink) {
  // Sad brows, high in the middle.
  final brow = _stroke(ink, 3.6);
  canvas
    ..drawLine(const Offset(27, 36), const Offset(43, 30), brow)
    ..drawLine(const Offset(73, 36), const Offset(57, 30), brow);

  // Streams of tears from both eyes, over the cheeks to the chin.
  for (final flip in [-1.0, 1.0]) {
    final x = 50 + 12 * flip;
    final stream = Path()
      ..moveTo(x - 5, 46)
      ..lineTo(x + 5, 46)
      ..cubicTo(
        x + 6 + 4 * flip,
        60,
        x + 2 + 8 * flip,
        72,
        x + 8 * flip + 5,
        88,
      )
      ..lineTo(x + 8 * flip - 5, 88)
      ..cubicTo(x - 6 + 6 * flip, 72, x - 6 + 2 * flip, 60, x - 5, 46)
      ..close();
    canvas
      ..save()
      ..clipPath(
        Path()..addOval(Rect.fromCircle(center: _center, radius: _radius)),
      )
      ..drawPath(
        stream,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_tearLight, _tear],
          ).createShader(Rect.fromLTRB(x - 12, 46, x + 12, 90)),
      )
      ..drawPath(stream, _stroke(_tearDark.withValues(alpha: .7), 1.4))
      ..restore();
  }

  // Shut, crying eyes: ∩
  final eye = _stroke(ink, 4.2);
  canvas
    ..drawArc(const Rect.fromLTRB(31, 40, 45, 52), pi, pi, false, eye)
    ..drawArc(const Rect.fromLTRB(55, 40, 69, 52), pi, pi, false, eye);

  // Wailing mouth: open, turned down.
  final mouth = Path()
    ..moveTo(38, 72)
    ..quadraticBezierTo(50, 54, 62, 72)
    ..quadraticBezierTo(50, 68, 38, 72)
    ..close();
  canvas
    ..drawPath(mouth, _fill(ink))
    ..save()
    ..clipPath(mouth)
    ..drawOval(const Rect.fromLTRB(43, 64, 57, 76), _fill(_tongue))
    ..restore()
    ..drawPath(mouth, _stroke(ink, 3));

  // Drops flying off.
  _tearDrop(canvas, const Offset(22, 50), 10, .75);
  _tearDrop(canvas, const Offset(78, 50), 10, -.75);
}

// ---------------------------------------------------------------------------
// Badges
// ---------------------------------------------------------------------------

void _gg(Canvas canvas, Color ink) {
  // Two chunky, rounded G's, drawn as strokes so they don't depend on a
  // font. Lifted on a dark edge, like the display text in the app.
  Path g(Offset c) {
    const r = 11.0;
    return Path()
      ..addArc(Rect.fromCircle(center: c, radius: r), -.55, -2 * pi + 1.25)
      ..moveTo(c.dx + r * .95, c.dy + 1)
      ..lineTo(c.dx + r * .95, c.dy + r * .55)
      ..moveTo(c.dx + r * .95, c.dy + 1)
      ..lineTo(c.dx + 2, c.dy + 1);
  }

  final letters = Path()
    ..addPath(g(const Offset(36, 48)), Offset.zero)
    ..addPath(g(const Offset(64, 48)), Offset.zero);
  canvas
    ..drawPath(letters.shift(const Offset(0, 3.5)), _stroke(ink, 8.5))
    ..drawPath(letters, _stroke(ink, 8.5))
    ..drawPath(letters, _stroke(_white, 6.5));
  _twinkle(canvas, const Offset(79, 21), 8);
  _twinkle(canvas, const Offset(21, 73), 6);
  _twinkle(canvas, const Offset(82, 72), 4.5, color: _white);
}

void _thumbsUp(Canvas canvas, Color ink) {
  canvas
    ..save()
    ..translate(50, 50)
    ..rotate(-.12);

  // Fist with the thumb up.
  final fist = RRect.fromRectAndRadius(
    const Rect.fromLTRB(-12, -6, 16, 24),
    const Radius.circular(7),
  );
  final thumb = Path()
    ..moveTo(-12, -2)
    ..lineTo(-6, -26)
    ..quadraticBezierTo(-4.5, -32, 1, -31)
    ..quadraticBezierTo(6, -30, 4.5, -23)
    ..lineTo(2, -7)
    ..close();
  final hand = Path.combine(PathOperation.union, Path()..addRRect(fist), thumb);
  // Sleeve.
  final sleeve = RRect.fromRectAndRadius(
    const Rect.fromLTRB(-24, -6, -11, 25),
    const Radius.circular(3.5),
  );

  canvas
    ..drawPath(hand.shift(const Offset(0, 2.5)), _fill(const Color(0xFF9FB7C9)))
    ..drawPath(
      hand,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_white, Color(0xFFDDEBF5)],
        ).createShader(const Rect.fromLTRB(-12, -32, 16, 24)),
    )
    ..drawPath(hand, _stroke(ink, 2.8));
  // Curled fingers.
  final crease = _stroke(ink, 2.2);
  for (final y in [4.0, 11.0, 18.0]) {
    canvas.drawLine(Offset(7, y), Offset(16, y), crease);
  }
  canvas
    ..drawRRect(
      sleeve.shift(const Offset(0, 2.5)),
      _fill(const Color(0xFF0E5E3A)),
    )
    ..drawRRect(sleeve, _fill(const Color(0xFF1E8F5E)))
    ..drawRRect(sleeve, _stroke(ink, 2.8))
    ..restore();

  _twinkle(canvas, const Offset(77, 26), 7);
  _twinkle(canvas, const Offset(22, 30), 5, color: _white);
}
