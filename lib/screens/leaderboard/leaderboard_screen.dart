import 'dart:async';

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
import '../../widgets/friends/challenge_banner.dart';
import '../../widgets/generic/app_bottom_nav.dart';
import '../../widgets/generic/screen_header.dart';
import '../../widgets/leaderboard/animated_board.dart';
import '../../widgets/leaderboard/segmented_tabs.dart';

/// Ranking by wins. "Global" is the top of everyone on the server,
/// "Vrienden" is you and your accepted friends (see [FriendsProvider]).
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  int _tab = 0;

  // Listened to once for the screen's lifetime: the backend stream allows
  // only one listener, and the tab switch would otherwise re-subscribe.
  StreamSubscription<List<LeaderboardEntry>>? _sub;
  List<LeaderboardEntry>? _global;
  Object? _globalError;

  @override
  void initState() {
    super.initState();
    _sub = context
        .read<GameProvider>()
        .backend
        .leaderboard(limit: AppConstants.leaderboardSize)
        .listen(
          (list) => setState(() {
            _global = list;
            _globalError = null;
          }),
          onError: (Object e) => setState(() => _globalError = e),
        );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

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
              const ChallengeBanner(padding: EdgeInsets.only(bottom: 16)),
              SegmentedTabs(
                labels: const ['Vrienden', 'Global'],
                selected: _tab,
                onSelected: (i) => setState(() => _tab = i),
              ),
              Expanded(
                // One board for both tabs: players move to their new place
                // when switching (see AnimatedBoard).
                child: _tab == 0
                    ? _friendsBoard(social, isMe)
                    : _globalBoard(isMe),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _globalBoard(bool Function(LeaderboardEntry) isMe) {
    if (_globalError != null) {
      return _Message('Scorebord laden mislukt.\n$_globalError');
    }
    final global = _global;
    if (global == null) return const _Loading();
    if (global.isEmpty) return const _Message('Nog niemand op het scorebord.');
    final entries = [...global]..sort((a, b) => b.wins.compareTo(a.wins));
    return AnimatedBoard(entries: entries, isMe: isMe);
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
    return AnimatedBoard(entries: social.board, isMe: isMe);
  }
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
