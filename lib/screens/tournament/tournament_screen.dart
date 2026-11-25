import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/tournament.dart';
import '../../navigators/app_router.dart';
import '../../providers/game_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/tournament_provider.dart';
import '../../services/permissions/camera_permission_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_theme.dart';
import '../../widgets/badges/badge_unlock_overlay.dart';
import '../../widgets/generic/camera_permission_dialog.dart';
import '../../widgets/generic/chunky_button.dart';
import '../../widgets/generic/icon_square_button.dart';
import '../../widgets/generic/screen_header.dart';
import '../../widgets/tournament/bracket_view.dart';
import '../../widgets/tournament/call_up_overlay.dart';
import '../../widgets/tournament/champion_overlay.dart';
import '../../widgets/tournament/draw_reveal_overlay.dart';
import '../../widgets/tournament/match_status_card.dart';
import '../../widgets/tournament/tournament_entry.dart';
import '../../widgets/tournament/waiting_room.dart';
import 'tournament_beamer_screen.dart';

/// The classroom tournament: make or join one, the waiting room, the live
/// bracket, and the big moments on top (the draw, "JOUW DUEL!", the
/// champion).
class TournamentScreen extends StatefulWidget {
  const TournamentScreen({super.key});

  @override
  State<TournamentScreen> createState() => _TournamentScreenState();
}

class _TournamentScreenState extends State<TournamentScreen> {
  late final TournamentProvider _t = context.read<TournamentProvider>();
  late final GameProvider _game = context.read<GameProvider>();

  Set<String> get _sawLobby => _t.seenLobby;
  Set<String> get _drawDone => _t.drawShown;
  Set<String> get _celebrated => _t.celebrated;
  Set<String> get _dismissed => _t.dismissedCallUps;

  String? _drawFor;
  bool _showChampion = false;
  String? _callUpFor;
  CallUpStage _stage = CallUpStage.ready;
  final _viewer = TransformationController();
  bool _fitted = false;

