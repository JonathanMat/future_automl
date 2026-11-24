import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// Small tinted label: "KLAAR", "WIN 3–1", "LIVE".
class PillBadge extends StatelessWidget {
  const PillBadge({
    super.key,
    required this.label,
    this.color = AppColors.green,
    this.icon,
    this.solid = false,
  });

  final String label;
  final Color color;
  final IconData? icon;

  /// Dark translucent background (on video) instead of a tint.
  final bool solid;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: solid ? AppColors.overlay : color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: solid ? AppColors.text : color),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body(
                solid ? 11 : 12,
                weight: FontWeight.w900,
                color: solid ? AppColors.text : color,
                letterSpacing: solid ? 1 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
