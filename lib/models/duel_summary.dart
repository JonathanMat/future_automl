import 'game_rules.dart';
import 'game_state.dart';

/// What happened in one round, from this phone's side.
class RoundRecord {
  const RoundRecord({required this.result, this.castLatency, this.confidence});

  final RoundResult result;

  /// Time between CAST and this phone submitting its spell.
  final Duration? castLatency;

  /// Model confidence when the spell was cast. Null for a tapped spell.
  final double? confidence;
}

/// Stats for one finished game, shown on the result screen.
class DuelSummary {
  const DuelSummary({
    required this.opponentName,
    required this.won,
    required this.rounds,
    required this.xpGained,
  });

  final String opponentName;
  final bool won;
  final List<RoundRecord> rounds;
  final int xpGained;

  int get roundsWon =>
      rounds.where((r) => r.result.outcome == RoundOutcome.win).length;
  int get roundsLost =>
      rounds.where((r) => r.result.outcome == RoundOutcome.lose).length;

  /// Rounds in which you cast a valid spell.
  int get spellsCast => rounds.where((r) => r.result.mySpell != null).length;

  /// Spells that won the round.
  int get hits => roundsWon;

  Spell? get favoriteSpell {
    final counts = <Spell, int>{};
    for (final r in rounds) {
      final s = r.result.mySpell;
      if (s != null) counts[s] = (counts[s] ?? 0) + 1;
    }
    if (counts.isEmpty) return null;
    return counts.entries.reduce((a, b) => b.value > a.value ? b : a).key;
  }

  /// Average model confidence, or null when every spell was tapped.
  double? get averageConfidence {
    final values = [
      for (final r in rounds)
        if (r.confidence != null) r.confidence!,
    ];
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }

  Duration? get fastestCast {
    Duration? best;
    for (final r in rounds) {
      final l = r.castLatency;
      if (l != null && (best == null || l < best)) best = l;
    }
    return best;
  }
}
