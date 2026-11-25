import 'dart:async';
import 'dart:math';

import 'tournament_backend.dart';

/// Tournaments in memory, with bots, to try the whole thing on one phone.
///
/// Bots join the waiting room with [addBots]. A match between two bots
/// finishes by itself after [botMatchTime]; in a match against you, a bot
/// opens the room when it is the first player, and you play the duel
/// against the mock game backend's bot.
class MockTournamentBackend extends TournamentBackend {
  MockTournamentBackend({
    Random? random,
    this.botMatchTime = (
      min: const Duration(seconds: 4),
      max: const Duration(seconds: 9),
    ),
    this.botRoomDelay = const Duration(milliseconds: 1200),
  }) : _random = random ?? Random();

  final Random _random;

  /// How long a bot-vs-bot match takes.
  final ({Duration min, Duration max}) botMatchTime;

  /// How long a bot takes to open the room for its match against you.
  final Duration botRoomDelay;

  static const botNames = [
    'Lotte',
    'Daan',
    'Milan',
    'Sara',
    'Yusuf',
    'Noah',
    'Emma',
    'Ines',
    'Ruben',
    'Aya',
    'Wout',
    'Fien',
    'Lars',
    'Nina',
    'Bram',
  ];

  final _data = <String, TournamentData>{};
  final _streams = <String, StreamController<TournamentData?>>{};
  final _busy = <String>{}; // "code/matchId" with a bot timer running
  final _timers = <Timer>[];

  int get _now => DateTime.now().millisecondsSinceEpoch;

  @override
  bool get supportsBots => true;

  StreamController<TournamentData?> _ctl(String code) =>
      _streams[code] ??= StreamController<TournamentData?>.broadcast();

  void _set(String code, TournamentData? data) {
    if (data == null) {
      _data.remove(code);
    } else {
      _data[code] = data;
    }
    final ctl = _streams[code];
    if (ctl != null && !ctl.isClosed) ctl.add(data);
    if (data != null && data.status == TournamentStatus.running) {
      _driveBots(data);
    }
  }

  TournamentData _get(String code) {
    final d = _data[code];
    if (d == null) throw TournamentException('Toernooi $code bestaat niet.');
    return d;
  }

  @override
  Future<String> create(TournamentMe me) async {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    String code;
    do {
      code = List.generate(
        5,
        (_) => alphabet[_random.nextInt(alphabet.length)],
      ).join();
    } while (_data.containsKey(code));
    _set(
      code,
      TournamentData(
        code: code,
        hostUid: me.uid,
        status: TournamentStatus.lobby,
        players: {
          me.uid: TournamentPlayer(
            uid: me.uid,
            name: me.name,
            tag: me.tag,
            joinedAt: _now,
          ),
        },
      ),
    );
    return code;
  }

  @override
  Future<void> join(String code, TournamentMe me) async {
    final d = _get(code);
    if (d.players.containsKey(me.uid)) return;
    if (d.status != TournamentStatus.lobby) {
      throw TournamentException('Dit toernooi is al begonnen.');
    }
    if (d.players.length >= maxTournamentPlayers) {
      throw TournamentException('Dit toernooi is vol ($maxTournamentPlayers).');
    }
    _set(
      code,
      d.copyWith(
        players: {
          ...d.players,
          me.uid: TournamentPlayer(
            uid: me.uid,
            name: me.name,
            tag: me.tag,
            joinedAt: _now,
          ),
        },
      ),
    );
  }

  @override
  Future<void> addBots(String code, int count) async {
    var d = _get(code);
    if (d.status != TournamentStatus.lobby) return;
    final players = {...d.players};
    for (final name in botNames) {
      if (count <= 0 || players.length >= maxTournamentPlayers) break;
      final uid = 'bot-${name.toLowerCase()}';
      if (players.containsKey(uid)) continue;
      players[uid] = TournamentPlayer(
        uid: uid,
        name: name,
        tag: '${1000 + _random.nextInt(9000)}',
        joinedAt: _now + players.length,
        bot: true,
      );
      count--;
    }
    d = d.copyWith(players: players);
    _set(code, d);
  }

  @override
  Stream<TournamentData?> watch(String code) => Stream.multi((out) {
    out.add(_data[code]);
    final sub = _ctl(code).stream.listen(out.add);
    out.onCancel = sub.cancel;
  });

