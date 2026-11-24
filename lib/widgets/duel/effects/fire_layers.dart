import 'dart:math';

import 'package:flutter/material.dart';

import 'fire_fx.dart';
import 'fx_core.dart';

/// A flying ball of fire made of flames: flames spiral into the caster's
/// hand first, then a churning fireball flies off, shedding a long trail of
/// rising flames, smoke and sparks. When it is held (a clash) it keeps
/// burning where it is.
class FireProjectile {
  FireProjectile({
    required this.charge,
    required this.flight,
    required this.hold,
    int seed = 1,
  }) {
    final rnd = Random(seed);
    double between(double a, double b) => a + rnd.nextDouble() * (b - a);
    final burning = flight + hold;
    final count = (burning * 170).round().clamp(40, 260);
    _bits = [
      for (var i = 0; i < count; i++)
        (
          bit: FlameBit(
            born: charge + (i + rnd.nextDouble()) / count * burning,
            velocity: Offset.zero,
            life: between(.3, .55),
            size: between(26, 44),
            jitter: polar(rnd.nextDouble() * 2 * pi, rnd.nextDouble() * 9),
            wobble: rnd.nextDouble() * 6,
          ),
          back: between(50, 130),
          side: between(-45, 45),
          rise: between(40, 110),
        ),
    ];
    _smoke = [
      for (var i = 0; i < count ~/ 3; i++)
        (
          born: charge + rnd.nextDouble() * burning,
          life: between(.6, .9),
          size: between(26, 44),
          drift: Offset(between(-25, 25), -between(30, 70)),
        ),
    ];
    _core = [
      for (var i = 0; i < 16; i++)
        (
          phase: rnd.nextDouble() * 2 * pi,
          radius: between(3, 15),
          speed: between(6, 14) * (rnd.nextBool() ? 1 : -1),
          size: between(30, 50),
          heat: rnd.nextDouble(),
        ),
    ];
    _sparks = [
      for (var i = 0; i < 34; i++)
        (
          born: charge + rnd.nextDouble() * burning,
          life: between(.35, .7),
          velocity:
              polar(rnd.nextDouble() * 2 * pi, between(40, 140)) +
              Offset(0, -between(40, 120)),
        ),
    ];
  }

  final double charge;
  final double flight;
  final double hold;

  double get arrival => charge + flight;

  late final List<({FlameBit bit, double back, double side, double rise})>
  _bits;
  late final List<({double born, double life, double size, Offset drift})>
  _smoke;
  late final List<
    ({double phase, double radius, double speed, double size, double heat})
  >
  _core;
  late final List<({double born, double life, Offset velocity})> _sparks;

