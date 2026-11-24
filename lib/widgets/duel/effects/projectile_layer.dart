import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../models/game_rules.dart';
import 'fire_layers.dart';
import 'fx_core.dart';

/// A spell flying from one point to another: a short charge-up at the
/// start, then a curved, accelerating flight with a trail.
///
/// Fire is a fireball with a flame tail, embers and smoke; ice a spinning
/// crystal with frost dust; lightning a crackling ball.
class ProjectileLayer extends FxLayer {
  ProjectileLayer({
    required super.start,
    required this.spell,
    required this.from,
    required this.to,
    this.charge = .12,
    this.flight = .5,
    this.bend = 50,
    this.hold = 0,
    this.wobble,
    int seed = 1,
  }) : _rnd = Random(seed),
       super(duration: charge + flight + hold + .6) {
    _embers = [
      for (var i = 0; i < 46; i++)
        (
          u: i / 46,
          side: _rnd.nextDouble() * 2 - 1,
          back: 20 + _rnd.nextDouble() * 70,
          life: .3 + _rnd.nextDouble() * .35,
          size: 1.5 + _rnd.nextDouble() * 2.5,
        ),
    ];
    if (spell == Spell.vuur) {
      _fire = FireProjectile(
        charge: charge,
        flight: flight,
        hold: hold,
        seed: seed,
      );
    }
  }

  /// Fire is drawn with real flames (see fire_layers.dart).
  FireProjectile? _fire;

  final Spell spell;
  final FxPoint from;
  final FxPoint to;
  final double charge;
  final double flight;

  /// Sideways curve in pixels (sign picks the side).
  final double bend;

  /// After arriving, keep the projectile at its target this long (seconds),
  /// e.g. pushing against another spell in a clash.
  final double hold;

  /// Offset of the held projectile over time (seconds since arrival).
  final Offset Function(double t)? wobble;

  final Random _rnd;
  late final List<
    ({double u, double side, double back, double life, double size})
  >
  _embers;

  /// Arrival time on this layer's clock.
  double get arrival => charge + flight;

  /// Fireballs speed up as they fly.
  static double _travel(double u) => u * u * .45 + u * .55;

  @override
  void paint(Canvas canvas, FxContext ctx, double t) {
    final a = from(ctx), b = to(ctx);
    final c = bendControl(a, b, bend);
    Offset at(double u) => bezier(a, c, b, _travel(clamp01(u)));
    Offset dirAt(double u) {
      final d = at(u + .02) - at(u - .02);
      return d.distance == 0 ? const Offset(0, 1) : d / d.distance;
    }

    if (_fire case final fire?) {
      fire.paint(
        canvas,
        t,
        start: a,
        at: at,
        dirAt: dirAt,
        heldAt: (held) => b + (wobble?.call(held) ?? Offset.zero),
      );
      return;
    }

    if (t < charge) {
      _paintCharge(canvas, a, t / charge, t);
      return;
    }

    final u = (t - charge) / flight;
    _paintTrail(canvas, t, u, at, dirAt);
    if (u <= 1) {
      _paintBody(canvas, at(u), dirAt(u), t);
    } else if (t - arrival <= hold) {
      final held = t - arrival;
      _paintBody(canvas, b + (wobble?.call(held) ?? Offset.zero), dirAt(1), t);
    }
  }

  void _paintBody(Canvas canvas, Offset p, Offset dir, double t) {
    switch (spell) {
      case Spell.vuur:
        _fireBody(canvas, p, dir, t);
      case Spell.ijs:
        _iceBody(canvas, p, t);
      case Spell.bliksem:
        _ballLightning(canvas, p, t);
      case Spell.schild:
        drawGlow(canvas, p, 50, shieldPalette[3], opacity: .8, core: .2);
    }
  }

  // -------------------------------------------------------------------------

  void _paintCharge(Canvas canvas, Offset p, double e, double t) {
    final color = _mainColor;
    drawGlow(
      canvas,
      p,
      18 + 34 * easeOut(e),
      color,
      opacity: .75 * e,
      core: .2,
    );
    for (var i = 0; i < 9; i++) {
      final angle = i * 2 * pi / 9 + t * 7;
      final r = 56 * (1 - e) + 8;
      drawGlow(
        canvas,
        p + polar(angle, r),
        5,
        Colors.white,
        opacity: .9 * e,
        core: .3,
      );
    }
  }

  Color get _mainColor => switch (spell) {
    Spell.vuur => firePalette[3],
    Spell.ijs => icePalette[3],
    Spell.bliksem => lightningPalette[2],
    Spell.schild => shieldPalette[3],
  };

