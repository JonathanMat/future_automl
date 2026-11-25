import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../../utils/db_values.dart';
import '../../../utils/player_tag.dart';
import '../commit_reveal.dart';
import '../game_backend.dart';
import 'audio_session.dart';
import 'ice_config.dart';
import 'webrtc_call.dart';

/// Real backend: Firebase Realtime Database for rooms, rounds and the
/// leaderboard, WebRTC for the video call.
///
/// Database layout (see `database.rules.json` for who may write what):
/// ```
/// rooms/{code}
///   hostUid, guestUid, status: waiting|playing|finished|closed,
///   game: 1, winnerUid, createdAt
///   players/{uid}: {name, lives, shieldsUsed, online}
///   currentRound: 3
///   rounds/{n}
///     castAt: <server ms>
///     commits/{uid}: {hash, at: <server ms>}
///     reveals/{uid}: {spell, salt}
///     result: {winnerUid?, reason, at, spells/{uid}: "vuur"}
///   rematch/{uid}: true                        (after a game, see playAgain)
///   emotes/{uid}: {e: "haha", at: <server ms>}  (last emote per player)
///   signaling/...                              (see WebRtcCall)
/// leaderboard/{uid}: {name, tag, wins, losses}
/// ```
///
/// The host phone runs the game: it starts rounds and decides results.
/// Both phones only ever write their own spell, using commit-reveal so the
/// opponent can't read it early.
class FirebaseGameBackend implements GameBackend {
  FirebaseGameBackend({
    FirebaseAuth? auth,
    FirebaseDatabase? database,
    this.config = const GameConfig(),
    this.ice = const IceConfig(),
  }) : _auth = auth ?? FirebaseAuth.instance,
       _db = database ?? FirebaseDatabase.instance;

  final FirebaseAuth _auth;
  final FirebaseDatabase _db;
  final GameConfig config;
  final IceConfig ice;

  @override
  bool voiceChat = true;

  /// Commits written by a phone up to this long after the cast window still
  /// count, to allow for network delay.
  static const _lateTolerance = Duration(milliseconds: 600);
  static const _earlyTolerance = Duration(milliseconds: 300);
  static const _codeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  late GameState _state = GameState(config: config);
  final _stateCtl = StreamController<GameState>.broadcast();
  final _remoteCtl = StreamController<MediaStream?>.broadcast();
  final _emoteCtl = StreamController<Emote>.broadcast();

  /// Server time of the last opponent emote shown, so each one shows once.
  int _lastEmoteAt = 0;

  /// Emotes older than this when they arrive are not shown (e.g. the last
  /// one in the room, when you join).
  static const _emoteMaxAge = Duration(seconds: 5);

  /// About the lobby's page transition (see [_enterRoom]).
  static const _connectDelay = Duration(milliseconds: 350);
  Timer? _connectTimer;

  String? _uid;
  String? _code;
  bool _isHost = false;
  DatabaseReference? _roomRef;
  Map<Object?, Object?>? _room;
  int _serverOffsetMs = 0;
  WebRtcCall? _call;
  CallStatus _callStatus = CallStatus.none;
  String? _error;
  Timer? _ticker;
  final List<StreamSubscription<Object?>> _subs = [];

  /// Spells this phone cast, per round, kept secret until reveal.
  final Map<int, ({Spell spell, String salt})> _secrets = {};
  final Set<int> _revealed = {};
  int _hostStartedRound = 0;
  int _hostResolvedRound = 0;
  bool _hostStartingGame = false;
  bool _hostStartingRematch = false;

  /// Game number in the room ([GameState.lastResult] belongs to it).
  int _game = 0;

  /// The game whose first round already got the intro delay.
  int? _introGame;
  final Set<int> _leaderboardRecorded = {};

  // ---------------------------------------------------------------------------
  // GameBackend API
  // ---------------------------------------------------------------------------

  @override
  GameState get state => _state;

  @override
  Stream<GameState> get gameState => _stateCtl.stream;

  @override
  MediaStream? get localStream => _call?.localStream;

  /// Opened by [openCamera] and handed to the next call.
  MediaStream? _warmStream;
  bool _warmAudio = false;

  @override
  Future<void> openCamera() async {
    // One camera at a time: some phones can't open the front camera twice.
    await _leaveIfInRoom();
    if (_warmStream != null && _warmAudio == voiceChat) return;
    await _releaseWarm();
    _warmStream = await WebRtcCall.openLocalStream(audio: voiceChat);
    _warmAudio = voiceChat;
  }

