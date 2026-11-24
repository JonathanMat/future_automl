import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// The Spell Duel logo: a gold hexagon shield in which a fire orb and an
/// ice orb clash, split by a lightning bolt. All four spells in one badge.
///
/// The same painter renders the app icon and splash images
/// (see `tool/render_logo_test.dart`).
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 96});

  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Spell Duel logo',
    image: true,
    child: CustomPaint(
      size: Size.square(size),
      painter: const SpellDuelLogoPainter(),
    ),
  );
}

class SpellDuelLogoPainter extends CustomPainter {
  const SpellDuelLogoPainter({this.background = false, this.scale = 1});

  /// Fill the whole square with the night-sky background (app icon).
  final bool background;

  /// Badge size relative to the canvas. 1 fills it; the adaptive icon and
  /// splash use less so the badge stays inside their safe zones.
  final double scale;

  // Spell colours, light → mid → dark (same as SpellInfo.orbColors).
  static const _fire = [
    Color(0xFFFFC79A),
    Color(0xFFFF7A2F),
    Color(0xFFA8360A),
  ];
  static const _ice = [Color(0xFFD4F3FF), Color(0xFF4FC3F7), Color(0xFF1769AA)];

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final c = size.center(Offset.zero);
    if (background) _paintBackground(canvas, size, s, c);
    if (scale <= 0) return;

