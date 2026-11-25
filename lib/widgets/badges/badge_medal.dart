import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../models/badge.dart';
import '../../theme/app_colors.dart';

/// A hexagonal medal in the badge's metal, with its icon. Locked badges
/// are grey with a small lock.
class BadgeMedal extends StatelessWidget {
  const BadgeMedal({
    super.key,
    required this.badge,
    this.size = 72,
    this.unlocked = true,
    this.shine = -1,
  });

  final BadgeDef badge;
  final double size;
  final bool unlocked;

  /// Position of a light sweep across the medal, 0–1. Negative: none.
  final double shine;

  @override
  Widget build(BuildContext context) {
    Widget medal = SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _MedalPainter(tier: badge.tier, shine: shine, glow: unlocked),
        child: Center(
          child: Icon(
            badge.icon,
            size: size * .4,
            color: unlocked ? badge.tier.metal[0] : AppColors.textMuted,
            shadows: [
              Shadow(
                color: badge.tier.metal[2].withValues(alpha: .9),
                offset: Offset(0, size * .02),
                blurRadius: size * .03,
              ),
            ],
          ),
        ),
      ),
    );
    if (!unlocked) {
      medal = Stack(
        clipBehavior: Clip.none,
        children: [
          Opacity(
            opacity: .45,
            child: ColorFiltered(
              colorFilter: const ColorFilter.matrix([
                .33, .33, .33, 0, 0, //
                .33, .33, .33, 0, 0, //
                .33, .33, .33, 0, 0, //
                0, 0, 0, 1, 0,
              ]),
              child: medal,
            ),
          ),
          Positioned(
            right: size * .02,
            bottom: size * .04,
            child: Container(
              width: size * .32,
              height: size * .32,
              decoration: BoxDecoration(
                color: AppColors.surfaceRaised,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.background, width: 2),
              ),
              child: Icon(
                Icons.lock_rounded,
                size: size * .18,
                color: AppColors.textSoft,
              ),
            ),
          ),
        ],
      );
    }
    return Semantics(
      label: '${badge.title}${unlocked ? '' : ', nog niet vrijgespeeld'}',
      excludeSemantics: true,
      child: medal,
    );
  }
}

Path _hexagon(Offset c, double r) {
  final path = Path();
  for (var i = 0; i < 6; i++) {
    final a = -pi / 2 + i * pi / 3;
    final p = c + Offset(cos(a), sin(a)) * r;
    i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
  }
  return path..close();
}

class _MedalPainter extends CustomPainter {
  _MedalPainter({required this.tier, required this.shine, required this.glow});

  final BadgeTier tier;
  final double shine;
  final bool glow;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final metal = tier.metal;
    final outer = _hexagon(c, r * .98);
    final inner = _hexagon(c, r * .76);

    if (glow) {
      canvas.drawPath(
        outer,
        Paint()
          ..color = tier.glow.withValues(
            alpha: tier == BadgeTier.episch ? .55 : .35,
          )
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * .18),
      );
    }

    // Metal rim, lit from the top left.
    canvas
      ..drawPath(
        outer,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(c.dx - r, c.dy - r),
            Offset(c.dx + r, c.dy + r),
            [metal[0], metal[1], metal[2], metal[1]],
            [0, .35, .75, 1],
          ),
      )
      ..drawPath(
        outer,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * .04
          ..color = metal[2],
      );

    // Inner face: dark enamel with a glow of the tier colour.
    canvas
      ..drawPath(
        inner,
        Paint()
          ..shader = ui.Gradient.radial(c.translate(0, -r * .2), r * .9, [
            Color.lerp(metal[1], AppColors.surface, .55)!,
            AppColors.background,
          ]),
      )
      ..drawPath(
        inner,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * .035
          ..color = metal[0].withValues(alpha: .7),
      );

    // Light sweeping across.
    if (shine >= 0 && shine <= 1) {
      final x = c.dx - r * 1.6 + shine * r * 3.2;
      canvas
        ..save()
        ..clipPath(outer)
        ..drawRect(
          Offset.zero & size,
          Paint()
            ..shader = ui.Gradient.linear(
              Offset(x - r * .35, c.dy - r),
              Offset(x + r * .35, c.dy + r),
              [
                Colors.white.withValues(alpha: 0),
                Colors.white.withValues(alpha: .65),
                Colors.white.withValues(alpha: 0),
              ],
              [0, .5, 1],
            ),
        )
        ..restore();
    }
  }

  @override
  bool shouldRepaint(_MedalPainter old) =>
      old.tier != tier || old.shine != shine || old.glow != glow;
}