  /// [at] and [dirAt] give the flight path (0–1), [heldAt] the position
  /// while held, by seconds since arrival.
  void paint(
    Canvas canvas,
    double t, {
    required Offset start,
    required Offset Function(double u) at,
    required Offset Function(double u) dirAt,
    required Offset Function(double held) heldAt,
  }) {
    final flames = SpriteBatch.flames();
    final glow = SpriteBatch.puffs();
    final smoke = SpriteBatch.puffs();

    // Where a flame born at [born] started, and which way the ball went.
    (Offset, Offset) originAt(double born) {
      if (born <= arrival) {
        final u = (born - charge) / flight;
        return (at(u), dirAt(u));
      }
      return (heldAt(born - arrival), dirAt(1));
    }

    // Summoning: flames spiral into the hand.
    if (t < charge) {
      final e = t / charge;
      for (var i = 0; i < 28; i++) {
        final angle = i * 2 * pi / 28 + t * 10 + i * .3;
        final r = 86 * (1 - e) + 10 + (i % 4) * 4;
        final tangent = polar(angle + pi / 2, 1);
        flames.add(
          start + polar(angle, r),
          16 + 14 * e,
          tipAngle(tangent * .4 + const Offset(0, -1)),
          fireColor(.3 + .3 * (1 - e), .7),
        );
      }
      glow.add(
        start,
        120 * e,
        0,
        const Color(0xFFFF7A2F).withValues(alpha: .55 * e),
      );
    }

    // The ball itself.
    Offset? head;
    var dir = const Offset(0, 1);
    final u = (t - charge) / flight;
    if (t >= charge && u <= 1) {
      head = at(u);
      dir = dirAt(u);
    } else if (t > arrival && t - arrival <= hold) {
      head = heldAt(t - arrival);
      dir = dirAt(1);
    }

    // Trail of flames left behind (or rising from it while held).
    for (final b in _bits) {
      final age = t - b.bit.born;
      if (age < 0 || age > b.bit.life) continue;
      final (origin, d) = originAt(b.bit.born);
      final perp = Offset(-d.dy, d.dx);
      final velocity = b.bit.born <= arrival
          ? -d * b.back + perp * b.side + Offset(0, -b.rise)
          : perp * (b.side * 1.4) + Offset(0, -b.rise * 1.6);
      final f = age / b.bit.life;
      final pos =
          origin +
          b.bit.jitter +
          velocity * age +
          Offset(sin(age * 14 + b.bit.wobble) * 5, -55 * age * age);
      flames.add(
        pos,
        flameSize(b.bit.size, f),
        tipAngle(velocity * .35 + const Offset(0, -100)) +
            sin(age * 20 + b.bit.wobble) * .3,
        fireColor(f, .75),
      );
    }

    for (final s in _smoke) {
      final age = t - s.born - .12;
      final f = age / s.life;
      if (f < 0 || f > 1) continue;
      final (origin, _) = originAt(s.born);
      smoke.add(
        origin + s.drift * age + Offset(0, -40 * age * age),
        s.size * (.6 + 1.3 * f),
        0,
        smokeColor.withValues(alpha: .34 * (1 - f) * span(f, 0, .15)),
      );
    }

    for (final s in _sparks) {
      final age = t - s.born;
      if (age < 0 || age > s.life) continue;
      final (origin, _) = originAt(s.born);
      final f = age / s.life;
      glow.add(
        origin + s.velocity * age,
        7 * (1 - f * .5),
        0,
        const Color(0xFFFFD27A).withValues(alpha: 1 - f),
      );
    }

    if (head != null) {
      glow
        ..add(head, 170, 0, const Color(0xFFFF5A14).withValues(alpha: .5))
        ..add(head, 90, 0, const Color(0xFFFF9A2E).withValues(alpha: .45));
      final back = -dir;
      for (final c in _core) {
        final angle = c.phase + t * c.speed;
        final wobble = .6 + .4 * sin(t * 23 + c.phase);
        flames.add(
          head + polar(angle, c.radius * wobble) + back * 4,
          c.size * (.85 + .25 * sin(t * 37 + c.phase)),
          tipAngle(back + const Offset(0, -1.4)) + sin(t * 30 + c.phase) * .4,
          fireColor(.18 + c.heat * .32, .7),
        );
      }
    }

    smoke.draw(canvas, additive: false);
    glow.draw(canvas);
    flames.draw(canvas);
    if (head != null) {
      drawGlow(
        canvas,
        head,
        11,
        const Color(0xFFFFF0B8),
        opacity: .7,
        core: .4,
      );
    }
  }
}

/// The camera that got hit is on fire for a moment: flames lick up from
/// its bottom edge, smoke rises, then it dies down.
class FlameCurtainLayer extends FxLayer {
  FlameCurtainLayer({
    required super.start,
    required this.side,
    super.duration = 1.6,
    int seed = 40,
  }) {
    final rnd = Random(seed);
    double between(double a, double b) => a + rnd.nextDouble() * (b - a);
    _bits = [
      for (var i = 0; i < 230; i++)
        (
          born: rnd.nextDouble() * duration * .75,
          // Flames come in tongues: clusters along the bottom edge.
          x: ((i % 7) + .5) / 7 + between(-.045, .045),
          y: rnd.nextDouble() * rnd.nextDouble(),
          bit: FlameBit(
            born: 0,
            velocity: Offset(between(-15, 15), -between(150, 300)),
            life: between(.3, .55),
            size: between(38, 66),
            jitter: Offset.zero,
            wobble: rnd.nextDouble() * 6,
          ),
        ),
    ];
    _smoke = [
      for (var i = 0; i < 26; i++)
        (
          born: rnd.nextDouble() * duration * .8,
          x: rnd.nextDouble(),
          life: between(.7, 1.1),
          size: between(40, 70),
        ),
    ];
  }

