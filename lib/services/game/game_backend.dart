import 'dart:typed_data';

import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../models/emote.dart';
import '../../models/game_rules.dart';
import '../../models/game_state.dart';

export '../../models/emote.dart';
export '../../models/game_rules.dart';
export '../../models/game_state.dart';

/// The contract between the frontend (UI + model) and the backend
/// (Firebase + WebRTC).
///
/// Use [FirebaseGameBackend] for real games and [MockGameBackend] to build
/// the UI without Firebase or a second phone.
abstract class GameBackend {
  /// Voice chat in the next room (microphone + opponent's audio). Set it
  /// before [createRoom] / [joinRoom].
  bool get voiceChat;
  set voiceChat(bool value);

  /// Current state. Also emitted on [gameState].
  GameState get state;

  /// Emits whenever anything changes: players, lives, phase, call status.
  /// Phase changes (countdown → cast → resolving) are emitted on time, so
  /// the UI does not need its own timer except for the "3… 2… 1…" text.
  Stream<GameState> get gameState;

  /// Creates a room, opens the camera and returns the 4-letter room code.
  Future<String> createRoom({required String playerName});

  /// Joins a room by code and opens the camera.
  /// Throws [GameBackendException] if the room is missing or full.
  Future<void> joinRoom(String code, {required String playerName});

  /// Opens the camera (and the microphone when [voiceChat] is on) ahead of
  /// [createRoom] or [joinRoom], which then use this same stream. Doubles
  /// as the permission check, so the camera opens only once. Throws the
  /// `getUserMedia` error when it can't open.
  Future<void> openCamera();

  /// This phone's camera. Show it with an `RTCVideoRenderer`.
  /// Null until [createRoom] or [joinRoom] finished.
  MediaStream? get localStream;

  /// The opponent's video. Emits null when the call ends.
  Stream<MediaStream?> get remoteStream;

  /// One PNG frame from this phone's camera, for the Teachable Machine
  /// model. The camera is owned by the video call, so do not open it with
  /// the `camera` plugin as well. About 5 calls per second is plenty.
  Future<Uint8List?> captureLocalFrame();

  /// Casts a spell for the current round. Only works while
  /// [GameState.canCast] is true; throws [GameBackendException] otherwise
  /// (too early, too late, already cast, or no shield left).
  Future<void> submitSpell(Spell spell);

  /// Sends an emote to the opponent. Works any time both players are in
  /// the room.
  Future<void> sendEmote(Emote emote);

  /// Emotes from the opponent, as they arrive.
  Stream<Emote> get opponentEmotes;

  /// After [GamePhase.finished]: ask for a new game in the same room with
  /// the same video call. It starts (a fresh countdown) once both players
  /// asked; see [GameState.iWantRematch] and
  /// [GameState.opponentWantsRematch].
  Future<void> playAgain();

  /// The opponent stayed away (offline or left) for the whole grace
  /// period: ends the game with you as the winner. Does nothing when the
  /// game isn't running or they are back.
  Future<void> claimForfeit();

  /// Top players by wins.
  Stream<List<LeaderboardEntry>> leaderboard({int limit = 10});

  /// Leaves the room, hangs up and closes the camera. During a game the
  /// room stays open: the opponent gets a while to wait for you (you
  /// count as away, see [PlayerState.left]) and then wins.
  Future<void> leaveRoom();

  /// Releases everything. The backend can't be used afterwards.
  Future<void> dispose();
}

class GameBackendException implements Exception {
  GameBackendException(this.message);

  final String message;

  @override
  String toString() => 'GameBackendException: $message';
}
