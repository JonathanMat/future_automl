import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../theme/app_text_styles.dart';
import 'fx_core.dart';

/// Freezes one camera: frost spreads from the impact point, ice crystals
/// grow in from the edges, the image stays frozen for [hold] seconds
/// ("BEVROREN"), then it cracks and shatters into falling shards.
class FreezeLayer extends FxLayer {
  FreezeLayer({
    required super.start,
    required this.side,
    required this.impact,
    this.hold = 1.15,
    this.seed = 4,
  }) : super(duration: grow + hold + crack + shatter);

  static const grow = .45;
  static const crack = .18;
  static const shatter = .7;

  final FxSide side;
  final FxPoint impact;
  final double hold;
  final int seed;

  double get crackStart => grow + hold;
  double get shatterStart => crackStart + crack;

  // Geometry depends on the camera's size, so it is built on first paint.
  Rect? _builtFor;
  late List<_Segment> _frost;
  late List<({Offset p, double size, double order})> _crystals;
  late List<List<Offset>> _cracks;
  late List<_Shard> _shards;
  late List<({double x, double y, double speed, double size})> _flakes;

  /// Edge frost, branches and crystals, drawn once into an image: drawing
  /// hundreds of glowing lines every frame made phones stutter.
  ui.Image? _frostImage;
  double _bakedRatio = 0;

  @override
  void paint(Canvas canvas, FxContext ctx, double t) {
    final rect = ctx.rect(side);
    final hit = impact(ctx);
    if (_builtFor != rect) _build(rect, hit);

    if (t >= shatterStart) {
      _paintShards(canvas, t - shatterStart);
      return;
    }

    final rr = ctx.rrect(side);
    canvas
      ..save()
      ..clipRRect(rr);

    // Impact flash.
    final flash = 1 - span(t, 0, .18);
    if (flash > 0) {
      canvas.drawRect(
        rect,
        Paint()..color = Colors.white.withValues(alpha: .65 * flash),
      );
    }

    // Frost front spreading from the impact point.
    final g = easeOut(span(t, 0, grow));
    final reach = (rect.longestSide * 1.3) * g;
    if (reach > 1) {
      canvas.drawCircle(
        hit,
        reach,
        Paint()
          ..shader = ui.Gradient.radial(
            hit,
            reach,
            [
              const Color(0xFFBFEFFF).withValues(alpha: .5),
              const Color(0xFFDDF7FF).withValues(alpha: .55),
              Colors.white.withValues(alpha: g < 1 ? .85 : .55),
            ],
            [0, .85, 1],
          ),
      );
    }

    _paintFrost(canvas, rect, hit, ctx.pixelRatio, t);
    _paintShimmer(canvas, rect, t);
    _paintFlakes(canvas, rect, t);

    // Cracks before it breaks.
    final c = span(t, crackStart, shatterStart);
    if (c > 0) _paintCracks(canvas, c);

    canvas.restore();

    // Label.
    final pop = span(t, grow, grow + .3);
    if (pop > 0 && t < crackStart + .1) {
      final scale = .6 + .4 * easeOutBack(pop);
      final at = Offset(rect.center.dx, rect.center.dy + rect.height * .2);
      drawGlow(canvas, at, 90, icePalette[3], opacity: .45 * pop);
      drawIcon(
        canvas,
        Icons.ac_unit_rounded,
        at - const Offset(0, 34),
        30,
        Colors.white,
        opacity: pop,
      );
      drawLabel(
        canvas,
        'BEVROREN',
        at,
        AppTextStyles.display(30, color: Colors.white).copyWith(
          letterSpacing: 2,
          shadows: const [
            Shadow(color: Color(0xFF1769AA), offset: Offset(0, 3)),
          ],
        ),
        scale: scale,
        opacity: pop,
      );
    }
  }

  // -------------------------------------------------------------------------

