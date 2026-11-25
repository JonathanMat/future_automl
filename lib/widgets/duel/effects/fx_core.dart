import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../services/audio/sfx_service.dart';
import 'fx_plan.dart';

export '../../../services/audio/sfx_service.dart' show SfxSound;
export 'fx_plan.dart' show FxSide;

/// Where the two cameras are, in the effect layer's coordinates.
class FxContext {
  const FxContext({
    required this.size,
    required this.top,
    required this.bottom,
    this.pixelRatio = 1,
  });

  final Size size;
  final Rect top;
  final Rect bottom;

  /// Device pixels per logical pixel, for effects baked into images.
  final double pixelRatio;

  static const feedRadius = 26.0;

  Rect rect(FxSide side) => side == FxSide.top ? top : bottom;

  RRect rrect(FxSide side) =>
      RRect.fromRectAndRadius(rect(side), const Radius.circular(feedRadius));

  Offset center(FxSide side) => rect(side).center;

  /// Just inside the edge of [side] that faces the other camera.
  Offset nearEdge(FxSide side, {double inset = 22}) {
    final r = rect(side);
    return side == FxSide.top
        ? Offset(r.center.dx, r.bottom - inset)
        : Offset(r.center.dx, r.top + inset);
  }

  /// Between the two cameras.
  Offset get middle => Offset(
    (top.center.dx + bottom.center.dx) / 2,
    (top.bottom + bottom.top) / 2,
  );
}

/// A point that is resolved when painting, so layout changes are followed.
typedef FxPoint = Offset Function(FxContext ctx);

/// One animated piece of an effect, with its own start time on the
/// effect's timeline (seconds).
abstract class FxLayer {
  FxLayer({required this.start, required this.duration});

  final double start;
  final double duration;

  double get end => start + duration;

  /// [t] is the time in seconds since this layer started.
  void paint(Canvas canvas, FxContext ctx, double t);
}

/// A moment something lands: shakes the screen, buzzes the phone and, for
/// [damage], shows the red flash and "−1" on [side].
class FxImpact {
  const FxImpact({
    required this.time,
    this.side,
    this.damage = false,
    this.shake = 8,
  });

  final double time;

  /// Null for a hit in the middle (a clash).
  final FxSide? side;
  final bool damage;

  /// Shake strength in pixels.
  final double shake;
}

/// A sound effect that starts at [time] on the effect's timeline.
class FxCue {
  const FxCue(this.time, this.sound, {this.volume = 1});

  final double time;
  final SfxSound sound;
  final double volume;
}

/// A complete effect: layers plus the impacts and sounds on its timeline.
class SpellFx {
  SpellFx({
    required this.layers,
    this.impacts = const [],
    this.sounds = const [],
  });

  final List<FxLayer> layers;
  final List<FxImpact> impacts;

  /// Sounds can ring on after [duration]; they don't keep the effect alive.
  final List<FxCue> sounds;

  /// Damage text stays this long after an impact.
  static const damageTime = 1.3;

  double get duration {
    var d = 0.0;
    for (final l in layers) {
      d = max(d, l.end);
    }
    for (final i in impacts) {
      d = max(d, i.time + (i.damage ? damageTime : 0.5));
    }
    return d;
  }
}

// ---------------------------------------------------------------------------
// Timing helpers
// ---------------------------------------------------------------------------

double clamp01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);

/// 0 before [from], 1 after [to], linear in between.
double span(double t, double from, double to) =>
    clamp01((t - from) / (to - from));

double easeOut(double x) => 1 - pow(1 - x, 3).toDouble();
double easeIn(double x) => x * x;
double easeInOut(double x) => x < .5 ? 2 * x * x : 1 - pow(-2 * x + 2, 2) / 2;

double easeOutBack(double x) {
  const c1 = 1.70158, c3 = c1 + 1;
  return 1 + c3 * pow(x - 1, 3) + c1 * pow(x - 1, 2);
}

