import 'package:flutter/material.dart';

import '../../models/duel_summary.dart';
import '../../models/spell_info.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/extensions.dart';
import '../generic/stat_tile.dart';

/// "JOUW DUEL": hits, favourite spell, confidence, fastest cast.
class DuelStatsCard extends StatelessWidget {
  const DuelStatsCard({super.key, required this.summary});

  final DuelSummary summary;

  @override
  Widget build(BuildContext context) {
    final fav = summary.favoriteSpell;
    final conf = summary.averageConfidence;
    final fastest = summary.fastestCast;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('JOUW DUEL', style: AppTextStyles.overline()),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 14,
            crossAxisSpacing: 10,
            childAspectRatio: 3,
            children: [
              InlineStat(
                value: '${summary.hits} / ${summary.rounds.length}',
                label: 'Rake spreuken',
              ),
              InlineStat(
                value: fav?.label ?? '–',
                label: 'Favoriete spreuk',
                valueColor: fav?.color ?? AppColors.text,
              ),
              InlineStat(
                value: conf?.percent ?? 'Getikt',
                label: 'Gem. zekerheid',
              ),
              InlineStat(
                value: fastest?.secondsLabel ?? '–',
                label: 'Snelste cast',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
