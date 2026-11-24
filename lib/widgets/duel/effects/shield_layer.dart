import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../theme/app_text_styles.dart';
import 'fx_core.dart';

/// Energy dome over one camera: a hexagon grid lights up in a wave, a
/// highlight runs around the rim, hits ripple out from where they land,
/// and lightning can smash it into flying hexagons.
class ShieldDomeLayer extends FxLayer {
  ShieldDomeLayer({
    required super.start,
    required super.duration,
    required this.side,
    this.hitAt,
    this.hitPoint,
    this.breakAt,
    this.pulseAt,
    this.label,
    int seed = 5,
  }) : _rnd = Random(seed);

  final FxSide side;

  /// Something bounces off the dome at this time (layer clock)…
  final double? hitAt;

  /// …at this point.
  final FxPoint? hitPoint;

  /// The dome shatters at this time.
  final double? breakAt;

  /// The dome throbs at this time (shield bash, shield vs shield).
  final double? pulseAt;

  /// Popped on the dome when it is hit ("BLOK!").
  final String? label;

  final Random _rnd;
  static const _cell = 15.0;

  Rect? _builtFor;
  late List<({Offset c, Offset v, double spin})> _hexes;

  RRect _dome(FxContext ctx) => RRect.fromRectAndRadius(
    ctx.rect(side).inflate(8),
    const Radius.circular(FxContext.feedRadius + 8),
  );

  @override
  void paint(Canvas canvas, FxContext ctx, double t) {
    final dome = _dome(ctx);
    final r = dome.outerRect;
    if (_builtFor != r) _build(r);
    final center = r.center;

    final broken = breakAt != null && t >= breakAt!;
    if (broken) {
      _paintFragments(canvas, t - breakAt!, center);
      return;
    }

    final appear = span(t, 0, .35);
    final alpha = span(t, 0, .2) * (1 - span(t, duration - .35, duration));
    if (alpha <= 0) return;
    final pulse = pulseAt == null ? 0.0 : exp(-pow((t - pulseAt!) * 7, 2));
    // Cracking up just before it breaks.
    final strain = breakAt == null ? 0.0 : span(t, breakAt! - .25, breakAt!);
    final shake = strain > 0 ? polar(t * 80, 3 * strain) : Offset.zero;

    canvas
      ..save()
      ..translate(center.dx + shake.dx, center.dy + shake.dy)
      ..scale(.85 + .15 * easeOutBack(appear) + .05 * pulse)
      ..translate(-center.dx, -center.dy);

    // Bubble fill, brighter towards the rim.
    canvas.drawRRect(
      dome,
      Paint()
        ..shader = ui.Gradient.radial(center, r.longestSide * .62, [
          shieldPalette[3].withValues(alpha: .14 * alpha),
          shieldPalette[3].withValues(alpha: .36 * alpha),
        ]),
    );

    // Hexagon grid.
    canvas
      ..save()
      ..clipRRect(dome);
    final hit = hitPoint?.call(ctx);
    final hitAge = hitAt == null ? -1.0 : t - hitAt!;
    final maxDist = r.longestSide * .7;
    for (final h in _hexes) {
      final d = (h.c - center).distance;
      final wave = t < .7 ? exp(-pow((d - t / .45 * maxDist) / 30, 2)) : 0.0;
      final ripple = hit != null && hitAge >= 0 && hitAge < .8
          ? exp(-pow(((h.c - hit).distance - hitAge * 650) / 28, 2)) *
                (1 - hitAge / .8)
          : 0.0;
      final base = .12 + .05 * sin(t * 3 + d * .05);
      final a = clamp01(
        alpha * (base + .75 * wave + .9 * ripple + .5 * pulse + .6 * strain),
      );
      canvas.drawPath(
        polygon(h.c, _cell * .9, 6, rotation: pi / 6),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3
          ..color = const Color(0xFFD7D0FF).withValues(alpha: a),
      );
    }
    canvas.restore();

    // Rim with glow and a highlight running around it.
    canvas
      ..drawRRect(
        dome,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..color = shieldPalette[3].withValues(alpha: .45 * alpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      )
      ..drawRRect(
        dome,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = shieldPalette[1].withValues(alpha: .95 * alpha),
      );
    final spin = Matrix4.identity()
      ..translateByDouble(center.dx, center.dy, 0, 1)
      ..rotateZ(t * 4.5)
      ..translateByDouble(-center.dx, -center.dy, 0, 1);
    canvas.drawRRect(
      dome,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..shader = ui.Gradient.sweep(
          center,
          [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: .95 * alpha),
            Colors.white.withValues(alpha: 0),
          ],
          [0, .08, .16],
          TileMode.clamp,
          0,
          2 * pi,
          spin.storage,
        ),
    );

    // Emblem that flares up when the dome appears.
    drawIcon(
      canvas,
      Icons.shield_rounded,
      center,
      68 + 10 * pulse,
      shieldPalette[1],
      opacity: alpha * (.6 * (1 - span(t, .25, .9)) + .14 + .4 * pulse),
    );

    canvas.restore();

    // Impact on the dome.
    if (hit != null && hitAge >= 0 && hitAge < .6) {
      drawGlow(
        canvas,
        hit,
        70 * (1 + hitAge),
        Colors.white,
        opacity: .9 * (1 - hitAge / .6),
        core: .2,
      );
      drawGlow(
        canvas,
        hit,
        130,
        shieldPalette[3],
        opacity: .6 * (1 - hitAge / .6),
      );
    }
    if (label != null && hit != null && hitAge >= 0 && hitAge < .9) {
      drawLabel(
        canvas,
        label!,
        hit + Offset(0, (side == FxSide.bottom ? 30 : -30) - 20 * hitAge),
        AppTextStyles.display(
          26,
          color: Colors.white,
        ).copyWith(shadows: [Shadow(color: shieldPalette[3], blurRadius: 14)]),
        scale: .7 + .3 * easeOutBack(span(hitAge, 0, .2)),
        opacity: 1 - span(hitAge, .6, .9),
      );
    }
  }