/// Fades in over [fadeIn], holds, fades out over the last [fadeOut].
double envelope(
  double t,
  double length, {
  double fadeIn = .1,
  double fadeOut = .3,
}) {
  if (t < 0 || t > length) return 0;
  return min(span(t, 0, fadeIn), 1 - span(t, length - fadeOut, length));
}

// ---------------------------------------------------------------------------
// Geometry
// ---------------------------------------------------------------------------

Offset bezier(Offset a, Offset c, Offset b, double t) =>
    a * ((1 - t) * (1 - t)) + c * (2 * (1 - t) * t) + b * (t * t);

/// Control point that bends the line a→b sideways by [bend] pixels.
Offset bendControl(Offset a, Offset b, double bend) {
  final d = b - a;
  final len = d.distance;
  if (len == 0) return a;
  final normal = Offset(-d.dy, d.dx) / len;
  return (a + b) / 2 + normal * bend;
}

Offset polar(double angle, double radius) =>
    Offset(cos(angle) * radius, sin(angle) * radius);

/// A jagged line from [a] to [b] (midpoint displacement), for lightning.
List<Offset> jaggedLine(
  Offset a,
  Offset b,
  Random rnd, {
  double roughness = .28,
  int depth = 6,
}) {
  var points = [a, b];
  var displace = (b - a).distance * roughness;
  for (var i = 0; i < depth; i++) {
    final next = <Offset>[points.first];
    for (var j = 0; j < points.length - 1; j++) {
      final p = points[j], q = points[j + 1];
      final d = q - p;
      final len = d.distance;
      final normal = len == 0 ? Offset.zero : Offset(-d.dy, d.dx) / len;
      next
        ..add((p + q) / 2 + normal * ((rnd.nextDouble() * 2 - 1) * displace))
        ..add(q);
    }
    points = next;
    displace *= .5;
  }
  return points;
}

Path polyline(List<Offset> points) {
  final path = Path();
  if (points.isEmpty) return path;
  path.moveTo(points.first.dx, points.first.dy);
  for (final p in points.skip(1)) {
    path.lineTo(p.dx, p.dy);
  }
  return path;
}

/// A regular polygon (hexagon for [sides] = 6).
Path polygon(Offset c, double radius, int sides, {double rotation = 0}) {
  final path = Path();
  for (var i = 0; i < sides; i++) {
    final p = c + polar(rotation + i * 2 * pi / sides, radius);
    i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
  }
  return path..close();
}

// ---------------------------------------------------------------------------
// Painting helpers
// ---------------------------------------------------------------------------

/// Soft round glow that fades to transparent.
void drawGlow(
  Canvas canvas,
  Offset p,
  double radius,
  Color color, {
  double opacity = 1,
  double core = 0,
}) {
  if (radius <= 0 || opacity <= 0) return;
  final a = clamp01(opacity);
  canvas.drawCircle(
    p,
    radius,
    Paint()
      ..shader = ui.Gradient.radial(
        p,
        radius,
        [
          color.withValues(alpha: a),
          color.withValues(alpha: a),
          color.withValues(alpha: 0),
        ],
        [0, core, 1],
      ),
  );
}

/// Bright electric stroke: wide blurred glow, coloured body, white core.
void drawBolt(
  Canvas canvas,
  Path path, {
  required Color glow,
  double width = 4,
  double opacity = 1,
}) {
  if (opacity <= 0) return;
  final a = clamp01(opacity);
  Paint stroke(double w, Color c) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = c;
  canvas
    ..drawPath(
      path,
      stroke(width * 5, glow.withValues(alpha: .35 * a))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, width * 2.5),
    )
    ..drawPath(path, stroke(width * 1.8, glow.withValues(alpha: .95 * a)))
    ..drawPath(path, stroke(width * .7, Colors.white.withValues(alpha: a)));
}

