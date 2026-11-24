import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_transitions.dart';

/// Two-option pill switch ("Vrienden" / "Campus").
class SegmentedTabs extends StatelessWidget {
  const SegmentedTabs({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelected,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: Semantics(
                selected: i == selected,
                button: true,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => onSelected(i),
                    child: AnimatedContainer(
                      duration: AppTransitions.fast,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: i == selected
                            ? AppColors.surfaceRaised
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        labels[i],
                        style: AppTextStyles.body(
                          14,
                          weight: FontWeight.w900,
                          color: i == selected
                              ? AppColors.text
                              : AppColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
