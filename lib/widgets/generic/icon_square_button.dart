import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// 44×44 icon button (back, settings).
class IconSquareButton extends StatelessWidget {
  const IconSquareButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color = AppColors.textMuted,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.borderStrong),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox.square(
            dimension: 44,
            child: Icon(icon, color: color, size: 22, semanticLabel: tooltip),
          ),
        ),
      ),
    );
  }
}
