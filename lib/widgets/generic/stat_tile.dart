import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// Big number with a small label under it ("12 · Gewonnen").
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.value,
    required this.label,
    this.valueColor = AppColors.text,
    this.valueSize = 26,
    this.compact = false,
  });

  final String value;
  final String label;
  final Color valueColor;
  final double valueSize;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.all(compact ? 10 : 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(compact ? 16 : 18),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: AppTextStyles.display(valueSize, color: valueColor),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTextStyles.caption().copyWith(
                fontSize: compact ? 11 : 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Value + label without a card, for grids inside a card.
class InlineStat extends StatelessWidget {
  const InlineStat({
    super.key,
    required this.value,
    required this.label,
    this.valueColor = AppColors.text,
  });

  final String value;
  final String label;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: AppTextStyles.display(22, color: valueColor)),
          Text(label, style: AppTextStyles.caption()),
        ],
      ),
    );
  }
}
