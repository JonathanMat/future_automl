import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/friends_provider.dart';
import '../../providers/game_provider.dart';
import '../../providers/profile_provider.dart';
import '../../services/game/game_backend.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_theme.dart';
import '../../utils/constants.dart';
import '../../widgets/generic/app_bottom_nav.dart';
import '../../widgets/generic/screen_header.dart';
import '../../widgets/leaderboard/leaderboard_row.dart';
import '../../widgets/leaderboard/podium.dart';
import '../../widgets/leaderboard/segmented_tabs.dart';

/// Ranking by wins. "Campus" is the top of everyone on the server,
/// "Vrienden" is you and your accepted friends (see [FriendsProvider]).
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  int _tab = 0;
  late final Stream<List<LeaderboardEntry>> _stream = context
      .read<GameProvider>()
      .backend
      .leaderboard(limit: AppConstants.leaderboardSize);

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>();
    final social = context.watch<FriendsProvider>();
    final myUid = social.myUid;
    final myName = profile.profile.name.trim().toLowerCase();
    bool isMe(LeaderboardEntry e) =>
        myUid != null ? e.uid == myUid : e.name.trim().toLowerCase() == myName;

    return Scaffold(
      bottomNavigationBar: const SafeArea(
        top: false,
        child: AppBottomNav(current: AppTab.leaderboard),
      ),
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            AppSpacing.screen,
            AppSpacing.screen,
            0,
          ),
          child: Column(
            children: [
              const ScreenHeader(title: 'Scorebord', onBack: null),
              const SizedBox(height: 16),
              SegmentedTabs(
                labels: const ['Vrienden', 'Campus'],
                selected: _tab,
                onSelected: (i) => setState(() => _tab = i),
              ),
              Expanded(
                child: _tab == 0
                    ? _friendsBoard(social, isMe)
                    : StreamBuilder<List<LeaderboardEntry>>(
                        stream: _stream,
                        builder: (context, snap) {
                          if (snap.hasError) {
                            return _Message(
                              'Scorebord laden mislukt.\n${snap.error}',
                            );
                          }
                          if (!snap.hasData) return const _Loading();
                          final entries = [...snap.data!]
                            ..sort((a, b) => b.wins.compareTo(a.wins));
                          if (entries.isEmpty) {
                            return const _Message(
                              'Nog niemand op het scorebord.',
                            );
                          }
                          return _Board(entries: entries, isMe: isMe);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _friendsBoard(
    FriendsProvider social,
    bool Function(LeaderboardEntry) isMe,
  ) {
    if (!social.isReady) {
      return social.error != null
          ? _Message('Vrienden laden mislukt.\n${social.error}')
          : const _Loading();
    }
    if (social.friends.isEmpty) {
      return const _Message(
        'Nog geen vrienden op het scorebord.\n'
        'Voeg vrienden toe via de Vrienden-pagina.',
      );
    }
    return _Board(entries: social.board, isMe: isMe);
  }
}

class _Board extends StatelessWidget {
  const _Board({required this.entries, required this.isMe});

  final List<LeaderboardEntry> entries;
  final bool Function(LeaderboardEntry) isMe;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.only(top: 22, bottom: 16),
    children: [
      Podium(entries: entries),
      const SizedBox(height: 14),
      for (var i = 3; i < entries.length; i++) ...[
        LeaderboardRow(
          rank: i + 1,
          name: entries[i].name,
          wins: entries[i].wins,
          losses: entries[i].losses,
          isMe: isMe(entries[i]),
        ),
        const SizedBox(height: 8),
      ],
    ],
  );
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator(color: AppColors.gold));
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: AppTextStyles.body(
        14,
        weight: FontWeight.w700,
        color: AppColors.textMuted,
      ),
    ),
  );
}
