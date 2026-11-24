import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../generic/app_card.dart';
import '../generic/copy_button.dart';

/// The 4-character room code with a copy button.
class RoomCodeCard extends StatelessWidget {
  const RoomCodeCard({super.key, required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final chars = code.split('');
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('KAMERCODE', style: AppTextStyles.overline()),
              ),
              CopyButton(
                text: code,
                label: 'Kopieer',
                tooltip: 'Kopieer kamercode',
                message: 'Kamercode $code gekopieerd.',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Semantics(
            label: 'Kamercode ${chars.join(' ')}',
            excludeSemantics: true,
            child: Row(
              children: [
                for (var i = 0; i < chars.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      height: 62,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(16),
                        border: const Border(
                          bottom: BorderSide(color: AppColors.track, width: 3),
                        ),
                      ),
                      child: Text(
                        chars[i],
                        style: AppTextStyles.display(34, color: AppColors.gold),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Deel de code met je tegenstander.',
            style: AppTextStyles.body(
              13,
              weight: FontWeight.w700,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
