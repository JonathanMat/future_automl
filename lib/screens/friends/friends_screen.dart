import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../navigators/room_flow.dart';
import '../../providers/game_provider.dart';
import '../../providers/profile_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_theme.dart';
import '../../widgets/friends/friend_tile.dart';
import '../../widgets/generic/app_bottom_nav.dart';
import '../../widgets/generic/chunky_button.dart';
import '../../widgets/generic/screen_header.dart';

/// Everyone you dueled, with your record against them.
class FriendsScreen extends StatelessWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final friends = context.watch<ProfileProvider>().friends;
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
            ChunkyButton(
              label: 'NIEUW DUEL',
              icon: Icons.person_add_alt_1_rounded,
              loading: busy,
              onPressed: () => RoomFlow.create(context),
            ),
            const SizedBox(height: 8),
            Text(
              'Maak een kamer en deel de code met een vriend.',
              textAlign: TextAlign.center,
              style: AppTextStyles.caption(),
            ),
            const SizedBox(height: 20),
            if (friends.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Column(
                  children: [
                    const Icon(
                      Icons.group_outlined,
                      size: 56,
                      color: AppColors.trackOff,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Nog geen vrienden.\nIedereen tegen wie je speelt, komt hier.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body(
                        14,
                        weight: FontWeight.w700,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              Text('LAATST GESPEELD', style: AppTextStyles.overline()),
              const SizedBox(height: 10),
              for (final f in friends) ...[
                FriendTile(friend: f),
                const SizedBox(height: 8),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
