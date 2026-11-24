import 'dart:math';

import 'package:flutter/material.dart';

import 'fx_core.dart';

/// Lightning strike on one camera: the sky darkens, a faint stepped
/// leader crawls down, then the bolt strikes and flickers a few times
/// (reshaping each flicker) with branches, white screen flashes, sparks,
/// and electric arcs crawling over the camera afterwards.
class LightningStrikeLayer extends FxLayer {
  LightningStrikeLayer({
    required super.start,
    required this.side,
    this.strikeAt = .3,
    int seed = 3,
  }) : _seed = seed,
       super(duration: strikeAt + 1.25) {
    _sparks = makeBurst(
      Random(seed),
      50,
      minSpeed: 160,
      maxSpeed: 680,
      minSize: 1.5,
      maxSize: 4,
      minLife: .3,
      maxLife: .85,
      colors: lightningPalette.length,
      direction: -pi / 2,
      spread: pi * 1.7,
    );
  }

  final FxSide side;

  /// When the bolt hits, on this layer's clock.
  final double strikeAt;

  final int _seed;
  late final List<FxParticle> _sparks;

  /// Bolt visibility after the strike: on, off, on… then fading.
  static double _flicker(double ts) {
    if (ts < 0) return 0;
    const pattern = [
      (.12, 1.0),
      (.16, .2),
      (.24, 1.0),
      (.30, .25),
      (.36, .9),
      (.42, .15),
      (.47, .7),
    ];
    for (final (until, value) in pattern) {
      if (ts < until) return value;
    }
    return max(0, .5 * (1 - (ts - .47) / .3));
  }

  @override
  void paint(Canvas canvas, FxContext ctx, double t) {
    final rect = ctx.rect(side);
    final ts = t - strikeAt;
    final rnd = Random(_seed);
    final from = Offset(
      rect.center.dx + (rnd.nextDouble() - .5) * rect.width * .3,
      rect.top - (side == FxSide.top ? 70 : 100),
    );
    final hit = Offset(rect.center.dx, rect.center.dy + rect.height * .12);

    // The world darkens before the strike.
    final dark = .42 * span(t, 0, strikeAt) * (1 - span(ts, .15, .6));
    if (dark > 0) {
      canvas.drawRect(
        Offset.zero & ctx.size,
        Paint()..color = const Color(0xFF05030F).withValues(alpha: dark),
      );
    }

    if (ts < .1) _paintCharge(canvas, from, hit, t);

    final flick = _flicker(ts);
    if (flick > 0) _paintBolt(canvas, from, hit, ts, flick);

    if (ts >= 0) {
      _paintImpact(canvas, ctx, hit, ts, flick);
      _paintSparks(canvas, hit, ts);
      _paintArcs(canvas, ctx, ts);
    }

    // Screen flashes on the first and third flicker.
    final flash =
        (ts >= 0 ? .85 * (1 - span(ts, 0, .12)) : 0.0) +
        (ts > .24 && ts < .36 ? .4 * (1 - span(ts, .24, .36)) : 0.0);
    if (flash > 0) {
      canvas.drawRect(
        Offset.zero & ctx.size,
        Paint()..color = const Color(0xFFFFFDF0).withValues(alpha: flash),
      );
    }
  }

  void _paintCharge(Canvas canvas, Offset from, Offset hit, double t) {
    final e = span(t, 0, strikeAt);
    drawGlow(
      canvas,
      from,
      30 + 50 * e,
      lightningPalette[1],
      opacity: .7 * e,
      core: .2,
    );
    final frame = (t / .05).floor();
    for (var i = 0; i < 3; i++) {
      final rnd = Random(frame * 17 + i);
      drawBolt(
        canvas,
        polyline(
          jaggedLine(
            from,
            from + polar(rnd.nextDouble() * 2 * pi, 20 + 30 * e),
            rnd,
            roughness: .45,
            depth: 3,
          ),
        ),
        glow: lightningPalette[2],
        width: 1,
        opacity: e,
      );
    }
    // Stepped leader: a faint path feeling its way down.
    final leader = jaggedLine(
      from,
      hit,
      Random(_seed + 99),
      roughness: .22,
      depth: 6,
    );
    final shown = (leader.length * easeIn(e)).ceil().clamp(0, leader.length);
    if (shown > 1) {
      drawBolt(
        canvas,
        polyline(leader.sublist(0, shown)),
        glow: lightningPalette[3],
        width: 1,
        opacity: .35 * e,
      );
    }
  }

