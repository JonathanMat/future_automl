import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../navigators/room_flow.dart';
import '../../providers/challenge_provider.dart';
import '../../providers/game_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/extensions.dart';
import '../generic/avatar_tile.dart';
import '../generic/chunky_button.dart';
import '../generic/player_name.dart';

/// "Lotte daagt je uit!" with Weiger / Speel. Shows the newest open
/// challenge; nothing when there is none. Used on Home, Vrienden and
/// Scorebord (never during a game).
class ChallengeBanner extends StatelessWidget {
  const ChallengeBanner({super.key, this.padding = EdgeInsets.zero});

  /// Space around the banner when it is shown.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final challenges = context.watch<ChallengeProvider>();
    final busy = context.select<GameProvider, bool>((g) => g.busy);
    final inRoom = context.select<GameProvider, bool>((g) => g.inRoom);
    final incoming = challenges.incoming;
    if (incoming.isEmpty || inRoom) return const SizedBox.shrink();
    final invite = incoming.first;
    final more = incoming.length - 1;

    return Padding(
      padding: padding,
      child: Semantics(
        liveRegion: true,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceRaised,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.gold, width: 2),
            boxShadow: [
              BoxShadow(
                color: AppColors.gold.withValues(alpha: 0.25),
                blurRadius: 18,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  AvatarTile(name: invite.name, size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PlayerName(
                          name: invite.name,
                          tag: invite.tag,
                          suffix: ' daagt je uit!',
                          style: AppTextStyles.display(18),
                        ),
                        Text(
                          'Kamer ${invite.roomCode} · '
                          '${invite.sentAt.timeAgo()}'
                          '${more > 0 ? ' · +$more meer' : ''}',
                          style: AppTextStyles.caption(),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.bolt_rounded, color: AppColors.gold),
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
                      onPressed: () => challenges.dismiss(invite),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ChunkyButton(
                      label: 'Speel',
                      display: false,
                      height: 44,
                      style: ChunkyButtonStyle.success,
                      loading: busy,
                      onPressed: () => RoomFlow.accept(context, invite),
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
