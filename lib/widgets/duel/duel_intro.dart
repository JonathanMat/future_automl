import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/extensions.dart';
import '../../utils/player_tag.dart';
import '../generic/avatar_tile.dart';
import 'effects/fx_core.dart';

/// One side of the intro.
class IntroPlayer {
  const IntroPlayer({required this.name, this.tag, this.subtitle});

  final String name;
  final String? tag;

  /// e.g. "LVL 7" or "Jij 3–1".
  final String? subtitle;
}

/// "VS" intro before the first round: both players' panels slam together
/// on a diagonal, lightning crackles along the seam, "VS" smashes in, then
/// everything slides away to reveal the duel.
///
/// The backend delays the first countdown by `GameConfig.introLead`, so
/// this never covers the moment you have to make your gesture.
class DuelIntro extends StatefulWidget {
  const DuelIntro({
    super.key,
    required this.me,
    required this.opponent,
    required this.onDone,
  });

  final IntroPlayer me;
  final IntroPlayer opponent;
  final VoidCallback onDone;

  static const duration = Duration(milliseconds: 2700);

  @override
  State<DuelIntro> createState() => _DuelIntroState();
}

class _DuelIntroState extends State<DuelIntro>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: DuelIntro.duration)
    ..addListener(_onTick)
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone();
    });

  bool _slammed = false;
  bool _vsLanded = false;

  /// Seconds on the intro's clock.
  double get _t => _c.value * DuelIntro.duration.inMilliseconds / 1000;

  static const _slam = .36;
  static const _vsLand = .58;
  static const _exit = 2.2;

  @override
  void initState() {
    super.initState();
    _c.forward();
  }

  void _onTick() {
    if (!_slammed && _t >= _slam) {
      _slammed = true;
      HapticFeedback.heavyImpact();
    }
    if (!_vsLanded && _t >= _vsLand) {
      _vsLanded = true;
      HapticFeedback.mediumImpact();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${widget.opponent.name} tegen ${widget.me.name}',
      // Shown on top of the screen, outside the Scaffold: give the text a
      // Material so it gets the normal text style.
      child: Material(
        type: MaterialType.transparency,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = _t;
            final size = MediaQuery.sizeOf(context);

            // Panels: in fast, a slow drift, out fast.
            final enter = easeOut(span(t, .02, _slam));
            final leave = easeIn(span(t, _exit, 2.62));
            final drift = 14 * span(t, _slam, _exit);
            final topDx = (1 - enter) * size.width + drift - leave * size.width;
            final bottomDx =
                -(1 - enter) * size.width - drift + leave * size.width;

            // Screen shake after the slam.
            final k = span(t, _slam, _slam + .35);
            final shake = k > 0 && k < 1
                ? Offset(sin(k * 70) * 12 * (1 - k), cos(k * 53) * 8 * (1 - k))
                : Offset.zero;

            final dim = span(t, 0, .12) * (1 - span(t, 2.35, 2.7));

            return Transform.translate(
              offset: shake,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(
                    color: AppColors.backdrop.withValues(alpha: .94 * dim),
                  ),
                  CustomPaint(
                    painter: _IntroPainter(
                      t: t,
                      topDx: topDx,
                      bottomDx: bottomDx,
                      topColor: widget.opponent.name.avatarColor,
                      bottomColor: widget.me.name.avatarColor,
                    ),
                  ),
                  _PlayerBlock(
                    player: widget.opponent,
                    alignRight: true,
                    top: size.height * .17,
                    dx: topDx * 1.15,
                  ),
                  _PlayerBlock(
                    player: widget.me,
                    alignRight: false,
                    top: size.height * .63,
                    dx: bottomDx * 1.15,
                  ),
                  _Vs(t: t, slam: _slam, land: _vsLand, exit: _exit),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PlayerBlock extends StatelessWidget {
  const _PlayerBlock({
    required this.player,
    required this.alignRight,
    required this.top,
    required this.dx,
  });

  final IntroPlayer player;
  final bool alignRight;
  final double top;
  final double dx;

  @override
  Widget build(BuildContext context) {
    final tag = PlayerTag.format(player.tag);
    final text = Column(
      crossAxisAlignment: alignRight
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          player.name.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.display(34).copyWith(
            height: 1,
            shadows: const [
              Shadow(
                color: Colors.black54,
                offset: Offset(0, 4),
                blurRadius: 8,
              ),
            ],
          ),
        ),
        if (tag.isNotEmpty || player.subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            [if (tag.isNotEmpty) tag, ?player.subtitle].join('  ·  '),
            style: AppTextStyles.body(
              13,
              weight: FontWeight.w900,
              color: Colors.white.withValues(alpha: .75),
              letterSpacing: 1,
            ),
          ),
        ],
      ],
    );
    final avatar = AvatarTile(name: player.name, size: 92);
    return Positioned(
      left: 24,
      right: 24,
      top: top,
      child: Transform.translate(
        offset: Offset(dx, 0),
        child: Row(
          mainAxisAlignment: alignRight
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: alignRight
              ? [Flexible(child: text), const SizedBox(width: 16), avatar]
              : [avatar, const SizedBox(width: 16), Flexible(child: text)],
        ),
      ),
    );
  }
}

/// The golden "VS" that smashes in on the seam.
class _Vs extends StatelessWidget {
  const _Vs({
    required this.t,
    required this.slam,
    required this.land,
    required this.exit,
  });

  final double t;
  final double slam;
  final double land;
  final double exit;

  @override
  Widget build(BuildContext context) {
    final inK = span(t, slam, land);
    if (inK <= 0) return const SizedBox.shrink();
    final out = span(t, exit, 2.55);
    final scale =
        (3.2 - 2.2 * Curves.easeOutBack.transform(inK)) *
        (1 + .08 * sin(max(0, t - land) * 9) * (1 - out)) *
        (1 + .6 * out);
    final opacity = (span(t, slam, slam + .08) * (1 - out)).clamp(0.0, 1.0);
    final ready = span(t, 1.25, 1.55) * (1 - span(t, exit, 2.4));

    return Center(
      child: Opacity(
        opacity: opacity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.scale(
              scale: scale,
              child: SizedBox.square(
                dimension: 130,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Transform.rotate(
                      angle: t * 1.4,
                      child: CustomPaint(
                        size: const Size.square(130),
                        painter: _VsRingPainter(),
                      ),
                    ),
                    Text(
                      'VS',
                      style:
                          AppTextStyles.display(
                            64,
                            color: AppColors.goldNumber,
                          ).copyWith(
                            height: 1,
                            shadows: const [
                              Shadow(
                                color: AppColors.goldNumberShadow,
                                offset: Offset(0, 4),
                              ),
                              Shadow(
                                color: AppColors.goldNumberDeep,
                                offset: Offset(0, 8),
                              ),
                            ],
                          ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            Opacity(
              opacity: ready,
              child: Text(
                'MAAK JE KLAAR',
                style: AppTextStyles.body(
                  14,
                  weight: FontWeight.w900,
                  color: AppColors.textSoft,
                  letterSpacing: 4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VsRingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    canvas.drawCircle(
      c,
      r * .92,
      Paint()
        ..shader = ui.Gradient.radial(c, r, [
          AppColors.backdrop,
          AppColors.hexInner,
        ]),
    );
    // Spiked ring.
    final spikes = Path();
    for (var i = 0; i < 24; i++) {
      final a = i * pi / 12;
      final rr = i.isEven ? r : r * .86;
      final p = c + Offset(cos(a), sin(a)) * rr;
      i == 0 ? spikes.moveTo(p.dx, p.dy) : spikes.lineTo(p.dx, p.dy);
    }
    spikes.close();
    canvas
      ..drawPath(
        spikes,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..shader = ui.Gradient.linear(c - Offset(r, r), c + Offset(r, r), [
            AppColors.goldLight,
            AppColors.goldNumberShadow,
          ]),
      )
      ..drawCircle(
        c,
        r * .74,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = AppColors.gold.withValues(alpha: .6),
      );
  }

  @override
  bool shouldRepaint(_VsRingPainter old) => false;
}

/// The two diagonal panels, the seam with its lightning, sparks and embers.
class _IntroPainter extends CustomPainter {
  _IntroPainter({
    required this.t,
    required this.topDx,
    required this.bottomDx,
    required this.topColor,
    required this.bottomColor,
  });

  final double t;
  final double topDx;
  final double bottomDx;
  final Color topColor;
  final Color bottomColor;

  static const _slam = .36;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    // The seam: a diagonal through the middle.
    final left = Offset(0, h * .56);
    final right = Offset(w, h * .44);

    void panel(bool top, double dx, Color color) {
      final path = top
          ? (Path()
              ..moveTo(-w, 0)
              ..lineTo(w * 2, 0)
              ..lineTo(w * 2, right.dy - (left.dy - right.dy))
              ..lineTo(right.dx, right.dy)
              ..lineTo(left.dx, left.dy)
              ..lineTo(-w, left.dy + (left.dy - right.dy))
              ..close())
          : (Path()
              ..moveTo(-w, h)
              ..lineTo(w * 2, h)
              ..lineTo(w * 2, right.dy - (left.dy - right.dy))
              ..lineTo(right.dx, right.dy)
              ..lineTo(left.dx, left.dy)
              ..lineTo(-w, left.dy + (left.dy - right.dy))
              ..close());
      canvas
        ..save()
        ..translate(dx, 0)
        ..clipPath(path);
      // Colour fading into the dark away from the seam.
      final seamY = (left.dy + right.dy) / 2;
      canvas.drawRect(
        Rect.fromLTWH(-w, 0, w * 3, h),
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(0, top ? 0 : h),
            Offset(0, seamY),
            [
              Color.lerp(color, AppColors.backdrop, .88)!,
              Color.lerp(color, AppColors.backdrop, .55)!,
              Color.lerp(color, Colors.white, .12)!,
            ],
            [0, .7, 1],
          ),
      );
      // Speed lines running along the seam.
      final dir = (right - left) / (right - left).distance;
      final normal = Offset(-dir.dy, dir.dx) * (top ? -1.0 : 1.0);
      final lines = Paint()
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: .07);
      for (var i = 0; i < 14; i++) {
        final off = 30.0 + i * 34;
        final run = ((t * 900 + i * 173) % (w * 1.6)) - w * .3;
        final a = left + normal * off + dir * run;
        canvas.drawLine(a, a + dir * (60 + (i % 3) * 40), lines);
      }
      canvas.restore();

      // Glowing edge on the seam.
      canvas
        ..save()
        ..translate(dx, 0)
        ..drawLine(
          left,
          right,
          Paint()
            ..strokeWidth = 6
            ..color = color.withValues(alpha: .9)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        )
        ..restore();
    }

    panel(true, topDx, topColor);
    panel(false, bottomDx, bottomColor);

    final ts = t - _slam;
    if (ts < 0 || t > 2.3) return;

    // Lightning along the seam, flickering.
    final flicker = ts < .45 ? 1.0 : (ts < 1.6 ? .35 + .3 * sin(t * 40) : 0.0);
    if (flicker > 0) {
      final rnd = Random((t / .05).floor());
      drawBolt(
        canvas,
        polyline(jaggedLine(left, right, rnd, roughness: .04, depth: 6)),
        glow: const Color(0xFFFFE680),
        width: ts < .3 ? 4 : 2.2,
        opacity: flicker,
      );
    }

    // White flash on impact.
    final flash = 1 - span(ts, 0, .25);
    if (flash > 0) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = Colors.white.withValues(alpha: .7 * flash),
      );
    }

    // Sparks bursting from the middle of the seam.
    final mid = Offset.lerp(left, right, .5)!;
    final burst = span(ts, 0, .9);
    if (burst > 0 && burst < 1) {
      final rnd = Random(4);
      for (var i = 0; i < 60; i++) {
        final a = rnd.nextDouble() * 2 * pi;
        final speed = 200 + rnd.nextDouble() * 500;
        final age = ts;
        final dist = speed * (1 - exp(-3 * age)) / 3;
        final p =
            mid + Offset(cos(a), sin(a)) * dist + Offset(0, 120 * age * age);
        final prev =
            mid +
            Offset(cos(a), sin(a)) *
                (speed * (1 - exp(-3 * max(0, age - .03))) / 3);
        canvas.drawLine(
          prev,
          p,
          Paint()
            ..strokeWidth = 2.5 * (1 - burst)
            ..strokeCap = StrokeCap.round
            ..color = (i.isEven ? AppColors.goldLight : Colors.white)
                .withValues(alpha: 1 - burst),
        );
      }
      canvas.drawCircle(
        mid,
        30 + 260 * easeOut(burst),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10 * (1 - burst) + 1
          ..color = Colors.white.withValues(alpha: .7 * (1 - burst)),
      );
    }

    // Embers drifting up while it holds.
    final embers = span(ts, .2, .5) * (1 - span(t, 2.0, 2.3));
    if (embers > 0) {
      final rnd = Random(9);
      for (var i = 0; i < 26; i++) {
        final x = rnd.nextDouble() * w;
        final speed = 40 + rnd.nextDouble() * 70;
        final y = h - ((ts * speed + rnd.nextDouble() * h) % h);
        canvas.drawCircle(
          Offset(x + sin(ts * 2 + i) * 10, y),
          1.5 + rnd.nextDouble() * 2,
          Paint()..color = AppColors.goldLight.withValues(alpha: .5 * embers),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_IntroPainter old) => true;
}