  /// The warmed-up stream for a new call, if it matches its audio setting.
  Future<MediaStream?> _takeWarm() async {
    final s = _warmStream;
    if (s == null) return null;
    if (_warmAudio != voiceChat) {
      await _releaseWarm();
      return null;
    }
    _warmStream = null;
    return s;
  }

  Future<void> _releaseWarm() async {
    final s = _warmStream;
    _warmStream = null;
    if (s == null) return;
    for (final track in s.getTracks()) {
      await track.stop();
    }
    await s.dispose();
    // Opening the mic put Android in call mode: switch back.
    if (_warmAudio) await AudioSession.release();
  }

  @override
  Stream<MediaStream?> get remoteStream => _remoteCtl.stream;

  @override
  Future<String> createRoom({required String playerName}) async {
    try {
      return await _createRoom(playerName);
    } catch (_) {
      await _releaseWarm();
      rethrow;
    }
  }

  Future<String> _createRoom(String playerName) async {
    await _leaveIfInRoom();
    final uid = await _signIn();

    for (var attempt = 0; attempt < 10; attempt++) {
      final code = _newCode();
      final ref = _db.ref('rooms/$code');
      // No get() first: the rules refuse a code someone else uses, which
      // saves a round trip before the lobby opens.
      try {
        await ref.set({
          'hostUid': uid,
          'status': 'waiting',
          'game': 1,
          'currentRound': 0,
          'createdAt': ServerValue.timestamp,
          'players': {uid: _newPlayer(playerName)},
        });
      } on FirebaseException catch (e) {
        // Someone else's room has this code: try another one.
        if (e.code == 'permission-denied') continue;
        rethrow;
      }
      await _enterRoom(code, isHost: true);
      return code;
    }
    throw GameBackendException('Kon geen vrije kamercode vinden.');
  }

  @override
  Future<void> joinRoom(String code, {required String playerName}) async {
    try {
      await _joinRoom(code, playerName);
    } catch (_) {
      await _releaseWarm();
      rethrow;
    }
  }

