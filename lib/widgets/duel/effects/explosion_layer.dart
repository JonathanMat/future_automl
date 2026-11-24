import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'fx_core.dart';

/// Fire explosion: white flash, expanding fireball, shockwave rings,
/// flying debris with motion streaks, smoke, and a scorch mark on the
/// camera it hit.
class ExplosionLayer extends FxLayer {
  ExplosionLayer({
    required super.start,
    required this.at,
    this.side,
    this.scale = 1,
    int seed = 2,
  }) : super(duration: 1.5) {
    final rnd = Random(seed);
    _debris = makeBurst(
      rnd,
      72,
      minSpeed: 180 * scale,
      maxSpeed: 620 * scale,
      maxSize: 6.5 * scale,
      minLife: .5,
      maxLife: 1.15,
      colors: 5,
    );
    _smoke = makeBurst(
      rnd,
      12,
      minSpeed: 30,
      maxSpeed: 110,
      minSize: 18,
      maxSize: 34,
      minLife: .9,
      maxLife: 1.4,
    );
  }

  final FxPoint at;

  /// The camera to scorch, if the explosion is on one.
  final FxSide? side;
  final double scale;

  late final List<FxParticle> _debris;
  late final List<FxParticle> _smoke;

  @override
  void paint(Canvas canvas, FxContext ctx, double t) {
    final p = at(ctx);

    if (side case final s?) _scorch(canvas, ctx, s, p, t);

    // Smoke, behind everything else.
    for (final s in _smoke) {
      final age = t - .08;
      final f = age / s.life;
      if (f < 0 || f > 1) continue;
      drawGlow(
        canvas,
        p + s.offsetAt(age, gravity: -70),
        s.size * scale * (1 + 1.8 * f),
        const Color(0xFF241B2B),
        opacity: .38 * (1 - f) * span(age, 0, .12),
      );
    }

    // Fireball.
    final grow = easeOut(span(t, 0, .32));
    final fade = 1 - span(t, .2, .8);
    final r = 130 * scale * grow;
    if (r > 1 && fade > 0) {
      canvas.drawCircle(
        p,
        r,
        Paint()
          ..shader = ui.Gradient.radial(
            p,
            r,
            [
              Colors.white.withValues(alpha: fade),
              firePalette[1].withValues(alpha: fade),
              firePalette[2].withValues(alpha: fade),
              firePalette[3].withValues(alpha: .85 * fade),
              firePalette[4].withValues(alpha: .45 * fade),
              firePalette[5].withValues(alpha: 0),
            ],
            [0, .16, .36, .58, .8, 1],
          ),
      );
    }

    // Shockwave rings.
    for (final (delay, width, color, reach) in [
      (0.0, 16.0, firePalette[2], 250.0),
      (.06, 6.0, Colors.white, 200.0),
    ]) {
      final k = span(t - delay, 0, .55);
      if (k <= 0 || k >= 1) continue;
      canvas.drawCircle(
        p,
        20 + reach * scale * easeOut(k),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width * (1 - k) + 1
          ..color = color.withValues(alpha: .75 * (1 - k))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }

    // Flash.
    final flash = 1 - span(t, 0, .14);
    if (flash > 0) {
      drawGlow(
        canvas,
        p,
        180 * scale,
        Colors.white,
        opacity: .95 * flash,
        core: .25,
      );
    }

    // Debris with short motion streaks.
    for (final d in _debris) {
      final age = t - d.delay;
      final f = age / d.life;
      if (f < 0 || f > 1) continue;
      final pos = p + d.offsetAt(age, gravity: 540, drag: 2.6);
      final prev = p + d.offsetAt(max(0, age - .035), gravity: 540, drag: 2.6);
      final color = Color.lerp(
        firePalette[1 + d.colorIndex],
        firePalette[5],
        f,
      )!.withValues(alpha: 1 - f * f);
      final size = d.size * (1 - f * .7);
      canvas.drawLine(
        prev,
        pos,
        Paint()
          ..color = color
          ..strokeWidth = size
          ..strokeCap = StrokeCap.round,
      );
      if (d.size > 4.5 && f < .5) {
        drawGlow(
          canvas,
          pos,
          size * 4,
          firePalette[3],
          opacity: .35 * (1 - f * 2),
        );
      }
    }
  }

  void _scorch(Canvas canvas, FxContext ctx, FxSide s, Offset p, double t) {
    canvas
      ..save()
      ..clipRRect(ctx.rrect(s));
    final heat = 1 - span(t, 0, .9);
    if (heat > 0) {
      canvas.drawRect(
        ctx.rect(s),
        Paint()..color = firePalette[3].withValues(alpha: .35 * heat),
      );
    }
    final burn = .6 * span(t, .05, .2) * (1 - span(t, .5, 1.5));
    drawGlow(canvas, p, 190 * scale, Colors.black, opacity: burn, core: .15);
    canvas.restore();
  }
}

/// A burst of sparks with a flash and ring, in any palette. Used where
/// spells collide and where a shield is hit.
class BurstLayer extends FxLayer {
  BurstLayer({
    required super.start,
    required this.at,
    required this.palette,
    this.count = 40,
    this.reach = 1,
    this.shards = false,
    this.bolts = false,
    int seed = 6,
  }) : super(duration: 1.1) {
    _particles = makeBurst(
      Random(seed),
      count,
      minSpeed: 140 * reach,
      maxSpeed: 520 * reach,
      minSize: 2,
      maxSize: shards ? 9 : 5,
      minLife: .4,
      maxLife: 1,
      colors: palette.length,
    );
  }

