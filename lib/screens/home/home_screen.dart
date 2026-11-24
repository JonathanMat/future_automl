import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../navigators/app_router.dart';
import '../../navigators/room_flow.dart';
import '../../providers/friends_provider.dart';
import '../../providers/game_provider.dart';
import '../../providers/profile_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/friends/challenge_banner.dart';
import '../../widgets/generic/app_bottom_nav.dart';
import '../../widgets/generic/chunky_button.dart';
import '../../widgets/generic/crossed_swords_icon.dart';
import '../../widgets/generic/stat_tile.dart';
import '../../widgets/home/join_room_row.dart';
import '../../widgets/home/profile_header.dart';
import '../../widgets/home/recent_duel_card.dart';
import '../../widgets/home/spell_hero_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>().profile;
    final game = context.watch<GameProvider>();

    return Scaffold(
      bottomNavigationBar: const SafeArea(
        top: false,
        child: AppBottomNav(current: AppTab.home),
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            AppSpacing.screen,
            AppSpacing.screen,
            16,
          ),
          children: [
            ProfileHeader(
              profile: profile,
              tag: context.select<FriendsProvider, String?>((f) => f.myTag),
              onSettings: () =>
                  Navigator.of(context).pushNamed(AppRoutes.settings),
            ),
            const SizedBox(height: 20),
            const ChallengeBanner(padding: EdgeInsets.only(bottom: 20)),
            SpellHeroCard(config: game.state.config),
            const SizedBox(height: 20),
            ChunkyButton(
              label: 'DUEL STARTEN',
              iconBuilder: (color, size) =>
                  CrossedSwordsIcon(color: color, size: size + 4),
              loading: game.busy,
              onPressed: () => RoomFlow.create(context),
            ),
            const SizedBox(height: 12),
            JoinRoomRow(
              busy: game.busy,
              onJoin: (code) => RoomFlow.join(context, code),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: StatTile(value: '${profile.wins}', label: 'Gewonnen'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StatTile(
                    value: '${profile.losses}',
                    label: 'Verloren',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StatTile(
                    value: '${profile.winRate}%',
                    label: 'Winrate',
                    valueColor: AppColors.gold,
                  ),
                ),
              ],
            ),
            if (profile.lastDuel != null) ...[
              const SizedBox(height: 12),
              RecentDuelCard(duel: profile.lastDuel!),
            ],
          ],
        ),
      ),
    );
  }
}