  void _build(Rect rect, Offset hit) {
    _builtFor = rect;
    _frostImage?.dispose();
    _frostImage = null;
    final rnd = Random(seed);

    // Frost branches growing in from the edges.
    _frost = [];
    void grow(Offset p, double angle, double len, int depth, double order) {
      if (depth <= 0 || len < 4) return;
      final q = p + polar(angle, len);
      _frost.add(_Segment(p, q, order));
      grow(
        q,
        angle + (rnd.nextDouble() - .5) * .6,
        len * .78,
        depth - 1,
        order + .12,
      );
      if (rnd.nextDouble() < .85) {
        final side = rnd.nextBool() ? 1 : -1;
        grow(
          Offset.lerp(p, q, .5)!,
          angle + side * (.7 + rnd.nextDouble() * .5),
          len * .55,
          depth - 2,
          order + .1,
        );
      }
    }

    for (var i = 0; i < 26; i++) {
      final edge = i % 4;
      final f = rnd.nextDouble();
      final (Offset p, double inward) = switch (edge) {
        0 => (Offset(rect.left + f * rect.width, rect.top), pi / 2),
        1 => (Offset(rect.right, rect.top + f * rect.height), pi),
        2 => (Offset(rect.left + f * rect.width, rect.bottom), -pi / 2),
        _ => (Offset(rect.left, rect.top + f * rect.height), 0.0),
      };
      grow(
        p,
        inward + (rnd.nextDouble() - .5) * 1.1,
        20 + rnd.nextDouble() * 30,
        5,
        rnd.nextDouble() * .3,
      );
    }

    _crystals = [
      for (var i = 0; i < 12; i++)
        (
          p: Offset(
            rect.left + rnd.nextDouble() * rect.width,
            rect.top + rnd.nextDouble() * rect.height,
          ),
          size: 5 + rnd.nextDouble() * 9,
          order: .3 + rnd.nextDouble() * .6,
        ),
    ];

    _flakes = [
      for (var i = 0; i < 22; i++)
        (
          x: rnd.nextDouble(),
          y: rnd.nextDouble(),
          speed: 18 + rnd.nextDouble() * 30,
          size: 1.2 + rnd.nextDouble() * 2.2,
        ),
    ];

    // Points around the edge, in order, for cracks and shards.
    final perimeter = <Offset>[];
    const n = 14;
    for (var i = 0; i < n; i++) {
      final angle = -pi + (i + rnd.nextDouble() * .6) * 2 * pi / n;
      perimeter.add(_toEdge(rect, hit, angle));
    }
    _cracks = [
      for (var i = 0; i < 8; i++)
        jaggedLine(
          hit,
          perimeter[(i * n / 8).floor()],
          rnd,
          roughness: .12,
          depth: 4,
        ),
    ];

    _shards = [
      for (var i = 0; i < n; i++)
        _Shard.from([hit, perimeter[i], perimeter[(i + 1) % n]], hit, rnd),
    ];
  }

  /// Where a ray from [c] at [angle] leaves [r].
  static Offset _toEdge(Rect r, Offset c, double angle) {
    final d = polar(angle, 1);
    var best = double.infinity;
    if (d.dx > 0) best = min(best, (r.right - c.dx) / d.dx);
    if (d.dx < 0) best = min(best, (r.left - c.dx) / d.dx);
    if (d.dy > 0) best = min(best, (r.bottom - c.dy) / d.dy);
    if (d.dy < 0) best = min(best, (r.top - c.dy) / d.dy);
    return c + d * best;
  }

  void _paintFrost(
    Canvas canvas,
    Rect rect,
    Offset hit,
    double ratio,
    double t,
  ) {
    final reveal = span(t, .05, grow + .35);
    if (reveal <= 0) return;
    if (_frostImage == null || _bakedRatio != ratio) _bake(rect, ratio);
    final image = _frostImage!;
    final src = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    final paint = Paint()..filterQuality = FilterQuality.low;
    if (reveal >= 1) {
      canvas.drawImageRect(image, src, rect, paint);
      return;
    }
    // The frost grows with the front spreading from the impact.
    canvas
      ..save()
      ..clipPath(
        Path()..addOval(
          Rect.fromCircle(
            center: hit,
            radius: rect.longestSide * 1.3 * easeOut(reveal),
          ),
        ),
      )
      ..drawImageRect(image, src, rect, paint)
      ..restore();
  }

  void _bake(Rect rect, double ratio) {
    _frostImage?.dispose();
    final recorder = ui.PictureRecorder();
    final c = Canvas(recorder)
      ..scale(ratio)
      ..translate(-rect.left, -rect.top);
    _paintEdgeFrost(c, rect, 1);
    // Past 1 so every branch is fully grown.
    _paintFrostBranches(c, 2);
    final picture = recorder.endRecording();
    _frostImage = picture.toImageSync(
      max(1, (rect.width * ratio).ceil()),
      max(1, (rect.height * ratio).ceil()),
    );
    _bakedRatio = ratio;
    picture.dispose();
  }

  void _paintEdgeFrost(Canvas canvas, Rect r, double g) {
    if (g <= 0) return;
    const depth = 46.0;
    final white = Colors.white.withValues(alpha: .75 * g);
    final clear = Colors.white.withValues(alpha: 0);
    void strip(Rect area, Offset from, Offset to) => canvas.drawRect(
      area,
      Paint()..shader = ui.Gradient.linear(from, to, [white, clear]),
    );
    strip(
      Rect.fromLTWH(r.left, r.top, r.width, depth),
      r.topLeft,
      r.topLeft + const Offset(0, depth),
    );
    strip(
      Rect.fromLTWH(r.left, r.bottom - depth, r.width, depth),
      r.bottomLeft,
      r.bottomLeft - const Offset(0, depth),
    );
    strip(
      Rect.fromLTWH(r.left, r.top, depth, r.height),
      r.topLeft,
      r.topLeft + const Offset(depth, 0),
    );
    strip(
      Rect.fromLTWH(r.right - depth, r.top, depth, r.height),
      r.topRight,
      r.topRight - const Offset(depth, 0),
    );
  }

