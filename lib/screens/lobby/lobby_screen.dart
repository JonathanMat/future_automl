import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../navigators/app_router.dart';
import '../../providers/challenge_provider.dart';
import '../../providers/game_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/tournament_provider.dart';
import '../../services/game/game_backend.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_theme.dart';
import '../../utils/extensions.dart';
import '../../widgets/generic/chunky_button.dart';
import '../../widgets/generic/screen_header.dart';
import '../../widgets/generic/stat_tile.dart';
import '../../widgets/lobby/challenge_waiting_card.dart';
import '../../widgets/lobby/lobby_player_card.dart';
import '../../widgets/lobby/room_code_card.dart';
import '../../widgets/lobby/video_share_card.dart';
import '../../widgets/tournament/match_status_card.dart';

/// Duel room: share the code, wait for the opponent, then the duel starts.
class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  bool _leaving = false;
  bool _navigated = false;

  /// The backend can still be idle for a moment after the room was made:
  /// Firebase only reports the room once its first snapshot arrives. Idle
  /// only means "closed" after the room has been seen.
  bool _sawRoom = false;
  Timer? _openTimeout;

  /// How long to wait for the room before giving up.
  static const _openTimeLimit = Duration(seconds: 15);

  @override
  void initState() {
    super.initState();
    _openTimeout = Timer(_openTimeLimit, () {
      if (!_sawRoom) {
        _close('De kamer kon niet geopend worden. Controleer je internet.');
      }
    });
  }

  @override
  void dispose() {
    _openTimeout?.cancel();
    super.dispose();
  }

  static const _activePhases = {
    GamePhase.countdown,
    GamePhase.cast,
    GamePhase.resolving,
    GamePhase.roundResult,
  };

  Future<void> _leave() async {
    if (_leaving) return;
    _leaving = true;
    final game = context.read<GameProvider>();
    final challenges = context.read<ChallengeProvider>();
    Navigator.of(context).pop();
    await challenges.cancelOutgoing();
    await game.leave();
  }

  void _goToDuel() {
    if (_navigated || !mounted) return;
    _navigated = true;
    Navigator.of(context).pushReplacementNamed(AppRoutes.duel);
  }

  void _react(GameState state) {
    if (_leaving || _navigated) return;
    if (state.phase != GamePhase.idle) {
      _sawRoom = true;
      _openTimeout?.cancel();
    }
    if (_activePhases.contains(state.phase)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _goToDuel());
    } else if (state.phase == GamePhase.idle && _sawRoom) {
      _close(state.error ?? 'De kamer is gesloten.');
    } else if (state.phase == GamePhase.finished && state.error != null) {
      // E.g. the opponent left, or the room was removed.
      _close(state.error!);
    }
  }

  /// Leaves the room and goes home with [message].
  void _close(String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _leaving) return;
      _leaving = true;
      final game = context.read<GameProvider>();
      context.read<ChallengeProvider>().cancelOutgoing();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      AppRouter.goHome(context);
      game.leave();
    });
  }

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameProvider>();
    final profile = context.watch<ProfileProvider>();
    final s = game.state;
    _react(s);

    final config = s.config;
    final opponent = s.opponent;
    final challenges = context.watch<ChallengeProvider>();
    final tournament = context.watch<TournamentProvider?>();
    // Waiting for a challenged friend (null once they join).
    final challenge = opponent == null ? challenges.outgoing : null;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.screen),
                  children: [
                    ScreenHeader(
                      title: challenge != null ? 'Uitdaging' : 'Duel-kamer',
                      onBack: _leave,
                    ),
                    const SizedBox(height: 20),
                    if (challenge != null)
                      ChallengeWaitingCard(
                        challenge: challenge,
                        expiresAt: challenges.outgoingExpiresAt!,
                        roomCode: s.roomCode,
                      )
                    else if (s.roomCode != null)
                      RoomCodeCard(code: s.roomCode!)
                    else
                      const _OpeningRoomCard(),
                    const SizedBox(height: 14),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: LobbyPlayerCard(
                              name: s.me?.name ?? profile.profile.name,
                              subtitle: 'LVL ${profile.profile.level} · Jij',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Center(child: _VsBadge()),
                          const SizedBox(width: 10),
                          Expanded(
                            child: LobbyPlayerCard(
                              name: opponent?.name,
                              invitedName: challenge?.name,
                              subtitle: opponent != null
                                  ? _friendSubtitle(profile, opponent.name)
                                  : challenge != null
                                  ? 'Uitgenodigd'
                                  : 'Deel de code',
                              online: opponent?.online ?? true,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (tournament != null && tournament.inMatch)
                      WalkoverAction(
                        t: tournament,
                        onClaim: () async {
                          if (await tournament.claimWalkover() && mounted) {
                            await _leave();
                          }
                        },
                      ),
                    const SizedBox(height: 14),
                    VideoShareCard(
                      value: profile.shareVideo,
                      onChanged: profile.setShareVideo,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: StatTile(
                            compact: true,
                            valueSize: 20,
                            value: '${config.startLives}',
                            label: 'Levens',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: StatTile(
                            compact: true,
                            valueSize: 20,
                            value: '${config.shieldUses}×',
                            label: 'Schild',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: StatTile(
                            compact: true,
                            valueSize: 20,
                            value: config.castWindow.secondsLabel,
                            label: 'Casttijd',
                          ),
                        ),
                      ],
                    ),
                    if (s.error != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        s.error!,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.body(13, color: AppColors.redSoft),
                      ),
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
                child: ChunkyButton(
                  label: opponent != null
                      ? 'START DUEL'
                      : challenge != null
                      ? 'WACHTEN OP ${challenge.name.toUpperCase()}'
                      : 'WACHTEN OP TEGENSTANDER',
                  style: ChunkyButtonStyle.success,
                  dimWhenDisabled: false,
                  fontSize: opponent == null ? 18 : 24,
                  onPressed: opponent == null ? null : _goToDuel,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _friendSubtitle(ProfileProvider profile, String name) {
    final key = name.trim().toLowerCase();
    final friend = profile.friends
        .where((f) => f.name.trim().toLowerCase() == key)
        .firstOrNull;
    if (friend == null) return 'Nieuwe tegenstander';
    return 'Jij ${friend.wins}–${friend.losses}';
  }
}

class _VsBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.gold,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: AppColors.goldShadow, offset: Offset(0, 4)),
        ],
      ),
      child: Text(
        'VS',
        style: AppTextStyles.display(17, color: AppColors.goldInk),
      ),
    );
  }
}

/// Shown until the backend reports the new room.
class _OpeningRoomCard extends StatelessWidget {
  const _OpeningRoomCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox.square(
            dimension: 26,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: AppColors.gold,
            ),
          ),
          const SizedBox(height: 12),
          Text('Kamer openen…', style: AppTextStyles.caption()),
        ],
      ),
    );
  }
}
