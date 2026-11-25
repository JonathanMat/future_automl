import 'package:flutter_test/flutter_test.dart';
import 'package:spell_duel/models/duel_summary.dart';
import 'package:spell_duel/models/game_rules.dart';
import 'package:spell_duel/models/game_state.dart';
import 'package:spell_duel/models/player_profile.dart';
import 'package:spell_duel/models/spell_info.dart';
import 'package:spell_duel/utils/round_text.dart';
import 'package:spell_duel/validators/player_name_validator.dart';
import 'package:spell_duel/validators/room_code_validator.dart';

RoundResult _result(int round, Spell? mine, Spell? theirs) {
  final r = resolveRound(hostSpell: mine, guestSpell: theirs);
  return RoundResult(
    round: round,
    mySpell: r.hostSpell,
    opponentSpell: r.guestSpell,
    outcome: r.winner == null
        ? RoundOutcome.draw
        : (r.winner == Side.host ? RoundOutcome.win : RoundOutcome.lose),
    reason: r.reason,
  );
}

void main() {
  group('PlayerProfile', () {
    test('level and progress come from XP', () {
      const p = PlayerProfile(xp: 3340);
      expect(p.level, 7);
      expect(p.xpInLevel, 340);
      expect(p.levelProgress, closeTo(0.68, 1e-9));
    });

    test('win rate, also with no games', () {
      expect(const PlayerProfile().winRate, 0);
      expect(const PlayerProfile(wins: 12, losses: 5).winRate, 71);
    });

    test('survives a JSON round trip', () {
      final p = PlayerProfile(
        name: 'Jonathan',
        xp: 120,
        wins: 1,
        streak: 1,
        lastDuel: LastDuel(
          opponentName: 'Maarten',
          won: true,
          roundsWon: 3,
          roundsLost: 1,
          playedAt: DateTime.fromMillisecondsSinceEpoch(1000),
        ),
      );
      final back = PlayerProfile.fromJson(p.toJson());
      expect(back.name, 'Jonathan');
      expect(back.xp, 120);
      expect(back.lastDuel!.opponentName, 'Maarten');
      expect(back.lastDuel!.roundsWon, 3);
      // Older profiles have no history yet: it starts with the last duel.
      expect(back.history.single.opponentName, 'Maarten');
    });

    test('duel history: round trip, newest first, database map form', () {
      LastDuel duel(int i) => LastDuel(
        opponentName: 'P$i',
        opponentUid: 'u$i',
        won: i.isEven,
        roundsWon: 3,
        roundsLost: 1,
        playedAt: DateTime.fromMillisecondsSinceEpoch(1000 * i),
      );
      final p = PlayerProfile(history: [duel(2), duel(1)]);
      final back = PlayerProfile.fromJson(p.toJson());
      expect(back.history.map((d) => d.opponentUid), ['u2', 'u1']);

      // The database can return the list as {"0": …, "1": …}.
      final json = p.toJson()
        ..['history'] = {'1': duel(1).toJson(), '0': duel(5).toJson()};
      expect(PlayerProfile.fromJson(json).history.map((d) => d.opponentName), [
        'P5',
        'P1',
      ]);
    });
  });

  group('DuelSummary', () {
    test('counts hits, favourite spell and fastest cast', () {
      final s = DuelSummary(
        opponentName: 'Bot',
        won: true,
        xpGained: 120,
        rounds: [
          RoundRecord(
            result: _result(1, Spell.ijs, Spell.vuur),
            castLatency: const Duration(milliseconds: 900),
            confidence: 0.9,
          ),
          RoundRecord(
            result: _result(2, Spell.ijs, Spell.bliksem),
            castLatency: const Duration(milliseconds: 600),
          ),
          RoundRecord(result: _result(3, Spell.vuur, Spell.bliksem)),
        ],
      );
      expect(s.hits, 2);
      expect(s.roundsLost, 1);
      expect(s.favoriteSpell, Spell.ijs);
      expect(s.fastestCast, const Duration(milliseconds: 600));
      expect(s.averageConfidence, closeTo(0.9, 1e-9));
    });
  });

  group('Spell texts', () {
    test('rules summary follows game_rules', () {
      expect(
        rulesSummary(const GameConfig()),
        'IJs › Vuur › Bliksem › IJs · Schild blokt Vuur en IJs (1×)',
      );
    });

    test('round text names the winning spell', () {
      expect(roundText(_result(1, Spell.ijs, Spell.vuur), opponentName: 'M'), (
        title: 'RAAK!',
        subtitle: 'IJS DOOFT VUUR',
      ));
      expect(
        roundText(_result(1, Spell.schild, Spell.bliksem), opponentName: 'M'),
        (title: 'AU!', subtitle: 'BLIKSEM BREEKT SCHILD'),
      );
      expect(
        roundText(_result(1, null, Spell.vuur), opponentName: 'M').title,
        'TE LAAT!',
      );
      expect(
        roundText(_result(1, null, null), opponentName: 'M').subtitle,
        'NIEMAND CASTTE',
      );
    });
  });

  group('Validators', () {
    test('room code', () {
      expect(RoomCodeValidator.validate(' k7q2 '), isNull);
      expect(RoomCodeValidator.normalize(' k7q2 '), 'K7Q2');
      expect(RoomCodeValidator.validate(''), isNotNull);
      expect(RoomCodeValidator.validate('K7Q'), isNotNull);
      expect(RoomCodeValidator.validate('K7-2'), isNotNull);
    });

    test('player name', () {
      expect(PlayerNameValidator.validate('Jonathan'), isNull);
      expect(PlayerNameValidator.validate('  '), isNotNull);
      expect(PlayerNameValidator.validate('J'), isNotNull);
      expect(PlayerNameValidator.validate('a' * 17), isNotNull);
      expect(PlayerNameValidator.normalize('  Jo   Mat '), 'Jo Mat');
    });
  });
}
