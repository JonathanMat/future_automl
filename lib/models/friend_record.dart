/// Someone you dueled before, with your record against them.
class FriendRecord {
  const FriendRecord({
    this.uid,
    required this.name,
    this.wins = 0,
    this.losses = 0,
    required this.lastPlayed,
  });

  /// The opponent's account id, used to send a friend request.
  /// Null for games saved before ids were stored.
  final String? uid;
  final String name;

  /// Your wins and losses against this friend.
  final int wins;
  final int losses;
  final DateTime lastPlayed;

  int get games => wins + losses;

  /// Same opponent: the account id when both have one, else the name.
  bool sameAs(FriendRecord other) => uid != null && other.uid != null
      ? uid == other.uid
      : name.trim().toLowerCase() == other.name.trim().toLowerCase();

  /// [a] and [b] together, most recently played first. For an opponent in
  /// both, the copy played most recently wins (the record keeps counting
  /// from there), or the one with the most games when that is the same.
  static List<FriendRecord> merge(List<FriendRecord> a, List<FriendRecord> b) {
    final out = <FriendRecord>[...a];
    for (final r in b) {
      final i = out.indexWhere(r.sameAs);
      if (i < 0) {
        out.add(r);
        continue;
      }
      final mine = out[i];
      final newer =
          r.lastPlayed.isAfter(mine.lastPlayed) ||
          (r.lastPlayed == mine.lastPlayed && r.games > mine.games);
      if (!newer) continue;
      out[i] = FriendRecord(
        uid: r.uid ?? mine.uid,
        name: r.name,
        wins: r.wins,
        losses: r.losses,
        lastPlayed: r.lastPlayed,
      );
    }
    return out..sort((x, y) => y.lastPlayed.compareTo(x.lastPlayed));
  }

  int get winRate => games == 0 ? 0 : (wins * 100 / games).round();

  FriendRecord recordGame({
    required bool won,
    required DateTime at,
    String? uid,
    String? name,
  }) => FriendRecord(
    uid: uid ?? this.uid,
    name: name ?? this.name,
    wins: wins + (won ? 1 : 0),
    losses: losses + (won ? 0 : 1),
    lastPlayed: at,
  );

  Map<String, Object?> toJson() => {
    'uid': ?uid,
    'name': name,
    'wins': wins,
    'losses': losses,
    'lastPlayed': lastPlayed.millisecondsSinceEpoch,
  };

  factory FriendRecord.fromJson(Map<String, Object?> json) => FriendRecord(
    uid: json['uid'] as String?,
    name: json['name'] as String? ?? '?',
    wins: json['wins'] as int? ?? 0,
    losses: json['losses'] as int? ?? 0,
    lastPlayed: DateTime.fromMillisecondsSinceEpoch(
      json['lastPlayed'] as int? ?? 0,
    ),
  );
}
