import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/duel_summary.dart';
import '../services/game/mock_game_backend.dart';
import '../services/tournament/tournament_backend.dart';
import 'friends_provider.dart';
import 'game_provider.dart';
import 'profile_provider.dart';

/// What [TournamentProvider.play] did.
enum PlayOutcome {
  /// You are in the room: open the lobby.
  inRoom,

  /// Your opponent opens the room; try again when it is there.
  waitForRoom,

  /// Something went wrong (see [TournamentProvider.error]).
  failed,
}

/// The tournament this phone is in: the waiting room, the bracket, your
/// next match, results and walk-overs.
///
/// Matches are normal duels: the first player of a match makes a room and
/// writes its code, the second joins it. When the duel ends the result is
/// reported here ([onGameFinished]) and the bracket moves on by itself.
class TournamentProvider extends ChangeNotifier {
  TournamentProvider({
    required this.backend,
    required this.friends,
    required this.game,
    required this.profile,
    Random? random,
    DateTime Function()? clock,
  }) : _random = random ?? Random(),
       _clock = clock ?? DateTime.now {
    game.addListener(_onGame);
  }

  final TournamentBackend backend;
  final FriendsProvider friends;
  final GameProvider game;
  final ProfileProvider profile;
  final Random _random;
  final DateTime Function() _clock;

  /// Waiting this long for an opponent who is offline lets you claim the
  /// win; [walkoverWait] when they look online but don't show up.
  static const offlineWait = Duration(seconds: 20);
  static const walkoverWait = Duration(seconds: 90);

  String? _code;
  TournamentData? _data;
  Bracket _bracket = Bracket.build(const [], const {});
  StreamSubscription<TournamentData?>? _sub;
  Timer? _ticker;
  bool _busy = false;
  String? _error;
  String? _activeMatch;
  final Set<String> _rewarded = {};
  bool _disposed = false;

  /// Remembered across screens (by tournament code or match id), so the
  /// draw, the champion and a call-up you waved away show only once.
  final Set<String> seenLobby = {};
  final Set<String> drawShown = {};
  final Set<String> celebrated = {};
  final Set<String> dismissedCallUps = {};

  String? get code => _code;
  TournamentData? get data => _data;
  Bracket get bracket => _bracket;
  bool get busy => _busy;
  String? get error => _error;

  bool get inTournament => _code != null && _data != null;
  TournamentStatus? get status => _data?.status;
  String? get myUid => friends.myUid;
  bool get isHost => _data != null && _data!.hostUid == myUid;

  /// The match whose duel you are playing right now.
  String? get activeMatch => _activeMatch;

  /// The tournament match whose duel just ended (for the result screen).
  String? get lastMatch => _lastMatch;
  String? _lastMatch;
  bool get inMatch => _activeMatch != null;

  /// Your next match (ready, or waiting for your opponent to be decided).
  BracketMatch? get myMatch {
    final me = myUid;
    if (me == null || _data?.status != TournamentStatus.running) return null;
    return _bracket.currentMatchFor(me);
  }

  TournamentPlayer? player(String? uid) =>
      uid == null ? null : _data?.players[uid];

  TournamentPlayer? get myOpponent {
    final me = myUid, m = myMatch;
    if (me == null || m == null) return null;
    return player(m.opponentOf(me));
  }

  bool get isEliminated {
    final me = myUid;
    return me != null && _bracket.isEliminated(me);
  }

  String? get champion => _bracket.champion;
  bool get isChampion => champion != null && champion == myUid;

  /// Server time now, as best this phone knows it.
  int get _serverNow =>
      _clock().add(backend.serverOffset).millisecondsSinceEpoch;

  /// How long your ready match has been waiting for your opponent.
  Duration get waitingFor {
    final since = myMatch?.readySince;
    if (since == null || !(myMatch?.isReady ?? false)) return Duration.zero;
    return Duration(milliseconds: max(0, _serverNow - since));
  }

