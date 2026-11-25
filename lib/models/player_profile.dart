import '../utils/constants.dart';
import 'player_stats.dart';

/// One finished duel: the last one is shown on the home screen, the
/// latest [PlayerProfile.maxHistory] on the profile page.
class LastDuel {
  const LastDuel({
    required this.opponentName,
    this.opponentUid,
    required this.won,
    required this.roundsWon,
    required this.roundsLost,
    required this.playedAt,
  });

  final String opponentName;

  /// The opponent's account id, to open their profile. Null for duels
  /// saved before ids were stored.
  final String? opponentUid;
  final bool won;
  final int roundsWon;
  final int roundsLost;
  final DateTime playedAt;

  Map<String, Object?> toJson() => {
    'opponentName': opponentName,
    'opponentUid': ?opponentUid,
    'won': won,
    'roundsWon': roundsWon,
    'roundsLost': roundsLost,
    'playedAt': playedAt.millisecondsSinceEpoch,
  };

  static LastDuel? fromJson(Object? json) {
    if (json is! Map) return null;
    return LastDuel(
      opponentName: json['opponentName'] as String? ?? '?',
      opponentUid: json['opponentUid'] as String?,
      won: json['won'] as bool? ?? false,
      roundsWon: json['roundsWon'] as int? ?? 0,
      roundsLost: json['roundsLost'] as int? ?? 0,
      playedAt: DateTime.fromMillisecondsSinceEpoch(
        json['playedAt'] as int? ?? 0,
      ),
    );
  }
}

/// The local player: name, XP and record. Stored on the phone and synced
/// to `users/{uid}/progress` (see FriendsProvider).
class PlayerProfile {
  const PlayerProfile({
    this.name = '',
    this.xp = 0,
    this.wins = 0,
    this.losses = 0,
    this.streak = 0,
    this.lastDuel,
    this.history = const [],
    this.stats = const PlayerStats(),
    this.badges = const {},
  });

  /// At most this many duels are kept in [history].
  static const maxHistory = 20;

  final String name;

  /// Total XP ever earned. Level and progress are derived from it.
  final int xp;
  final int wins;
  final int losses;

  /// Wins in a row (0 after a loss).
  final int streak;
  final LastDuel? lastDuel;

  /// The latest duels, newest first (at most [maxHistory]). Only duels
  /// with the opponent's account id: older ones can't link to a profile,
  /// so they are left out.
  final List<LastDuel> history;

  /// Lifetime counters for the badges.
  final PlayerStats stats;

  /// Unlocked badge ids, with when (ms since epoch).
  final Map<String, int> badges;

  bool hasBadge(String id) => badges.containsKey(id);

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
    List<LastDuel>? history,
    PlayerStats? stats,
    Map<String, int>? badges,
  }) => PlayerProfile(
    name: name ?? this.name,
    xp: xp ?? this.xp,
    wins: wins ?? this.wins,
    losses: losses ?? this.losses,
    streak: streak ?? this.streak,
    lastDuel: lastDuel ?? this.lastDuel,
    history: history ?? this.history,
    stats: stats ?? this.stats,
    badges: badges ?? this.badges,
  );

  Map<String, Object?> toJson() => {
    'name': name,
    'xp': xp,
    'wins': wins,
    'losses': losses,
    'streak': streak,
    'lastDuel': lastDuel?.toJson(),
    'history': [for (final d in history) d.toJson()],
    'stats': stats.toJson(),
    'badges': badges,
  };

  /// Everything except the name, for syncing to the server.
  Map<String, Object?> progressJson() => toJson()..remove('name');

  /// This profile with XP, record and last duel taken from [progress].
  PlayerProfile withProgress(Map<String, Object?> progress) =>
      PlayerProfile.fromJson({...progress, 'name': name});

  factory PlayerProfile.fromJson(Map<String, Object?> json) {
    final last = LastDuel.fromJson(json['lastDuel']);
    final history = _historyFromJson(json['history']);
    return PlayerProfile(
      name: json['name'] as String? ?? '',
      xp: json['xp'] as int? ?? 0,
      wins: json['wins'] as int? ?? 0,
      losses: json['losses'] as int? ?? 0,
      streak: json['streak'] as int? ?? 0,
      lastDuel: last,
      history: history,
      stats: PlayerStats.fromJson(json['stats']),
      badges: _badgesFromJson(json['badges']),
    );
  }

  /// Stored as a list; the database may hand it back as a map with "0",
  /// "1", … keys instead.
  static List<LastDuel> _historyFromJson(Object? json) {
    final items = switch (json) {
      final List l => l,
      final Map m => [
        for (final k
            in m.keys.toList()..sort(
              (a, b) => (int.tryParse('$a') ?? 0) - (int.tryParse('$b') ?? 0),
            ))
          m[k],
      ],
      _ => const [],
    };
    final list = [
      for (final i in items)
        if (LastDuel.fromJson(i) case final d? when d.opponentUid != null) d,
    ]..sort((a, b) => b.playedAt.compareTo(a.playedAt));
    return List.unmodifiable(list.take(maxHistory));
  }

  static Map<String, int> _badgesFromJson(Object? json) {
    if (json is! Map) return const {};
    return {
      for (final e in json.entries)
        if (e.value is num) '${e.key}': (e.value as num).toInt(),
    };
  }
}
