import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spell_duel/models/duel_summary.dart';
import 'package:spell_duel/providers/game_provider.dart';
import 'package:spell_duel/providers/profile_provider.dart';
import 'package:spell_duel/services/game/game_backend.dart';
import 'package:spell_duel/services/game/mock_game_backend.dart';
import 'package:spell_duel/services/permissions/camera_permission_service.dart';
import 'package:spell_duel/services/storage/local_storage_service.dart';

void main() {
  const fast = GameConfig(
    introLead: Duration.zero,
    countdown: Duration(milliseconds: 60),
    castWindow: Duration(milliseconds: 300),
    resultPause: Duration(milliseconds: 60),
    roundLead: Duration(milliseconds: 20),
  );

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('opponent away', () {
    // Slow rounds, so the game is still running during the test.
    const slow = GameConfig(
      introLead: Duration.zero,
      countdown: Duration(seconds: 5),
      roundLead: Duration.zero,
    );

    Future<(GameProvider, MockGameBackend)> start({
      Future<void> Function(DuelSummary)? onAbandoned,
      Future<void> Function(DuelSummary)? onFinished,
    }) async {
      final backend = MockGameBackend(
        config: slow,
        useCamera: false,
        botJoinDelay: const Duration(milliseconds: 10),
        botEmotes: false,
      );
      final game = GameProvider(
        backend: backend,
        forfeitWait: const Duration(milliseconds: 80),
        onGameAbandoned: onAbandoned,
        onGameFinished: onFinished,
      );
      await game.createRoom('Jonathan');
      await backend.gameState.firstWhere((s) => s.opponent != null);
      await pumpEventQueue();
      return (game, backend);
    }

    test('you win when they stay away', () async {
      DuelSummary? finished;
      final (game, backend) = await start(
        onFinished: (s) async => finished = s,
      );
      backend.opponentAway(left: true);
      await pumpEventQueue();
      expect(game.opponentAwaySince, isNotNull);
      expect(game.state.opponent!.left, isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(game.state.phase, GamePhase.finished);
      expect(game.state.iWon, isTrue);
      expect(game.state.error, isNull, reason: 'a real win: result screen');
      expect(finished?.won, isTrue);
      expect(game.opponentAwaySince, isNull);
      await game.leave();
      game.dispose();
    });

    test('the duel goes on when they come back in time', () async {
      final (game, backend) = await start();
      backend.opponentAway();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      backend.opponentBack();
      await pumpEventQueue();
      expect(game.opponentAwaySince, isNull);

      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(game.state.phase, isNot(GamePhase.finished));
      await game.leave();
      game.dispose();
    });

    test('leaving a running game counts as a loss', () async {
      DuelSummary? abandoned;
      final (game, _) = await start(onAbandoned: (s) async => abandoned = s);
      await game.leave();
      expect(abandoned?.won, isFalse);
      expect(abandoned?.opponentName, 'Bot');
      game.dispose();
    });
  });

  test('a full game produces a summary and updates the profile', () async {
    final profile = ProfileProvider(LocalStorageService());
    await profile.load();
    await profile.setName('Jonathan');

    DuelSummary? finished;
    final game = GameProvider(
      backend: MockGameBackend(
        config: fast,
        useCamera: false,
        botJoinDelay: const Duration(milliseconds: 20),
        random: Random(3),
      ),
      onGameFinished: (s) async {
        finished = s;
        await profile.recordGame(s);
      },
    );

    expect(await game.createRoom('Jonathan'), 'TEST');

    // Tap "vuur" every round.
    game.addListener(() {
      if (game.state.canCast) game.castSpell(Spell.vuur);
    });
    await game.backend.gameState
        .firstWhere((s) => s.phase == GamePhase.finished)
        .timeout(const Duration(seconds: 20));
    await Future<void>.delayed(const Duration(milliseconds: 10));

    final s = finished!;
    expect(s.opponentName, 'Bot');
    expect(s.rounds, isNotEmpty);
    expect(
      s.rounds.map((r) => r.result.round).toSet().length,
      s.rounds.length,
      reason: 'each round is recorded once',
    );
    expect(game.lastSummary, same(s));

    final p = profile.profile;
    expect(p.wins + p.losses, 1);
    expect(p.xp, s.won ? 120 : 40);
    expect(p.lastDuel!.opponentName, 'Bot');
    expect(p.history.single.opponentName, 'Bot');
    expect(profile.friends.single.name, 'Bot');

    // Stored on the phone too.
    final reloaded = ProfileProvider(LocalStorageService());
    await reloaded.load();
    expect(reloaded.profile.xp, p.xp);
    expect(reloaded.friends.single.games, 1);

    game.dispose();
  });

  test('a refused camera stops before any room is made', () async {
    final backend = MockGameBackend(useCamera: false);
    final game = GameProvider(
      backend: backend,
      cameraPermission: const FakeCameraPermission(MediaAccess.denied),
    );
    expect(await game.createRoom('Jo'), isNull);
    expect(await game.joinRoom('ABCD', 'Jo'), isFalse);
    expect(game.mediaAccess, MediaAccess.denied);
    expect(game.actionError, 'Spell Duel heeft je camera en microfoon nodig.');
    expect(backend.state.phase, GamePhase.idle, reason: 'no room created');
    game.dispose();
  });

  test('getUserMedia errors are classified per platform', () {
    // Android and iOS wording from flutter_webrtc.
    expect(
      CameraPermissionService.classify(
        Exception('getUserMediaFailed: DOMException, NotAllowedError'),
      ),
      MediaAccess.denied,
    );
    expect(
      CameraPermissionService.classify(
        Exception('Error DOMException: NotAllowedError'),
      ),
      MediaAccess.denied,
    );
    expect(
      CameraPermissionService.classify(Exception('DOMException NotFoundError')),
      MediaAccess.unavailable,
    );
    expect(
      CameraPermissionService.classify(Exception('boom')),
      MediaAccess.failed,
    );
  });

  test('joining reports errors from the backend', () async {
    final game = GameProvider(backend: _FailingBackend());
    expect(await game.joinRoom('ABCD', 'Jo'), isFalse);
    expect(game.actionError, 'Kamer niet gevonden.');
  });
}

class FakeCameraPermission extends CameraPermissionService {
  const FakeCameraPermission(this.result) : super(microphone: true);

  final MediaAccess result;

  @override
  Future<MediaAccess> ensureAccess({
    bool withMicrophone = true,
    Future<void> Function()? open,
  }) async => result;
}

class _FailingBackend extends MockGameBackend {
  _FailingBackend() : super(useCamera: false);

  @override
  Future<void> joinRoom(String code, {required String playerName}) async =>
      throw GameBackendException('Kamer niet gevonden.');
}
