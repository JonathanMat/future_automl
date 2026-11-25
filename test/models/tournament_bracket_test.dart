import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:spell_duel/models/tournament.dart';

List<String> players(int n) => [for (var i = 0; i < n; i++) 'p$i'];

/// Plays a whole tournament with random winners; returns the bracket.
Bracket playOut(List<String> seeds, Random rnd, {bool walkovers = false}) {
  final results = <String, MatchResult>{};
  var clock = 1000;
  for (var guard = 0; guard < 100; guard++) {
    final bracket = Bracket.build(seeds, results, startedAt: 0);
    if (bracket.champion != null) return bracket;
    final ready = bracket.matches.where((m) => m.isReady).toList();
    expect(ready, isNotEmpty, reason: 'stuck without a champion');
    for (final m in ready) {
      clock += 10;
      results[m.id] = MatchResult(
        winner: rnd.nextBool() ? m.a! : m.b!,
        at: clock,
        walkover: walkovers && rnd.nextBool(),
      );
    }
  }
  fail('never finished');
}

void main() {
  group('draw', () {
    test('every player gets exactly one seat, byes fill the rest', () {
      final rnd = Random(1);
      for (var n = 2; n <= maxTournamentPlayers; n++) {
        for (var run = 0; run < 50; run++) {
          final seeds = Bracket.draw(players(n), rnd);
          final seats = Bracket.seatsFor(n);
          expect(seeds.length, seats, reason: 'n=$n');
          expect(
            seeds.where((s) => s != byeSeat).toSet(),
            players(n).toSet(),
            reason: 'n=$n',
          );
          expect(seeds.where((s) => s == byeSeat).length, seats - n);
        }
      }
    });

    test('two byes never meet, so no match is empty', () {
      final rnd = Random(2);
      for (var n = 2; n <= maxTournamentPlayers; n++) {
        for (var run = 0; run < 50; run++) {
          final seeds = Bracket.draw(players(n), rnd);
          for (var i = 0; i < seeds.length; i += 2) {
            expect(
              seeds[i] == byeSeat && seeds[i + 1] == byeSeat,
              isFalse,
              reason: 'n=$n seeds=$seeds',
            );
          }
          // From round 2 on, every match has two real players.
          final bracket = Bracket.build(seeds, const {}, startedAt: 0);
          for (final m in bracket.rounds.skip(1).expand((r) => r)) {
            expect(m.a == byeSeat || m.b == byeSeat, isFalse);
          }
        }
      }
    });

    test('byes are spread over both halves when there are several', () {
      final seeds = Bracket.draw(players(5), Random(3)); // 8 seats, 3 byes
      final half = seeds.length ~/ 2;
      final left = seeds.take(half).where((s) => s == byeSeat).length;
      final right = seeds.skip(half).where((s) => s == byeSeat).length;
      expect(left, greaterThan(0));
      expect(right, greaterThan(0));
    });

    test('needs at least two players', () {
      expect(() => Bracket.draw(['solo'], Random()), throwsArgumentError);
    });
  });

  group('playing it out', () {
    test('every size from 2 to 16 ends with one champion', () {
      final rnd = Random(4);
      for (var n = 2; n <= maxTournamentPlayers; n++) {
        for (var run = 0; run < 40; run++) {
          final everyone = players(n);
          final seeds = Bracket.draw(everyone, rnd);
          final bracket = playOut(seeds, rnd, walkovers: run.isOdd);

          final champion = bracket.champion!;
          expect(everyone, contains(champion));
          // log2(seats) rounds, ending in one final.
          expect(bracket.rounds.length, log(Bracket.seatsFor(n)) ~/ log(2));
          expect(bracket.rounds.last, hasLength(1));
          // Everybody but the champion lost exactly once.
          final losers = [
            for (final m in bracket.matches)
              if (m.loser != null) m.loser!,
          ];
          expect(losers.length, n - 1, reason: 'n=$n');
          expect(losers.toSet().length, n - 1);
          expect(losers, isNot(contains(champion)));
          for (final p in everyone) {
            expect(bracket.isEliminated(p), p != champion);
            expect(bracket.currentMatchFor(p), isNull);
          }
        }
      }
    });

    test('a bye goes through without playing and is not "eliminated"', () {
      // 3 players: p0 vs p1, p2 has a bye.
      final bracket = Bracket.build(['p0', 'p1', 'p2', byeSeat], const {});
      final bye = bracket.rounds[0][1];
      expect(bye.isBye, isTrue);
      expect(bye.winner, 'p2');
      expect(bye.loser, isNull);
      expect(bracket.isEliminated('p2'), isFalse);
      // p2 already sits in the final, waiting for p0 or p1.
      final next = bracket.currentMatchFor('p2')!;
      expect(next.round, 1);
      expect(next.b, 'p2');
      expect(next.a, isNull);
      expect(next.isReady, isFalse);
    });

    test('the next match is ready once both sides are decided', () {
      final seeds = ['a', 'b', 'c', 'd'];
      final results = {'r0m0': const MatchResult(winner: 'a', at: 500)};
      var bracket = Bracket.build(seeds, results, startedAt: 100);
      expect(bracket.currentMatchFor('a')!.isReady, isFalse);
      expect(bracket.currentMatchFor('b'), isNull);
      expect(bracket.isEliminated('b'), isTrue);

      results['r0m1'] = const MatchResult(winner: 'd', at: 900);
      bracket = Bracket.build(seeds, results, startedAt: 100);
      final finale = bracket.currentMatchFor('a')!;
      expect(finale.isReady, isTrue);
      expect(finale.opponentOf('a'), 'd');
      expect(finale.readySince, 900, reason: 'when the later semi ended');
      expect(bracket.rounds[0][0].readySince, 100);
    });

    test('a result naming someone outside the match is ignored', () {
      final bracket = Bracket.build(
        ['a', 'b', 'c', 'd'],
        {'r0m0': const MatchResult(winner: 'c', at: 1)},
      );
      expect(bracket.rounds[0][0].winner, isNull);
      expect(bracket.rounds[0][0].isReady, isTrue);
    });

    test('a walk-over is remembered', () {
      final bracket = Bracket.build(
        ['a', 'b'],
        {'r0m0': const MatchResult(winner: 'b', at: 1, walkover: true)},
      );
      expect(bracket.champion, 'b');
      expect(bracket.finalMatch!.walkover, isTrue);
    });
  });

  test('round names count back from the final', () {
    expect(Bracket.roundName(0, 1), 'Finale');
    expect(Bracket.roundName(0, 2), 'Halve finale');
    expect(Bracket.roundName(1, 3), 'Halve finale');
    expect(Bracket.roundName(0, 3), 'Kwartfinale');
    expect(Bracket.roundName(0, 4), 'Achtste finale');
  });
}