  void _paintTrail(
    Canvas canvas,
    double t,
    double u,
    Offset Function(double) at,
    Offset Function(double) dirAt,
  ) {
    // Things left behind along the path, each living a short while.
    for (final e in _embers) {
      final emitted = charge + e.u * flight;
      final age = t - emitted;
      if (e.u > u || age < 0 || age > e.life) continue;
      final f = age / e.life;
      final dir = dirAt(e.u);
      final normal = Offset(-dir.dy, dir.dx);
      final base = at(e.u);
      switch (spell) {
        case Spell.vuur:
          // Smoke for some, rising embers for the rest.
          if (e.size > 3.4) {
            final pos = base + normal * (e.side * 10) + Offset(0, -20 * age);
            drawGlow(
              canvas,
              pos,
              8 + 20 * f,
              const Color(0xFF2B2233),
              opacity: .3 * (1 - f),
            );
          } else {
            final pos =
                base +
                (-dir * e.back + normal * (e.side * 70)) * age +
                Offset(0, -60 * age * age);
            final color = Color.lerp(firePalette[1], firePalette[5], f)!;
            canvas.drawCircle(
              pos,
              e.size * (1 - f * .6),
              Paint()..color = color.withValues(alpha: 1 - f),
            );
          }
        case Spell.ijs:
          final pos =
              base + normal * (e.side * 18) + -dir * (e.back * age * .4);
          final twinkle = .5 + .5 * sin(age * 30 + e.side * 10);
          _sparkle(canvas, pos, e.size * 1.8, (1 - f) * twinkle);
          if (e.size > 3) {
            drawGlow(canvas, pos, 14, icePalette[2], opacity: .2 * (1 - f));
          }
        case Spell.bliksem:
          final pos = base + normal * (e.side * 24);
          drawGlow(canvas, pos, 4, lightningPalette[1], opacity: 1 - f);
        case Spell.schild:
          break;
      }
    }

    // A glowing streak right behind the projectile.
    if (u > 1) return;
    const steps = 16;
    for (var k = steps; k >= 1; k--) {
      final uk = u - k * .02;
      if (uk < 0) continue;
      final f = k / steps;
      final p = at(uk);
      switch (spell) {
        case Spell.vuur:
          drawGlow(
            canvas,
            p,
            24 * (1 - f * .7),
            Color.lerp(firePalette[2], firePalette[5], f)!,
            opacity: .55 * (1 - f),
            core: .2,
          );
        case Spell.ijs:
          drawGlow(
            canvas,
            p,
            18 * (1 - f * .6),
            icePalette[2],
            opacity: .3 * (1 - f),
          );
        case Spell.bliksem:
          drawGlow(
            canvas,
            p,
            12 * (1 - f * .6),
            lightningPalette[2],
            opacity: .4 * (1 - f),
          );
        case Spell.schild:
          drawGlow(
            canvas,
            p,
            20 * (1 - f),
            shieldPalette[3],
            opacity: .4 * (1 - f),
          );
      }
    }
  }

  void _fireBody(Canvas canvas, Offset p, Offset dir, double t) {
    drawGlow(canvas, p, 92, const Color(0xFFFF7A2F), opacity: .5, core: .1);
    canvas
      ..save()
      ..translate(p.dx, p.dy)
      ..rotate(atan2(dir.dy, dir.dx));

    // Flame tail streaming backwards.
    final wobble = sin(t * 38) * 3;
    final tail = Path()
      ..moveTo(-125, wobble)
      ..quadraticBezierTo(-36, -32, 5, -26)
      ..arcToPoint(const Offset(5, 26), radius: const Radius.circular(26))
      ..quadraticBezierTo(-36, 32, -125, -wobble)
      ..close();
    canvas.drawPath(
      tail,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(-125, 0),
          const Offset(12, 0),
          [
            firePalette[5].withValues(alpha: 0),
            firePalette[4].withValues(alpha: .7),
            firePalette[2],
          ],
          [0, .55, 1],
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    // Licking flames around the core.
    for (var i = 0; i < 7; i++) {
      final angle = t * 16 + i * 2 * pi / 7;
      final r = 14 + 5 * sin(t * 33 + i);
      drawGlow(
        canvas,
        polar(angle, r) + const Offset(-6, 0),
        16,
        firePalette[2 + i % 3],
        opacity: .75,
        core: .2,
      );
    }

    final r = 24 + 2 * sin(t * 45);
    canvas
      ..drawCircle(
        Offset.zero,
        r,
        Paint()
          ..shader = ui.Gradient.radial(
            const Offset(5, -3),
            r,
            [Colors.white, firePalette[1], firePalette[2], firePalette[4]],
            [0, .35, .65, 1],
          ),
      )
      ..restore();
  }

  void _iceBody(Canvas canvas, Offset p, double t) {
    drawGlow(canvas, p, 60, icePalette[3], opacity: .5, core: .15);
    drawGlow(canvas, p, 28, Colors.white, opacity: .55);
    canvas
      ..save()
      ..translate(p.dx, p.dy)
      ..rotate(t * 9);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = Colors.white;
    for (var i = 0; i < 6; i++) {
      final angle = i * pi / 3;
      final arm = polar(angle, 24);
      canvas.drawLine(Offset.zero, arm, stroke);
      for (final f in [.45, .72]) {
        final base = arm * f;
        final len = 9 * (1.25 - f);
        canvas
          ..drawLine(base, base + polar(angle + .75, len), stroke)
          ..drawLine(base, base + polar(angle - .75, len), stroke);
      }
    }
    canvas
      ..drawPath(polygon(Offset.zero, 8, 6), Paint()..color = icePalette[2])
      ..restore();
  }

  void _ballLightning(Canvas canvas, Offset p, double t) {
    drawGlow(canvas, p, 56, lightningPalette[2], opacity: .55, core: .1);
    drawGlow(canvas, p, 18, Colors.white, opacity: 1, core: .4);
    final frame = (t / .045).floor();
    for (var i = 0; i < 5; i++) {
      final rnd = Random(frame * 31 + i);
      final end =
          p + polar(rnd.nextDouble() * 2 * pi, 26 + rnd.nextDouble() * 14);
      drawBolt(
        canvas,
        polyline(jaggedLine(p, end, rnd, roughness: .4, depth: 3)),
        glow: lightningPalette[2],
        width: 1.3,
      );
    }
  }

  void _sparkle(Canvas canvas, Offset p, double size, double opacity) {
    if (opacity <= 0) return;
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: clamp01(opacity))
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawLine(p - Offset(size, 0), p + Offset(size, 0), paint)
      ..drawLine(p - Offset(0, size), p + Offset(0, size), paint);
  }
}