  void _paintFrostBranches(Canvas canvas, double progress) {
    if (progress <= 0) return;
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF8FDBFF).withValues(alpha: .5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: .9);
    for (final s in _frost) {
      final f = span(progress, s.order, s.order + .12);
      if (f <= 0) continue;
      final end = Offset.lerp(s.a, s.b, f)!;
      canvas
        ..drawLine(s.a, end, glow)
        ..drawLine(s.a, end, line);
    }
    for (final c in _crystals) {
      final f = span(progress, c.order, c.order + .15);
      if (f <= 0) continue;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = Colors.white.withValues(alpha: .85 * f);
      for (var i = 0; i < 6; i++) {
        canvas.drawLine(c.p, c.p + polar(i * pi / 3, c.size * f), paint);
      }
    }
  }

  void _paintShimmer(Canvas canvas, Rect r, double t) {
    if (t < grow) return;
    final k = ((t - grow) % 1.1) / 1.1;
    final x = r.left - r.width * .6 + k * r.width * 2.2;
    canvas.drawRect(
      r,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(x, r.top),
          Offset(x + 90, r.bottom),
          [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: .3),
            Colors.white.withValues(alpha: 0),
          ],
          [0, .5, 1],
        ),
    );
  }

  void _paintFlakes(Canvas canvas, Rect r, double t) {
    final a = span(t, grow * .5, grow);
    if (a <= 0) return;
    for (final f in _flakes) {
      final y = r.top + ((f.y * r.height + t * f.speed) % r.height);
      final x = r.left + f.x * r.width + sin(t * 2 + f.y * 9) * 6;
      canvas.drawCircle(
        Offset(x, y),
        f.size,
        Paint()..color = Colors.white.withValues(alpha: .8 * a),
      );
    }
  }

  void _paintCracks(Canvas canvas, double c) {
    for (final crack in _cracks) {
      final n = (crack.length * easeOut(c)).ceil().clamp(0, crack.length);
      if (n < 2) continue;
      final path = polyline(crack.sublist(0, n));
      canvas
        ..drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5
            ..strokeCap = StrokeCap.round
            ..color = const Color(0xFF4FC3F7).withValues(alpha: .45),
        )
        ..drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = Colors.white,
        );
    }
  }

  void _paintShards(Canvas canvas, double age) {
    final fade = 1 - span(age, .3, shatter);
    if (fade <= 0) return;
    for (final s in _shards) {
      final pos =
          s.centroid + s.velocity * age + Offset(0, 900 * age * age / 2);
      canvas
        ..save()
        ..translate(pos.dx, pos.dy)
        ..rotate(s.spin * age);
      final path = polyline(s.points)..close();
      canvas
        ..drawPath(
          path,
          Paint()..color = const Color(0xFFCFF4FF).withValues(alpha: .6 * fade),
        )
        ..drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = Colors.white.withValues(alpha: .9 * fade),
        )
        ..restore();
    }
    // Burst of light where it broke.
    drawGlow(
      canvas,
      _shards.first.origin,
      120,
      Colors.white,
      opacity: .7 * (1 - span(age, 0, .25)),
      core: .2,
    );
  }
}

class _Segment {
  const _Segment(this.a, this.b, this.order);

  final Offset a, b;

  /// When it grows, 0–1.
  final double order;
}

class _Shard {
  _Shard({
    required this.points,
    required this.centroid,
    required this.velocity,
    required this.spin,
    required this.origin,
  });

  factory _Shard.from(List<Offset> corners, Offset origin, Random rnd) {
    final centroid =
        corners.reduce((a, b) => a + b) / corners.length.toDouble();
    final out = centroid - origin;
    final dir = out.distance == 0 ? const Offset(0, -1) : out / out.distance;
    return _Shard(
      points: [for (final c in corners) c - centroid],
      centroid: centroid,
      velocity: dir * (140 + rnd.nextDouble() * 220) + const Offset(0, -140),
      spin: (rnd.nextDouble() - .5) * 9,
      origin: origin,
    );
  }

  /// Corners relative to [centroid].
  final List<Offset> points;
  final Offset centroid;
  final Offset velocity;
  final double spin;
  final Offset origin;
}
