import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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

/// Ranking by wins. "Campus" is everyone on the server, "Vrienden" only
/// the people you have dueled (and you).
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

  List<LeaderboardEntry> _filter(
    List<LeaderboardEntry> all,
    ProfileProvider profile,
  ) {
    if (_tab == 1) return all;
    final names = {
      profile.profile.name.trim().toLowerCase(),
      for (final f in profile.friends) f.name.trim().toLowerCase(),
    };
    return all
        .where((e) => names.contains(e.name.trim().toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>();
    final myName = profile.profile.name.trim().toLowerCase();

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
                child: StreamBuilder<List<LeaderboardEntry>>(
                  stream: _stream,
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return _Message(
                        'Scorebord laden mislukt.\n${snap.error}',
                      );
                    }
                    if (!snap.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(color: AppColors.gold),
                      );
                    }
                    final entries = [..._filter(snap.data!, profile)]
                      ..sort((a, b) => b.wins.compareTo(a.wins));
                    if (entries.isEmpty) {
                      return _Message(
                        _tab == 0
                            ? 'Nog geen vrienden op het scorebord.\nSpeel een duel om ze hier te zien.'
                            : 'Nog niemand op het scorebord.',
                      );
                    }
                    return ListView(
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
                            isMe:
                                entries[i].name.trim().toLowerCase() == myName,
                          ),
                          const SizedBox(height: 8),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
