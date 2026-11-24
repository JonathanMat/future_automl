import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_transitions.dart';

/// Thin rounded bar (XP, confidence).
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
    final v = value.clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        return SizedBox(
          height: height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(height),
                ),
              ),
              AnimatedContainer(
                duration: AppTransitions.fast,
                width: w * v,
                decoration: BoxDecoration(
                  color: gradient == null ? color : null,
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(height),
                ),
              ),
              if (marker != null)
                Positioned(
                  left: w * marker!.clamp(0.0, 1.0) - 1,
                  top: -4,
                  bottom: -4,
                  child: Container(
                    width: 2,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
