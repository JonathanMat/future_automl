import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'icon_square_button.dart';

/// Back button + title, as on the lobby and leaderboard screens.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.title,
    this.onBack,
    this.trailing,
  });

  final String title;

  /// Defaults to popping the route. Null hides the button when nothing
  /// can be popped.
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    final back =
        onBack ?? (canPop ? () => Navigator.of(context).maybePop() : null);
    return Row(
      children: [
        if (back != null) ...[
          IconSquareButton(
            icon: Icons.chevron_left_rounded,
            tooltip: 'Terug',
            color: AppColors.textSoft,
            onPressed: back,
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Semantics(
            header: true,
            child: Text(title, style: AppTextStyles.display(26)),
          ),
        ),
        ?trailing,
      ],
    );
  }
}