  @override
  Future<void> start(String code, List<String> seeds) async {
    final d = _get(code);
    _set(
      code,
      d.copyWith(
        status: TournamentStatus.running,
        seeds: seeds,
        startedAt: _now,
      ),
    );
  }

  @override
  Future<void> setRoom(String code, String matchId, String roomCode) async {
    final d = _get(code);
    _set(code, d.copyWith(rooms: {...d.rooms, matchId: roomCode}));
  }

  @override
  Future<void> setMatchReady(
    String code,
    String matchId,
    String uid, {
    required bool ready,
  }) async {
    final d = _get(code);
    final times = {...?d.readyAt[matchId]};
    if (ready) {
      if (d.status != TournamentStatus.running ||
          d.results.containsKey(matchId)) {
        throw TournamentException('Dit duel is afgelopen.');
      }
      times.putIfAbsent(uid, () => _now);
    } else {
      times.remove(uid);
    }
    _set(code, d.copyWith(readyAt: {...d.readyAt, matchId: times}));
  }

  @override
  Future<bool> reportResult(
    String code,
    String matchId,
    String winner, {
    bool walkover = false,
    bool force = false,
    String? noShow,
  }) async {
    final d = _data[code];
    if (d == null || (d.results.containsKey(matchId) && !force)) return false;
    if (noShow != null) {
      final times = d.readyAt[matchId];
      if (times?[winner] == null ||
          (times?[noShow] != null && d.players[noShow]?.online == true)) {
        return false;
      }
    }
    _set(
      code,
      d.copyWith(
        results: {
          ...d.results,
          matchId: MatchResult(winner: winner, at: _now, walkover: walkover),
        },
      ),
    );
    return true;
  }

  @override
  Future<void> finish(String code) async {
    final d = _data[code];
    if (d == null || d.status == TournamentStatus.finished) return;
    _set(code, d.copyWith(status: TournamentStatus.finished));
  }

  @override
  Future<void> leave(String code, String uid, {required bool isHost}) async {
    final d = _data[code];
    if (d == null) return;
    if (d.status == TournamentStatus.lobby) {
      if (isHost) {
        _set(code, d.copyWith(status: TournamentStatus.cancelled));
      } else {
        _set(code, d.copyWith(players: {...d.players}..remove(uid)));
      }
      return;
    }
    final p = d.players[uid];
    if (p == null) return;
    _set(
      code,
      d.copyWith(
        players: {
          ...d.players,
          uid: TournamentPlayer(
            uid: p.uid,
            name: p.name,
            tag: p.tag,
            joinedAt: p.joinedAt,
            online: false,
            bot: p.bot,
          ),
        },
      ),
    );
  }

  /// Plays the bots' part: finishes bot-vs-bot matches after a while and
  /// opens the room when a bot is the first player against a person.
  void _driveBots(TournamentData d) {
    final bracket = Bracket.of(d);
    for (final m in bracket.matches.where((m) => m.isReady)) {
      final key = '${d.code}/${m.id}';
      if (_busy.contains(key)) continue;
      final a = d.players[m.a], b = d.players[m.b];
      if (a == null || b == null) continue;

      if (a.bot && b.bot) {
        _busy.add(key);
        final spread =
            botMatchTime.max.inMilliseconds - botMatchTime.min.inMilliseconds;
        final wait =
            botMatchTime.min +
            Duration(milliseconds: spread <= 0 ? 0 : _random.nextInt(spread));
        // A room code so the bracket shows the match as live.
        _later(
          const Duration(milliseconds: 300),
          () => setRoom(d.code, m.id, 'B0T${m.index % 10}'),
        );
        _later(
          wait,
          () => reportResult(d.code, m.id, _random.nextBool() ? a.uid : b.uid),
        );
      } else if (a.bot && !d.rooms.containsKey(m.id)) {
        _busy.add(key);
        // The mock game backend accepts any code: the person joins this.
        _later(botRoomDelay, () => setRoom(d.code, m.id, 'TEST'));
      }
    }
  }

  void _later(Duration delay, void Function() action) {
    _timers.add(
      Timer(delay, () {
        if (!_closed) action();
      }),
    );
  }

  bool _closed = false;

  @override
  Future<void> dispose() async {
    _closed = true;
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
    for (final c in _streams.values) {
      await c.close();
    }
  }
}
