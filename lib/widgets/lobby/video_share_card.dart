import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../generic/app_card.dart';

/// "Elkaar zien": whether the opponent's live video is shown during the duel.
class VideoShareCard extends StatelessWidget {
  const VideoShareCard({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

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
                  child: const Icon(
                    Icons.videocam_rounded,
                    color: AppColors.lavender,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Elkaar zien',
                        style: AppTextStyles.body(15, weight: FontWeight.w900),
                      ),
                      Text(
                        'Live video van je tegenstander tonen',
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
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              value
                  ? 'Aan: jullie zien elkaar live (peer-to-peer). Beelden worden '
                        'nergens opgeslagen, de spreuk wordt herkend op je eigen gsm.'
                  : 'Uit: je ziet je tegenstander als avatar. Je camera blijft '
                        'aan op je eigen gsm om je gebaren te herkennen.',
              style: AppTextStyles.body(
                12,
                weight: FontWeight.w700,
                color: AppColors.textMuted,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
