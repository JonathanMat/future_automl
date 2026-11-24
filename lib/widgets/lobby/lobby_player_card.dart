import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/extensions.dart';
import '../generic/avatar_tile.dart';
import '../generic/pill_badge.dart';

/// One seat in the lobby. Shows a waiting state while [name] is null.
class LobbyPlayerCard extends StatelessWidget {
  const LobbyPlayerCard({
    super.key,
    required this.name,
    required this.subtitle,
    this.online = true,
    this.invitedName,
  });

  final String? name;

  /// While [name] is null: the friend you challenged, shown greyed out.
  final String? invitedName;
  final String subtitle;
  final bool online;

  @override
  Widget build(BuildContext context) {
    final waiting = name == null;
    final invited = waiting ? invitedName : null;
    final accent = waiting ? AppColors.track : name!.avatarColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent, width: 2),
      ),
      child: Column(
        children: [
          if (invited != null)
            SizedBox.square(
              dimension: 64,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Opacity(
                    opacity: 0.45,
                    child: AvatarTile(name: invited, size: 64),
                  ),
                  const SizedBox.square(
                    dimension: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: AppColors.text,
                    ),
                  ),
                ],
              ),
            )
          else if (waiting)
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: AppColors.textMuted,
                ),
              ),
            )
          else
            AvatarTile(name: name!, size: 64),
          const SizedBox(height: 10),
          Text(
            name ?? invited ?? 'Wachten…',
            style: AppTextStyles.body(
              16,
              weight: FontWeight.w900,
              color: waiting ? AppColors.textMuted : AppColors.text,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(subtitle, style: AppTextStyles.caption()),
          const SizedBox(height: 10),
          if (invited != null)
            const PillBadge(label: 'UITGENODIGD', color: AppColors.gold)
          else if (waiting)
            const PillBadge(label: 'NIET KLAAR', color: AppColors.textMuted)
          else if (!online)
            const PillBadge(
              label: 'OFFLINE',
              color: AppColors.redSoft,
              icon: Icons.wifi_off_rounded,
            )
          else
            const PillBadge(label: 'KLAAR', icon: Icons.check_rounded),
        ],
      ),
    );
  }
}