/// Text painted on the canvas (labels like "BEVROREN").
void drawLabel(
  Canvas canvas,
  String text,
  Offset center,
  TextStyle style, {
  double scale = 1,
  double opacity = 1,
}) {
  if (opacity <= 0) return;
  // Laying out text is slow: reuse painters across frames, and fade with
  // a small layer instead of a new style per opacity.
  final key = (text, style);
  final painter = _labels[key] ??= (TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
  )..layout());
  if (_labels.length > 48) _labels.remove(_labels.keys.first);

  final w = painter.width, h = painter.height;
  canvas
    ..save()
    ..translate(center.dx, center.dy)
    ..scale(scale);
  final fade = opacity < .99;
  if (fade) {
    canvas.saveLayer(
      Rect.fromLTWH(-w / 2 - 20, -h / 2 - 20, w + 40, h + 40),
      Paint()..color = Color.fromRGBO(0, 0, 0, clamp01(opacity)),
    );
  }
  painter.paint(canvas, Offset(-w / 2, -h / 2));
  if (fade) canvas.restore();
  canvas.restore();
}

final _labels = <(String, TextStyle), TextPainter>{};

/// A material icon painted on the canvas.
void drawIcon(
  Canvas canvas,
  IconData icon,
  Offset center,
  double size,
  Color color, {
  double opacity = 1,
}) {
  drawLabel(
    canvas,
    String.fromCharCode(icon.codePoint),
    center,
    TextStyle(
      fontFamily: icon.fontFamily,
      package: icon.fontPackage,
      fontSize: size,
      color: color,
      height: 1,
    ),
    opacity: opacity,
  );
}

// ---------------------------------------------------------------------------
// Particles
// ---------------------------------------------------------------------------

/// One particle of a burst. Its position is a pure function of time, so
/// any frame can be drawn without simulating the ones before it.
class FxParticle {
  FxParticle({
    required this.angle,
    required this.speed,
    required this.size,
    required this.life,
    required this.delay,
    required this.colorIndex,
    required this.spin,
  });

  final double angle;
  final double speed;
  final double size;
  final double life;
  final double delay;
  final int colorIndex;
  final double spin;

  /// Offset from the origin after [age] seconds, slowing down with drag
  /// and pulled down by [gravity].
  Offset offsetAt(double age, {double gravity = 0, double drag = 2.2}) {
    final dist = speed * (1 - exp(-drag * age)) / drag;
    return polar(angle, dist) + Offset(0, .5 * gravity * age * age);
  }
}

List<FxParticle> makeBurst(
  Random rnd,
  int count, {
  double minSpeed = 80,
  double maxSpeed = 400,
  double minSize = 2,
  double maxSize = 6,
  double minLife = .4,
  double maxLife = 1,
  double maxDelay = 0,
  int colors = 1,
  double direction = 0,
  double spread = 2 * pi,
}) {
  double between(double a, double b) => a + rnd.nextDouble() * (b - a);
  return [
    for (var i = 0; i < count; i++)
      FxParticle(
        angle: direction + (rnd.nextDouble() - .5) * spread,
        speed: between(minSpeed, maxSpeed),
        size: between(minSize, maxSize),
        life: between(minLife, maxLife),
        delay: rnd.nextDouble() * maxDelay,
        colorIndex: rnd.nextInt(colors),
        spin: between(-8, 8),
      ),
  ];
}

/// Fire colours from hot to cool.
const firePalette = [
  Color(0xFFFFFFFF),
  Color(0xFFFFE9A8),
  Color(0xFFFFC14D),
  Color(0xFFFF8A2A),
  Color(0xFFE8461E),
  Color(0xFF9E1B0E),
];

const icePalette = [
  Color(0xFFFFFFFF),
  Color(0xFFE6FAFF),
  Color(0xFFA8E8FF),
  Color(0xFF4FC3F7),
];

const lightningPalette = [
  Color(0xFFFFFFFF),
  Color(0xFFFFF4B8),
  Color(0xFFFFD23F),
  Color(0xFFB8E1FF),
];

const shieldPalette = [
  Color(0xFFFFFFFF),
  Color(0xFFDCD5FF),
  Color(0xFFB2A6FF),
  Color(0xFF8B7CFF),
];
