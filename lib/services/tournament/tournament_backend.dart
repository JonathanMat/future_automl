import '../../models/tournament.dart';

export '../../models/tournament.dart';

/// Who is joining: this phone's player.
class TournamentMe {
  const TournamentMe({required this.uid, required this.name, this.tag});

  final String uid;
  final String name;
  final String? tag;
}

class TournamentException implements Exception {
  TournamentException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Stores tournaments: who joined, the draw, the room of every match and
/// the results. The bracket is computed from that on every phone.
///
/// [FirebaseTournamentBackend] for real use; [MockTournamentBackend] with
/// bots to try a whole tournament on one phone.
abstract class TournamentBackend {
  /// Makes a tournament in the waiting-room state; returns its code.
  Future<String> create(TournamentMe me);

  /// Joins the waiting room. Throws [TournamentException] when the code is
  /// unknown, the tournament has started, or it is full.
  Future<void> join(String code, TournamentMe me);

  /// Live state; emits null when the tournament is gone.
  Stream<TournamentData?> watch(String code);

  /// Host: closes the waiting room with this draw (see [Bracket.draw]).
  Future<void> start(String code, List<String> seeds);

  /// The first player of a match made [roomCode] for it.
  Future<void> setRoom(String code, String matchId, String roomCode);

  /// Records or withdraws a player's acceptance of this match.
  Future<void> setMatchReady(
    String code,
    String matchId,
    String uid, {
    required bool ready,
  });

  /// Reports who won [matchId]. The first report counts; later ones are
  /// ignored (the host may overrule with [force]).
  /// Returns whether the report was saved. [noShow] is the opponent in a
  /// walk-over claimed after waiting for them to accept.
  Future<bool> reportResult(
    String code,
    String matchId,
    String winner, {
    bool walkover = false,
    bool force = false,
    String? noShow,
  });

  /// Host: the final is decided.
  Future<void> finish(String code);

  /// Leaves: removes you from the waiting room, or marks you offline once
  /// it has started. A host leaving the waiting room cancels it.
  Future<void> leave(String code, String uid, {required bool isHost});

  /// Server time minus this phone's time, for walk-over timers.
  Duration get serverOffset => Duration.zero;

  /// Bots that fill the waiting room (mock only).
  bool get supportsBots => false;

  Future<void> addBots(String code, int count) async {}

  Future<void> dispose() async {}
}
