import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../navigators/app_router.dart';
import '../../providers/game_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/tournament_provider.dart';
import '../../services/game/game_backend.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_transitions.dart';
import '../../widgets/generic/pill_badge.dart';
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
  Timer? _badgeTimer;

  @override
  void initState() {
    super.initState();
    // Let the result play out first (its sound and animation), then
    // celebrate new badges, so the two sounds don't overlap.
    final won = context.read<GameProvider>().lastSummary?.won ?? false;
    _badgeTimer = Timer(ResultHero.doneAfter(won), () {
      if (!mounted || _navigated) return;
      final fresh = context.read<ProfileProvider>().takeNewBadges();
      if (fresh.isNotEmpty) showBadgeUnlocks(context, fresh);
    });
  }

  @override
  void dispose() {
    _badgeTimer?.cancel();
    super.dispose();
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

  /// Asks for (or accepts) a rematch. The duel opens by itself once both
  /// players agreed and the new countdown starts.
  Future<void> _rematch(BuildContext context) async {
    final game = context.read<GameProvider>();
    await game.playAgain();
    if (!context.mounted) return;
    if (game.actionError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(game.actionError!)));
      game.clearError();
    }
  }

  Future<void> _backToTournament(BuildContext context) async {
    if (_navigated) return;
    _navigated = true;
    final game = context.read<GameProvider>();
    AppRouter.backToTournament(context);
    await game.leave();
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
    // Both asked for a rematch: the new game has started.
    if (!_navigated && _activePhases.contains(game.state.phase)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _goToDuel());
    }
    final profile = context.watch<ProfileProvider>().profile;
    final summary = game.lastSummary;
    final s = game.state;
    // "finished" with an error: the opponent left or the room is gone.
    final roomOpen = s.phase == GamePhase.finished && s.error == null;
    final opponentName =
        s.opponent?.name ?? summary?.opponentName ?? 'je tegenstander';
    // A tournament match: no rematch, back to the bracket.
    final tournament = context.watch<TournamentProvider?>();
    final inTournament =
        tournament != null &&
        tournament.inTournament &&
        tournament.lastMatch != null;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          inTournament
              ? _backToTournament(context)
              : _leaveTo(context, AppRoutes.home);
        }
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
                        offerRematch: !inTournament,
                      ),
                      const SizedBox(height: 24),
                      RewardCards(
                        profile: profile,
                        xpGained: summary.xpGained,
                        won: summary.won,
                        brokenStreak: context.select<ProfileProvider, int>(
                          (p) => p.brokenStreak,
                        ),
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
                child: inTournament
                    ? _TournamentButtons(
                        won: summary?.won ?? false,
                        onBack: () => _backToTournament(context),
                      )
                    : Column(
                        children: [
                          _RematchNote(
                            roomOpen: roomOpen,
                            iAsked: s.iWantRematch,
                            theyAsked: s.opponentWantsRematch,
                            opponentName: opponentName,
                          ),
                          ChunkyButton(
                            label: !roomOpen
                                ? 'REVANCHE'
                                : s.iWantRematch
                                ? 'WACHTEN…'
                                : s.opponentWantsRematch
                                ? 'REVANCHE ACCEPTEREN'
                                : 'REVANCHE',
                            height: 62,
                            fontSize: 22,
                            style: s.opponentWantsRematch && !s.iWantRematch
                                ? ChunkyButtonStyle.success
                                : ChunkyButtonStyle.primary,
                            onPressed: roomOpen && !s.iWantRematch
                                ? () => _rematch(context)
                                : null,
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
                                  onPressed: () =>
                                      _leaveTo(context, AppRoutes.home),
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

/// One line above the rematch button: who asked, or why it's off.
class _RematchNote extends StatelessWidget {
  const _RematchNote({
    required this.roomOpen,
    required this.iAsked,
    required this.theyAsked,
    required this.opponentName,
  });

  final bool roomOpen;
  final bool iAsked;
  final bool theyAsked;
  final String opponentName;

  @override
  Widget build(BuildContext context) {
    final (String? text, Color color, IconData icon) = !roomOpen
        ? (
            '$opponentName heeft de kamer verlaten.',
            AppColors.textMuted,
            Icons.logout_rounded,
          )
        : iAsked
        ? (
            'Revanche gevraagd. We starten zodra $opponentName ook wil.',
            AppColors.gold,
            Icons.hourglass_top_rounded,
          )
        : theyAsked
        ? (
            '$opponentName wil een revanche!',
            AppColors.green,
            Icons.replay_rounded,
          )
        : (null, AppColors.text, Icons.replay_rounded);
    return AnimatedSize(
      duration: AppTransitions.fast,
      alignment: Alignment.bottomCenter,
      child: text == null
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: PillBadge(label: text, color: color, icon: icon),
            ),
    );
  }
}

class _TournamentButtons extends StatelessWidget {
  const _TournamentButtons({required this.won, required this.onBack});

  final bool won;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          won
              ? 'Je gaat door naar de volgende ronde!'
              : 'Je ligt uit het toernooi. Kijk mee naar de rest!',
          textAlign: TextAlign.center,
          style: AppTextStyles.body(15, color: AppColors.textSoft),
        ),
        const SizedBox(height: 12),
        ChunkyButton(
          label: 'TERUG NAAR TOERNOOI',
          icon: Icons.account_tree_rounded,
          height: 62,
          fontSize: 22,
          style: ChunkyButtonStyle.primary,
          onPressed: onBack,
        ),
      ],
    );
  }
}
