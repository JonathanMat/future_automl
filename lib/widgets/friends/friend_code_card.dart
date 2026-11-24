import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../generic/app_card.dart';
import '../generic/player_name.dart';

/// Your own friend code, with a copy button. Shows a spinner while [code]
/// is null.
class FriendCodeCard extends StatelessWidget {
  const FriendCodeCard({super.key, required this.code, this.name, this.tag});

  final String? code;

  /// Your name and tag, shown as "Zo zien anderen je: Jan #4821".
  final String? name;
  final String? tag;

  Future<void> _copy(BuildContext context, String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Vriendcode $code gekopieerd.')));
  }

  @override
  Widget build(BuildContext context) {
    final code = this.code;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(18, 14, 12, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('JOUW VRIENDCODE', style: AppTextStyles.overline()),
                const SizedBox(height: 6),
                if (code == null)
                  const SizedBox(
                    height: 30,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppColors.gold,
                        ),
                      ),
                    ),
                  )
                else
                  Semantics(
                    label: 'Vriendcode ${code.split('').join(' ')}',
                    excludeSemantics: true,
                    child: Text(
                      code,
                      style: AppTextStyles.display(
                        28,
                        color: AppColors.goldNumber,
                      ).copyWith(letterSpacing: 5),
                    ),
                  ),
                if (code != null && name != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'Zo zien anderen je: ',
                        style: AppTextStyles.caption(),
                      ),
                      Flexible(
                        child: PlayerName(
                          name: name!,
                          tag: tag,
                          style: AppTextStyles.body(
                            13,
                            weight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (code != null)
            IconButton(
              tooltip: 'Kopieer vriendcode',
              onPressed: () => _copy(context, code),
              icon: const Icon(Icons.copy_rounded, color: AppColors.textSoft),
            ),
        ],
      ),
    );
  }
}
