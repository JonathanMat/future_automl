import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'game_backend.dart';

/// Offline backend for building and testing the UI on one phone.
///
/// The opponent is a bot that joins after [botJoinDelay], casts a random
/// spell every round and sometimes sends an emote (after a round, or back
/// when you send one). No Firebase or second phone needed.
class MockGameBackend implements GameBackend {
  MockGameBackend({
    this.config = const GameConfig(),
    this.useCamera = true,
    this.mirrorCameraAsOpponent = true,
    this.botJoinDelay = const Duration(seconds: 2),
    this.botEmotes = true,
    this.botAsksRematch = true,
    Random? random,
  }) : _random = random ?? Random();

  final GameConfig config;

  /// The mock never uses audio.
  @override
  bool voiceChat = true;

  /// Open the real camera. Turn off in widget tests.
  final bool useCamera;

  /// Show your own camera as the "opponent" video, to test the layout.
  final bool mirrorCameraAsOpponent;

  final Duration botJoinDelay;

  /// The bot's name, e.g. your tournament opponent's (mock tournaments).
  String botName = 'Bot';

  /// Let the bot send emotes. Turn off in tests that count them.
  final bool botEmotes;

  /// Let the bot sometimes ask for a rematch itself after a game. Turn off
  /// in tests that check asking for one yourself.
  final bool botAsksRematch;
  final Random _random;

  static const _myUid = 'mock-me';
  static const _botUid = 'mock-bot';

  late GameState _state = GameState(config: config);
  final _stateCtl = StreamController<GameState>.broadcast();
  final _remoteCtl = StreamController<MediaStream?>.broadcast();
  final _emoteCtl = StreamController<Emote>.broadcast();
  MediaStream? _localStream;
  Timer? _ticker;
  final List<Timer> _timers = [];
  Spell? _botSpell;
  int _wins = 0, _losses = 0;

  @override
  GameState get state => _state;

  @override
  Stream<GameState> get gameState => _stateCtl.stream;

  @override
  MediaStream? get localStream => _localStream;

  @override
  Stream<MediaStream?> get remoteStream => _remoteCtl.stream;

  @override
  Future<String> createRoom({required String playerName}) async {
    await _openCamera();
    _emit(
      GameState(
        config: config,
        phase: GamePhase.waitingForOpponent,
        roomCode: 'TEST',
        isHost: true,
        me: _player(_myUid, playerName),
        callStatus: CallStatus.connecting,
      ),
    );
    _later(botJoinDelay, _botJoined);
    return 'TEST';
  }

  @override
  Future<void> joinRoom(String code, {required String playerName}) async {
    await _openCamera();
    _emit(
      GameState(
        config: config,
        phase: GamePhase.waitingForOpponent,
        roomCode: code.toUpperCase(),
        me: _player(_myUid, playerName),
        callStatus: CallStatus.connecting,
      ),
    );
    _botJoined();
  }

  void _botJoined() {
    _emit(
      _state.copyWith(
        opponent: _player(_botUid, botName),
        callStatus: CallStatus.connected,
      ),
    );
    if (mirrorCameraAsOpponent) _remoteCtl.add(_localStream);
    _startRound(intro: true);
  }

  PlayerState _player(String uid, String name) => PlayerState(
    uid: uid,
    name: name,
    lives: config.startLives,
    shieldsUsed: 0,
    online: true,
  );

  /// The bot drops out (for tests): [left] on purpose, else a lost
  /// connection. No new rounds start until it is back.
  void opponentAway({bool left = false}) {
    final bot = _state.opponent;
    if (bot == null) return;
    _emit(
      _state.copyWith(opponent: _withPresence(bot, online: false, left: left)),
    );
  }

  /// The bot is back: the game goes on.
  void opponentBack() {
    final bot = _state.opponent;
    if (bot == null || bot.online) return;
    _emit(_state.copyWith(opponent: _withPresence(bot, online: true)));
    if (_waitingForBot) {
      _waitingForBot = false;
      _startRound();
    }
  }

  bool _waitingForBot = false;

  PlayerState _withPresence(
    PlayerState p, {
    required bool online,
    bool left = false,
  }) => PlayerState(
    uid: p.uid,
    name: p.name,
    lives: p.lives,
    shieldsUsed: p.shieldsUsed,
    online: online,
    left: left,
  );

