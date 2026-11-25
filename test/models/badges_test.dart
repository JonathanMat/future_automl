import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spell_duel/models/badge.dart';
import 'package:spell_duel/models/duel_summary.dart';
import 'package:spell_duel/models/game_rules.dart';
import 'package:spell_duel/models/game_state.dart';
import 'package:spell_duel/models/player_profile.dart';
import 'package:spell_duel/models/player_stats.dart';
import 'package:spell_duel/providers/profile_provider.dart';
import 'package:spell_duel/services/storage/local_storage_service.dart';

RoundRecord round(int n, Spell? mine, Spell? theirs, {int? castMs}) {
  final r = resolveRound(hostSpell: mine, guestSpell: theirs);
  return RoundRecord(
    result: RoundResult(
      round: n,
      mySpell: r.hostSpell,
      opponentSpell: r.guestSpell,
      outcome: r.winner == null
          ? RoundOutcome.draw
          : (r.winner == Side.host ? RoundOutcome.win : RoundOutcome.lose),
      reason: r.reason,
    ),
    castLatency: castMs == null ? null : Duration(milliseconds: castMs),
  );
}

DuelSummary duel(List<RoundRecord> rounds, {bool? won}) => DuelSummary(
  opponentName: 'Bot',
  opponentUid: 'bot',
  won:
      won ??
      rounds.where((r) => r.result.outcome == RoundOutcome.win).length >
          rounds.where((r) => r.result.outcome == RoundOutcome.lose).length,
  rounds: rounds,
  xpGained: 120,
);

void main() {
  group('PlayerStats', () {
    test('counts wins per spell, reflects, clashes and the fastest cast', () {
      final s = const PlayerStats().withDuel(
        duel([
          round(1, Spell.schild, Spell.vuur), // reflect
          round(2, Spell.ijs, Spell.ijs), // clash
          round(3, Spell.vuur, Spell.bliksem, castMs: 420),
          round(4, Spell.bliksem, Spell.ijs, castMs: 900),
        ]),
        streakAfter: 1,
      );
      expect(s.roundWins(Spell.schild), 1);
      expect(s.roundWins(Spell.vuur), 1);
      expect(s.roundWins(Spell.bliksem), 1);
      expect(s.reflects, 1);
      expect(s.clashes, 1);
      expect(s.fastestMs, 420);
      expect(s.flawless, 1);
      expect(s.bestStreak, 1);
    });

    test('comeback: won with one life left', () {
      final s = const PlayerStats().withDuel(
        duel([
          round(1, Spell.vuur, Spell.ijs),
          round(2, Spell.vuur, Spell.ijs),
          round(3, Spell.ijs, Spell.vuur),
          round(4, Spell.ijs, Spell.vuur),
          round(5, Spell.ijs, Spell.vuur),
        ]),
        streakAfter: 1,
        vsFriend: true,
      );
      expect(s.comebacks, 1);
      expect(s.flawless, 0);
      expect(s.friendWins, 1);
    });

    test('survives a JSON round trip inside the profile', () {
      final p = PlayerProfile(
        name: 'Jo',
        stats: const PlayerStats().withDuel(
          duel([round(1, Spell.vuur, Spell.bliksem)]),
          streakAfter: 1,
        ),
        badges: const {'eerste_winst': 1000},
      );
      final back = PlayerProfile.fromJson(p.toJson());
      expect(back.stats.roundWins(Spell.vuur), 1);
      expect(back.hasBadge('eerste_winst'), isTrue);
      expect(back.withProgress(p.progressJson()).badges, p.badges);
    });
  });

  group('ProfileProvider badges', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('a first flawless win unlocks the right badges, once', () async {
      final provider = ProfileProvider(LocalStorageService());
      await provider.load();

      await provider.recordGame(
        duel([
          round(1, Spell.schild, Spell.ijs),
          round(2, Spell.vuur, Spell.bliksem, castMs: 300),
          round(3, Spell.bliksem, Spell.ijs),
        ]),
      );
      final ids = provider.newBadges.map((b) => b.id).toSet();
      expect(
        ids,
        containsAll([
          'eerste_winst',
          'foutloos',
          'spiegelmeester',
          'bliksemsnel',
        ]),
      );
      expect(ids, isNot(contains('kampioen')));

      expect(provider.takeNewBadges(), isNotEmpty);
      expect(provider.newBadges, isEmpty);

      // The same achievements again unlock nothing new.
      await provider.recordGame(duel([round(1, Spell.vuur, Spell.bliksem)]));
      expect(
        provider.newBadges.map((b) => b.id),
        isNot(contains('eerste_winst')),
      );

      // Saved with the profile.
      final reloaded = ProfileProvider(LocalStorageService());
      await reloaded.load();
      expect(reloaded.profile.hasBadge('foutloos'), isTrue);
    });
  });

  test('every badge has a unique, server-safe id', () {
    final ids = allBadges.map((b) => b.id).toList();
    expect(ids.toSet().length, ids.length);
    for (final id in ids) {
      expect(RegExp(r'^[a-z_]{1,32}$').hasMatch(id), isTrue, reason: id);
    }
  });
}
