import 'package:flutter/material.dart';

import '../../services/social/friends_backend.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/player_tag.dart';
import '../generic/avatar_tile.dart';
import '../generic/player_name.dart';

/// Avatar, name, subtitle and trailing actions in a rounded row.
class _PlayerRow extends StatelessWidget {
  const _PlayerRow({
    required this.name,
    this.tag,
    required this.subtitle,
    required this.trailing,
  });

  final String name;
  final String? tag;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
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

  /// Null disables the challenge button (e.g. while a room is opening).
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
      trailing: busy
          ? const _Spinner()
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton.filled(
                  tooltip: 'Daag ${friend.name} uit',
                  onPressed: onChallenge,
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.goldInk,
                  ),
                  icon: const Icon(Icons.bolt_rounded),
                ),
                PopupMenuButton<void>(
                  tooltip: 'Opties voor ${friend.name}',
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: AppColors.textMuted,
                  ),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      onTap: onRemove,
                      child: const Text('Verwijder als vriend'),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}
