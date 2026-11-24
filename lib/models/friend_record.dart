/// Someone you dueled before, with your record against them.
class FriendRecord {
  const FriendRecord({
    required this.name,
    this.wins = 0,
    this.losses = 0,
    required this.lastPlayed,
  });

  final String name;

  /// Your wins and losses against this friend.
  final int wins;
  final int losses;
  final DateTime lastPlayed;

  int get games => wins + losses;
  int get winRate => games == 0 ? 0 : (wins * 100 / games).round();

  FriendRecord recordGame({required bool won, required DateTime at}) =>
      FriendRecord(
        name: name,
        wins: wins + (won ? 1 : 0),
        losses: losses + (won ? 0 : 1),
        lastPlayed: at,
      );

  Map<String, Object?> toJson() => {
    'name': name,
    'wins': wins,
    'losses': losses,
    'lastPlayed': lastPlayed.millisecondsSinceEpoch,
  };

  factory FriendRecord.fromJson(Map<String, Object?> json) => FriendRecord(
    name: json['name'] as String? ?? '?',
    wins: json['wins'] as int? ?? 0,
    losses: json['losses'] as int? ?? 0,
    lastPlayed: DateTime.fromMillisecondsSinceEpoch(
      json['lastPlayed'] as int? ?? 0,
    ),
  );
}