  @override
  Future<void> claimForfeit() async {
    final bot = _state.opponent;
    final running = {
      GamePhase.countdown,
      GamePhase.cast,
      GamePhase.resolving,
      GamePhase.roundResult,
    }.contains(_state.phase);
    if (bot == null || bot.online || !running) return;
    _cancelTimers();
    _waitingForBot = false;
    _wins++;
    _emit(_state.copyWith(phase: GamePhase.finished, iWon: true));
  }

  /// [intro]: first round of a game, wait for the "VS" intro.
  void _startRound({bool intro = false}) {
    // Like the Firebase host: no new round while the opponent is away.
    if (_state.opponent?.online == false) {
      _waitingForBot = true;
      return;
    }
    final castAt = DateTime.now()
        .add(config.roundLead)
        .add(intro ? config.introLead : Duration.zero)
        .add(config.countdown);
    _botSpell = null;
    _emit(
      _state.copyWith(
        round: _state.round + 1,
        castAt: castAt,
        clearMySpell: true,
        phase: GamePhase.countdown,
      ),
    );

    // The bot casts somewhere in the first second of the cast window.
    final botDelay =
        castAt.difference(DateTime.now()) +
        Duration(milliseconds: _random.nextInt(1000));
    _later(botDelay, () {
      final bot = _state.opponent!;
      final options = Spell.values
          .where((s) => s != Spell.schild || bot.shieldAvailable(config))
          .toList();
      _botSpell = options[_random.nextInt(options.length)];
    });

    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) => _tick());
  }

  void _tick() {
    final castAt = _state.castAt!;
    final phase = phaseForTime(
      now: DateTime.now(),
      castAt: castAt,
      config: config,
      hasResult: false,
    );
    if (phase == GamePhase.resolving) {
      _ticker?.cancel();
      _resolve();
    } else if (phase != _state.phase) {
      _emit(_state.copyWith(phase: phase));
    }
  }

  void _resolve() {
    final me = _state.me!, bot = _state.opponent!;
    final r = resolveRound(
      hostSpell: _state.mySpell,
      guestSpell: _botSpell,
      hostShieldsUsed: me.shieldsUsed,
      guestShieldsUsed: bot.shieldsUsed,
      config: config,
    );
    final newMe = PlayerState(
      uid: me.uid,
      name: me.name,
      lives: me.lives - (r.winner == Side.guest ? 1 : 0),
      shieldsUsed: r.hostShieldsUsed,
      online: true,
    );
    final newBot = PlayerState(
      uid: bot.uid,
      name: bot.name,
      lives: bot.lives - (r.winner == Side.host ? 1 : 0),
      shieldsUsed: r.guestShieldsUsed,
      online: bot.online,
      left: bot.left,
    );
    final finished = newMe.lives <= 0 || newBot.lives <= 0;
    if (finished) newMe.lives > 0 ? _wins++ : _losses++;

    _emit(
      _state.copyWith(
        me: newMe,
        opponent: newBot,
        phase: finished ? GamePhase.finished : GamePhase.roundResult,
        iWon: finished ? newMe.lives > 0 : null,
        lastResult: RoundResult(
          round: _state.round,
          mySpell: r.hostSpell,
          opponentSpell: r.guestSpell,
          outcome: r.winner == null
              ? RoundOutcome.draw
              : (r.winner == Side.host ? RoundOutcome.win : RoundOutcome.lose),
          reason: r.reason,
        ),
      ),
    );
    if (!finished) _later(config.resultPause, _startRound);

    // Now and then the bot reacts to the round.
    final Emote? reaction;
    if (finished) {
      reaction = _random.nextBool() ? Emote.gg : Emote.goedGespeeld;
    } else if (r.winner == null || _random.nextDouble() > .35) {
      reaction = null;
    } else if (r.winner == Side.guest) {
      reaction = Emote.haha;
    } else {
      reaction = _random.nextBool() ? Emote.boos : Emote.huilen;
    }
    if (reaction != null) {
      _botEmote(reaction, const Duration(milliseconds: 1400));
    }
    // Sometimes the bot asks for a rematch itself.
    if (finished && botAsksRematch && _random.nextBool()) {
      _later(const Duration(milliseconds: 2500), () {
        if (_state.phase == GamePhase.finished) {
          _emit(_state.copyWith(opponentWantsRematch: true));
        }
      });
    }
  }

  void _botEmote(Emote emote, Duration delay) {
    if (!botEmotes) return;
    _later(delay, () {
      if (_state.opponent != null && !_emoteCtl.isClosed) {
        _emoteCtl.add(emote);
      }
    });
  }

  @override
  Stream<Emote> get opponentEmotes => _emoteCtl.stream;

  @override
  Future<void> sendEmote(Emote emote) async {
    if (_state.opponent == null) return;
    // The bot answers half of the time.
    if (_random.nextBool()) return;
    final answer = switch (emote) {
      Emote.hallo => Emote.hallo,
      Emote.gg || Emote.goedGespeeld => Emote.gg,
      Emote.haha => Emote.boos,
      Emote.boos => Emote.haha,
      Emote.huilen => Emote.haha,
    };
    _botEmote(answer, Duration(milliseconds: 900 + _random.nextInt(800)));
  }

  @override
  Future<void> submitSpell(Spell spell) async {
    if (!_state.canCast) {
      throw GameBackendException('Je kan nu geen spreuk casten.');
    }
    if (spell == Spell.schild && !_state.myShieldAvailable) {
      throw GameBackendException('Je schild is al gebruikt.');
    }
    _emit(_state.copyWith(mySpell: spell));
  }

  /// The bot always accepts, after a moment (at once when it asked first).
  @override
  Future<void> playAgain() async {
    if (_state.phase != GamePhase.finished || _state.iWantRematch) return;
    _emit(_state.copyWith(iWantRematch: true));
    _later(
      _state.opponentWantsRematch
          ? Duration.zero
          : const Duration(milliseconds: 900),
      _startRematch,
    );
  }

  void _startRematch() {
    if (_state.phase != GamePhase.finished) return;
    _emit(
      GameState(
        config: config,
        phase: GamePhase.countdown,
        roomCode: _state.roomCode,
        isHost: _state.isHost,
        me: _player(_myUid, _state.me!.name),
        opponent: _player(_botUid, botName),
        callStatus: _state.callStatus,
      ),
    );
    _startRound(intro: true);
  }

  @override
  Future<Uint8List?> captureLocalFrame() async {
    final tracks = _localStream?.getVideoTracks() ?? const [];
    if (tracks.isEmpty) return null;
    return (await tracks.first.captureFrame()).asUint8List();
  }

  @override
  Stream<List<LeaderboardEntry>> leaderboard({int limit = 10}) async* {
    yield [
      LeaderboardEntry(
        uid: _myUid,
        name: _state.me?.name ?? 'Jij',
        wins: _wins,
        losses: _losses,
      ),
      // Demo players, so the scorebord (and its animations) can be tried
      // without a Firebase account full of test data.
      for (final (i, (name, w, l)) in _demoPlayers.indexed)
        LeaderboardEntry(
          uid: 'demo-$i',
          name: name,
          tag: '${2101 + i * 737}',
          wins: w,
          losses: l,
        ),
    ].take(limit).toList();
  }

  static const _demoPlayers = [
    ('Lotte', 14, 5),
    ('Jonas', 11, 7),
    ('Amira', 9, 4),
    ('Daan', 7, 8),
    ('Noor', 6, 3),
    ('Milan', 4, 6),
    ('Sofie', 2, 5),
  ];

  @override
  Future<void> leaveRoom() async {
    _cancelTimers();
    _remoteCtl.add(null);
    await _closeCamera();
    _emit(GameState(config: config));
  }

  @override
  Future<void> dispose() async {
    await leaveRoom();
    await _stateCtl.close();
    await _remoteCtl.close();
    await _emoteCtl.close();
  }

  @override
  Future<void> openCamera() => _openCamera();

  Future<void> _openCamera() async {
    if (!useCamera || _localStream != null) return;
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': false,
      'video': {'facingMode': 'user'},
    });
  }

  Future<void> _closeCamera() async {
    final stream = _localStream;
    _localStream = null;
    if (stream == null) return;
    for (final track in stream.getTracks()) {
      await track.stop();
    }
    await stream.dispose();
  }

  void _later(Duration delay, void Function() action) =>
      _timers.add(Timer(delay, action));

  void _cancelTimers() {
    _ticker?.cancel();
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
  }

  void _emit(GameState state) {
    _state = state;
    if (!_stateCtl.isClosed) _stateCtl.add(state);
  }
}