  void _build(Rect r) {
    _builtFor = r;
    final w = sqrt(3) * _cell;
    final h = 1.5 * _cell;
    _hexes = [];
    var row = 0;
    for (var y = r.top; y < r.bottom + h; y += h, row++) {
      for (var x = r.left + (row.isOdd ? w / 2 : 0); x < r.right + w; x += w) {
        final c = Offset(x, y);
        final out = c - r.center;
        final dir = out.distance == 0
            ? const Offset(0, -1)
            : out / out.distance;
        _hexes.add((
          c: c,
          v:
              dir * (120 + _rnd.nextDouble() * 320) +
              polar(_rnd.nextDouble() * 2 * pi, 60),
          spin: (_rnd.nextDouble() - .5) * 10,
        ));
      }
    }
  }

  void _paintFragments(Canvas canvas, double age, Offset center) {
    final fade = 1 - span(age, .25, .75);
    if (fade <= 0) return;
    drawGlow(
      canvas,
      center,
      200,
      shieldPalette[2],
      opacity: .7 * (1 - span(age, 0, .25)),
    );
    for (final h in _hexes) {
      final pos = h.c + h.v * age + Offset(0, 500 * age * age);
      canvas
        ..save()
        ..translate(pos.dx, pos.dy)
        ..rotate(h.spin * age);
      final hex = polygon(Offset.zero, _cell * .85, 6, rotation: pi / 6);
      canvas
        ..drawPath(
          hex,
          Paint()..color = shieldPalette[3].withValues(alpha: .4 * fade),
        )
        ..drawPath(
          hex,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..color = Colors.white.withValues(alpha: .9 * fade),
        )
        ..restore();
    }
  }
}

/// A crescent of force flying from one camera to the other (shield bash).
class ShockwaveLayer extends FxLayer {
  ShockwaveLayer({
    required super.start,
    required this.from,
    required this.to,
    super.duration = .32,
  });

  final FxPoint from;
  final FxPoint to;

  @override
  void paint(Canvas canvas, FxContext ctx, double t) {
    final a = from(ctx), b = to(ctx);
    final d = b - a;
    final angle = atan2(d.dy, d.dx);
    for (var k = 4; k >= 0; k--) {
      final u = easeIn(clamp01(t / duration - k * .07));
      if (u <= 0) continue;
      final p = Offset.lerp(a, b, u)!;
      final size = 40 + 50 * u;
      final fade = 1 - k / 5;
      canvas
        ..save()
        ..translate(p.dx, p.dy)
        ..rotate(angle);
      final arc = Rect.fromCircle(center: Offset(-size * .6, 0), radius: size);
      canvas
        ..drawArc(
          arc,
          -1,
          2,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 16
            ..strokeCap = StrokeCap.round
            ..color = shieldPalette[3].withValues(alpha: .5 * fade)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
        )
        ..drawArc(
          arc,
          -.9,
          1.8,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4
            ..strokeCap = StrokeCap.round
            ..color = Colors.white.withValues(alpha: .9 * fade),
        )
        ..restore();
    }
  }
}
