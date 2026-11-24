import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_transitions.dart';

/// Thin rounded bar (XP, confidence).
///
/// Painted rather than built with a LayoutBuilder, so it also works inside
/// an IntrinsicHeight (the result screen's reward cards).
class ProgressBar extends StatelessWidget {
  const ProgressBar({
    super.key,
    required this.value,
    this.height = 8,
    this.color = AppColors.violet,
    this.gradient,
    this.background = AppColors.track,
    this.marker,
  });

  /// 0–1.
  final double value;
  final double height;
  final Color color;
  final Gradient? gradient;
  final Color background;

  /// Optional threshold line at this position (0–1).
  final double? marker;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value.clamp(0.0, 1.0)),
      duration: AppTransitions.fast,
      builder: (context, v, _) => SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _BarPainter(
            value: v,
            color: color,
            gradient: gradient,
            background: background,
            marker: marker?.clamp(0.0, 1.0),
          ),
        ),
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  _BarPainter({
    required this.value,
    required this.color,
    required this.gradient,
    required this.background,
    required this.marker,
  });

  final double value;
  final Color color;
  final Gradient? gradient;
  final Color background;
  final double? marker;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(size.height);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, radius),
      Paint()..color = background,
    );
    if (value > 0) {
      final fill = Rect.fromLTWH(0, 0, size.width * value, size.height);
      final paint = Paint();
      if (gradient != null) {
        paint.shader = gradient!.createShader(fill);
      } else {
        paint.color = color;
      }
      canvas.drawRRect(RRect.fromRectAndRadius(fill, radius), paint);
    }
    if (marker case final m?) {
      final x = size.width * m;
      canvas.drawRRect(
        RRect.fromLTRBR(
          x - 1,
          -4,
          x + 1,
          size.height + 4,
          const Radius.circular(1),
        ),
        Paint()..color = Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.value != value ||
      old.color != color ||
      old.gradient != gradient ||
      old.background != background ||
      old.marker != marker;
}
