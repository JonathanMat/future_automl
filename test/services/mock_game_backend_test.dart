import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:spell_duel/services/game/game_backend.dart';
import 'package:spell_duel/services/game/mock_game_backend.dart';

void main() {
  const fast = GameConfig(
    introLead: Duration.zero,
    countdown: Duration(milliseconds: 60),
    castWindow: Duration(milliseconds: 300),
    resultPause: Duration(milliseconds: 60),
    roundLead: Duration(milliseconds: 20),
  );

  MockGameBackend newBackend() => MockGameBackend(
    config: fast,
    useCamera: false,
    botJoinDelay: const Duration(milliseconds: 20),
    random: Random(1),
  );

  test('a full game ends with one player at 0 lives', () async {
    final backend = newBackend();
    await backend.createRoom(playerName: 'Maarten');
    expect(backend.state.phase, GamePhase.waitingForOpponent);

    // Cast "vuur" in every round until the game ends.
    final sub = backend.gameState.listen((s) {
      if (s.canCast) backend.submitSpell(Spell.vuur);
    });
    final end = await backend.gameState
        .firstWhere((s) => s.phase == GamePhase.finished)
        .timeout(const Duration(seconds: 20));
    await sub.cancel();

    expect(end.iWon, isNotNull);
    expect([end.me!.lives, end.opponent!.lives].where((l) => l <= 0).length, 1);
    await backend.dispose();
  });

  test('submitSpell is refused outside the cast window', () async {
    final backend = newBackend();
    await backend.joinRoom('abcd', playerName: 'Jonathan');
    expect(backend.state.roomCode, 'ABCD');
    expect(backend.state.phase, GamePhase.countdown);
    expect(
      () => backend.submitSpell(Spell.ijs),
      throwsA(isA<GameBackendException>()),
    );
    await backend.dispose();
  });

  test('the shield can only be cast once', () async {
    final backend = newBackend();
    await backend.joinRoom('abcd', playerName: 'Jonathan');
    await backend.gameState.firstWhere((s) => s.canCast);
    await backend.submitSpell(Spell.schild);
    await backend.gameState.firstWhere(
      (s) => s.phase == GamePhase.roundResult || s.phase == GamePhase.finished,
    );
    expect(backend.state.myShieldAvailable, isFalse);

    if (backend.state.phase != GamePhase.finished) {
      await backend.gameState.firstWhere((s) => s.canCast);
      expect(
        () => backend.submitSpell(Spell.schild),
        throwsA(isA<GameBackendException>()),
      );
    }
    await backend.dispose();
  });

  test('only the first round of a game waits for the VS intro', () async {
    final backend = MockGameBackend(
      useCamera: false,
      botJoinDelay: Duration.zero,
      config: const GameConfig(
        countdown: Duration(milliseconds: 300),
        castWindow: Duration(milliseconds: 100),
        resultPause: Duration(milliseconds: 50),
        roundLead: Duration(milliseconds: 20),
        introLead: Duration(seconds: 2),
      ),
    );
    await backend.joinRoom('abcd', playerName: 'Jo');
    final first = backend.state.castAt!.difference(DateTime.now());
    expect(first, greaterThan(const Duration(milliseconds: 2200)));

    final second = await backend.gameState
        .firstWhere((s) => s.round == 2)
        .timeout(const Duration(seconds: 10));
    final wait = second.castAt!.difference(DateTime.now());
    expect(wait, lessThan(const Duration(milliseconds: 400)));
    await backend.dispose();
  });
}
