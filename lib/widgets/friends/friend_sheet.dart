import 'package:flutter/material.dart';

import '../../services/social/friends_backend.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../generic/avatar_tile.dart';
import '../generic/chunky_button.dart';
import '../generic/crossed_swords_icon.dart';
import '../generic/player_name.dart';
import '../generic/stat_tile.dart';

/// Bottom sheet for one friend: their record, "Duel" and, tucked away at
/// the bottom, "Verwijder als vriend".
Future<void> showFriendSheet(
  BuildContext context, {
  required Friend friend,
  required VoidCallback? onChallenge,
  required VoidCallback onRemove,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) {
      final games = friend.wins + friend.losses;
      final rate = games == 0 ? 0 : (friend.wins * 100 / games).round();
      void close(VoidCallback action) {
        Navigator.of(sheetContext).pop();
        action();
      }

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: AvatarTile(name: friend.name, size: 72)),
              const SizedBox(height: 12),
              PlayerName(
                name: friend.name,
                tag: friend.tag,
                style: AppTextStyles.display(26),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: StatTile(
                      compact: true,
                      valueSize: 20,
                      value: '${friend.wins}',
                      label: 'Gewonnen',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatTile(
                      compact: true,
                      valueSize: 20,
                      value: '${friend.losses}',
                      label: 'Verloren',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatTile(
                      compact: true,
                      valueSize: 20,
                      value: '$rate%',
                      label: 'Winrate',
                      valueColor: AppColors.gold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              ChunkyButton(
                label: 'DUEL ${friend.name.toUpperCase()}',
                iconBuilder: (color, size) =>
                    CrossedSwordsIcon(color: color, size: size + 4),
                height: 58,
                fontSize: 20,
                onPressed: onChallenge == null
                    ? null
                    : () => close(onChallenge),
              ),
              const SizedBox(height: 6),
              TextButton.icon(
                onPressed: () => close(onRemove),
                style: TextButton.styleFrom(foregroundColor: AppColors.redSoft),
                icon: const Icon(Icons.person_remove_rounded, size: 18),
                label: const Text('Verwijder als vriend'),
              ),
            ],
          ),
        ),
      );
    },
  );
}
