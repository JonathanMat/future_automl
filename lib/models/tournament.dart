import 'dart:math';

/// Stands in a seed slot for "nobody": the other player goes through.
const byeSeat = '_bye';

/// Most players in one tournament (a bracket of 16).
const maxTournamentPlayers = 16;

enum TournamentStatus { lobby, running, finished, cancelled }

class TournamentPlayer {
  const TournamentPlayer({
    required this.uid,
    required this.name,
    this.tag,
    this.online = true,
    this.joinedAt = 0,
    this.bot = false,
  });

  final String uid;
  final String name;
  final String? tag;
  final bool online;

  /// Server ms, for the order in the waiting room.
  final int joinedAt;

  /// Only in the mock backend: plays its matches by itself.
  final bool bot;
}

class MatchResult {
  const MatchResult({
    required this.winner,
    required this.at,
    this.walkover = false,
  });

  final String winner;

  /// Server ms.
  final int at;

  /// Won because the opponent didn't show up (or the host decided).
  final bool walkover;
}

/// Everything stored about one tournament. The bracket itself is not
/// stored: every phone computes it from [seeds] and [results] (see
/// [Bracket]), so it can never get out of sync.
class TournamentData {
  const TournamentData({
    required this.code,
    required this.hostUid,
    required this.status,
    this.players = const {},
    this.seeds = const [],
    this.rooms = const {},
    this.results = const {},
    this.startedAt,
  });

  final String code;
  final String hostUid;
  final TournamentStatus status;
  final Map<String, TournamentPlayer> players;

  /// Seat order after the draw: two seats per first-round match. Empty
  /// until the host starts.
  final List<String> seeds;

  /// Room code per match id, written by the first player of the match.
  final Map<String, String> rooms;
  final Map<String, MatchResult> results;

  /// Server ms when the host started.
  final int? startedAt;

  /// Players in the order they joined.
  List<TournamentPlayer> get roster =>
      players.values.toList()..sort((a, b) => a.joinedAt.compareTo(b.joinedAt));

  TournamentData copyWith({
    TournamentStatus? status,
    Map<String, TournamentPlayer>? players,
    List<String>? seeds,
    Map<String, String>? rooms,
    Map<String, MatchResult>? results,
    int? startedAt,
  }) => TournamentData(
    code: code,
    hostUid: hostUid,
    status: status ?? this.status,
    players: players ?? this.players,
    seeds: seeds ?? this.seeds,
    rooms: rooms ?? this.rooms,
    results: results ?? this.results,
    startedAt: startedAt ?? this.startedAt,
  );
}

/// One match of the bracket, computed.
class BracketMatch {
  const BracketMatch({
    required this.round,
    required this.index,
    required this.a,
    required this.b,
    this.winner,
    this.walkover = false,
    this.readySince,
  });

  final int round;
  final int index;

  /// Player uid, [byeSeat], or null while the earlier match isn't decided.
  final String? a;
  final String? b;
  final String? winner;
  final bool walkover;

  /// Server ms since both players are known.
  final int? readySince;

  String get id => matchId(round, index);

  /// One side is a bye: the other player goes through without playing.
  bool get isBye => a == byeSeat || b == byeSeat;

  /// Both players known and not played yet.
  bool get isReady => a != null && b != null && !isBye && winner == null;

  bool get isDone => winner != null;

  bool involves(String uid) => a == uid || b == uid;

  String? opponentOf(String uid) => a == uid ? b : (b == uid ? a : null);

  String? get loser {
    final w = winner;
    if (w == null || isBye) return null;
    return w == a ? b : a;
  }
}

String matchId(int round, int index) => 'r${round}m$index';

/// The knock-out bracket of a tournament, computed from the draw and the
/// results.
///
/// Uneven numbers of players are filled up with byes in the first round:
/// with 6 players the bracket has 8 seats, so 2 players go straight to the
/// second round. Byes are spread over the bracket and never meet each
/// other, so from the second round on every match has two real players.
class Bracket {
  Bracket._(this.rounds);

  factory Bracket.of(TournamentData data) =>
      Bracket.build(data.seeds, data.results, startedAt: data.startedAt);