  /// Your opponent didn't show up: you may take the win.
  bool get canClaimWalkover {
    final m = myMatch, opp = myOpponent;
    if (m == null || !m.isReady || opp == null || inMatch) return false;
    return waitingFor >= (opp.online ? walkoverWait : offlineWait);
  }

  /// Seconds until [canClaimWalkover], for a countdown in the UI.
  Duration get walkoverIn {
    final opp = myOpponent;
    if (opp == null) return Duration.zero;
    final left = (opp.online ? walkoverWait : offlineWait) - waitingFor;
    return left.isNegative ? Duration.zero : left;
  }

  // ---------------------------------------------------------------------------
  // Waiting room
  // ---------------------------------------------------------------------------

  TournamentMe? _me() {
    final uid = myUid;
    if (uid == null) {
      _error = 'Even geduld: je account wordt nog geladen.';
      _notify();
      return null;
    }
    return TournamentMe(
      uid: uid,
      name: profile.profile.name,
      tag: friends.myTag,
    );
  }

  Future<String?> create() => _run<String?>(() async {
    final me = _me();
    if (me == null) return null;
    final code = await backend.create(me);
    await _follow(code);
    return code;
  });

  Future<bool> join(String code) async {
    final ok = await _run(() async {
      final me = _me();
      if (me == null) return false;
      final normal = code.trim().toUpperCase();
      await backend.join(normal, me);
      await _follow(normal);
      return true;
    });
    return ok ?? false;
  }

  /// Mock only: fill the waiting room with bots.
  Future<void> addBots(int count) async {
    final c = _code;
    if (c != null) await backend.addBots(c, count);
  }

  /// Host: the draw, and off we go.
  Future<bool> start() async {
    final d = _data;
    if (d == null || !isHost || d.status != TournamentStatus.lobby) {
      return false;
    }
    if (d.players.length < 2) {
      _error = 'Er zijn minstens 2 spelers nodig.';
      _notify();
      return false;
    }
    final ok = await _run(() async {
      await backend.start(
        d.code,
        Bracket.draw(d.players.keys.toList(), _random),
      );
      return true;
    });
    return ok ?? false;
  }

  Future<void> leave() async {
    final c = _code, me = myUid;
    final host = isHost;
    _stopFollowing();
    _activeMatch = null;
    _lastMatch = null;
    _notify();
    if (c != null && me != null) await backend.leave(c, me, isHost: host);
  }

  void clearError() {
    _error = null;
    _notify();
  }

  // ---------------------------------------------------------------------------
  // Matches
  // ---------------------------------------------------------------------------

  /// Gets you into the room of your match: makes it when you are the first
  /// player, joins it when you are the second (once it exists).
  Future<PlayOutcome> play() async {
    final d = _data, m = myMatch, me = myUid;
    if (d == null || m == null || me == null || !m.isReady) {
      return PlayOutcome.failed;
    }
    _lastMatch = null;
    final opponent = player(m.opponentOf(me));
    // On one phone the duel is played against the mock game's bot.
    if (game.backend case final MockGameBackend mock) {
      mock.botName = opponent?.name ?? 'Bot';
    }

    if (m.a == me) {
      final room = await game.createRoom(profile.profile.name);
      if (room == null) {
        _error = game.actionError ?? 'Kamer maken mislukt.';
        _notify();
        return PlayOutcome.failed;
      }
      await backend.setRoom(d.code, m.id, room);
      _activeMatch = m.id;
      _sawRoom = game.inRoom;
      _notify();
      return PlayOutcome.inRoom;
    }

    final room = d.rooms[m.id];
    if (room == null) return PlayOutcome.waitForRoom;
    final ok = await game.joinRoom(room, profile.profile.name);
    if (!ok) {
      _error = game.actionError ?? 'Meedoen aan de kamer mislukt.';
      _notify();
      return PlayOutcome.failed;
    }
    _activeMatch = m.id;
    _sawRoom = game.inRoom;
    _notify();
    return PlayOutcome.inRoom;
  }

  /// The room for your match, once your opponent made it.
  String? get myRoom {
    final m = myMatch;
    return m == null ? null : _data?.rooms[m.id];
  }

