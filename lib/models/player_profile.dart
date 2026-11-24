import '../utils/constants.dart';

/// The last duel, shown on the home screen.
class LastDuel {
  const LastDuel({
    required this.opponentName,
    required this.won,
    required this.roundsWon,
    required this.roundsLost,
    required this.playedAt,
  });

  final String opponentName;
  final bool won;
  final int roundsWon;
  final int roundsLost;
  final DateTime playedAt;

  Map<String, Object?> toJson() => {
    'opponentName': opponentName,
    'won': won,
    'roundsWon': roundsWon,
    'roundsLost': roundsLost,
    'playedAt': playedAt.millisecondsSinceEpoch,
  };

  static LastDuel? fromJson(Object? json) {
    if (json is! Map) return null;
    return LastDuel(
      opponentName: json['opponentName'] as String? ?? '?',
      won: json['won'] as bool? ?? false,
      roundsWon: json['roundsWon'] as int? ?? 0,
      roundsLost: json['roundsLost'] as int? ?? 0,
      playedAt: DateTime.fromMillisecondsSinceEpoch(
        json['playedAt'] as int? ?? 0,
      ),
    );
  }
}

/// The local player: name, XP and record. Stored on the phone.
class PlayerProfile {
  const PlayerProfile({
    this.name = '',
    this.xp = 0,
    this.wins = 0,
    this.losses = 0,
    this.streak = 0,
    this.lastDuel,
  });

  final String name;

  /// Total XP ever earned. Level and progress are derived from it.
  final int xp;
  final int wins;
  final int losses;

  /// Wins in a row (0 after a loss).
  final int streak;
  final LastDuel? lastDuel;

  bool get hasName => name.trim().isNotEmpty;

  int get level => xp ~/ AppConstants.xpPerLevel + 1;
  int get xpInLevel => xp % AppConstants.xpPerLevel;
  double get levelProgress => xpInLevel / AppConstants.xpPerLevel;

  int get gamesPlayed => wins + losses;

  /// 0–100, rounded. 0 when no games were played.
  int get winRate => gamesPlayed == 0 ? 0 : (wins * 100 / gamesPlayed).round();

  PlayerProfile copyWith({
    String? name,
    int? xp,
    int? wins,
    int? losses,
    int? streak,
    LastDuel? lastDuel,
  }) => PlayerProfile(
    name: name ?? this.name,
    xp: xp ?? this.xp,
    wins: wins ?? this.wins,
    losses: losses ?? this.losses,
    streak: streak ?? this.streak,
    lastDuel: lastDuel ?? this.lastDuel,
  );

  Map<String, Object?> toJson() => {
    'name': name,
    'xp': xp,
    'wins': wins,
    'losses': losses,
    'streak': streak,
    'lastDuel': lastDuel?.toJson(),
  };

  factory PlayerProfile.fromJson(Map<String, Object?> json) => PlayerProfile(
    name: json['name'] as String? ?? '',
    xp: json['xp'] as int? ?? 0,
    wins: json['wins'] as int? ?? 0,
    losses: json['losses'] as int? ?? 0,
    streak: json['streak'] as int? ?? 0,
    lastDuel: LastDuel.fromJson(json['lastDuel']),
  );
}
