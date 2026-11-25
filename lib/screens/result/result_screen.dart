import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../navigators/app_router.dart';
import '../../providers/game_provider.dart';
import '../../providers/profile_provider.dart';
import '../../services/game/game_backend.dart';
import '../../theme/app_theme.dart';
import '../../widgets/badges/badge_unlock_overlay.dart';
import '../../widgets/generic/chunky_button.dart';
import '../../widgets/result/duel_stats_card.dart';
import '../../widgets/result/result_hero.dart';
import '../../widgets/result/reward_cards.dart';

/// After a finished game: win or loss, XP, stats and what next.
class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    // Let the result settle in first, then celebrate new badges.
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      if (!mounted || _navigated) return;
      final fresh = context.read<ProfileProvider>().takeNewBadges();
      if (fresh.isNotEmpty) showBadgeUnlocks(context, fresh);
    });
  }

  static const _activePhases = {
    GamePhase.countdown,
    GamePhase.cast,
    GamePhase.resolving,
    GamePhase.roundResult,
  };

  void _goToDuel() {
    if (_navigated || !mounted) return;
    _navigated = true;
    Navigator.of(context).pushReplacementNamed(AppRoutes.duel);
  }

  Future<void> _rematch(BuildContext context) async {
    final game = context.read<GameProvider>();
    await game.playAgain();
    if (!context.mounted) return;
    if (game.actionError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(game.actionError!)));
      game.clearError();
      return;
    }
    _goToDuel();
  }

  Future<void> _leaveTo(BuildContext context, String route) async {
    if (_navigated) return;
    _navigated = true;
    final game = context.read<GameProvider>();
    Navigator.of(context).pushNamedAndRemoveUntil(route, (_) => false);
    await game.leave();
  }

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameProvider>();
    // The opponent asked for a rematch: the new game has started.
    if (!_navigated && _activePhases.contains(game.state.phase)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _goToDuel());
    }
    final profile = context.watch<ProfileProvider>().profile;
    final summary = game.lastSummary;
    final roomOpen = game.state.phase == GamePhase.finished;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leaveTo(context, AppRoutes.home);
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screen,
                    56,
                    AppSpacing.screen,
                    AppSpacing.screen,
                  ),
                  children: [
                    if (summary != null) ...[
                      ResultHero(
                        won: summary.won,
                        opponentName: summary.opponentName,
                        rounds: summary.rounds.length,
                      ),
                      const SizedBox(height: 24),
                      RewardCards(
                        profile: profile,
                        xpGained: summary.xpGained,
                        won: summary.won,
                      ),
                      const SizedBox(height: 12),
                      DuelStatsCard(summary: summary),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screen,
                  0,
                  AppSpacing.screen,
                  24,
                ),
                child: Column(
                  children: [
                    ChunkyButton(
                      label: 'REVANCHE',
                      height: 62,
                      fontSize: 22,
                      onPressed: roomOpen ? () => _rematch(context) : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ChunkyButton(
                            label: 'Home',
                            display: false,
                            height: 52,
                            style: ChunkyButtonStyle.secondary,
                            onPressed: () => _leaveTo(context, AppRoutes.home),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ChunkyButton(
                            label: 'Scorebord',
                            display: false,
                            height: 52,
                            style: ChunkyButtonStyle.secondary,
                            onPressed: () =>
                                _leaveTo(context, AppRoutes.leaderboard),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
