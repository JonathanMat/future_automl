import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Two crossed swords (the "duel" icon). Material Icons has none, so it is
/// drawn here, in one colour like a normal icon.
class CrossedSwordsIcon extends StatelessWidget {
  const CrossedSwordsIcon({super.key, this.size = 24, this.color});

  final double size;

  /// Defaults to the surrounding [IconTheme] colour.
  final Color? color;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: Size.square(size),
      painter: _SwordsPainter(
        color ?? IconTheme.of(context).color ?? Colors.white,
      ),
    ),
  );
}

class _SwordsPainter extends CustomPainter {
  const _SwordsPainter(this.color);

  final Color color;

  /// One sword pointing up, centred on (0, 0), in units of the icon size.
  static Path _sword(double s) {
    Offset p(double x, double y) => Offset(x * s, y * s);
    final blade = Path()
      ..moveTo(p(0, -0.62).dx, p(0, -0.62).dy)
      ..lineTo(p(0.064, -0.47).dx, p(0.064, -0.47).dy)
      ..lineTo(p(0.064, 0.20).dx, p(0.064, 0.20).dy)
      ..lineTo(p(-0.064, 0.20).dx, p(-0.064, 0.20).dy)
      ..lineTo(p(-0.064, -0.47).dx, p(-0.064, -0.47).dy)
      ..close();
    final guard = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: p(0, 0.25),
            width: 0.40 * s,
            height: 0.09 * s,
          ),
          Radius.circular(0.045 * s),
        ),
      );
    final grip = Path()
      ..addRect(Rect.fromLTRB(-0.04 * s, 0.27 * s, 0.04 * s, 0.45 * s));
    final pommel = Path()
      ..addOval(Rect.fromCircle(center: p(0, 0.50), radius: 0.07 * s));
    return Path.combine(
      PathOperation.union,
      Path.combine(PathOperation.union, blade, guard),
      Path.combine(PathOperation.union, grip, pommel),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final c = size.center(Offset.zero);
    final sword = _sword(s);
    Path placed(double angle) => sword.transform(
      (Matrix4.identity()
            ..translateByDouble(c.dx, c.dy, 0, 1)
            ..rotateZ(angle))
          .storage,
    );
    final a = placed(-math.pi / 4); // tip to the upper left
    final b = placed(math.pi / 4); // tip to the upper right

    final fill = Paint()..color = color;
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawPath(a, fill);
    // Cut a thin gap around the front sword so the two read as separate.
    canvas.drawPath(
      b,
      Paint()
        ..blendMode = BlendMode.clear
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.09,
    );
    canvas.drawPath(b, fill);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SwordsPainter old) => old.color != color;
}