  final FxPoint at;
  final List<Color> palette;
  final int count;
  final double reach;

  /// Ice: spinning diamond shards instead of round sparks.
  final bool shards;

  /// Lightning: short electric arcs shooting out.
  final bool bolts;

  late final List<FxParticle> _particles;

  @override
  void paint(Canvas canvas, FxContext ctx, double t) {
    final p = at(ctx);
    final main = palette.last;

    final flash = 1 - span(t, 0, .2);
    drawGlow(canvas, p, 120 * reach, main, opacity: .8 * flash, core: .2);
    drawGlow(canvas, p, 60 * reach, Colors.white, opacity: flash, core: .3);

    final k = span(t, 0, .5);
    if (k < 1) {
      canvas.drawCircle(
        p,
        16 + 170 * reach * easeOut(k),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10 * (1 - k) + 1
          ..color = main.withValues(alpha: .8 * (1 - k))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }

    if (bolts && t < .35) {
      for (var i = 0; i < 7; i++) {
        final rnd = Random((t / .05).floor() * 13 + i);
        final end =
            p + polar(i * 2 * pi / 7 + rnd.nextDouble(), 60 + 70 * reach);
        drawBolt(
          canvas,
          polyline(jaggedLine(p, end, rnd, roughness: .3, depth: 4)),
          glow: main,
          width: 1.8,
          opacity: 1 - t / .35,
        );
      }
    }

    for (final s in _particles) {
      final age = t - s.delay;
      final f = age / s.life;
      if (f < 0 || f > 1) continue;
      final pos = p + s.offsetAt(age, gravity: shards ? 700 : 300);
      final color = palette[s.colorIndex].withValues(alpha: 1 - f);
      if (shards) {
        canvas
          ..save()
          ..translate(pos.dx, pos.dy)
          ..rotate(s.spin * age);
        final r = s.size * (1 - f * .5);
        final diamond = Path()
          ..moveTo(0, -r)
          ..lineTo(r * .45, 0)
          ..lineTo(0, r)
          ..lineTo(-r * .45, 0)
          ..close();
        canvas
          ..drawPath(diamond, Paint()..color = color)
          ..restore();
      } else {
        canvas.drawCircle(pos, s.size * (1 - f * .6), Paint()..color = color);
      }
    }
  }
}
