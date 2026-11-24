import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/extensions.dart';

/// Rounded square with the player's initial and a "3D" bottom edge.
class AvatarTile extends StatelessWidget {
  const AvatarTile({
    super.key,
    required this.name,
    this.size = 52,
    this.color,
    this.circle = false,
    this.ringColor,
  });

  final String name;
  final double size;
  final Color? color;
  final bool circle;

  /// Optional ring around a circular avatar (podium).
  final Color? ringColor;

  @override
  Widget build(BuildContext context) {
    final bg = color ?? name.avatarColor;
    final radius = circle ? size / 2 : size * 0.31;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            if (ringColor != null) ...[
              const BoxShadow(color: AppColors.background, spreadRadius: 3),
              BoxShadow(color: ringColor!, spreadRadius: 5),
            ] else
              BoxShadow(
                color: AppColors.shadowOf(bg),
                offset: Offset(0, size >= 50 ? 4 : 3),
              ),
          ],
        ),
        child: Text(name.initial, style: AppTextStyles.display(size * 0.45)),
      ),
    );
  }
}
