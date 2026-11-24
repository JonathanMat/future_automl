import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'app_card.dart';

/// A setting with an icon, title, switch and a short note below that
/// explains the current choice.
class ToggleCard extends StatelessWidget {
  const ToggleCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.note,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  /// Shown under the switch, e.g. what "on" or "off" means.
  final String? note;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          MergeSemantics(
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceRaised,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: AppColors.lavender, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.body(15, weight: FontWeight.w900),
                      ),
                      Text(
                        subtitle,
                        style: AppTextStyles.body(
                          12,
                          weight: FontWeight.w700,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: value,
                  onChanged: onChanged,
                  activeThumbColor: Colors.white,
                  activeTrackColor: AppColors.green,
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: AppColors.trackOff,
                  trackOutlineColor: const WidgetStatePropertyAll(
                    Colors.transparent,
                  ),
                ),
              ],
            ),
          ),
          if (note != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                note!,
                style: AppTextStyles.body(
                  12,
                  weight: FontWeight.w700,
                  color: AppColors.textMuted,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
