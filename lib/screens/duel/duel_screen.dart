import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../navigators/app_router.dart';
import '../../models/spell_info.dart';
import '../../providers/game_provider.dart';
import '../../providers/profile_provider.dart';
import '../../services/game/game_backend.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/gesture_constants.dart';
import '../../widgets/duel/cast_meter.dart';
import '../../widgets/duel/duel_center_banner.dart';
import '../../widgets/duel/duel_header.dart';
import '../../widgets/duel/feed_overlays.dart';
import '../../widgets/duel/gesture_debug_overlay.dart';
import '../../widgets/duel/spell_card_grid.dart';
import '../../widgets/duel/video_feed.dart';
import '../../widgets/generic/avatar_tile.dart';
import '../../widgets/generic/chunky_button.dart';

/// The live duel: opponent on top, you at the bottom, countdown and
/// reveal in between.
class DuelScreen extends StatefulWidget {
  const DuelScreen({super.key});

  @override
  State<DuelScreen> createState() => _DuelScreenState();
}

class _DuelScreenState extends State<DuelScreen> {
  bool _leaving = false;
  String? _shownError;

  /// While these phases run, the opponent's video is blurred.
  static const _hiddenPhases = {
    GamePhase.countdown,
    GamePhase.cast,
    GamePhase.resolving,
  };

  Future<void> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Duel verlaten?'),
        content: const Text('Het duel stopt dan voor jullie allebei.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Blijven'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.redSoft),
            child: const Text('Verlaten'),
          ),
        ],
      ),
    );
    if (leave == true && mounted) await _leave();
  }

  Future<void> _leave() async {
    if (_leaving) return;
    _leaving = true;
    final game = context.read<GameProvider>();
    AppRouter.goHome(context);
    await game.leave();
  }

  void _react(GameProvider game) {
    final s = game.state;
    if (_leaving) return;
    if (s.phase == GamePhase.idle) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _leaving) return;
        _leaving = true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.error ?? 'Het duel is gestopt.')),
        );
        AppRouter.goHome(context);
      });
      return;
    }
    final error = game.actionError;
    if (error != null && error != _shownError) {
      _shownError = error;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(error),
              duration: const Duration(seconds: 2),
            ),
          );
        game.clearError();
        _shownError = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameProvider>();
    final shareVideo = context.select<ProfileProvider, bool>(
      (p) => p.shareVideo,
    );
    final s = game.state;
    _react(game);

    final result = s.lastResult;
    final showingResult =
        s.phase == GamePhase.roundResult || s.phase == GamePhase.finished;
    final opponentHit = showingResult && result?.outcome == RoundOutcome.win
        ? result!.round
        : null;
    final meHit = showingResult && result?.outcome == RoundOutcome.lose
        ? result!.round
        : null;
    final opponentName = s.opponent?.name ?? 'Tegenstander';
    final mySpellOnFeed = s.mySpell ?? (showingResult ? result?.mySpell : null);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          s.phase == GamePhase.finished ? _leave() : _confirmLeave();
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                DuelHeader(
                  me: s.me,
                  opponent: s.opponent,
                  round: s.round,
                  config: s.config,
                ),
                const SizedBox(height: 12),
                Expanded(
                  flex: 206,
                  child: VideoFeed(
                    stream: shareVideo ? game.remoteStream : null,
                    blurred: _hiddenPhases.contains(s.phase),
                    placeholder: shareVideo
                        ? null
                        : Center(
                            child: AvatarTile(name: opponentName, size: 72),
                          ),
                    overlays: [
                      HitOverlay(trigger: opponentHit),
                      Positioned(
                        top: 12,
                        left: 12,
                        child: LiveBadge(status: s.callStatus),
                      ),
                      Positioned(
                        top: 12,
                        right: 12,
                        child: ConnectionBars(status: s.callStatus),
                      ),
                      Positioned(
                        left: 14,
                        right: 14,
                        bottom: 12,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                opponentName,
                                style: AppTextStyles.display(20),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            OpponentSpellChip(
                              hidden: !showingResult,
                              spell: result?.opponentSpell,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                DuelCenterBanner(state: s),
                Expanded(
                  flex: 240,
                  child: VideoFeed(
                    stream: game.localStream,
                    mirror: true,
                    borderColor: mySpellOnFeed?.color ?? AppColors.gold,
                    glowColor: mySpellOnFeed?.color ?? AppColors.gold,
                    overlays: [
                      const AimBrackets(),
                      HitOverlay(trigger: meHit),
                      const Positioned(
                        top: 12,
                        left: 12,
                        child: FeedLabel('JIJ'),
                      ),
                      if (GestureConstants.debug && game.recognitionAvailable)
                        Positioned(
                          top: 12,
                          right: 12,
                          child: GestureDebugOverlay(
                            frame: game.prediction.frame,
                          ),
                        ),
                      Positioned(
                        left: 10,
                        right: 10,
                        bottom: 10,
                        child: CastMeter(
                          prediction: game.prediction,
                          holdProgress: game.holdProgress,
                          recognitionAvailable: game.recognitionAvailable,
                          castSpell: mySpellOnFeed,
                          canCast: s.canCast,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 104,
                  child: _BottomArea(state: s, game: game),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomArea extends StatelessWidget {
  const _BottomArea({required this.state, required this.game});

  final GameState state;
  final GameProvider game;

  @override
  Widget build(BuildContext context) {
    final s = state;
    final opponentName = s.opponent?.name ?? 'Tegenstander';
    final oppLives = s.opponent?.lives ?? 0;
    final livesText =
        '$opponentName heeft nog $oppLives ${oppLives == 1 ? 'leven' : 'levens'} over';

    switch (s.phase) {
      case GamePhase.finished:
        final won = s.iWon ?? false;
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ChunkyButton(
              label: won ? 'GEWONNEN! BEKIJK RESULTAAT' : 'BEKIJK RESULTAAT',
              height: 62,
              fontSize: 22,
              style: won
                  ? ChunkyButtonStyle.success
                  : ChunkyButtonStyle.primary,
              onPressed: () =>
                  Navigator.of(context).pushReplacementNamed(AppRoutes.result),
            ),
            const SizedBox(height: 8),
            Text(
              won
                  ? '$opponentName heeft geen levens meer'
                  : 'Je hebt geen levens meer',
              style: AppTextStyles.caption(color: AppColors.textFeed),
            ),
          ],
        );
      case GamePhase.roundResult:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: AppColors.gold,
              ),
            ),
            const SizedBox(height: 10),
            Text('Volgende ronde start zo…', style: AppTextStyles.display(18)),
            const SizedBox(height: 4),
            Text(
              livesText,
              style: AppTextStyles.caption(color: AppColors.textFeed),
            ),
          ],
        );
      default:
        final shieldsLeft = s.config.shieldUses - (s.me?.shieldsUsed ?? 0);
        return SpellCardGrid(
          enabled: s.canCast,
          selected: s.mySpell,
          shieldsLeft: shieldsLeft.clamp(0, s.config.shieldUses),
          onCast: (spell) => game.castSpell(spell),
        );
    }
  }
}
