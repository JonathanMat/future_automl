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
