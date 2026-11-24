import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../models/duel_summary.dart';
import '../models/spell_prediction.dart';
import '../services/game/game_backend.dart';
import '../services/permissions/camera_permission_service.dart';
import '../services/recognition/spell_recognizer.dart';
import '../utils/constants.dart';
import 'profile_provider.dart';

/// Wraps the [GameBackend] for the UI: the current [GameState], the video
/// streams, spell recognition and per-game stats.
class GameProvider extends ChangeNotifier {
  GameProvider({
    required this.backend,
    this.recognizer = const ManualSpellRecognizer(),
    this.cameraPermission = const CameraPermissionService(enabled: false),
    this.onGameFinished,
  }) {
    _state = backend.state;
    _subs.add(backend.gameState.listen(_onState));
    _subs.add(
      backend.remoteStream.listen((stream) {
        _remoteStream = stream;
        notifyListeners();
      }),
    );
    recognizer.load().catchError((Object e) {
      debugPrint('SpellRecognizer.load: $e');
    });
  }

  final GameBackend backend;
  final SpellRecognizer recognizer;

  /// Checked before a room is created or joined.
  final CameraPermissionService cameraPermission;

  /// Called once per finished game, e.g. to update the profile.
  Future<void> Function(DuelSummary summary)? onGameFinished;

  final List<StreamSubscription<Object?>> _subs = [];
  late GameState _state;
  MediaStream? _remoteStream;
  bool _busy = false;
  String? _actionError;
  MediaAccess _mediaAccess = MediaAccess.granted;
  bool _disposed = false;

  // Recognition
  Timer? _recognitionTimer;
  bool _predicting = false;
  SpellPrediction _prediction = SpellPrediction.none;
  double _holdProgress = 0;

  // Stats for the current game
  final List<RoundRecord> _rounds = [];
  int _lastRecordedRound = 0;
  Duration? _pendingLatency;
  double? _pendingConfidence;
  bool _finishedHandled = false;
  DuelSummary? _lastSummary;

  GameState get state => _state;
  MediaStream? get localStream => backend.localStream;
  MediaStream? get remoteStream => _remoteStream;

  /// True while a room is being created or joined.
  bool get busy => _busy;

  /// Last error from an action the user started (join, cast…).
  String? get actionError => _actionError;

  /// Result of the last camera check. [MediaAccess.denied] means the UI
  /// should send the player to the system settings.
  MediaAccess get mediaAccess => _mediaAccess;

  bool get recognitionAvailable => recognizer.isAvailable;
  SpellPrediction get prediction => _prediction;

  /// 0–1: how far the current gesture is towards counting as stable
  /// (`GestureConstants.stableFrames` identical frames).
  double get holdProgress => _holdProgress;

  /// Summary of the last finished game, for the result screen.
  DuelSummary? get lastSummary => _lastSummary;

  bool get inRoom => _state.phase != GamePhase.idle;

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  /// Creates a room and returns its code, or null on failure
  /// (see [actionError]).
  Future<String?> createRoom(String playerName) => _run<String?>(() async {
    if (!await _checkCamera()) return null;
    _resetGameStats();
    return backend.createRoom(playerName: playerName);
  });

  /// Joins a room. Returns false on failure (see [actionError]).
  Future<bool> joinRoom(String code, String playerName) async {
    final ok = await _run(() async {
      if (!await _checkCamera()) return false;
      _resetGameStats();
      await backend.joinRoom(code, playerName: playerName);
      return true;
    });
    return ok ?? false;
  }

  /// Asks for the camera before touching the backend, so a refusal never
  /// leaves a half-made room behind.
  Future<bool> _checkCamera() async {
    _mediaAccess = await cameraPermission.ensureAccess(
      withMicrophone: backend.voiceChat,
    );
    final message = _cameraMessage(_mediaAccess);
    if (message != null) _actionError = message;
    return message == null;
  }

  String? _cameraMessage(MediaAccess access) => switch (access) {
    MediaAccess.granted => null,
    MediaAccess.denied =>
      cameraPermission.microphone
          ? 'Spell Duel heeft je camera en microfoon nodig.'
          : 'Spell Duel heeft je camera nodig.',
    MediaAccess.unavailable => 'Geen camera gevonden op dit toestel.',
    MediaAccess.failed => 'De camera kon niet starten. Probeer opnieuw.',
  };

  Future<void> leave() async {
    _stopRecognition();
    _resetGameStats();
    try {
      await backend.leaveRoom();
    } catch (e) {
      debugPrint('leaveRoom: $e');
    }
  }

  Future<void> playAgain() async {
    _resetGameStats();
    try {
      await backend.playAgain();
    } on GameBackendException catch (e) {
      _setError(e.message);
    }
  }