    // Everything below is laid out in "badge units": u = badge radius.
    final u = s * 0.47 * scale;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    _paintBadge(canvas, u);
    canvas.restore();
  }

  void _paintBackground(Canvas canvas, Size size, double s, Offset c) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.15),
          radius: 0.85,
          colors: const [
            Color(0xFF3A2A86),
            Color(0xFF1C1640),
            AppColors.background,
          ],
          stops: const [0, 0.55, 1],
        ).createShader(rect),
    );
    // A few faint stars.
    final rnd = math.Random(7);
    final star = Paint()..color = Colors.white.withValues(alpha: 0.5);
    for (var i = 0; i < 26; i++) {
      final p = Offset(
        rnd.nextDouble() * size.width,
        rnd.nextDouble() * size.height,
      );
      if ((p - c).distance < s * 0.4) continue;
      canvas.drawCircle(p, s * (0.002 + rnd.nextDouble() * 0.004), star);
    }
  }

  Path _hex(double r) {
    final p = Path();
    for (var i = 0; i < 6; i++) {
      final a = -math.pi / 2 + i * math.pi / 3;
      final pt = Offset(math.cos(a) * r, math.sin(a) * r);
      i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
    }
    return p..close();
  }

  /// Hexagon with rounded corners.
  Path _roundHex(double r, double corner) {
    final pts = [
      for (var i = 0; i < 6; i++)
        Offset(
          math.cos(-math.pi / 2 + i * math.pi / 3) * r,
          math.sin(-math.pi / 2 + i * math.pi / 3) * r,
        ),
    ];
    final p = Path();
    for (var i = 0; i < 6; i++) {
      final prev = pts[(i + 5) % 6], cur = pts[i], next = pts[(i + 1) % 6];
      final a = cur + (prev - cur) / (prev - cur).distance * corner;
      final b = cur + (next - cur) / (next - cur).distance * corner;
      i == 0 ? p.moveTo(a.dx, a.dy) : p.lineTo(a.dx, a.dy);
      p.quadraticBezierTo(cur.dx, cur.dy, b.dx, b.dy);
    }
    return p..close();
  }

  void _paintBadge(Canvas canvas, double u) {
    final outer = _roundHex(u * 0.92, u * 0.16);
    final drop = Offset(0, u * 0.07);

    // Glow behind the badge.
    canvas.drawPath(
      outer,
      Paint()
        ..color = AppColors.violet.withValues(alpha: 0.55)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, u * 0.12),
    );

    // Chunky 3D edge, like the buttons.
    canvas.drawPath(
      outer.shift(drop),
      Paint()..color = AppColors.goldTitleShadow,
    );

    // Gold rim.
    final rimRect = Rect.fromCircle(center: Offset.zero, radius: u);
    canvas.drawPath(
      outer,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.goldLight, AppColors.gold, Color(0xFFE08A00)],
          stops: [0, 0.5, 1],
        ).createShader(rimRect),
    );

    // Inner field.
    final inner = _roundHex(u * 0.78, u * 0.12);
    canvas.drawPath(
      inner,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -0.2),
          radius: 0.8,
          colors: [Color(0xFF3B2C8C), Color(0xFF1C1640), AppColors.hexInner],
          stops: [0, 0.6, 1],
        ).createShader(rimRect),
    );
    // Thin dark line where rim meets field, for depth.
    canvas.drawPath(
      inner,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = u * 0.025
        ..color = AppColors.goldShadow,
    );

    canvas.save();
    canvas.clipPath(inner);

    // Shield ring (the 4th spell) inside the field.
    canvas.drawPath(
      _hex(u * 0.66),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = u * 0.018
        ..color = AppColors.shieldPip.withValues(alpha: 0.45),
    );

    // Fire and ice orbs, clashing in the middle.
    final orbR = u * 0.29;
    final fireC = Offset(-u * 0.27, u * 0.07);
    final iceC = Offset(u * 0.27, u * 0.07);
    _trail(canvas, fireC, orbR, -1, _fire[1]);
    _trail(canvas, iceC, orbR, 1, _ice[1]);
    _orb(canvas, fireC, orbR, _fire);
    _orb(canvas, iceC, orbR, _ice);
    _flame(canvas, fireC + Offset(-orbR * 0.22, orbR * 0.16), orbR * 0.48);
    _snowflake(canvas, iceC + Offset(orbR * 0.16, orbR * 0.1), orbR * 0.5);

    // Clash flash where they meet.
    canvas.drawCircle(
      Offset(0, u * 0.06),
      u * 0.22,
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                Colors.white.withValues(alpha: 0.95),
                const Color(0xFFFFF4B8).withValues(alpha: 0.6),
                const Color(0xFFFFF4B8).withValues(alpha: 0),
              ],
              stops: const [0, 0.35, 1],
            ).createShader(
              Rect.fromCircle(center: Offset(0, u * 0.06), radius: u * 0.22),
            ),
    );

    _sparkles(canvas, u);
    canvas.restore();

    _bolt(canvas, u);
  }

  /// Energy streak behind an orb, pointing away from the clash.
  void _trail(Canvas canvas, Offset c, double r, int dir, Color color) {
    final tail = c + Offset(dir * r * 2.1, -r * 0.55);
    final path = Path()
      ..moveTo(c.dx, c.dy - r * 0.95)
      ..quadraticBezierTo(
        c.dx + dir * r * 1.2,
        c.dy - r * 1.05,
        tail.dx,
        tail.dy,
      )
      ..quadraticBezierTo(
        c.dx + dir * r * 1.3,
        c.dy + r * 0.35,
        c.dx,
        c.dy + r * 0.95,
      )
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          colors: [color.withValues(alpha: 0.55), color.withValues(alpha: 0)],
        ).createShader(Rect.fromPoints(c, tail))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.08),
    );
  }

  /// Teardrop flame, tip leaning slightly right. [g] is half its height.
  Path _drop(Offset c, double g, {double lean = 0.12}) {
    Offset p(double x, double y) => c + Offset(x * g, y * g);
    final tip = p(lean, -1);
    final r1 = p(0.58, 0.42), bot = p(0, 1), l1 = p(-0.58, 0.42);
    return Path()
      ..moveTo(tip.dx, tip.dy)
      ..cubicTo(
        p(lean + 0.18, -0.55).dx,
        p(lean + 0.18, -0.55).dy,
        p(0.58, -0.2).dx,
        p(0.58, -0.2).dy,
        r1.dx,
        r1.dy,
      )
      ..cubicTo(
        p(0.58, 0.78).dx,
        p(0.58, 0.78).dy,
        p(0.32, 1).dx,
        p(0.32, 1).dy,
        bot.dx,
        bot.dy,
      )
      ..cubicTo(
        p(-0.32, 1).dx,
        p(-0.32, 1).dy,
        p(-0.58, 0.78).dx,
        p(-0.58, 0.78).dy,
        l1.dx,
        l1.dy,
      )
      ..cubicTo(
        p(-0.58, -0.1).dx,
        p(-0.58, -0.1).dy,
        p(lean - 0.2, -0.5).dx,
        p(lean - 0.2, -0.5).dy,
        tip.dx,
        tip.dy,
      )
      ..close();
  }

  void _flame(Canvas canvas, Offset c, double g) {
    Offset p(double x, double y) => c + Offset(x * g, y * g);
    void cubic(Path path, List<double> v) {
      final a = p(v[0], v[1]), b = p(v[2], v[3]), e = p(v[4], v[5]);
      path.cubicTo(a.dx, a.dy, b.dx, b.dy, e.dx, e.dy);
    }

    final start = p(0.05, -1);
    final outer = Path()..moveTo(start.dx, start.dy);
    for (final v in const <List<double>>[
      [0.38, -0.62, 0.55, -0.38, 0.52, -0.02],
      [0.62, -0.1, 0.68, -0.22, 0.68, -0.4], // right tongue
      [0.95, -0.05, 0.9, 0.6, 0.45, 0.88],
      [0.25, 1.0, -0.25, 1.0, -0.45, 0.88],
      [-0.9, 0.6, -0.88, 0.05, -0.62, -0.28], // left tongue
      [-0.6, -0.1, -0.52, 0.0, -0.4, 0.06],
      [-0.5, -0.4, -0.25, -0.75, 0.05, -1],
    ]) {
      cubic(outer, v);
    }
    outer.close();
    canvas.drawPath(
      outer,
      Paint()..color = Colors.white.withValues(alpha: 0.95),
    );
    // Hot core, sitting at the bottom of the flame.
    canvas.drawPath(
      _drop(c + Offset(0, g * 0.42), g * 0.46, lean: -0.08),
      Paint()..color = const Color(0xFFFF9A57),
    );
  }

  void _snowflake(Canvas canvas, Offset c, double g) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.95)
      ..strokeWidth = g * 0.17
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < 6; i++) {
      final a = math.pi / 2 + i * math.pi / 3;
      final d = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(c, c + d * g, paint);
      // A "V" on each arm, opening towards the tip.
      final base = c + d * g * 0.52;
      for (final turn in [-0.8, 0.8]) {
        final b = a + turn;
        canvas.drawLine(
          base,
          base + Offset(math.cos(b), math.sin(b)) * g * 0.36,
          paint,
        );
      }
    }
  }

  void _orb(Canvas canvas, Offset center, double r, List<Color> c) {
    // Glow.
    canvas.drawCircle(
      center,
      r * 1.15,
      Paint()
        ..color = c[1].withValues(alpha: 0.55)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.35),
    );
    final rect = Rect.fromCircle(center: center, radius: r);
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.44),
          radius: 0.95,
          colors: c,
          stops: const [0, 0.44, 1],
        ).createShader(rect),
    );
    // Glossy highlight.
    canvas.drawOval(
      Rect.fromCenter(
        center: center + Offset(-r * 0.3, -r * 0.45),
        width: r * 0.8,
        height: r * 0.42,
      ),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.75),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(rect),
    );
  }

  void _bolt(Canvas canvas, double u) {
    // Classic zig-zag bolt, slightly tilted, sticking out of the field.
    const pts = [
      Offset(0.00, -0.76),
      Offset(-0.26, 0.10),
      Offset(-0.05, 0.10),
      Offset(-0.11, 0.64),
      Offset(0.28, -0.12),
      Offset(0.03, -0.10),
      Offset(0.22, -0.76),
    ];
    final path = Path()..moveTo(pts[0].dx * u, pts[0].dy * u);
    for (final p in pts.skip(1)) {
      path.lineTo(p.dx * u, p.dy * u);
    }
    path.close();

    final rect = path.getBounds();
    // White-hot glow.
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFFFF4B8).withValues(alpha: 0.9)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, u * 0.07),
    );
    // 3D edge under the bolt.
    canvas.drawPath(
      path.shift(Offset(0, u * 0.045)),
      Paint()..color = const Color(0xFF5A3E00),
    );
    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFDE8), Color(0xFFFFE066), Color(0xFFFFB020)],
          stops: [0, 0.45, 1],
        ).createShader(rect),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = u * 0.03
        ..color = const Color(0xFF5A3E00),
    );
  }

  void _sparkles(Canvas canvas, double u) {
    const spots = [
      (Offset(-0.42, -0.38), 0.07),
      (Offset(0.46, -0.30), 0.055),
      (Offset(0.40, 0.48), 0.05),
      (Offset(-0.50, 0.40), 0.045),
    ];
    for (final (o, r) in spots) {
      _star(canvas, o * u, r * u);
    }
  }

  void _star(Canvas canvas, Offset c, double r) {
    final p = Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx, c.dy, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx, c.dy, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - r)
      ..close();
    canvas.drawPath(p, Paint()..color = Colors.white.withValues(alpha: 0.9));
  }

  @override
  bool shouldRepaint(SpellDuelLogoPainter old) =>
      old.background != background || old.scale != scale;
}
