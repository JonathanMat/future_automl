import 'package:flutter/material.dart';

import '../../services/social/friends_backend.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/player_tag.dart';
import '../generic/avatar_tile.dart';
import '../generic/chunky_button.dart';
import '../generic/crossed_swords_icon.dart';
import '../generic/player_name.dart';
import 'friend_sheet.dart';

/// Avatar, name, subtitle and trailing actions in a rounded row.
class _PlayerRow extends StatelessWidget {
  const _PlayerRow({
    required this.name,
    this.tag,
    required this.subtitle,
    required this.trailing,
    this.onTap,
  });

  final String name;
  final String? tag;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
          child: Row(
            children: [
              AvatarTile(name: name, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      label: PlayerTag.withName(name, tag),
                      excludeSemantics: true,
                      child: PlayerName(
                        name: name,
                        tag: tag,
                        style: AppTextStyles.body(15, weight: FontWeight.w900),
                      ),
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
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(12),
    child: SizedBox.square(
      dimension: 22,
      child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.gold),
    ),
  );
}

/// An incoming friend request with accept / decline.
class FriendRequestTile extends StatelessWidget {
  const FriendRequestTile({
    super.key,
    required this.request,
    required this.onAccept,
    required this.onDecline,
    this.busy = false,
  });

  final FriendRequest request;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return _PlayerRow(
      name: request.name,
      tag: request.tag,
      subtitle: 'Wil je vriend worden',
      trailing: busy
          ? const _Spinner()
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Weiger ${request.name}',
                  onPressed: onDecline,
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppColors.textMuted,
                  ),
                ),
                IconButton.filled(
                  tooltip: 'Accepteer ${request.name}',
                  onPressed: onAccept,
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.green,
                    foregroundColor: AppColors.greenInk,
                  ),
                  icon: const Icon(Icons.check_rounded),
                ),
              ],
            ),
    );
  }
}

/// A confirmed friend with their overall record and a remove action.
class ServerFriendTile extends StatelessWidget {
  const ServerFriendTile({
    super.key,
    required this.friend,
    required this.onRemove,
    this.onChallenge,
    this.busy = false,
  });

  final Friend friend;
  final VoidCallback onRemove;

  /// Null disables the duel button (e.g. while a room is opening).
  final VoidCallback? onChallenge;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final games = friend.wins + friend.losses;
    return _PlayerRow(
      name: friend.name,
      tag: friend.tag,
      subtitle: games == 0
          ? 'Nog geen duels gespeeld'
          : '${friend.wins} gewonnen · ${friend.losses} verloren',
      // Tap the row for their record and "Verwijder als vriend".
      onTap: busy
          ? null
          : () => showFriendSheet(
              context,
              friend: friend,
              onChallenge: onChallenge,
              onRemove: onRemove,
            ),
      trailing: busy
          ? const _Spinner()
          : SizedBox(
              width: 86,
              child: ChunkyButton(
                label: 'Duel',
                iconBuilder: (color, size) =>
                    CrossedSwordsIcon(color: color, size: size + 2),
                display: false,
                height: 38,
                semanticLabel: 'Daag ${friend.name} uit',
                onPressed: onChallenge,
              ),
            ),
    );
  }
}
