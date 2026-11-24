import 'package:flutter/material.dart';

import '../../models/friend_record.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/extensions.dart';
import '../generic/avatar_tile.dart';

/// A recent opponent with your head-to-head record.
class FriendTile extends StatelessWidget {
  const FriendTile({super.key, required this.friend, this.trailing});

  final FriendRecord friend;

  /// E.g. an "add friend" button, shown after the record.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final ahead = friend.wins >= friend.losses;
    return Semantics(
      label:
          '${friend.name}: jij ${friend.wins} gewonnen, '
          '${friend.losses} verloren, laatst ${friend.lastPlayed.timeAgo()}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            AvatarTile(name: friend.name, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    friend.name,
                    style: AppTextStyles.body(15, weight: FontWeight.w900),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${friend.games} ${friend.games == 1 ? 'duel' : 'duels'} · '
                    '${friend.lastPlayed.timeAgo()}',
                    style: AppTextStyles.body(
                      12,
                      weight: FontWeight.w700,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${friend.wins}–${friend.losses}',
                  style: AppTextStyles.display(
                    18,
                    color: ahead ? AppColors.green : AppColors.redSoft,
                  ),
                ),
                Text(
                  'jij – ${friend.name.split(' ').first}',
                  style: AppTextStyles.caption(),
                ),
              ],
            ),
            if (trailing != null) ...[const SizedBox(width: 4), trailing!],
          ],
        ),
      ),
    );
  }
}