  void _paintBolt(
    Canvas canvas,
    Offset from,
    Offset hit,
    double ts,
    double flick,
  ) {
    // A new shape for every flicker.
    final rnd = Random(_seed * 1000 + (ts / .08).floor());
    final main = jaggedLine(from, hit, rnd, roughness: .22, depth: 7);
    for (var i = 0; i < 4; i++) {
      final start = main[(main.length * (.2 + rnd.nextDouble() * .5)).floor()];
      final end =
          start +
          polar(
            pi / 2 + (rnd.nextDouble() - .5) * 1.8,
            50 + rnd.nextDouble() * 70,
          );
      drawBolt(
        canvas,
        polyline(jaggedLine(start, end, rnd, roughness: .3, depth: 4)),
        glow: lightningPalette[3],
        width: 2.8,
        opacity: flick * .85,
      );
    }
    drawBolt(
      canvas,
      polyline(main),
      glow: lightningPalette[2],
      width: 6.5,
      opacity: flick,
    );
  }

  void _paintImpact(
    Canvas canvas,
    FxContext ctx,
    Offset hit,
    double ts,
    double flick,
  ) {
    canvas
      ..save()
      ..clipRRect(ctx.rrect(side));
    canvas.drawRect(
      ctx.rect(side),
      Paint()..color = lightningPalette[1].withValues(alpha: .3 * flick),
    );
    drawGlow(
      canvas,
      hit,
      150,
      Colors.black,
      opacity: .5 * span(ts, .05, .15) * (1 - span(ts, .4, 1.2)),
      core: .1,
    );
    canvas.restore();

    final glow = 1 - span(ts, 0, .8);
    drawGlow(
      canvas,
      hit,
      120,
      lightningPalette[2],
      opacity: .85 * glow,
      core: .2,
    );
    final k = span(ts, 0, .45);
    if (k < 1) {
      canvas.drawCircle(
        hit,
        20 + 170 * easeOut(k),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8 * (1 - k) + 1
          ..color = Colors.white.withValues(alpha: .8 * (1 - k)),
      );
    }
  }

  void _paintSparks(Canvas canvas, Offset hit, double ts) {
    for (final s in _sparks) {
      final age = ts - s.delay;
      final f = age / s.life;
      if (f < 0 || f > 1) continue;
      final pos = hit + s.offsetAt(age, gravity: 760, drag: 2);
      final prev = hit + s.offsetAt(max(0, age - .03), gravity: 760, drag: 2);
      canvas.drawLine(
        prev,
        pos,
        Paint()
          ..color = lightningPalette[s.colorIndex].withValues(alpha: 1 - f)
          ..strokeWidth = s.size * (1 - f * .5)
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _paintArcs(Canvas canvas, FxContext ctx, double ts) {
    final fade = 1 - span(ts, .65, 1.15);
    if (ts < .05 || fade <= 0) return;
    final rect = ctx.rect(side).deflate(12);
    canvas
      ..save()
      ..clipRRect(ctx.rrect(side));
    final frame = (ts / .06).floor();
    for (var i = 0; i < 4; i++) {
      final rnd = Random(frame * 7 + i * 101 + _seed);
      final a = Offset(
        rect.left + rnd.nextDouble() * rect.width,
        rect.top + rnd.nextDouble() * rect.height,
      );
      final b =
          a + polar(rnd.nextDouble() * 2 * pi, 40 + rnd.nextDouble() * 60);
      drawBolt(
        canvas,
        polyline(jaggedLine(a, b, rnd, roughness: .35, depth: 4)),
        glow: lightningPalette[3],
        width: 1.2,
        opacity: .9 * fade,
      );
    }
    canvas.restore();
  }
}
