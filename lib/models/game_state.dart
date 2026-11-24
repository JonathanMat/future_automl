import 'game_rules.dart';

/// What the UI should show right now.
enum GamePhase {
  /// Not in a room.
  idle,

  /// Room created, waiting for the second player.
  waitingForOpponent,

  /// "3… 2… 1…" – blur the opponent's video now.
  countdown,

  /// CAST! Spells are accepted until [GameState.castDeadline].
  cast,

  /// Cast window closed, waiting for both phones to reveal their spell.
  resolving,

  /// Show [GameState.lastResult] until the next countdown.
  roundResult,

  /// Someone has 0 lives. See [GameState.iWon].
  finished,
}

/// State of the video call.
enum CallStatus { none, connecting, connected, failed, closed }

class PlayerState {
  const PlayerState({
    required this.uid,
    required this.name,
    required this.lives,
    required this.shieldsUsed,
    required this.online,
  });

  final String uid;
  final String name;
  final int lives;
  final int shieldsUsed;
  final bool online;

  bool shieldAvailable(GameConfig config) => shieldsUsed < config.shieldUses;
}

enum RoundOutcome { win, lose, draw }

/// A finished round, seen from this phone's point of view.
class RoundResult {
  const RoundResult({
    required this.round,
    required this.mySpell,
    required this.opponentSpell,
    required this.outcome,
    required this.reason,
  });

  final int round;

  /// Null when that player cast nothing valid.
  final Spell? mySpell;
  final Spell? opponentSpell;
  final RoundOutcome outcome;
  final RoundReason reason;
}

/// Immutable snapshot of the game, emitted by [GameBackend.gameState].
class GameState {
  const GameState({
    this.phase = GamePhase.idle,
    this.config = const GameConfig(),
    this.roomCode,
    this.isHost = false,
    this.me,
    this.opponent,
    this.round = 0,
    this.castAt,
    this.mySpell,
    this.lastResult,
    this.iWon,
    this.callStatus = CallStatus.none,
    this.error,
  });

  final GamePhase phase;
  final GameConfig config;
  final String? roomCode;
  final bool isHost;
  final PlayerState? me;
  final PlayerState? opponent;

  /// Current round number, starting at 1.
  final int round;

  /// When CAST happens, in this phone's clock (already corrected for the
  /// difference with the server clock). The countdown ends here.
  final DateTime? castAt;

  /// The spell this phone cast this round, if any.
  final Spell? mySpell;

  final RoundResult? lastResult;

  /// Set when [phase] is [GamePhase.finished].
  final bool? iWon;

  final CallStatus callStatus;

  /// Last non-fatal error, e.g. "opponent left".
  final String? error;

  /// Last moment a spell is accepted.
  DateTime? get castDeadline => castAt?.add(config.castWindow);

  /// Whether [GameBackend.submitSpell] would accept a spell right now.
  bool get canCast => phase == GamePhase.cast && mySpell == null;

  bool get myShieldAvailable => me?.shieldAvailable(config) ?? false;

  GameState copyWith({
    GamePhase? phase,
    String? roomCode,
    bool? isHost,
    PlayerState? me,
    PlayerState? opponent,
    int? round,
    DateTime? castAt,
    Spell? mySpell,
    bool clearMySpell = false,
    RoundResult? lastResult,
    bool? iWon,
    CallStatus? callStatus,
    String? error,
  }) => GameState(
    phase: phase ?? this.phase,
    config: config,
    roomCode: roomCode ?? this.roomCode,
    isHost: isHost ?? this.isHost,
    me: me ?? this.me,
    opponent: opponent ?? this.opponent,
    round: round ?? this.round,
    castAt: castAt ?? this.castAt,
    mySpell: clearMySpell ? null : (mySpell ?? this.mySpell),
    lastResult: lastResult ?? this.lastResult,
    iWon: iWon ?? this.iWon,
    callStatus: callStatus ?? this.callStatus,
    error: error ?? this.error,
  );
}

/// Phase from round timing. Shared by both backends.
GamePhase phaseForTime({
  required DateTime now,
  required DateTime castAt,
  required GameConfig config,
  required bool hasResult,
}) {
  if (hasResult) return GamePhase.roundResult;
  // Includes the short lead before the countdown visually starts.
  if (now.isBefore(castAt)) return GamePhase.countdown;
  if (now.isBefore(castAt.add(config.castWindow))) return GamePhase.cast;
  return GamePhase.resolving;
}

class LeaderboardEntry {
  const LeaderboardEntry({
    required this.uid,
    required this.name,
    required this.wins,
    required this.losses,
    this.tag,
  });

  final String uid;
  final String name;
  final int wins;
  final int losses;

  /// Public 4-digit tag ("Jan #4821"), see `PlayerTag`.
  final String? tag;
}