  Future<void> _joinRoom(String code, String playerName) async {
    await _leaveIfInRoom();
    final uid = await _signIn();
    code = code.trim().toUpperCase();
    final ref = _db.ref('rooms/$code');

    final snap = await ref.get();
    final room = _asMap(snap.value);
    if (room == null) throw GameBackendException('Kamer $code bestaat niet.');
    final guestUid = room['guestUid'];
    if (room['hostUid'] == uid) {
      throw GameBackendException('Dit is je eigen kamer.');
    }
    if (guestUid != null && guestUid != uid) {
      throw GameBackendException('Kamer $code is al vol.');
    }
    if (guestUid == null && room['status'] != 'waiting') {
      throw GameBackendException('Het spel in kamer $code is al bezig.');
    }

    try {
      if (guestUid == null) await ref.child('guestUid').set(uid);
      await ref.child('players/$uid').set(_newPlayer(playerName));
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw GameBackendException('Kamer $code is net vol geraakt.');
      }
      rethrow;
    }
    await _enterRoom(code, isHost: false);
  }

  @override
  Future<void> submitSpell(Spell spell) async {
    final round = _state.round;
    final room = _room;
    if (room == null || !_state.canCast) {
      throw GameBackendException('Je kan nu geen spreuk casten.');
    }
    if (spell == Spell.schild && !_state.myShieldAvailable) {
      throw GameBackendException('Je schild is al gebruikt.');
    }
    final salt = CommitReveal.newSalt();
    _secrets[round] = (spell: spell, salt: salt);
    _recompute(force: true);
    await _roomRef!.child('rounds/$round/commits/$_uid').set({
      'hash': CommitReveal.commitHash(spell, salt),
      'at': ServerValue.timestamp,
    });
  }

  @override
  Stream<Emote> get opponentEmotes => _emoteCtl.stream;

  @override
  Future<void> sendEmote(Emote emote) async {
    final ref = _roomRef;
    final uid = _uid;
    if (ref == null || uid == null) return;
    // One slot per player: each emote overwrites the previous one.
    await ref.child('emotes/$uid').set({
      'e': emote.wire,
      'at': ServerValue.timestamp,
    });
  }

  void _onEmote(DataSnapshot snap) {
    if (snap.key == null || snap.key == _uid) return;
    final v = _asMap(snap.value);
    final emote = Emote.fromWire(v?['e']);
    final at = _asInt(v?['at']);
    if (emote == null || at <= _lastEmoteAt) return;
    _lastEmoteAt = at;
    if (_serverNow - at > _emoteMaxAge.inMilliseconds) return;
    if (!_emoteCtl.isClosed) _emoteCtl.add(emote);
  }

  /// Asks for a rematch. The host starts it once both asked (see
  /// [_startRematchIfAgreed]).
  @override
  Future<void> playAgain() async {
    final room = _room;
    if (room == null || room['status'] != 'finished') return;
    await _roomRef!.child('rematch/$_uid').set(true);
  }

  @override
  Future<void> claimForfeit() async {
    final room = _room;
    final ref = _roomRef;
    if (room == null || ref == null || room['status'] != 'playing') return;
    final opponentUid = _isHost ? room['guestUid'] : room['hostUid'];
    final players = _asMap(room['players']) ?? const {};
    if (_asMap(players[opponentUid])?['online'] == true) return; // back
    await ref.update({
      'status': 'finished',
      'winnerUid': _uid,
      'forfeit': true,
    });
  }

  @override
  Future<Uint8List?> captureLocalFrame() async {
    final tracks = localStream?.getVideoTracks() ?? const [];
    if (tracks.isEmpty) return null;
    return (await tracks.first.captureFrame()).asUint8List();
  }

  @override
  Stream<List<LeaderboardEntry>> leaderboard({int limit = 10}) {
    return _db
        .ref('leaderboard')
        .orderByChild('wins')
        .limitToLast(limit)
        .onValue
        .map((event) {
          final entries = <LeaderboardEntry>[];
          for (final child in event.snapshot.children) {
            final v = _asMap(child.value) ?? const {};
            entries.add(
              LeaderboardEntry(
                uid: child.key ?? '',
                name: DbValues.text(v['name']) ?? '?',
                tag: PlayerTag.parse(v['tag']),
                wins: _asInt(v['wins']),
                losses: _asInt(v['losses']),
              ),
            );
          }
          return entries.reversed.toList();
        });
  }

  @override
  Future<void> leaveRoom() async {
    final ref = _roomRef;
    final uid = _uid;
    final wasHost = _isHost;
    final midGame = _room?['status'] == 'playing';
    final myName = _asMap(_asMap(_room?['players'])?[uid])?['name'];
    await _cleanup();
    if (ref == null || uid == null) return;
    try {
      await ref.child('players/$uid/online').onDisconnect().cancel();
      if (midGame) {
        // Keep the room: the opponent waits a moment for you, then wins
        // (see claimForfeit). For you it is a loss.
        await ref.update({
          'players/$uid/online': false,
          'players/$uid/left': true,
        });
        _writeLeaderboard(uid, won: false, name: myName);
      } else if (wasHost) {
        await ref.update({'status': 'closed', 'signaling': null});
      } else {
        await ref.update({'status': 'closed', 'players/$uid/online': false});
      }
    } catch (e) {
      debugPrint('leaveRoom: $e');
    }
  }

  @override
  Future<void> dispose() async {
    await leaveRoom();
    await _releaseWarm();
    await _stateCtl.close();
    await _remoteCtl.close();
    await _emoteCtl.close();
  }

  // ---------------------------------------------------------------------------
  // Room lifecycle
  // ---------------------------------------------------------------------------

  Future<String> _signIn() async {
    final user = _auth.currentUser ?? (await _auth.signInAnonymously()).user;
    if (user == null) throw GameBackendException('Inloggen mislukt.');
    _uid = user.uid;
    return user.uid;
  }

  Map<String, Object> _newPlayer(String name) => {
    'name': name.trim().isEmpty ? 'Speler' : name.trim(),
    'lives': config.startLives,
    'shieldsUsed': 0,
    'online': true,
  };

  String _newCode() {
    final r = Random.secure();
    return List.generate(
      4,
      (_) => _codeAlphabet[r.nextInt(_codeAlphabet.length)],
    ).join();
  }

  Future<void> _enterRoom(String code, {required bool isHost}) async {
    _introGame = null;
    _code = code;
    _isHost = isHost;
    _error = null;
    final ref = _roomRef = _db.ref('rooms/$code');

    // Presence: mark offline when the app loses its connection.
    // onDisconnect fires once, so register it again after every reconnect.
    final online = ref.child('players/$_uid/online');
    _subs.add(
      _db.ref('.info/connected').onValue.listen((event) async {
        if (event.snapshot.value != true || _roomRef == null) return;
        await online.onDisconnect().set(false);
        await online.set(true);
      }),
    );

    _subs.add(
      _db.ref('.info/serverTimeOffset').onValue.listen((event) {
        _serverOffsetMs = _asInt(event.snapshot.value);
      }),
    );

    final call = _call = WebRtcCall(
      signaling: ref.child('signaling'),
      isCaller: isHost,
      ice: ice,
      audio: voiceChat,
      localStream: await _takeWarm(),
    );
    _subs.add(call.remoteStream.listen(_remoteCtl.add));
    _subs.add(
      call.status.listen((s) {
        _callStatus = s;
        _recompute(force: true);
      }),
    );
    await call.openCamera();
    // Setting up the peer connection is heavy: start it once the lobby has
    // slid in, so the page transition stays smooth. The guest needs the
    // offer, which the host writes right after.
    _connectTimer?.cancel();
    _connectTimer = Timer(_connectDelay, () {
      if (_call != call) return; // left already
      unawaited(
        call.connect().catchError((Object e) {
          debugPrint('WebRTC connect failed: $e');
          _callStatus = CallStatus.failed;
          _recompute(force: true);
        }),
      );
    });

    _subs.add(
      ref.onValue.listen(
        (event) {
          _room = _asMap(event.snapshot.value);
          _recompute(force: true);
        },
        onError: (Object e) {
          _error = 'Verbinding met de kamer verloren: $e';
          _recompute(force: true);
        },
      ),
    );

    final emotes = ref.child('emotes');
    _subs
      ..add(emotes.onChildAdded.listen((e) => _onEmote(e.snapshot)))
      ..add(emotes.onChildChanged.listen((e) => _onEmote(e.snapshot)));

    _ticker = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => _recompute(),
    );
  }

  Future<void> _leaveIfInRoom() async {
    if (_roomRef != null) await leaveRoom();
  }

  Future<void> _cleanup() async {
    _ticker?.cancel();
    _ticker = null;
    _connectTimer?.cancel();
    _connectTimer = null;
    for (final sub in _subs) {
      await sub.cancel();
    }
    _subs.clear();
    final call = _call;
    _call = null;
    await call?.close();
    _remoteCtl.add(null);
    _roomRef = null;
    _room = null;
    _code = null;
    _isHost = false;
    _callStatus = CallStatus.none;
    _secrets.clear();
    _revealed.clear();
    _hostStartedRound = 0;
    _hostResolvedRound = 0;
    _hostStartingGame = false;
    _hostStartingRematch = false;
    _game = 0;
    _leaderboardRecorded.clear();
    _lastEmoteAt = 0;
    _emit(GameState(config: config));
  }

  // ---------------------------------------------------------------------------
  // State + game loop (runs on every room change and every 100 ms)
  // ---------------------------------------------------------------------------

  int get _serverNow => DateTime.now().millisecondsSinceEpoch + _serverOffsetMs;

  DateTime _toLocal(int serverMs) =>
      DateTime.fromMillisecondsSinceEpoch(serverMs - _serverOffsetMs);

  void _recompute({bool force = false}) {
    final room = _room;
    if (_roomRef == null) return;
    if (room == null) {
      if (force && _state.phase != GamePhase.idle) {
        _error = 'De kamer bestaat niet meer.';
        _emit(_state.copyWith(phase: GamePhase.finished, error: _error));
      }
      return;
    }

    final next = _buildState(room);
    if (force ||
        next.phase != _state.phase ||
        next.round != _state.round ||
        next.error != _state.error) {
      _emit(next);
    }

    _revealIfReady(room);
    if (_isHost) _driveGame(room);
    _recordLeaderboard(room);
  }

  GameState _buildState(Map<Object?, Object?> room) {
    final players = _asMap(room['players']) ?? const {};
    final status = room['status'] as String? ?? 'waiting';
    final hostUid = room['hostUid'] as String?;
    final guestUid = room['guestUid'] as String?;
    final opponentUid = _isHost ? guestUid : hostUid;

    final me = _player(_uid, players[_uid]);
    final opponent = _player(opponentUid, players[opponentUid]);

    final roundNr = _asInt(room['currentRound']);
    final round = _asMap(_asMap(room['rounds'])?['$roundNr']);
    final castAtServer = round == null ? null : _asInt(round['castAt']);
    final rematch = _asMap(room['rematch']) ?? const {};

    // A new game in this room: forget the last result of the old one.
    final game = _asInt(room['game']);
    final sameGame = game == _game;
    _game = game;
    final castAt = castAtServer == null ? null : _toLocal(castAtServer);
    final resultMap = _asMap(round?['result']);

    GamePhase phase;
    String? error = _error;
    switch (status) {
      case 'closed':
        phase = GamePhase.finished;
        error ??= 'Je tegenstander heeft de kamer verlaten.';
      case 'finished':
        phase = GamePhase.finished;
      case 'playing' when castAt != null:
        phase = phaseForTime(
          now: DateTime.now(),
          castAt: castAt,
          config: config,
          hasResult: resultMap != null,
        );
      case 'playing':
        phase = GamePhase.countdown;
      default:
        phase = GamePhase.waitingForOpponent;
    }

    RoundResult? lastResult = sameGame ? _state.lastResult : null;
    // Show the result of the last finished round, also after the game ended.
    final resultRoundNr = resultMap != null ? roundNr : roundNr - 1;
    final resultSource =
        resultMap ??
        _asMap(_asMap(_asMap(room['rounds'])?['$resultRoundNr'])?['result']);
    if (resultSource != null && opponentUid != null) {
      final winnerUid = resultSource['winnerUid'];
      final spells = _asMap(resultSource['spells']) ?? const {};
      lastResult = RoundResult(
        round: resultRoundNr,
        mySpell: Spell.fromWire(spells[_uid]),
        opponentSpell: Spell.fromWire(spells[opponentUid]),
        outcome: winnerUid == null
            ? RoundOutcome.draw
            : (winnerUid == _uid ? RoundOutcome.win : RoundOutcome.lose),
        reason: RoundReason.values.firstWhere(
          (r) => r.name == resultSource['reason'],
          orElse: () => RoundReason.spellBeatsSpell,
        ),
      );
    }

    return GameState(
      config: config,
      phase: phase,
      roomCode: _code,
      isHost: _isHost,
      me: me,
      opponent: opponent,
      round: roundNr,
      castAt: castAt,
      mySpell: _secrets[roundNr]?.spell,
      lastResult: lastResult,
      iWon: status == 'finished' ? room['winnerUid'] == _uid : null,
      iWantRematch: status == 'finished' && rematch[_uid] == true,
      opponentWantsRematch:
          status == 'finished' &&
          opponentUid != null &&
          rematch[opponentUid] == true,
      callStatus: _callStatus,
      error: error,
    );
  }

  PlayerState? _player(String? uid, Object? value) {
    final v = _asMap(value);
    if (uid == null || v == null) return null;
    return PlayerState(
      uid: uid,
      name: v['name'] as String? ?? 'Speler',
      lives: _asInt(v['lives']),
      shieldsUsed: _asInt(v['shieldsUsed']),
      online: v['online'] == true,
      left: v['left'] == true,
    );
  }

  /// Both phones: write the real spell once both commits are in, or once
  /// the cast window closed (so a missing opponent can't block the round).
  void _revealIfReady(Map<Object?, Object?> room) {
    final roundNr = _asInt(room['currentRound']);
    final secret = _secrets[roundNr];
    if (secret == null || _revealed.contains(roundNr)) return;
    final round = _asMap(_asMap(room['rounds'])?['$roundNr']);
    if (round == null) return;
    final commits = _asMap(round['commits']) ?? const {};
    if (!commits.containsKey(_uid)) return; // own commit not stored yet
    final windowClosed =
        _serverNow > _asInt(round['castAt']) + config.castWindow.inMilliseconds;
    if (commits.length < 2 && !windowClosed) return;

    _revealed.add(roundNr);
    _roomRef!
        .child('rounds/$roundNr/reveals/$_uid')
        .set({'spell': secret.spell.wire, 'salt': secret.salt})
        .catchError((Object e) {
          _revealed.remove(roundNr);
          debugPrint('reveal failed: $e');
        });
  }

  /// Host only: start the game, start rounds, decide results.
  void _driveGame(Map<Object?, Object?> room) {
    final status = room['status'];
    final guestUid = room['guestUid'] as String?;
    final players = _asMap(room['players']) ?? const {};

    if (status == 'waiting') {
      if (guestUid != null &&
          players.containsKey(guestUid) &&
          !_hostStartingGame) {
        _hostStartingGame = true;
        _roomRef!
            .update({'status': 'playing'})
            .whenComplete(() => _hostStartingGame = false);
      }
      return;
    }
    if (status == 'finished' && guestUid != null) {
      _startRematchIfAgreed(room, guestUid);
      return;
    }
    if (status != 'playing' || guestUid == null) return;

    final roundNr = _asInt(room['currentRound']);
    final round = _asMap(_asMap(room['rounds'])?['$roundNr']);
    final result = _asMap(round?['result']);

    // Next round: right away at the start, else after the result pause.
    final resultAt = result == null ? null : _asInt(result['at']);
    final readyForNext =
        round == null ||
        (resultAt != null &&
            _serverNow >= resultAt + config.resultPause.inMilliseconds);
    // The guest is away: no new rounds until they are back (or forfeit).
    final guestOnline = _asMap(players[guestUid])?['online'] == true;
    if (readyForNext && !guestOnline) return;
    if (readyForNext && _hostStartedRound <= roundNr) {
      // The first round of each game (also a rematch) waits for the intro.
      final game = _asInt(room['game']);
      final intro = game != _introGame;
      _introGame = game;
      _startRound(roundNr + 1, intro: intro);
      return;
    }

    if (round == null || result != null || _hostResolvedRound >= roundNr) {
      return;
    }
    final reveals = _asMap(round['reveals']) ?? const {};
    final deadline =
        _asInt(round['castAt']) +
        config.castWindow.inMilliseconds +
        config.revealGrace.inMilliseconds;
    if (reveals.length >= 2 || _serverNow > deadline) {
      _resolve(room, roundNr, round, guestUid);
    }
  }

  /// Host only: once both players asked for a rematch, reset the lives and
  /// start the first round of the new game in the same write.
  ///
  /// Starting the round right away matters: a room that is "playing" while
  /// its current round still holds the old game's final result would show
  /// (and replay the effect of) that result on both phones.
  void _startRematchIfAgreed(Map<Object?, Object?> room, String guestUid) {
    final rematch = _asMap(room['rematch']) ?? const {};
    if (_hostStartingRematch ||
        rematch[_uid] != true ||
        rematch[guestUid] != true) {
      return;
    }
    _hostStartingRematch = true;
    final players = _asMap(room['players']) ?? const {};
    final roundNr = _asInt(room['currentRound']) + 1;
    // The new game opens with the "VS" intro, like the first one.
    final castAt =
        _serverNow +
        config.roundLead.inMilliseconds +
        config.introLead.inMilliseconds +
        config.countdown.inMilliseconds;
    _hostStartedRound = roundNr;
    // This write bumps the game number: its first round has the intro
    // delay now, so _driveGame must not add it again to round 2.
    _introGame = _asInt(room['game']) + 1;
    _roomRef!
        .update({
          for (final uid in players.keys) ...{
            'players/$uid/lives': config.startLives,
            'players/$uid/shieldsUsed': 0,
          },
          'status': 'playing',
          'winnerUid': null,
          'forfeit': null,
          'game': ServerValue.increment(1),
          'rematch': null,
          'currentRound': roundNr,
          // Drop the old game's rounds: only the new first round is left.
          'rounds': {
            '$roundNr': {'castAt': castAt},
          },
        })
        .catchError((Object e) {
          _hostStartedRound = roundNr - 1;
          debugPrint('rematch failed: $e');
        })
        .whenComplete(() => _hostStartingRematch = false);
  }

  void _startRound(int roundNr, {bool intro = false}) {
    _hostStartedRound = roundNr;
    final castAt =
        _serverNow +
        config.roundLead.inMilliseconds +
        (intro ? config.introLead.inMilliseconds : 0) +
        config.countdown.inMilliseconds;
    _roomRef!
        .update({
          'currentRound': roundNr,
          'rounds/$roundNr': {'castAt': castAt},
        })
        .catchError((Object e) {
          _hostStartedRound = roundNr - 1;
          debugPrint('startRound failed: $e');
        });
  }

  void _resolve(
    Map<Object?, Object?> room,
    int roundNr,
    Map<Object?, Object?> round,
    String guestUid,
  ) {
    _hostResolvedRound = roundNr;
    final hostUid = _uid!;
    final castAt = _asInt(round['castAt']);
    final commits = _asMap(round['commits']) ?? const {};
    final reveals = _asMap(round['reveals']) ?? const {};
    final players = _asMap(room['players']) ?? const {};

    Spell? validSpell(String uid) {
      final commit = _asMap(commits[uid]);
      final reveal = _asMap(reveals[uid]);
      if (commit == null || reveal == null) return null;
      final at = _asInt(commit['at']);
      final inTime =
          at >= castAt - _earlyTolerance.inMilliseconds &&
          at <=
              castAt +
                  config.castWindow.inMilliseconds +
                  _lateTolerance.inMilliseconds;
      final spell = Spell.fromWire(reveal['spell']);
      final salt = reveal['salt'];
      final hash = commit['hash'];
      if (!inTime || spell == null || salt is! String || hash is! String) {
        return null;
      }
      return CommitReveal.verify(hash: hash, spell: spell, salt: salt)
          ? spell
          : null;
    }

    final host = _player(hostUid, players[hostUid])!;
    final guest = _player(guestUid, players[guestUid])!;
    final r = resolveRound(
      hostSpell: validSpell(hostUid),
      guestSpell: validSpell(guestUid),
      hostShieldsUsed: host.shieldsUsed,
      guestShieldsUsed: guest.shieldsUsed,
      config: config,
    );

    final hostLives = host.lives - (r.winner == Side.guest ? 1 : 0);
    final guestLives = guest.lives - (r.winner == Side.host ? 1 : 0);
    final finished = hostLives <= 0 || guestLives <= 0;
    final winnerUid = switch (r.winner) {
      Side.host => hostUid,
      Side.guest => guestUid,
      null => null,
    };

    _roomRef!
        .update({
          'rounds/$roundNr/result': {
            'winnerUid': ?winnerUid,
            'reason': r.reason.name,
            'at': ServerValue.timestamp,
            'spells': {
              if (r.hostSpell != null) hostUid: r.hostSpell!.wire,
              if (r.guestSpell != null) guestUid: r.guestSpell!.wire,
            },
          },
          'players/$hostUid/lives': hostLives,
          'players/$hostUid/shieldsUsed': r.hostShieldsUsed,
          'players/$guestUid/lives': guestLives,
          'players/$guestUid/shieldsUsed': r.guestShieldsUsed,
          if (finished) 'status': 'finished',
          if (finished) 'winnerUid': hostLives > 0 ? hostUid : guestUid,
        })
        .catchError((Object e) {
          _hostResolvedRound = roundNr - 1;
          debugPrint('resolve failed: $e');
        });
  }

  /// Both phones: add this game's win or loss to the own leaderboard entry.
  void _recordLeaderboard(Map<Object?, Object?> room) {
    if (room['status'] != 'finished') return;
    final game = _asInt(room['game']);
    if (!_leaderboardRecorded.add(game)) return;
    final me = _asMap(_asMap(room['players'])?[_uid]);
    final uid = _uid;
    if (uid == null) return;
    _writeLeaderboard(uid, won: room['winnerUid'] == uid, name: me?['name']);
  }

  void _writeLeaderboard(String uid, {required bool won, Object? name}) {
    // The tag lives in users/{uid} (made by the friends backend).
    _db
        .ref('users/$uid/tag')
        .get()
        .then(
          (tag) => _db.ref('leaderboard/$uid').update({
            'name': name ?? 'Speler',
            'tag': ?PlayerTag.parse(tag.value),
            'wins': ServerValue.increment(won ? 1 : 0),
            'losses': ServerValue.increment(won ? 0 : 1),
          }),
        )
        .catchError((Object e) => debugPrint('leaderboard failed: $e'));
  }

  void _emit(GameState state) {
    _state = state;
    if (!_stateCtl.isClosed) _stateCtl.add(state);
  }

  static Map<Object?, Object?>? _asMap(Object? value) {
    if (value is Map) return value.cast<Object?, Object?>();
    // RTDB returns a List for keys 1, 2, 3… (our round numbers).
    if (value is List) {
      return {
        for (var i = 0; i < value.length; i++)
          if (value[i] != null) '$i': value[i],
      };
    }
    return null;
  }

  static int _asInt(Object? value) => value is num ? value.toInt() : 0;
}