  @override
  void initState() {
    super.initState();
    _t.addListener(_sync);
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Back on top (after a duel): catch up on what happened meanwhile, like
    // the final being decided.
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void dispose() {
    _t.removeListener(_sync);
    final id = _callUpFor;
    if (id != null && _stage == CallUpStage.waitingForRoom) {
      unawaited(_t.cancelPlay(id));
    }
    _viewer.dispose();
    super.dispose();
  }

  bool get _onTop => mounted && (ModalRoute.of(context)?.isCurrent ?? true);

  /// Reacts to the tournament: errors, the draw, call-ups, the champion.
  void _sync() {
    if (!mounted) return;
    final t = _t;
    final error = t.error;
    if (error != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || t.error == null) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(t.error!)));
        t.clearError();
      });
    }

    final d = t.data;
    if (d == null) {
      _cancelCallUp();
      if (_drawFor != null || _showChampion) {
        setState(() {
          _drawFor = null;
          _showChampion = false;
        });
      }
      return;
    }
    if (d.status == TournamentStatus.lobby) {
      _sawLobby.add(d.code);
      _fitted = false;
      return;
    }

    // The draw, for everybody who was in the waiting room.
    if (_sawLobby.contains(d.code) &&
        !_drawDone.contains(d.code) &&
        _drawFor == null &&
        _onTop) {
      setState(() => _drawFor = d.code);
      return;
    }
    if (_drawFor != null) return;

    // The champion.
    if (t.champion != null && !_celebrated.contains(d.code) && _onTop) {
      _cancelCallUp();
      _celebrated.add(d.code);
      setState(() => _showChampion = true);
      return;
    }

    // Your duel.
    final m = t.myMatch;
    final id = _callUpFor;
    if (id != null) {
      if (m == null || m.id != id || !m.isReady) {
        _cancelCallUp();
      } else if (_stage == CallUpStage.waitingForRoom && t.myRoom != null) {
        _play();
      }
      return;
    }
    if (m != null &&
        m.isReady &&
        !t.inMatch &&
        !_game.inRoom &&
        !_showChampion &&
        !_dismissed.contains(_dismissalKey(m.id)) &&
        _onTop) {
      _startCallUp(m.id);
    }
  }

  String _dismissalKey(String id) => '${_t.code}/$id';

  void _startCallUp(String matchId) {
    setState(() {
      _callUpFor = matchId;
      _stage = CallUpStage.ready;
    });
  }

  void _cancelCallUp() {
    if (_callUpFor != null && mounted) setState(() => _callUpFor = null);
  }

  bool _playing = false;

  Future<void> _play() async {
    if (_playing) return;
    _playing = true;
    final id = _callUpFor;
    setState(() => _stage = CallUpStage.joining);
    final outcome = await _t.play();
    _playing = false;
    if (!mounted) return;
    switch (outcome) {
      case PlayOutcome.inRoom:
        // Back from the room without playing: no second call-up.
        setState(() {
          _callUpFor = null;
          if (id != null) _dismissed.add(_dismissalKey(id));
        });
        unawaited(Navigator.of(context).pushNamed(AppRoutes.lobby));
      case PlayOutcome.waitForRoom:
        setState(() => _stage = CallUpStage.waitingForRoom);
        _sync();
      case PlayOutcome.failed:
        setState(() {
          _callUpFor = null;
          if (id != null) _dismissed.add(_dismissalKey(id));
        });
        await _showFailure();
    }
  }

  Future<void> _showFailure() async {
    final message = _t.error ?? _game.actionError ?? 'Er ging iets mis.';
    _t.clearError();
    _game.clearError();
    if (_game.mediaAccess == MediaAccess.denied) {
      await showCameraPermissionDialog(
        context,
        service: _game.cameraPermission,
      );
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _later() {
    final id = _callUpFor;
    if (id != null && _stage == CallUpStage.waitingForRoom) {
      unawaited(_t.cancelPlay(id));
    }
    _cancelCallUp();
    if (id != null) _dismissed.add(_dismissalKey(id));
  }

  void _playNow() {
    final m = _t.myMatch;
    if (m == null || !m.isReady) return;
    _dismissed.remove(_dismissalKey(m.id));
    _startCallUp(m.id);
    _play();
  }

  Future<void> _closeChampion() async {
    setState(() => _showChampion = false);
    final profile = context.read<ProfileProvider>();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    final fresh = profile.takeNewBadges();
    if (fresh.isNotEmpty) await showBadgeUnlocks(context, fresh);
  }

  Future<void> _confirmLeave() async {
    final t = _t;
    final lobbyHost = t.isHost && t.status == TournamentStatus.lobby;
    final running = t.status == TournamentStatus.running && !t.isEliminated;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(lobbyHost ? 'Toernooi stoppen?' : 'Toernooi verlaten?'),
        content: Text(
          lobbyHost
              ? 'Het toernooi wordt voor iedereen gestopt.'
              : running
              ? 'Je tegenstanders kunnen dan winnen met een walk-over.'
              : 'Je kunt later opnieuw meedoen zolang het niet begonnen is.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Blijven'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(lobbyHost ? 'Stoppen' : 'Verlaten'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    _cancelCallUp();
    await t.leave();
  }

  /// Host: decide a match by hand (somebody left, the duel got stuck).
  Future<void> _decide(BracketMatch m) async {
    final t = _t;
    if (!t.isHost || m.isBye || m.a == null || m.b == null) return;
    final a = t.player(m.a), b = t.player(m.b);
    final winner = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Wie gaat door?', style: AppTextStyles.display(24)),
              const SizedBox(height: 6),
              Text(
                m.isDone
                    ? 'Deze uitslag staat al. Als host kun je hem aanpassen.'
                    : 'Gebruik dit als iemand weg is of het duel vastloopt. '
                          'Het telt als walk-over.',
                style: AppTextStyles.body(
                  14,
                  weight: FontWeight.w700,
                  color: AppColors.textSoft,
                ),
              ),
              const SizedBox(height: 16),
              for (final p in [a, b])
                if (p != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ChunkyButton(
                      label: '${p.name} wint',
                      display: false,
                      height: 52,
                      style: m.winner == p.uid
                          ? ChunkyButtonStyle.success
                          : ChunkyButtonStyle.secondary,
                      onPressed: () => Navigator.of(context).pop(p.uid),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
    if (winner != null && winner != m.winner) await t.decide(m.id, winner);
  }

  void _openBeamer() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const TournamentBeamerScreen(),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TournamentProvider>();
    // Rebuilds (and re-syncs) when this route comes back on top.
    ModalRoute.of(context)?.isCurrent;
    final profile = context.read<ProfileProvider>();
    final d = t.data;
    final me = t.myUid;

    final Widget body;
    if (d == null) {
      body = ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen,
          0,
          AppSpacing.screen,
          AppSpacing.screen,
        ),
        children: [
          TournamentEntry(busy: t.busy, onCreate: t.create, onJoin: t.join),
        ],
      );
    } else if (d.status == TournamentStatus.lobby) {
      body = WaitingRoom(
        data: d,
        myUid: me,
        isHost: t.isHost,
        busy: t.busy,
        onStart: t.start,
        onAddBots: t.backend.supportsBots ? () => t.addBots(3) : null,
      );
    } else {
      body = _BracketBody(
        t: t,
        viewer: _viewer,
        fitted: _fitted,
        onFitted: () => _fitted = true,
        onPlay: _playNow,
        onTapMatch: t.isHost ? _decide : null,
        animateIn: _drawFor == null,
      );
    }

    final callUp = _callUpFor;
    final m = t.myMatch;
    final opp = t.myOpponent;
    final champ = t.champion == null ? null : t.player(t.champion);

    return Stack(
      children: [
        Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screen,
                    AppSpacing.screen,
                    AppSpacing.screen,
                    14,
                  ),
                  child: ScreenHeader(
                    title: 'Toernooi',
                    trailing: d == null
                        ? null
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconSquareButton(
                                icon: Icons.tv_rounded,
                                tooltip: 'Beamer-weergave',
                                color: AppColors.lavender,
                                onPressed: _openBeamer,
                              ),
                              const SizedBox(width: 8),
                              IconSquareButton(
                                icon: Icons.logout_rounded,
                                tooltip: 'Toernooi verlaten',
                                color: AppColors.redSoft,
                                onPressed: _confirmLeave,
                              ),
                            ],
                          ),
                  ),
                ),
                Expanded(child: body),
              ],
            ),
          ),
        ),
        if (_drawFor != null && d != null && me != null)
          Positioned.fill(
            child: DrawRevealOverlay(
              names: [
                for (final p in d.roster)
                  if (p.uid != me) p.name,
              ],
              opponent: _firstOpponent(t, me),
              players: d.players.length,
              byes: Bracket.seatsFor(d.players.length) - d.players.length,
              onDone: () {
                _drawDone.add(_drawFor!);
                setState(() => _drawFor = null);
                _sync();
              },
            ),
          ),
        if (callUp != null && m != null && m.id == callUp)
          Positioned.fill(
            child: CallUpOverlay(
              myName: profile.profile.name,
              opponentName: opp?.name ?? 'Tegenstander',
              opponentOffline: opp != null && !opp.online,
              roundName: Bracket.roundName(m.round, t.bracket.rounds.length),
              stage: _stage,
              onPlay: _play,
              onLater: _later,
              walkover: _stage == CallUpStage.waitingForRoom
                  ? WalkoverAction(t: t)
                  : null,
            ),
          ),
        if (_showChampion && champ != null)
          Positioned.fill(
            child: ChampionOverlay(
              name: champ.name,
              tag: champ.tag,
              isMe: t.isChampion,
              players: d?.players.length ?? 0,
              xp: t.isChampion ? ProfileProvider.tournamentWinXp : null,
              onClose: _closeChampion,
            ),
          ),
      ],
    );
  }

  static String? _firstOpponent(TournamentProvider t, String me) {
    final first = t.bracket.rounds.isEmpty ? null : t.bracket.rounds.first;
    final m = first?.where((m) => m.involves(me)).firstOrNull;
    if (m == null || m.isBye) return null;
    return t.player(m.opponentOf(me))?.name;
  }
}

