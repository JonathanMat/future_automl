import 'duel_summary.dart';
import 'game_rules.dart';
import 'game_state.dart';

/// Lifetime counters the badges are based on. Stored with the profile and
/// synced to `users/{uid}/progress/stats`.
class PlayerStats {
  const PlayerStats([this._values = const {}]);

  final Map<String, int> _values;

  int operator [](String key) => _values[key] ?? 0;

  /// Round wins with [spell].
  int roundWins(Spell spell) => this['wins_${spell.wire}'];

  /// Shield bounced fire or ice back.
  int get reflects => this['reflects'];

  /// Duels won without losing a life.
  int get flawless => this['flawless'];

  /// Duels won with only one life left.
  int get comebacks => this['comebacks'];

  /// Duels won against a friend.
  int get friendWins => this['friendWins'];

  /// Rounds where both cast the same spell.
  int get clashes => this['clashes'];

  /// Longest win streak ever.
  int get bestStreak => this['bestStreak'];

  /// Fastest cast after CAST, in ms. 0 = none yet.
  int get fastestMs => this['fastestMs'];

  /// These stats plus one finished duel.
  PlayerStats withDuel(
    DuelSummary summary, {
    required int streakAfter,
    bool vsFriend = false,
  }) {
    final v = Map<String, int>.of(_values);
    void add(String key, [int n = 1]) => v[key] = (v[key] ?? 0) + n;

    for (final r in summary.rounds) {
      final mine = r.result.mySpell;
      final theirs = r.result.opponentSpell;
      if (r.result.outcome == RoundOutcome.win && mine != null) {
        add('wins_${mine.wire}');
        if (mine == Spell.schild &&
            (theirs == Spell.vuur || theirs == Spell.ijs)) {
          add('reflects');
        }
      }
      if (r.result.outcome == RoundOutcome.draw &&
          mine != null &&
          mine == theirs) {
        add('clashes');
      }
    }
    if (summary.won) {
      if (summary.roundsLost == 0) add('flawless');
      if (summary.roundsLost == summary.startLives - 1) add('comebacks');
      if (vsFriend) add('friendWins');
    }
    if (streakAfter > this['bestStreak']) v['bestStreak'] = streakAfter;
    final fastest = summary.fastestCast?.inMilliseconds;
    if (fastest != null && fastest >= 0) {
      final best = this['fastestMs'];
      if (best == 0 || fastest < best) v['fastestMs'] = fastest;
    }
    return PlayerStats(v);
  }

  Map<String, int> toJson() => Map.of(_values);

  factory PlayerStats.fromJson(Object? json) {
    if (json is! Map) return const PlayerStats();
    return PlayerStats({
      for (final e in json.entries)
        if (e.value is num) '${e.key}': (e.value as num).toInt(),
    });
  }
}