  final FxSide side;

  late final List<({double born, double x, double y, FlameBit bit})> _bits;
  late final List<({double born, double x, double life, double size})> _smoke;

  @override
  void paint(Canvas canvas, FxContext ctx, double t) {
    final rect = ctx.rect(side);
    final flames = SpriteBatch.flames();
    final glow = SpriteBatch.puffs();
    final smoke = SpriteBatch.puffs();

    // Burns hardest right after the hit, then dies down.
    double strength(double at) =>
        span(at, 0, .08) * (1 - span(at, duration * .35, duration * .8) * .75);

    for (final s in _smoke) {
      final age = t - s.born;
      final f = age / s.life;
      if (f < 0 || f > 1) continue;
      smoke.add(
        Offset(rect.left + s.x * rect.width, rect.center.dy - 140 * age),
        s.size * (.7 + f),
        0,
        smokeColor.withValues(alpha: .3 * (1 - f) * strength(s.born)),
      );
    }

    final heat = strength(t);
    for (var i = 0; i < 6; i++) {
      glow.add(
        Offset(rect.left + (i + .5) / 6 * rect.width, rect.bottom - 10),
        rect.width / 3,
        0,
        const Color(0xFFFF5A14).withValues(alpha: .45 * heat),
      );
    }

    for (final b in _bits) {
      final age = t - b.born;
      if (age < 0 || age > b.bit.life) continue;
      final f = age / b.bit.life;
      final origin = Offset(
        rect.left + b.x * rect.width,
        rect.bottom + 16 - b.y * rect.height * .25,
      );
      flames.add(
        b.bit.at(origin, age),
        flameSize(b.bit.size, f) * (.5 + .5 * strength(b.born)),
        tipAngle(b.bit.velocity) + sin(age * 18 + b.bit.wobble) * .2,
        fireColor(f, .8),
      );
    }

    canvas
      ..save()
      ..clipRRect(ctx.rrect(side));
    smoke.draw(canvas, additive: false);
    glow.draw(canvas);
    flames.draw(canvas);
    canvas.restore();
  }
}

/// Flames gushing sideways (and up) from where two fireballs push against
/// each other.
class FlameJets {
  FlameJets({required this.duration, int seed = 50}) {
    final rnd = Random(seed);
    double between(double a, double b) => a + rnd.nextDouble() * (b - a);
    _bits = [
      for (var i = 0; i < 160; i++)
        () {
          final roll = rnd.nextDouble();
          final side = roll < .4 ? -1.0 : (roll < .8 ? 1.0 : 0.0);
          final velocity = side == 0
              ? Offset(between(-30, 30), -between(150, 260))
              : Offset(side * between(180, 380), -between(30, 110));
          return (
            born: rnd.nextDouble() * duration,
            bit: FlameBit(
              born: 0,
              velocity: velocity,
              life: between(.25, .45),
              size: between(26, 48),
              jitter: polar(rnd.nextDouble() * 2 * pi, rnd.nextDouble() * 6),
              wobble: rnd.nextDouble() * 6,
            ),
          );
        }(),
    ];
  }

  final double duration;
  late final List<({double born, FlameBit bit})> _bits;

  /// [contact] is where the fireballs touch at a given time; [k] (0–1) is
  /// how far the struggle is, and makes the jets bigger.
  void paint(
    Canvas canvas,
    double t,
    Offset Function(double t) contact,
    double k,
  ) {
    final flames = SpriteBatch.flames();
    for (final b in _bits) {
      final age = t - b.born;
      if (age < 0 || age > b.bit.life) continue;
      final f = age / b.bit.life;
      final grow = .7 + .6 * clamp01(b.born / duration);
      flames.add(
        b.bit.at(contact(b.born), age),
        flameSize(b.bit.size * grow, f),
        tipAngle(b.bit.velocity) + sin(age * 22 + b.bit.wobble) * .2,
        fireColor(f * .9),
      );
    }
    flames.draw(canvas);
  }
}
