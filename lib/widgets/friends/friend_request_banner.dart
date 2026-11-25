import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/friends_provider.dart';
import '../../providers/game_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../generic/avatar_tile.dart';
import '../generic/chunky_button.dart';
import '../generic/player_name.dart';

/// "Lotte wil je vriend worden" with Weiger / Accepteer, in the same
/// style as the duel challenge banner. Shows the first open friend
/// request; nothing when there is none. Used on Home, Vrienden and
/// Scorebord (never during a game).
class FriendRequestBanner extends StatelessWidget {
  const FriendRequestBanner({super.key, this.padding = EdgeInsets.zero});

  /// Space around the banner when it is shown.
  final EdgeInsetsGeometry padding;

  Future<void> _run(
    BuildContext context,
    Future<FriendActionResult> action,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final r = await action;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(r.message)));
  }

  @override
  Widget build(BuildContext context) {
    final social = context.watch<FriendsProvider>();
    final inRoom = context.select<GameProvider, bool>((g) => g.inRoom);
    final requests = social.requests;
    if (requests.isEmpty || inRoom) return const SizedBox.shrink();
    final request = requests.first;
    final more = requests.length - 1;
    final busy = social.isWorking(request.fromUid);

    return Padding(
      padding: padding,
      child: Semantics(
        liveRegion: true,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceRaised,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.green, width: 2),
            boxShadow: [
              BoxShadow(
                color: AppColors.green.withValues(alpha: 0.22),
                blurRadius: 18,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  AvatarTile(name: request.name, size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PlayerName(
                          name: request.name,
                          tag: request.tag,
                          suffix: ' wil je vriend worden',
                          style: AppTextStyles.display(18),
                        ),
                        Text(
                          more > 0
                              ? 'Vriendverzoek · +$more meer'
                              : 'Vriendverzoek',
                          style: AppTextStyles.caption(),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.person_add_alt_1_rounded,
                    color: AppColors.green,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ChunkyButton(
                      label: 'Weiger',
                      display: false,
                      height: 44,
                      style: ChunkyButtonStyle.secondary,
                      onPressed: busy
                          ? null
                          : () => _run(context, social.decline(request)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ChunkyButton(
                      label: 'Accepteer',
                      display: false,
                      height: 44,
                      style: ChunkyButtonStyle.success,
                      loading: busy,
                      onPressed: () => _run(context, social.accept(request)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