  /// A duel ended. If it was your tournament match, the result goes in.
  ///
  /// [iWon] null means the duel ended without a winner: your opponent left
  /// the room, which counts as a walk-over for you.
  Future<void> onGameFinished(DuelSummary summary, {bool? iWon}) async {
    final id = _activeMatch, me = myUid, d = _data;
    if (id == null || me == null || d == null) return;
    _activeMatch = null;
    _lastMatch = id;
    final m = _bracket.byId(id);
    if (m == null || m.isDone || !m.involves(me)) {
      _notify();
      return;
    }
    final won = iWon ?? true;
    final winner = won ? me : m.opponentOf(me)!;
    await backend.reportResult(d.code, id, winner, walkover: iWon == null);
    await profile.recordTournamentMatch();
    _notify();
  }

  /// You left the room of your match without playing it out: the match
  /// stays open (your opponent can claim it), you can try again.
  bool _sawRoom = false;
  void _onGame() {
    if (_activeMatch == null) {
      _sawRoom = false;
      return;
    }
    if (game.inRoom) {
      _sawRoom = true;
    } else if (_sawRoom) {
      _sawRoom = false;
      _activeMatch = null;
      _notify();
    }
  }

  /// Your opponent didn't show: take the win.
  Future<void> claimWalkover() async {
    final d = _data, m = myMatch, me = myUid;
    if (d == null || m == null || me == null || !canClaimWalkover) return;
    await backend.reportResult(d.code, m.id, me, walkover: true);
    _notify();
  }

  /// Host: decide a match that is stuck (somebody left).
  Future<void> decide(String matchId, String winner) async {
    final d = _data;
    if (d == null || !isHost) return;
    await backend.reportResult(
      d.code,
      matchId,
      winner,
      walkover: true,
      force: true,
    );
  }

  // ---------------------------------------------------------------------------

  /// Follows [code]; completes once its first state is in.
  Future<void> _follow(String code) {
    _stopFollowing();
    _code = code;
    final first = _firstData = Completer<void>();
    _sub = backend.watch(code).listen(_onData);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      // Walk-over countdowns depend on time, not only on data.
      if (_data?.status == TournamentStatus.running) _notify();
    });
    return first.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw TournamentException(
        'Geen verbinding met het toernooi. Probeer opnieuw.',
      ),
    );
  }

  Completer<void>? _firstData;
  void _completeFirst() {
    final c = _firstData;
    _firstData = null;
    if (c != null && !c.isCompleted) c.complete();
  }

  void _stopFollowing() {
    _completeFirst();
    _sub?.cancel();
    _sub = null;
    _ticker?.cancel();
    _ticker = null;
    _code = null;
    _data = null;
    _bracket = Bracket.build(const [], const {});
  }

  void _onData(TournamentData? d) {
    if (d == null || d.status == TournamentStatus.cancelled) {
      final wasIn = _data != null;
      _stopFollowing();
      _activeMatch = null;
      if (wasIn || d != null) {
        _error = d?.status == TournamentStatus.cancelled
            ? 'De host heeft het toernooi gestopt.'
            : 'Dit toernooi bestaat niet meer.';
      }
      _notify();
      return;
    }
    _data = d;
    _bracket = Bracket.of(d);
    _completeFirst();

    final champ = _bracket.champion;
    if (champ != null) {
      if (isHost && d.status == TournamentStatus.running) {
        unawaited(backend.finish(d.code));
      }
      if (champ == myUid && _rewarded.add(d.code)) {
        unawaited(profile.recordTournamentWin());
      }
    }
    _notify();
  }

  Future<T?> _run<T>(Future<T> Function() action) async {
    _busy = true;
    _error = null;
    _notify();
    try {
      return await action();
    } on TournamentException catch (e) {
      _error = e.message;
      return null;
    } catch (e) {
      debugPrint('Tournament: $e');
      _error = 'Er ging iets mis. Probeer opnieuw.';
      return null;
    } finally {
      _busy = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    game.removeListener(_onGame);
    _stopFollowing();
    super.dispose();
  }
}
