import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/friend_record.dart';
import '../../navigators/room_flow.dart';
import '../../providers/friends_provider.dart';
import '../../providers/game_provider.dart';
import '../../providers/profile_provider.dart';
import '../../services/social/friends_backend.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_theme.dart';
import '../../widgets/friends/add_friend_button.dart';
import '../../widgets/friends/add_friend_row.dart';
import '../../widgets/friends/challenge_banner.dart';
import '../../widgets/friends/friend_request_banner.dart';
import '../../widgets/friends/friend_code_card.dart';
import '../../widgets/friends/friend_tile.dart';
import '../../widgets/friends/social_tiles.dart';
import '../../widgets/generic/app_bottom_nav.dart';
import '../../widgets/generic/chunky_button.dart';
import '../../widgets/generic/screen_header.dart';

/// Your friend code, friend requests (as a banner on top), friends (on the server) and the
/// people you recently dueled (on this phone).
class FriendsScreen extends StatelessWidget {
  const FriendsScreen({super.key});

  /// Runs a friend action and shows its message. Returns whether it worked.
  static Future<bool> _run(
    BuildContext context,
    Future<FriendActionResult> action,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final r = await action;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(r.message)));
    return r.ok;
  }

  Future<void> _confirmRemove(BuildContext context, Friend friend) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${friend.name} verwijderen?'),
        content: const Text(
          'Jullie staan dan niet meer op elkaars vriendenscorebord.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuleren'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.redSoft),
            child: const Text('Verwijderen'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await _run(context, context.read<FriendsProvider>().remove(friend));
  }

  @override
  Widget build(BuildContext context) {
    final recent = context.watch<ProfileProvider>().friends;
    final social = context.watch<FriendsProvider>();
    final busy = context.select<GameProvider, bool>((g) => g.busy);

    return Scaffold(
      bottomNavigationBar: const SafeArea(
        top: false,
        child: AppBottomNav(current: AppTab.friends),
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          children: [
            const ScreenHeader(title: 'Vrienden', onBack: null),
            const SizedBox(height: 16),
            const ChallengeBanner(padding: EdgeInsets.only(bottom: 16)),
            const FriendRequestBanner(padding: EdgeInsets.only(bottom: 16)),
            if (social.error != null && !social.isReady)
              _ErrorCard(
                message: social.error!,
                retrying: social.connecting,
                onRetry: social.connect,
              )
            else ...[
              FriendCodeCard(
                code: social.friendCode,
                name: context.watch<ProfileProvider>().profile.name,
                tag: social.myTag,
              ),
              const SizedBox(height: 10),
              AddFriendRow(
                enabled: social.isReady,
                onAdd: (code) => _run(context, social.addByCode(code)),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Deel je code. Zodra de ander je verzoek accepteert, '
                  'staan jullie op elkaars scorebord.',
                  style: AppTextStyles.caption(),
                ),
              ),
            ],
            const SizedBox(height: 22),
            Text('VRIENDEN', style: AppTextStyles.overline()),
            const SizedBox(height: 10),
            if (social.friends.isEmpty)
              _Empty(
                social.isReady
                    ? 'Nog geen vrienden.\nVoeg iemand toe met een vriendcode.'
                    : 'Vrienden laden…',
              )
            else
              for (final f in social.friends) ...[
                ServerFriendTile(
                  friend: f,
                  busy: social.isWorking(f.uid),
                  onRemove: () => _confirmRemove(context, f),
                  onChallenge: busy
                      ? null
                      : () => RoomFlow.challenge(context, f),
                ),
                const SizedBox(height: 8),
              ],
            if (recent.isNotEmpty) ...[
              const SizedBox(height: 22),
              Text('RECENT GESPEELD', style: AppTextStyles.overline()),
              const SizedBox(height: 10),
              for (final r in recent) ...[
                FriendTile(
                  friend: r,
                  isFriend: r.uid != null && social.isFriend(r.uid!),
                  trailing: _addButton(context, social, r),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ],
        ),
      ),
    );
  }

  /// Add-friend button next to a recent opponent. Gone once they are a
  /// friend (the tile shows a small friend icon instead).
  Widget? _addButton(
    BuildContext context,
    FriendsProvider social,
    FriendRecord r,
  ) {
    final uid = r.uid;
    if (uid == null || !social.isReady || uid == social.myUid) return null;
    if (social.isFriend(uid)) return null;
    final state = social.isWorking(uid)
        ? AddFriendState.working
        : social.requestSent(uid)
        ? AddFriendState.sent
        : social.requests.any((q) => q.fromUid == uid)
        ? AddFriendState.accept
        : AddFriendState.add;
    return AddFriendButton(
      state: state,
      name: r.name,
      onPressed: () => _run(context, social.addByUid(uid, r.name)),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 20),
    child: Column(
      children: [
        const Icon(Icons.group_outlined, size: 48, color: AppColors.trackOff),
        const SizedBox(height: 10),
        Text(
          text,
          textAlign: TextAlign.center,
          style: AppTextStyles.body(
            14,
            weight: FontWeight.w700,
            color: AppColors.textMuted,
          ),
        ),
      ],
    ),
  );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({
    required this.message,
    required this.retrying,
    required this.onRetry,
  });

  final String message;
  final bool retrying;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        message,
        textAlign: TextAlign.center,
        style: AppTextStyles.body(14, color: AppColors.redSoft),
      ),
      const SizedBox(height: 10),
      ChunkyButton(
        label: 'Opnieuw proberen',
        display: false,
        height: 48,
        style: ChunkyButtonStyle.secondary,
        loading: retrying,
        onPressed: onRetry,
      ),
    ],
  );
}
