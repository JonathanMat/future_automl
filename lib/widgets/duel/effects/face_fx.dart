import 'dart:math';

import 'package:flutter/material.dart';

import '../../../models/face_shape.dart';
import '../../../models/game_rules.dart';
import '../../../models/spell_info.dart';
import 'fx_core.dart';
import 'fx_plan.dart';

/// What happens to the face of the player who got hit.
enum FaceFxKind {
  none,

  /// Ice: frost grows over the face from the cheeks, blue lips, icicles on
  /// the eyebrows, glazed eyes.
  frozen,

  /// Fire: soot on the cheeks, a glowing edge, smoke and embers rising.
  burnt,

  /// Lightning: a white flash, eyes glowing, sparks crawling over the face.
  shocked,

  /// Shield bash: stars circling the head, spinning eyes.
  dizzy,
}

/// The face effects of one round: on the loser's face after the hit, and
/// the winner's eyes lighting up in their spell's colour as they cast.
class FaceFxPlan {
  const FaceFxPlan({
    required this.kind,
    required this.loser,
    required this.hitTime,
    this.winnerSpell,
  });

  static const none = FaceFxPlan(
    kind: FaceFxKind.none,
    loser: null,
    hitTime: 0,
  );

  final FaceFxKind kind;
  final FxSide? loser;

  /// When the spell hits the loser, on the effect's timeline (seconds).
  final double hitTime;

  /// For the winner's glowing eyes.
  final Spell? winnerSpell;

  FxSide? get winner => loser?.other;

  static FaceFxPlan forRound(FxPlan plan, SpellFx? fx) {
    final loser = plan.loser;
    if (loser == null) return none;
    final kind = switch (plan.kind) {
      FxKind.freeze => FaceFxKind.frozen,
      FxKind.fireball => FaceFxKind.burnt,
      FxKind.lightning || FxKind.lightningBreaksShield => FaceFxKind.shocked,
      FxKind.shieldReflect =>
        plan.reflected == Spell.ijs ? FaceFxKind.frozen : FaceFxKind.burnt,
      FxKind.shieldBash => FaceFxKind.dizzy,
      _ => FaceFxKind.none,
    };
    if (kind == FaceFxKind.none) return none;
    final hit = fx?.impacts
        .where((i) => i.damage && i.side == loser)
        .map((i) => i.time)
        .fold<double?>(null, (a, b) => a == null ? b : min(a, b));
    return FaceFxPlan(
      kind: kind,
      loser: loser,
      hitTime: hit ?? 0.8,
      winnerSpell: plan.spell,
    );
  }
}

/// Draws the face effects for one camera.
///
/// [time] is on the effect's timeline (seconds since the spells were
/// revealed); [face] is already laid out on this camera.
class FaceFxPainter extends CustomPainter {
  FaceFxPainter({
    required this.face,
    required this.plan,
    required this.side,
    required this.time,
    this.debug = false,
  });

