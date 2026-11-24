import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:spell_duel/backend/game_backend.dart';
import 'package:spell_duel/backend/mock_game_backend.dart';

void main() {
  const fast = GameConfig(
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
    expect(
        [end.me!.lives, end.opponent!.lives].where((l) => l <= 0).length, 1);
    await backend.dispose();
  });

  test('submitSpell is refused outside the cast window', () async {
    final backend = newBackend();
    await backend.joinRoom('abcd', playerName: 'Jonathan');
    expect(backend.state.roomCode, 'ABCD');
    expect(backend.state.phase, GamePhase.countdown);
    expect(() => backend.submitSpell(Spell.ijs),
        throwsA(isA<GameBackendException>()));
    await backend.dispose();
  });

  test('the shield can only be cast once', () async {
    final backend = newBackend();
    await backend.joinRoom('abcd', playerName: 'Jonathan');
    await backend.gameState.firstWhere((s) => s.canCast);
    await backend.submitSpell(Spell.schild);
    await backend.gameState.firstWhere(
        (s) => s.phase == GamePhase.roundResult || s.phase == GamePhase.finished);
    expect(backend.state.myShieldAvailable, isFalse);

    if (backend.state.phase != GamePhase.finished) {
      await backend.gameState.firstWhere((s) => s.canCast);
      expect(() => backend.submitSpell(Spell.schild),
          throwsA(isA<GameBackendException>()));
    }
    await backend.dispose();
  });
}
