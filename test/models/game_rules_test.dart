import 'package:flutter_test/flutter_test.dart';
import 'package:spell_duel/backend/commit_reveal.dart';
import 'package:spell_duel/backend/game_rules.dart';

void main() {
  group('Spell.beatsSpell – all 16 combinations', () {
    // Expected winner for (host, guest): host, guest or null (draw).
    const v = Spell.vuur, i = Spell.ijs, b = Spell.bliksem, s = Spell.schild;
    final expected = <(Spell, Spell), Side?>{
      (v, v): null, (v, i): Side.guest, (v, b): Side.host, (v, s): Side.guest,
      (i, v): Side.host, (i, i): null, (i, b): Side.guest, (i, s): Side.guest,
      (b, v): Side.guest, (b, i): Side.host, (b, b): null, (b, s): Side.host,
      (s, v): Side.host, (s, i): Side.host, (s, b): Side.guest, (s, s): null,
    };

    for (final entry in expected.entries) {
      final (host, guest) = entry.key;
      test('${host.wire} vs ${guest.wire} -> ${entry.value?.name ?? 'draw'}',
          () {
        final r = resolveRound(hostSpell: host, guestSpell: guest);
        expect(r.winner, entry.value);
      });
    }

    test('every pair of different spells has exactly one winner', () {
      for (final a in Spell.values) {
        for (final c in Spell.values) {
          if (a == c) continue;
          expect(a.beatsSpell(c) != c.beatsSpell(a), isTrue,
              reason: '${a.wire} vs ${c.wire}');
        }
      }
    });
  });

  group('shield', () {
    test('a valid shield is used up, even in a draw', () {
      final r = resolveRound(hostSpell: Spell.schild, guestSpell: Spell.schild);
      expect(r.winner, isNull);
      expect(r.reason, RoundReason.sameSpell);
      expect(r.hostShieldsUsed, 1);
      expect(r.guestShieldsUsed, 1);
    });

    test('a second shield counts as no spell and loses', () {
      final r = resolveRound(
        hostSpell: Spell.schild,
        guestSpell: Spell.vuur,
        hostShieldsUsed: 1,
      );
      expect(r.hostSpell, isNull);
      expect(r.winner, Side.guest);
      expect(r.reason, RoundReason.opponentNoSpell);
      expect(r.hostShieldsUsed, 1);
    });

    test('other spells do not use the shield', () {
      final r = resolveRound(hostSpell: Spell.ijs, guestSpell: Spell.vuur);
      expect(r.hostShieldsUsed, 0);
      expect(r.guestShieldsUsed, 0);
    });
  });

  group('missing spells', () {
    test('nothing vs a spell: the spell wins', () {
      final r = resolveRound(hostSpell: null, guestSpell: Spell.ijs);
      expect(r.winner, Side.guest);
      expect(r.reason, RoundReason.opponentNoSpell);
    });

    test('nothing vs nothing: draw', () {
      final r = resolveRound(hostSpell: null, guestSpell: null);
      expect(r.winner, isNull);
      expect(r.reason, RoundReason.bothNoSpell);
    });
  });

  group('CommitReveal', () {
    test('verifies the right spell and salt', () {
      final salt = CommitReveal.newSalt();
      final hash = CommitReveal.commitHash(Spell.bliksem, salt);
      expect(CommitReveal.verify(hash: hash, spell: Spell.bliksem, salt: salt),
          isTrue);
    });

    test('rejects a changed spell or salt', () {
      final salt = CommitReveal.newSalt();
      final hash = CommitReveal.commitHash(Spell.bliksem, salt);
      expect(CommitReveal.verify(hash: hash, spell: Spell.vuur, salt: salt),
          isFalse);
      expect(
          CommitReveal.verify(
              hash: hash, spell: Spell.bliksem, salt: CommitReveal.newSalt()),
          isFalse);
    });

    test('salts are random', () {
      expect(CommitReveal.newSalt(), isNot(CommitReveal.newSalt()));
    });
  });
}