  final FaceGeometry face;
  final FaceFxPlan plan;
  final FxSide side;
  final double time;
  final bool debug;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    if (side == plan.winner) _powerEyes(canvas);
    if (side == plan.loser) {
      final hit = time - plan.hitTime;
      if (hit >= 0) _rim(canvas, hit);
      if (hit >= 0) {
        switch (plan.kind) {
          case FaceFxKind.frozen:
            _frozen(canvas, hit);
          case FaceFxKind.burnt:
            _burnt(canvas, hit);
          case FaceFxKind.shocked:
            _shocked(canvas, hit);
          case FaceFxKind.dizzy:
            _dizzy(canvas, hit);
          case FaceFxKind.none:
            break;
        }
      }
    }
    if (debug) _debugPoints(canvas);
    canvas.restore();
  }

  double get _w => face.width;

  /// A soft edge around the face where it shows through the spell, so it
  /// melts into the frost / smoke / glow instead of looking cut out.
  void _rim(Canvas canvas, double hit) {
    final a = span(hit, .08, .45);
    final (Color color, double strength) = switch (plan.kind) {
      FaceFxKind.frozen => (const Color(0xFFEAF7FF), .95),
      FaceFxKind.burnt => (const Color(0xFF2A1A12), .7),
      FaceFxKind.shocked => (
        const Color(0xFFFFE066),
        .8 * (1 - span(hit, 2.6, 3.4)),
      ),
      _ => (Colors.transparent, 0.0),
    };
    if (a * strength <= 0) return;
    canvas.drawPath(
      face.ovalPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _w * .07
        ..color = color.withValues(alpha: a * strength)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, _w * .035),
    );
  }

  // ---------------------------------------------------------------------------
  // Winner: eyes light up in the spell's colour while casting.

  void _powerEyes(Canvas canvas) {
    final spell = plan.winnerSpell;
    if (spell == null) return;
    // Bright while the spell leaves, then a steady glow to the end.
    final a = span(time, 0, .18) * (1 - .55 * span(time, .55, .95));
    if (a <= 0) return;
    final color = spell.color;
    for (final eye in [face.eyeA, face.eyeB]) {
      final r = eye.radius;
      canvas.drawCircle(
        eye.center,
        r * 3.2,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: .75 * a),
              color.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: eye.center, radius: r * 3.2)),
      );
      canvas.drawCircle(
        eye.center,
        r * .7,
        Paint()..color = Colors.white.withValues(alpha: .9 * a),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Ice

  void _frozen(Canvas canvas, double hit) {
    final grow = easeOut(span(hit, 0, 1.1));
    final oval = face.ovalPath;
    final bounds = face.bounds;

    canvas.save();
    canvas.clipPath(oval);

    // The skin turns cold: a pale blue wash, strongest at the edges.
    canvas.drawRect(
      bounds.inflate(4),
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFBFE6FF).withValues(alpha: .2 * grow),
            const Color(0xFF8CCBFF).withValues(alpha: .42 * grow),
          ],
          stops: const [.45, 1],
        ).createShader(bounds)
        ..blendMode = BlendMode.screen,
    );

    // Frost spreading out from both cheeks and the forehead.
    for (final origin in [face.cheekA, face.cheekB, face.forehead]) {
      final r = _w * (.08 + .62 * grow);
      canvas.drawCircle(
        origin,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [
              Colors.white.withValues(alpha: .4 * grow),
              const Color(0xFFDDF3FF).withValues(alpha: .18 * grow),
              Colors.white.withValues(alpha: 0),
            ],
            stops: const [0, .6, 1],
          ).createShader(Rect.fromCircle(center: origin, radius: r)),
      );
    }

    // Ice crystals: branching lines growing from the same spots.
    final rnd = Random(7);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: .75 * grow);
    for (final origin in [face.cheekA, face.cheekB, face.forehead]) {
      for (var i = 0; i < 9; i++) {
        final angle = rnd.nextDouble() * 2 * pi;
        final length = _w * (.12 + rnd.nextDouble() * .3) * grow;
        final end = origin + polar(angle, length);
        line.strokeWidth = max(1, _w * .006);
        canvas.drawLine(origin, end, line);
        // Two side branches, like frost on a window.
        for (final side in [-1, 1]) {
          final at = .35 + rnd.nextDouble() * .4;
          final from = Offset.lerp(origin, end, at)!;
          final branch = polar(angle + side * .7, length * .35);
          line.strokeWidth = max(.8, _w * .004);
          canvas.drawLine(from, from + branch, line);
        }
      }
    }
    canvas.restore();

    // Blue lips: recoloured, so they keep their shading.
    canvas.drawPath(
      face.lipsPath,
      Paint()
        ..color = const Color(0xFF4F7DFF).withValues(alpha: .85 * grow)
        ..blendMode = BlendMode.color,
    );
    canvas.drawPath(
      face.lipsPath,
      Paint()..color = const Color(0xFFCFE6FF).withValues(alpha: .22 * grow),
    );

    // Glazed eyes.
    for (final eye in [face.eyeA, face.eyeB]) {
      final r = eye.radius * 1.05;
      canvas.drawCircle(
        eye.center,
        r,
        Paint()..color = const Color(0xFFE6F7FF).withValues(alpha: .5 * grow),
      );
      canvas.drawCircle(
        eye.center + Offset(-r * .35, -r * .35),
        r * .28,
        Paint()..color = Colors.white.withValues(alpha: .9 * grow),
      );
    }

    // Icicles hanging from the eyebrows, frost on top.
    final icicles = easeOutBack(span(hit, .35, 1.2));
    final down = -face.up;
    for (final brow in [face.browA, face.browB]) {
      for (var i = 0; i < brow.length; i++) {
        final p = brow[i];
        canvas.drawCircle(
          p,
          _w * .018,
          Paint()
            ..color = Colors.white.withValues(alpha: .8 * grow)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, _w * .01),
        );
        if (i.isOdd || icicles <= 0) continue;
        final len = _w * (.05 + .03 * (i % 3)) * icicles;
        final across = Offset(-down.dy, down.dx) * (_w * .012);
        final tip = p + down * len;
        canvas.drawPath(
          Path()
            ..moveTo(p.dx - across.dx, p.dy - across.dy)
            ..lineTo(p.dx + across.dx, p.dy + across.dy)
            ..lineTo(tip.dx, tip.dy)
            ..close(),
          Paint()
            ..shader = LinearGradient(
              colors: [
                Colors.white.withValues(alpha: .95),
                const Color(0xFF9FD8FF).withValues(alpha: .6),
              ],
            ).createShader(Rect.fromPoints(p, tip)),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Fire

  void _burnt(Canvas canvas, double hit) {
    final soot = easeOut(span(hit, 0, .35));
    final glow = 1 - span(hit, .3, 2.4);
    final oval = face.ovalPath;

    // Hot glowing edge right after the hit.
    if (glow > 0) {
      canvas.drawPath(
        oval,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _w * .09
          ..color = const Color(0xFFFF7A1A).withValues(alpha: .55 * glow)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, _w * .06),
      );
    }

    // Soot smudges, blurred, inside the face.
    canvas.save();
    canvas.clipPath(oval);
    final rnd = Random(11);
    final spots = [
      face.cheekA,
      face.cheekB,
      face.forehead,
      Offset.lerp(face.noseTip, face.cheekA, .5)!,
      Offset.lerp(face.chin, face.cheekB, .45)!,
    ];
    for (final spot in spots) {
      for (var i = 0; i < 3; i++) {
        final p = spot + polar(rnd.nextDouble() * 2 * pi, _w * .05 * i);
        final r = _w * (.07 + rnd.nextDouble() * .06);
        canvas.drawCircle(
          p,
          r,
          Paint()
            ..color = const Color(0xFF1A0F08).withValues(alpha: .38 * soot)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * .7),
        );
      }
    }
    // Warm, reddened skin.
    canvas.drawRect(
      face.bounds,
      Paint()
        ..color = const Color(0xFFFF6A2A).withValues(alpha: .16 * soot)
        ..blendMode = BlendMode.overlay,
    );
    canvas.restore();

    // Smoke curling up from the head.
    final up = face.up;
    final top = face.foreheadTop;
    final smoke = Random(23);
    for (var i = 0; i < 12; i++) {
      final delay = smoke.nextDouble() * 1.2;
      final life = 1.6 + smoke.nextDouble() * .8;
      final local = (hit - delay) % (life + .4);
      if (hit < delay || local > life) continue;
      final k = local / life;
      final sideways = Offset(-up.dy, up.dx);
      final start =
          top +
          sideways * ((smoke.nextDouble() - .5) * _w * .8) -
          up * _w * .05;
      final p =
          start + up * (_w * .9 * k) + sideways * (sin(k * 5 + i) * _w * .08);
      final r = _w * (.05 + .14 * k);
      canvas.drawCircle(
        p,
        r,
        Paint()
          ..color = const Color(
            0xFF5A5450,
          ).withValues(alpha: .42 * soot * sin(k * pi))
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * .6),
      );
    }

    // Embers floating up from the edge of the face.
    final pts = face.oval;
    final ember = Random(31);
    for (var i = 0; i < 18; i++) {
      final from = pts[ember.nextInt(pts.length)];
      final delay = ember.nextDouble() * 1.4;
      final local = hit - delay;
      if (local < 0 || local > 1.1) continue;
      final k = local / 1.1;
      final p =
          from + up * (_w * .45 * k) + Offset(sin(k * 9 + i) * _w * .03, 0);
      canvas.drawCircle(
        p,
        max(1.2, _w * .012) * (1 - k * .5),
        Paint()
          ..color = Color.lerp(
            const Color(0xFFFFE08A),
            const Color(0xFFFF5A1A),
            k,
          )!.withValues(alpha: 1 - k)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Lightning

  void _shocked(Canvas canvas, double hit) {
    final oval = face.ovalPath;

    // The flash of the strike.
    final flash = 1 - span(hit, 0, .22);
    if (flash > 0) {
      canvas.drawPath(
        oval,
        Paint()
          ..color = Colors.white.withValues(alpha: .75 * flash)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, _w * .05),
      );
    }

    final on = span(hit, 0, .1) * (1 - span(hit, 2.6, 3.4));
    if (on <= 0) return;

    // Glowing eyes, flickering.
    final step = (hit * 14).floor();
    final flicker = .7 + .3 * Random(step).nextDouble();
    for (final eye in [face.eyeA, face.eyeB]) {
      final r = eye.radius;
      canvas.drawCircle(
        eye.center,
        r * 3.4,
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFFFFF6C0).withValues(alpha: .95 * on * flicker),
              const Color(0xFFFFD23F).withValues(alpha: .55 * on * flicker),
              const Color(0xFFFFD23F).withValues(alpha: 0),
            ],
            stops: const [0, .3, 1],
          ).createShader(Rect.fromCircle(center: eye.center, radius: r * 3.4)),
      );
      canvas.drawCircle(
        eye.center,
        r * .8,
        Paint()..color = Colors.white.withValues(alpha: on),
      );
    }

    // Sparks crawling over the face: new zigzags every few frames.
    canvas.save();
    canvas.clipPath(oval);
    final pts = face.oval;
    final rnd = Random(step * 31 + 5);
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = max(3, _w * .02)
      ..color = const Color(0xFFFFE066).withValues(alpha: .55 * on)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, _w * .015);
    final core = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = max(1.2, _w * .006)
      ..color = Colors.white.withValues(alpha: .95 * on);
    for (var i = 0; i < 3; i++) {
      final a = pts[rnd.nextInt(pts.length)];
      final b = Offset.lerp(
        pts[rnd.nextInt(pts.length)],
        face.center,
        .3 + rnd.nextDouble() * .4,
      )!;
      final path = Path()..moveTo(a.dx, a.dy);
      const segments = 7;
      final dir = b - a;
      final normal = Offset(-dir.dy, dir.dx) / max(dir.distance, 1);
      for (var s = 1; s < segments; s++) {
        final p =
            Offset.lerp(a, b, s / segments)! +
            normal * ((rnd.nextDouble() - .5) * _w * .12);
        path.lineTo(p.dx, p.dy);
      }
      path.lineTo(b.dx, b.dy);
      canvas
        ..drawPath(path, glow)
        ..drawPath(path, core);
    }
    canvas.restore();
  }

  // ---------------------------------------------------------------------------
  // Shield bash

  void _dizzy(Canvas canvas, double hit) {
    final on = easeOutBack(span(hit, 0, .4)) * (1 - span(hit, 3.0, 3.6));
    if (on <= 0) return;
    final up = face.up;
    final sideways = Offset(-up.dy, up.dx);
    final rx = _w * .55 * on, ry = _w * .13 * on;
    // A ring around the top of the head; kept inside the camera when the
    // head is near the top edge.
    var center = face.foreheadTop + up * (_w * .03);
    final room = ry + _w * .09;
    if (center.dy < room) center = Offset(center.dx, room);
    const count = 5;
    final spin = hit * 3.2;

    // Back half first (smaller, dimmer), so stars pass behind the head.
    final stars = <({Offset p, double depth})>[];
    for (var i = 0; i < count; i++) {
      final a = spin + i * 2 * pi / count;
      final p = center + sideways * (cos(a) * rx) + up * (sin(a) * ry);
      stars.add((p: p, depth: sin(a)));
    }
    stars.sort((x, y) => y.depth.compareTo(x.depth));
    for (final s in stars) {
      final front = s.depth < 0;
      final r = _w * (front ? .075 : .055);
      _star(
        canvas,
        s.p,
        r,
        spin * 2,
        const Color(0xFFFFD23F).withValues(alpha: front ? 1 : .6),
      );
    }

    // Spinning spirals over the eyes.
    final spiral = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = max(1.5, _w * .012)
      ..color = Colors.white.withValues(alpha: .9 * on);
    for (final eye in [face.eyeA, face.eyeB]) {
      final path = Path();
      const turns = 2.6;
      for (var k = 0; k <= 60; k++) {
        final f = k / 60;
        final a = -spin * 2 + f * turns * 2 * pi;
        final p = eye.center + polar(a, eye.radius * 1.3 * f);
        k == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, spiral);
    }
  }

  static void _star(
    Canvas canvas,
    Offset c,
    double r,
    double rotation,
    Color color,
  ) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final a = rotation - pi / 2 + i * pi / 5;
      final p = c + polar(a, i.isEven ? r : r * .45);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas
      ..drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: color.a * .6)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * .5),
      )
      ..drawPath(path, Paint()..color = color);
  }

  void _debugPoints(Canvas canvas) {
    final dot = Paint()..color = const Color(0xFF00E5FF);
    for (final p in face.points) {
      canvas.drawCircle(p, 1.2, dot);
    }
    canvas.drawPath(
      face.ovalPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = const Color(0xFF00E5FF),
    );
  }

  @override
  bool shouldRepaint(FaceFxPainter old) =>
      old.time != time || old.face != face || old.plan != plan;
}
