import 'dart:math';

import 'package:flutter/material.dart';

import '../../../models/game_rules.dart';
import 'fx_core.dart';

/// Two equal spells pushing against each other in the middle before they
/// burst: a throbbing ball of energy where they touch, pressure rings,
/// jets of sparks spraying out sideways and, per spell, licking flames, a
/// growing ice crystal or crackling arcs. It gets brighter and wilder the
/// longer it lasts.
class ClashStruggleLayer extends FxLayer {
  ClashStruggleLayer({
    required super.start,
    required super.duration,
    required this.spell,
    required this.at,
    required this.push,
    this.gap = 28,
    int seed = 30,
  }) {
    final rnd = Random(seed);
    _sparks = [
      for (var i = 0; i < 90; i++)
        (
          emit: rnd.nextDouble() * duration,
          side: rnd.nextBool() ? 1.0 : -1.0,
          angle: (rnd.nextDouble() - .5) * 1.1,
          speed: 220 + rnd.nextDouble() * 320,
          life: .22 + rnd.nextDouble() * .22,
          size: 1.5 + rnd.nextDouble() * 2.2,
          color: rnd.nextInt(4),
        ),
    ];
  }

  final Spell spell;

  /// The meeting point when nobody is winning.
  final FxPoint at;

  /// How the meeting point moves as the spells push (seconds since start).
  final Offset Function(double t) push;

  /// Distance from the meeting point to each spell's centre.
  final double gap;

  late final List<
    ({
      double emit,
      double side,
      double angle,
      double speed,
      double life,
      double size,
      int color,
    })
  >
  _sparks;

  List<Color> get _palette => switch (spell) {
    Spell.vuur => firePalette,
    Spell.ijs => icePalette,
    Spell.bliksem => lightningPalette,
    Spell.schild => shieldPalette,
  };

  Color get _main => switch (spell) {
    Spell.vuur => firePalette[3],
    Spell.ijs => icePalette[3],
    Spell.bliksem => lightningPalette[2],
    Spell.schild => shieldPalette[3],
  };

  @override
  void paint(Canvas canvas, FxContext ctx, double t) {
    final k = clamp01(t / duration);
    final c = at(ctx) + push(t);
    // The cameras are stacked, so spells meet along a vertical line and
    // spray out sideways.
    const axis = Offset(0, 1);
    const perp = Offset(1, 0);
    final flicker = .5 + .5 * sin(t * 61);

    // Heat haze behind it all.
    drawGlow(canvas, c, 110 + 70 * k, _main, opacity: .28 + .2 * k, core: .1);

    // Pressure rings, faster as the tension rises.
    final every = .18 - .07 * k;
    for (var i = 0; i * every < t; i++) {
      final age = t - i * every;
      if (age > .35) continue;
      final f = age / .35;
      canvas.drawCircle(
        c,
        18 + 95 * easeOut(f),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5 * (1 - f) + .5
          ..color = Colors.white.withValues(alpha: .55 * (1 - f)),
      );
    }

    switch (spell) {
      case Spell.vuur:
        _flames(canvas, c, perp, t, k);
      case Spell.ijs:
        _iceCrystal(canvas, c, t, k);
      case Spell.bliksem:
        _arcs(canvas, c, axis, t, k);
      case Spell.schild:
        break;
    }

    // Jets of sparks to both sides.
    for (final s in _sparks) {
      final age = t - s.emit;
      if (age < 0 || age > s.life) continue;
      final f = age / s.life;
      final origin = at(ctx) + push(s.emit);
      final dir = perp * (s.side * cos(s.angle)) + axis * sin(s.angle);
      final pos = origin + dir * (s.speed * age) + Offset(0, 160 * age * age);
      final prev = origin + dir * (s.speed * max(0, age - .03));
      final color = _palette[s.color].withValues(alpha: 1 - f);
      if (spell == Spell.ijs) {
        canvas
          ..save()
          ..translate(pos.dx, pos.dy)
          ..rotate(age * 14 + s.angle);
        final r = s.size * 2 * (1 - f * .4);
        canvas
          ..drawPath(
            Path()
              ..moveTo(0, -r)
              ..lineTo(r * .45, 0)
              ..lineTo(0, r)
              ..lineTo(-r * .45, 0)
              ..close(),
            Paint()..color = color,
          )
          ..restore();
      } else {
        canvas.drawLine(
          prev,
          pos,
          Paint()
            ..color = color
            ..strokeWidth = s.size * (1 - f * .5)
            ..strokeCap = StrokeCap.round,
        );
      }
    }

    // The throbbing core where they touch.
    drawGlow(
      canvas,
      c,
      30 + 48 * k + 8 * flicker,
      _main,
      opacity: .9,
      core: .25,
    );
    drawGlow(
      canvas,
      c,
      12 + 18 * k + 4 * flicker,
      Colors.white,
      opacity: 1,
      core: .5,
    );
    // About to blow.
    final overload = span(k, .75, 1);
    if (overload > 0) {
      drawGlow(canvas, c, 70 * overload, Colors.white, opacity: .8 * overload);
    }
  }

  void _flames(Canvas canvas, Offset c, Offset perp, double t, double k) {
    for (var i = 0; i < 12; i++) {
      final side = i.isEven ? 1.0 : -1.0;
      final reach = 14 + (i ~/ 2) * 9 * (1 + k) + 6 * sin(t * 40 + i);
      final lift = -8 * sin(t * 23 + i * 1.7);
      drawGlow(
        canvas,
        c + perp * (side * reach) + Offset(0, lift),
        18 - (i ~/ 2) * 1.6,
        firePalette[2 + i % 3],
        opacity: .75,
        core: .2,
      );
    }
  }

  void _iceCrystal(Canvas canvas, Offset c, double t, double k) {
    final grow = 14 + 44 * easeOut(k);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: .95);
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..color = icePalette[3].withValues(alpha: .5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    for (var i = 0; i < 6; i++) {
      final angle = i * pi / 3 + t * 1.5;
      final len = grow * (.8 + .2 * sin(t * 30 + i));
      final tip = c + polar(angle, len);
      canvas
        ..drawLine(c, tip, glow)
        ..drawLine(c, tip, stroke);
      for (final f in [.5, .78]) {
        final base = c + polar(angle, len * f);
        final twig = len * .28 * (1.2 - f);
        canvas
          ..drawLine(base, base + polar(angle + .8, twig), stroke)
          ..drawLine(base, base + polar(angle - .8, twig), stroke);
      }
    }
  }

  void _arcs(Canvas canvas, Offset c, Offset axis, double t, double k) {
    final frame = (t / .04).floor();
    // Bolts between the two spells and the contact point.
    for (final side in [-1.0, 1.0]) {
      final head = c + axis * (side * gap);
      final rnd = Random(frame * 7 + side.toInt() + 50);
      drawBolt(
        canvas,
        polyline(jaggedLine(head, c, rnd, roughness: .5, depth: 3)),
        glow: lightningPalette[2],
        width: 2,
      );
    }
    // Wild arcs lashing out, more of them as it builds up.
    final count = 3 + (k * 5).round();
    for (var i = 0; i < count; i++) {
      final rnd = Random(frame * 31 + i);
      final end =
          c +
          polar(
            rnd.nextDouble() * 2 * pi,
            40 + rnd.nextDouble() * 70 * (1 + k),
          );
      drawBolt(
        canvas,
        polyline(jaggedLine(c, end, rnd, roughness: .38, depth: 4)),
        glow: lightningPalette[3],
        width: 1.5,
        opacity: .9,
      );
    }
  }
}