  factory Bracket.build(
    List<String> seeds,
    Map<String, MatchResult> results, {
    int? startedAt,
  }) {
    if (seeds.length < 2) return Bracket._(const []);
    final rounds = <List<BracketMatch>>[];

    // First round straight from the seats.
    var current = <BracketMatch>[
      for (var i = 0; i < seeds.length ~/ 2; i++)
        _decide(
          round: 0,
          index: i,
          a: seeds[2 * i],
          b: seeds[2 * i + 1],
          readySince: startedAt,
          results: results,
        ),
    ];
    rounds.add(current);

    while (current.length > 1) {
      final r = rounds.length;
      final next = <BracketMatch>[];
      for (var j = 0; j < current.length ~/ 2; j++) {
        final left = current[2 * j], right = current[2 * j + 1];
        next.add(
          _decide(
            round: r,
            index: j,
            a: left.winner,
            b: right.winner,
            readySince: left.winner != null && right.winner != null
                ? max(
                    _doneAt(left, results, startedAt),
                    _doneAt(right, results, startedAt),
                  )
                : null,
            results: results,
          ),
        );
      }
      rounds.add(next);
      current = next;
    }
    return Bracket._(rounds);
  }

  static int _doneAt(
    BracketMatch m,
    Map<String, MatchResult> results,
    int? startedAt,
  ) => results[m.id]?.at ?? startedAt ?? 0;

  static BracketMatch _decide({
    required int round,
    required int index,
    required String? a,
    required String? b,
    required int? readySince,
    required Map<String, MatchResult> results,
  }) {
    // A bye: the other player goes through.
    if (a == byeSeat || b == byeSeat) {
      return BracketMatch(
        round: round,
        index: index,
        a: a,
        b: b,
        winner: a == byeSeat ? b : a,
        readySince: readySince,
      );
    }
    final result = results[matchId(round, index)];
    // Ignore a result that names someone who isn't in this match.
    final valid =
        result != null &&
        a != null &&
        b != null &&
        (result.winner == a || result.winner == b);
    return BracketMatch(
      round: round,
      index: index,
      a: a,
      b: b,
      winner: valid ? result.winner : null,
      walkover: valid && result.walkover,
      readySince: a != null && b != null ? readySince : null,
    );
  }

  /// `rounds[0]` is the first round, the last one holds only the final.
  final List<List<BracketMatch>> rounds;

  bool get isEmpty => rounds.isEmpty;

  BracketMatch? get finalMatch => rounds.isEmpty ? null : rounds.last.single;

  String? get champion => finalMatch?.winner;

  /// Every match, round by round.
  Iterable<BracketMatch> get matches => rounds.expand((r) => r);

  BracketMatch? byId(String id) {
    for (final m in matches) {
      if (m.id == id) return m;
    }
    return null;
  }

  /// The match [uid] has to play next: ready, or waiting for the other
  /// side to be decided. Null when they are knocked out or the champion.
  ///
  /// A winner already appears in the next round's match (with the other
  /// seat still empty), so the first unfinished match they are in is it.
  BracketMatch? currentMatchFor(String uid) {
    if (isEliminated(uid)) return null;
    for (final m in matches) {
      if (m.involves(uid) && !m.isDone) return m;
    }
    return null;
  }

  /// Lost a match (byes don't count).
  bool isEliminated(String uid) =>
      matches.any((m) => m.isDone && !m.isBye && m.loser == uid);

  /// The furthest round [uid] has reached, for "Halve finale" in the UI.
  int roundReached(String uid) {
    var reached = 0;
    for (final m in matches) {
      if (m.involves(uid)) reached = max(reached, m.round);
    }
    return reached;
  }

  /// "Finale", "Halve finale", "Kwartfinale", "Achtste finale".
  static String roundName(int round, int roundCount) {
    final fromEnd = roundCount - 1 - round;
    return switch (fromEnd) {
      0 => 'Finale',
      1 => 'Halve finale',
      2 => 'Kwartfinale',
      3 => 'Achtste finale',
      _ => 'Ronde ${round + 1}',
    };
  }

  /// The draw: shuffles [players] and fills the bracket up with byes,
  /// spread so that no first-round match has two of them.
  static List<String> draw(List<String> players, Random random) {
    if (players.length < 2) {
      throw ArgumentError('Een toernooi heeft minstens 2 spelers nodig.');
    }
    final shuffled = [...players]..shuffle(random);
    var size = 2;
    while (size < shuffled.length) {
      size *= 2;
    }
    final matches = size ~/ 2;
    final byes = size - shuffled.length;
    // Spread the bye matches over the bracket.
    final byeMatches = {for (var k = 0; k < byes; k++) k * matches ~/ byes};
    final seats = <String>[];
    var next = 0;
    for (var i = 0; i < matches; i++) {
      seats.add(shuffled[next++]);
      seats.add(byeMatches.contains(i) ? byeSeat : shuffled[next++]);
    }
    return seats;
  }

  /// Seats a draw of [players] needs, e.g. 8 for 6 players.
  static int seatsFor(int players) {
    var size = 2;
    while (size < players) {
      size *= 2;
    }
    return size;
  }
}