  /// Casts [spell] for the current round. [confidence] is set when the
  /// model recognised it, null when the player tapped it.
  Future<bool> castSpell(Spell spell, {double? confidence}) async {
    if (!_state.canCast) return false;
    if (spell == Spell.schild && !_state.myShieldAvailable) {
      _setError('Je schild is al gebruikt.');
      return false;
    }
    final castAt = _state.castAt;
    final latency = castAt == null ? null : DateTime.now().difference(castAt);
    try {
      await backend.submitSpell(spell);
      _pendingLatency = latency;
      _pendingConfidence = confidence;
      _resetHold();
      _actionError = null;
      _notify();
      return true;
    } on GameBackendException catch (e) {
      _setError(e.message);
      return false;
    }
  }

  void clearError() {
    if (_actionError == null) return;
    _actionError = null;
    _notify();
  }

  Future<T?> _run<T>(Future<T> Function() action) async {
    _busy = true;
    _actionError = null;
    _notify();
    try {
      return await action();
    } on GameBackendException catch (e) {
      _actionError = e.message;
      return null;
    } catch (e) {
      debugPrint('GameProvider: $e');
      final access = CameraPermissionService.classify(e);
      if (e.toString().contains('NotAllowedError') ||
          e.toString().contains('NotFoundError')) {
        // The camera failed inside the backend (e.g. permission taken
        // away mid-session): close the half-made room.
        _mediaAccess = access;
        _actionError = _cameraMessage(access);
        unawaited(leave());
      } else {
        _actionError = 'Er ging iets mis. Probeer opnieuw.';
      }
      return null;
    } finally {
      _busy = false;
      _notify();
    }
  }

  // ---------------------------------------------------------------------------
  // State updates
  // ---------------------------------------------------------------------------

  void _onState(GameState s) {
    final prev = _state;
    _state = s;

    // New round: forget the gestures of the previous one.
    if (s.round != prev.round) recognizer.reset();

    // A new game in the same room (after "revanche").
    if (prev.phase == GamePhase.finished &&
        s.phase != GamePhase.finished &&
        s.phase != GamePhase.idle) {
      _resetGameStats();
    }

    final result = s.lastResult;
    final showsResult =
        s.phase == GamePhase.roundResult || s.phase == GamePhase.finished;
    if (result != null && showsResult && result.round != _lastRecordedRound) {
      _rounds.add(
        RoundRecord(
          result: result,
          castLatency: _pendingLatency,
          confidence: _pendingConfidence,
        ),
      );
      _lastRecordedRound = result.round;
      _pendingLatency = null;
      _pendingConfidence = null;
    }

    if (s.phase == GamePhase.finished && !_finishedHandled) {
      _finishedHandled = true;
      final won = s.iWon ?? false;
      final summary = DuelSummary(
        opponentName: s.opponent?.name ?? 'Tegenstander',
        opponentUid: s.opponent?.uid,
        won: won,
        rounds: List.unmodifiable(_rounds),
        xpGained: ProfileProvider.xpFor(won: won),
      );
      _lastSummary = summary;
      onGameFinished?.call(summary);
    }

    _updateRecognition();
    _notify();
  }

  void _resetGameStats() {
    _rounds.clear();
    _lastRecordedRound = 0;
    _pendingLatency = null;
    _pendingConfidence = null;
    _finishedHandled = false;
    _resetHold();
    _prediction = SpellPrediction.none;
  }

  // ---------------------------------------------------------------------------
  // Spell recognition
  // ---------------------------------------------------------------------------

  bool get _shouldRecognize =>
      recognizer.isAvailable &&
      _state.mySpell == null &&
      (_state.phase == GamePhase.countdown || _state.phase == GamePhase.cast);

  void _updateRecognition() {
    if (_shouldRecognize) {
      _recognitionTimer ??= Timer.periodic(
        AppConstants.recognitionInterval,
        (_) => _recognizeFrame(),
      );
    } else {
      _stopRecognition();
    }
  }

  void _stopRecognition() {
    _recognitionTimer?.cancel();
    _recognitionTimer = null;
    if (_prediction.spell != null || _holdProgress > 0) {
      _prediction = SpellPrediction.none;
      _resetHold();
    }
  }

  Future<void> _recognizeFrame() async {
    if (_predicting || !_shouldRecognize) return;
    _predicting = true;
    try {
      final frame = await backend.captureLocalFrame();
      if (frame == null || _disposed) return;
      final p = await recognizer.predict(frame);
      if (_disposed) return;
      _prediction = p;
      await _castIfStable(p);
      _notify();
    } catch (e) {
      debugPrint('recognizeFrame: $e');
    } finally {
      _predicting = false;
    }
  }

  /// Casts as soon as the recognizer reports a stable gesture.
  Future<void> _castIfStable(SpellPrediction p) async {
    _holdProgress = p.stability;
    final spell = p.spell;
    if (!p.isStable || spell == null || !_state.canCast) return;
    if (spell == Spell.schild && !_state.myShieldAvailable) return;
    await castSpell(spell, confidence: p.confidence);
  }

  void _resetHold() {
    _holdProgress = 0;
  }

  void _setError(String message) {
    _actionError = message;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _recognitionTimer?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    backend.dispose();
    recognizer.dispose();
    super.dispose();
  }
}