class _BracketBody extends StatelessWidget {
  const _BracketBody({
    required this.t,
    required this.viewer,
    required this.fitted,
    required this.onFitted,
    required this.onPlay,
    required this.onTapMatch,
    required this.animateIn,
  });

  final TournamentProvider t;
  final TransformationController viewer;
  final bool fitted;
  final VoidCallback onFitted;
  final VoidCallback onPlay;
  final ValueChanged<BracketMatch>? onTapMatch;
  final bool animateIn;

  @override
  Widget build(BuildContext context) {
    final d = t.data!;
    final b = t.bracket;
    final live = b.matches.where((m) => m.isReady && d.rooms.containsKey(m.id));
    final done = b.matches.where((m) => m.isDone && !m.isBye).length;
    final total = b.matches.where((m) => !m.isBye).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
          child: MatchStatusCard(t: t, onPlay: onPlay, onDone: t.leave),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
          child: Row(
            children: [
              Text('SCHEMA', style: AppTextStyles.overline()),
              const SizedBox(width: 8),
              if (live.isNotEmpty)
                Text(
                  '· ${live.length} live',
                  style: AppTextStyles.overline(color: AppColors.redSoft),
                ),
              const Spacer(),
              Flexible(
                flex: 4,
                child: Text(
                  '$done/$total gespeeld',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: AppTextStyles.caption(),
                ),
              ),
            ],
          ),
        ),
        if (t.isHost && t.status == TournamentStatus.running)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screen,
              4,
              AppSpacing.screen,
              0,
            ),
            child: Text(
              'Host: tik op een duel om het zelf te beslissen.',
              style: AppTextStyles.caption(color: AppColors.textHint),
            ),
          ),
        const SizedBox(height: 6),
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) {
              final size = BracketView.sizeFor(b);
              if (!fitted && size.width > 0) {
                // Start zoomed to the width (not too small to read).
                final s = min(1.0, max(0.62, (box.maxWidth - 24) / size.width));
                viewer.value = Matrix4.identity()..scaleByDouble(s, s, 1, 1);
                onFitted();
              }
              return ClipRect(
                child: InteractiveViewer(
                  transformationController: viewer,
                  constrained: false,
                  minScale: 0.35,
                  maxScale: 2.2,
                  boundaryMargin: const EdgeInsets.all(120),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 40, 40),
                    child: BracketView(
                      bracket: b,
                      players: d.players,
                      rooms: d.rooms,
                      myUid: t.myUid,
                      onTapMatch: onTapMatch,
                      animateIn: animateIn,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
