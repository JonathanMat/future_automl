import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/badge.dart';
import '../../services/audio/sfx_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../generic/chunky_button.dart';
import 'badge_medal.dart';

/// Shows freshly unlocked badges one by one: the medal spins in, lands
/// with a burst of sparkles, light rays turn behind it and the text slides
/// up.
Future<void> showBadgeUnlocks(BuildContext context, List<BadgeDef> badges) {
  if (badges.isEmpty) return Future.value();
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Badge vrijgespeeld',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (_, _, _) => _BadgeUnlockOverlay(badges: badges),
    transitionBuilder: (_, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

class _BadgeUnlockOverlay extends StatefulWidget {
  const _BadgeUnlockOverlay({required this.badges});

  final List<BadgeDef> badges;

  @override
  State<_BadgeUnlockOverlay> createState() => _BadgeUnlockOverlayState();
}

class _BadgeUnlockOverlayState extends State<_BadgeUnlockOverlay>
    with TickerProviderStateMixin {
  /// One badge's entrance, 1.8 s.
  late final _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..addListener(_onTick);

  /// Rays and the idle float, forever.
  late final _idle = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  )..repeat();

  int _index = 0;
  bool _landed = false;

  /// When the medal lands. The badge sound's chord hits at the same moment
  /// (BADGE_LAND in tool/gen_sfx.py): change both together.
  static const _land = .42;

  BadgeDef get _badge => widget.badges[_index];

  @override
  void initState() {
    super.initState();
    _intro.forward();
    SfxService.instance.play(SfxSound.badgeUnlock);
  }

  void _onTick() {
    if (!_landed && _intro.value >= _land) {
      _landed = true;
      HapticFeedback.heavyImpact();
    }
  }

  void _next() {
    if (_index + 1 >= widget.badges.length) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _index++;
      _landed = false;
    });
    _intro.forward(from: 0);
    SfxService.instance.play(SfxSound.badgeUnlock);
  }

  @override
  void dispose() {
    _intro.dispose();
    _idle.dispose();
    super.dispose();
  }

  double _span(double t, double a, double b) =>
      ((t - a) / (b - a)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final count = widget.badges.length;
    return Material(
      type: MaterialType.transparency,
      child: AnimatedBuilder(
        animation: Listenable.merge([_intro, _idle]),
        builder: (context, _) {
          final t = _intro.value;
          final tier = _badge.tier;

          // Medal: spins in from far away, overshoots, settles.
          final fly = Curves.easeOutBack.transform(_span(t, .05, _land));
          final scale = .15 + .85 * fly;
          final spin =
              (1 - Curves.easeOutCubic.transform(_span(t, .05, _land))) *
              pi *
              3;
          final float = sin(_idle.value * 2 * pi * 4) * 5 * _span(t, .6, 1);
          final shine = _span(t, .55, .9);

          Widget fadeUp(double from, Widget child) {
            final k = Curves.easeOutCubic.transform(_span(t, from, from + .2));
            return Opacity(
              opacity: k,
              child: Transform.translate(
                offset: Offset(0, 24 * (1 - k)),
                child: child,
              ),
            );
          }

          return Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(
                color: Colors.black.withValues(
                  alpha:
                      .8 * _span(t, 0, .15) +
                      (_index > 0 ? .9 * (1 - _span(t, 0, .15)) : 0),
                ),
              ),
              CustomPaint(
                painter: _RaysPainter(
                  color: tier.glow,
                  turn: _idle.value,
                  strength: _span(t, _land - .05, _land + .15),
                ),
              ),
              CustomPaint(
                painter: _BurstPainter(
                  color: tier.glow,
                  light: tier.metal[0],
                  t: _span(t, _land, _land + .45),
                  seed: _index,
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      fadeUp(
                        .45,
                        Text(
                          count > 1
                              ? 'BADGE VRIJGESPEELD · ${_index + 1}/$count'
                              : 'BADGE VRIJGESPEELD',
                          style: AppTextStyles.overline(color: tier.metal[0]),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Transform.translate(
                        offset: Offset(0, float),
                        child: Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, .0012)
                            ..rotateY(spin)
                            ..scaleByDouble(scale, scale, 1, 1),
                          child: BadgeMedal(
                            badge: _badge,
                            size: 168,
                            shine: shine > 0 && shine < 1 ? shine : -1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      fadeUp(
                        .55,
                        Text(
                          _badge.title,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.display(34).copyWith(
                            shadows: [
                              Shadow(
                                color: tier.metal[2],
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      fadeUp(
                        .62,
                        Text(
                          _badge.description,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.body(
                            15,
                            weight: FontWeight.w700,
                            color: AppColors.textSoft,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      fadeUp(
                        .68,
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: tier.glow.withValues(alpha: .16),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: tier.glow.withValues(alpha: .5),
                            ),
                          ),
                          child: Text(
                            tier.label.toUpperCase(),
                            style: AppTextStyles.body(
                              11,
                              weight: FontWeight.w900,
                              color: tier.metal[0],
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                      fadeUp(
                        .78,
                        IgnorePointer(
                          ignoring: t < .78,
                          child: ChunkyButton(
                            label: _index + 1 < count
                                ? 'VOLGENDE'
                                : 'GEWELDIG!',
                            onPressed: _next,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Light rays turning slowly behind the medal.
class _RaysPainter extends CustomPainter {
  _RaysPainter({
    required this.color,
    required this.turn,
    required this.strength,
  });

  final Color color;
  final double turn;
  final double strength;

  @override
  void paint(Canvas canvas, Size size) {
    if (strength <= 0) return;
    final c = Offset(size.width / 2, size.height * .42);
    final r = size.longestSide * .7;
    canvas
      ..save()
      ..translate(c.dx, c.dy)
      ..rotate(turn * 2 * pi);
    const rays = 14;
    for (var i = 0; i < rays; i++) {
      final a = i * 2 * pi / rays;
      final path = Path()
        ..moveTo(0, 0)
        ..lineTo(cos(a - .09) * r, sin(a - .09) * r)
        ..lineTo(cos(a + .09) * r, sin(a + .09) * r)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: .38 * strength),
              color.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: Offset.zero, radius: r)),
      );
    }
    canvas
      ..drawCircle(
        Offset.zero,
        150,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: .5 * strength),
              color.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: Offset.zero, radius: 150)),
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_RaysPainter old) =>
      old.turn != turn || old.strength != strength || old.color != color;
}

/// Sparkles and a ring flying out when the medal lands.
class _BurstPainter extends CustomPainter {
  _BurstPainter({
    required this.color,
    required this.light,
    required this.t,
    required this.seed,
  });

  final Color color;
  final Color light;
  final double t;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;
    final c = Offset(size.width / 2, size.height * .42);
    final rnd = Random(seed + 7);
    final ease = Curves.easeOutCubic.transform(t);

    canvas.drawCircle(
      c,
      60 + 220 * ease,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10 * (1 - t) + 1
        ..color = light.withValues(alpha: .8 * (1 - t)),
    );

    for (var i = 0; i < 46; i++) {
      final a = rnd.nextDouble() * 2 * pi;
      final dist = (90 + rnd.nextDouble() * 220) * ease;
      final p = c + Offset(cos(a), sin(a)) * dist + Offset(0, 60 * t * t);
      final s = (2 + rnd.nextDouble() * 4) * (1 - t * .7);
      final paint = Paint()
        ..color = (i.isEven ? light : color).withValues(alpha: 1 - t);
      if (i % 3 == 0) {
        // Four-point star.
        final star = Path()
          ..moveTo(p.dx, p.dy - s * 2)
          ..lineTo(p.dx + s * .5, p.dy - s * .5)
          ..lineTo(p.dx + s * 2, p.dy)
          ..lineTo(p.dx + s * .5, p.dy + s * .5)
          ..lineTo(p.dx, p.dy + s * 2)
          ..lineTo(p.dx - s * .5, p.dy + s * .5)
          ..lineTo(p.dx - s * 2, p.dy)
          ..lineTo(p.dx - s * .5, p.dy - s * .5)
          ..close();
        canvas.drawPath(star, paint);
      } else {
        canvas.drawCircle(p, s * .6, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.t != t || old.seed != seed;
}
