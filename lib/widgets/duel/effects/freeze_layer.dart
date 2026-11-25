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
    this.seed = defaultSeed,
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

  // Geometry that depends on where it was hit, built on first paint.
  // The frost itself (edges, branches, crystals) comes from [FrostArt].
  Rect? _builtFor;
  late List<List<Offset>> _cracks;
  late List<_Shard> _shards;
  late List<({double x, double y, double speed, double size})> _flakes;

  /// Seeds used by the effects, so [FrostArt.prepare] can draw them early.
  static const defaultSeed = 4;
  static const reflectSeed = 13;

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
    final rnd = Random(seed + 1);

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
    final image = FrostArt.image(rect.size, ratio, seed);
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

/// The frozen look of a camera: frost along the edges, branches growing in
/// and small crystals, drawn once per camera size into an image.
///
/// Drawing it during the effect (hundreds of glowing lines) made phones
/// stutter at the moment of impact. [prepare] draws it in the background
/// before the duel; [image] is instant after that.
abstract final class FrostArt {
  static final _images = <String, ui.Image>{};
  static final _pending = <String, Future<void>>{};

  static String _key(Size size, double ratio, int seed) =>
      '${size.width.round()}x${size.height.round()}@$ratio#$seed';

  /// Draws the frost for a camera of [size] in the background, if it isn't
  /// ready yet. Safe to call more than once.
  static Future<void> prepare(Size size, double ratio, int seed) {
    if (size.width < 1 || size.height < 1) return Future.value();
    final key = _key(size, ratio, seed);
    if (_images.containsKey(key)) return Future.value();
    return _pending[key] ??= () async {
      final picture = _record(size, ratio, seed);
      final image = await picture.toImage(
        max(1, (size.width * ratio).ceil()),
        max(1, (size.height * ratio).ceil()),
      );
      picture.dispose();
      _images[key] = image;
      _pending.remove(key);
    }();
  }

  /// The frost image; drawn right now if [prepare] didn't run.
  static ui.Image image(Size size, double ratio, int seed) {
    final key = _key(size, ratio, seed);
    return _images[key] ??= () {
      final picture = _record(size, ratio, seed);
      final image = picture.toImageSync(
        max(1, (size.width * ratio).ceil()),
        max(1, (size.height * ratio).ceil()),
      );
      picture.dispose();
      return image;
    }();
  }

  static ui.Picture _record(Size size, double ratio, int seed) {
    final r = Offset.zero & size;
    final rnd = Random(seed);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(ratio);

    // Frost along the edges.
    const depth = 46.0;
    final white = Colors.white.withValues(alpha: .75);
    final clear = Colors.white.withValues(alpha: 0);
    void strip(Rect area, Offset from, Offset to) => canvas.drawRect(
      area,
      Paint()..shader = ui.Gradient.linear(from, to, [white, clear]),
    );
    strip(
      Rect.fromLTWH(0, 0, r.width, depth),
      r.topLeft,
      r.topLeft + const Offset(0, depth),
    );
    strip(
      Rect.fromLTWH(0, r.bottom - depth, r.width, depth),
      r.bottomLeft,
      r.bottomLeft - const Offset(0, depth),
    );
    strip(
      Rect.fromLTWH(0, 0, depth, r.height),
      r.topLeft,
      r.topLeft + const Offset(depth, 0),
    );
    strip(
      Rect.fromLTWH(r.right - depth, 0, depth, r.height),
      r.topRight,
      r.topRight - const Offset(depth, 0),
    );

    // Branches growing in from the edges, all in one path: one blur for the
    // glow instead of one per line.
    final branches = Path();
    void grow(Offset p, double angle, double len, int level) {
      if (level <= 0 || len < 4) return;
      final q = p + polar(angle, len);
      branches
        ..moveTo(p.dx, p.dy)
        ..lineTo(q.dx, q.dy);
      grow(q, angle + (rnd.nextDouble() - .5) * .6, len * .78, level - 1);
      if (rnd.nextDouble() < .85) {
        final side = rnd.nextBool() ? 1 : -1;
        grow(
          Offset.lerp(p, q, .5)!,
          angle + side * (.7 + rnd.nextDouble() * .5),
          len * .55,
          level - 2,
        );
      }
    }

    for (var i = 0; i < 26; i++) {
      final f = rnd.nextDouble();
      final (Offset p, double inward) = switch (i % 4) {
        0 => (Offset(f * r.width, 0), pi / 2),
        1 => (Offset(r.right, f * r.height), pi),
        2 => (Offset(f * r.width, r.bottom), -pi / 2),
        _ => (Offset(0, f * r.height), 0.0),
      };
      grow(
        p,
        inward + (rnd.nextDouble() - .5) * 1.1,
        20 + rnd.nextDouble() * 30,
        5,
      );
      rnd.nextDouble(); // keeps the old layout's random sequence
    }
    canvas
      ..drawPath(
        branches,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFF8FDBFF).withValues(alpha: .55)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      )
      ..drawPath(
        branches,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round
          ..color = Colors.white.withValues(alpha: .9),
      );

    // Small six-armed crystals.
    final crystals = Path();
    for (var i = 0; i < 12; i++) {
      final c = Offset(rnd.nextDouble() * r.width, rnd.nextDouble() * r.height);
      final arm = 5 + rnd.nextDouble() * 9;
      rnd.nextDouble();
      for (var k = 0; k < 6; k++) {
        final tip = c + polar(k * pi / 3, arm);
        crystals
          ..moveTo(c.dx, c.dy)
          ..lineTo(tip.dx, tip.dy);
      }
    }
    canvas.drawPath(
      crystals,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = Colors.white.withValues(alpha: .85),
    );

    return recorder.endRecording();
  }
}
