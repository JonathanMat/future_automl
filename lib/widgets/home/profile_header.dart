import 'package:flutter/material.dart';

import '../../models/player_profile.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/constants.dart';
import '../generic/avatar_tile.dart';
import '../generic/icon_square_button.dart';
import '../generic/player_name.dart';
import '../generic/progress_bar.dart';

/// Avatar, name, level bar and the settings button.
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.profile,
    required this.onSettings,
    this.onOpen,
    this.tag,
  });

  final PlayerProfile profile;

  /// Public tag shown after the name ("#4821"), once signed in.
  final String? tag;
  final VoidCallback onSettings;

  /// Opens your profile page (tap on avatar, name or level).
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Semantics(
            button: onOpen != null,
            hint: onOpen != null ? 'Open je profiel' : null,
            child: InkWell(
              onTap: onOpen,
              borderRadius: BorderRadius.circular(16),
              child: Row(
                children: [
                  AvatarTile(name: profile.name, size: 52),
                  const SizedBox(width: 12),
                  Expanded(child: _details()),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        IconSquareButton(
          icon: Icons.settings_rounded,
          tooltip: 'Instellingen',
          onPressed: onSettings,
        ),
      ],
    );
  }

  Widget _details() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      PlayerName(
        name: profile.name,
        tag: tag,
        style: AppTextStyles.body(17, weight: FontWeight.w900),
      ),
      const SizedBox(height: 6),
      Semantics(
        label:
            'Level ${profile.level}, '
            '${profile.xpInLevel} van ${AppConstants.xpPerLevel} XP',
        excludeSemantics: true,
        child: Row(
          children: [
            Text(
              'LVL ${profile.level}',
              style: AppTextStyles.body(
                12,
                weight: FontWeight.w900,
                color: AppColors.lavender,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: ProgressBar(value: profile.levelProgress)),
            const SizedBox(width: 8),
            Text(
              '${profile.xpInLevel}/${AppConstants.xpPerLevel}',
              style: AppTextStyles.caption(),
            ),
          ],
        ),
      ),
    ],
  );
}
