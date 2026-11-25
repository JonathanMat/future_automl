import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../navigators/app_router.dart';
import '../../models/spell_info.dart';
import '../../providers/friends_provider.dart';
import '../../providers/game_provider.dart';
import '../../providers/profile_provider.dart';
import '../../services/audio/sfx_service.dart';
import '../../services/game/game_backend.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/constants.dart';
import '../../utils/gesture_constants.dart';
import '../../widgets/duel/cast_meter.dart';
import '../../widgets/duel/duel_center_banner.dart';
import '../../widgets/duel/duel_header.dart';
import '../../widgets/duel/duel_intro.dart';
import '../../widgets/duel/effects/spell_effects_layer.dart';
import '../../widgets/duel/emotes/emote_burst.dart';
import '../../widgets/duel/emotes/emote_picker.dart';
import '../../widgets/duel/feed_overlays.dart';
import '../../widgets/duel/gesture_debug_overlay.dart';
import '../../widgets/duel/spell_card_grid.dart';
import '../../widgets/duel/video_feed.dart';
import '../../widgets/generic/avatar_tile.dart';
import '../../widgets/duel/effects/fx_plan.dart';

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
  final _topFeedKey = GlobalKey();
  final _bottomFeedKey = GlobalKey();

  /// The "VS" intro plays once when the duel opens.
  bool _introDone = false;

  StreamSubscription<Emote>? _emoteSub;

  /// The emote on each feed right now; the id restarts its animation.
  ({Emote emote, int id})? _theirEmote, _myEmote;
  int _emoteId = 0;

  @override
  void initState() {
    super.initState();
    _emoteSub = context.read<GameProvider>().opponentEmotes.listen(
      _onOpponentEmote,
    );
  }

  /// Opens the result screen once the final effect has played.
  Timer? _resultTimer;
  bool _openedResult = false;

  void _openResult() {
    _resultTimer?.cancel();
    if (!mounted || _leaving || _openedResult) return;
    _openedResult = true;
    Navigator.of(context).pushReplacementNamed(AppRoutes.result);
  }

  @override
  void dispose() {
    _resultTimer?.cancel();
    _emoteSub?.cancel();
    super.dispose();
  }

  void _onOpponentEmote(Emote emote) {
    if (!mounted || _leaving) return;
    SfxService.instance.play(SfxSound.forEmote(emote));
    HapticFeedback.selectionClick();
    setState(() => _theirEmote = (emote: emote, id: ++_emoteId));
  }

  void _sendEmote(Emote emote) {
    // Like the other player, you hear your emote's own sound, a bit softer.
    SfxService.instance.play(SfxSound.forEmote(emote), volume: .8);
    setState(() => _myEmote = (emote: emote, id: ++_emoteId));
    context.read<GameProvider>().sendEmote(emote);
  }

  /// An emote popping up: the opponent's in the middle of their feed, yours
  /// small above the emote button, so it doesn't cover your hand.
  Widget? _burst(({Emote emote, int id})? shown, double size, bool mine) {
    if (shown == null) return null;
    return Positioned(
      left: mine ? null : 0,
      top: mine ? null : 0,
      right: mine ? 4 : 0,
      bottom: mine ? 60 : 0,
      child: Center(
        child: EmoteBurst(
          key: ValueKey(shown.id),
          emote: shown.emote,
          size: size,
          onDone: () {
            if (!mounted) return;
            setState(() {
              if (mine && _myEmote?.id == shown.id) _myEmote = null;
              if (!mine && _theirEmote?.id == shown.id) _theirEmote = null;
            });
          },
        ),
      ),
    );
  }

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
    // A normal game end: show the final effect, then the result screen by
    // itself. Not when the opponent left: there is no real result then.
    if (s.phase == GamePhase.finished && s.error == null) {
      _resultTimer ??= Timer(AppConstants.resultScreenDelay, _openResult);
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
    final opponentName = s.opponent?.name ?? 'Tegenstander';
    final profile = context.read<ProfileProvider>();
    final friends = context.read<FriendsProvider>();
    final opponentUid = s.opponent?.uid;
    final opponentFriend = opponentUid == null
        ? null
        : friends.friends.where((f) => f.uid == opponentUid).firstOrNull;
    final mySpellOnFeed = s.mySpell ?? (showingResult ? result?.mySpell : null);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          s.phase == GamePhase.finished ? _leave() : _confirmLeave();
        }
      },
      child: Stack(
        children: [
          Scaffold(
            body: SafeArea(
              child: SpellEffectsLayer(
                result: showingResult ? result : null,
                topKey: _topFeedKey,
                bottomKey: _bottomFeedKey,
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
                        child: FxTintTarget(
                          side: FxSide.top,
                          child: VideoFeed(
                            key: _topFeedKey,
                            stream: shareVideo ? game.remoteStream : null,
                            blurred: _hiddenPhases.contains(s.phase),
                            placeholder: shareVideo
                                ? null
                                : Center(
                                    child: AvatarTile(
                                      name: opponentName,
                                      size: 72,
                                    ),
                                  ),
                            overlays: [
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
                              ?_burst(_theirEmote, 96, false),
                            ],
                          ),
                        ),
                      ),
                      DuelCenterBanner(state: s),
                      Expanded(
                        flex: 240,
                        child: FxTintTarget(
                          side: FxSide.bottom,
                          child: VideoFeed(
                            key: _bottomFeedKey,
                            stream: game.localStream,
                            mirror: true,
                            borderColor: mySpellOnFeed?.color ?? AppColors.gold,
                            glowColor: mySpellOnFeed?.color ?? AppColors.gold,
                            overlays: [
                              const AimBrackets(),
                              const Positioned(
                                top: 12,
                                left: 12,
                                child: FeedLabel('JIJ'),
                              ),
                              if (GestureConstants.debug &&
                                  game.recognitionAvailable)
                                Positioned(
                                  top: 12,
                                  right: 12,
                                  child: GestureDebugOverlay(
                                    frame: game.prediction.frame,
                                  ),
                                ),
                              Positioned(
                                left: 10,
                                bottom: 10,
                                child: CastMeter(
                                  prediction: game.prediction,
                                  holdProgress: game.holdProgress,
                                  recognitionAvailable:
                                      game.recognitionAvailable,
                                  castSpell: mySpellOnFeed,
                                  canCast: s.canCast,
                                ),
                              ),
                              ?_burst(_myEmote, 56, true),
                              Positioned.fill(
                                child: EmoteControls(
                                  enabled: s.opponent != null,
                                  onSend: _sendEmote,
                                ),
                              ),
                            ],
                          ),
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
          ),
          if (!_introDone)
            Positioned.fill(
              child: DuelIntro(
                me: IntroPlayer(
                  name: profile.profile.name,
                  tag: friends.myTag,
                  subtitle: 'LVL ${profile.profile.level}',
                ),
                opponent: IntroPlayer(
                  name: opponentName,
                  tag: opponentFriend?.tag,
                  subtitle: opponentFriend == null
                      ? null
                      : '${opponentFriend.wins} WINS',
                ),
                onDone: () => setState(() => _introDone = true),
              ),
            ),
        ],
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
        // No button: the result screen opens by itself after the final
        // effect, and a button flashing up right before that looked odd.
        final won = s.iWon ?? false;
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              won ? 'Je hebt gewonnen!' : 'Je hebt verloren',
              style: AppTextStyles.display(
                22,
                color: won ? AppColors.green : AppColors.lavender,
              ),
            ),
            const SizedBox(height: 4),
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
