import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spell_duel/providers/challenge_provider.dart';
import 'package:spell_duel/providers/friends_provider.dart';
import 'package:spell_duel/providers/game_provider.dart';
import 'package:spell_duel/providers/profile_provider.dart';
import 'package:spell_duel/services/game/mock_game_backend.dart';
import 'package:spell_duel/services/push/push_service.dart';
import 'package:spell_duel/services/social/friends_backend.dart';
import 'package:spell_duel/services/social/mock_friends_backend.dart';
import 'package:spell_duel/services/storage/local_storage_service.dart';

class _RecordingPush implements PushService {
  final registered = <String>[];
  final unregistered = <String>[];

  @override
  Future<void> register(String uid) async => registered.add(uid);

  @override
  Future<void> unregister(String uid) async => unregistered.add(uid);

  final notified = <String>[];

  @override
  Future<void> notifyChallenge(String toUid) async => notified.add(toUid);
}

void main() {
  late MockFriendsBackend backend;
  late FriendsProvider friends;
  late GameProvider game;
  late ChallengeProvider challenges;
  late _RecordingPush push;
  final now = DateTime(2026, 11, 24, 12);

  Future<void> setup({List<ChallengeInvite> invites = const []}) async {
    SharedPreferences.setMockInitialValues({});
    final profile = ProfileProvider(LocalStorageService());
    await profile.load();
    await profile.setName('Maarten');
    backend = MockFriendsBackend(seedInvites: invites);
    friends = FriendsProvider(backend)..attach(profile);
    game = GameProvider(
      backend: MockGameBackend(
        useCamera: false,
        botJoinDelay: const Duration(milliseconds: 30),
      ),
    );
    push = _RecordingPush();
    challenges = ChallengeProvider(
      backend: backend,
      friends: friends,
      game: game,
      push: push,
      clock: () => now,
    );
    await pumpEventQueue();
  }

  tearDown(() {
    challenges.dispose();
    game.dispose();
  });

  test('shows fresh invites, newest first, and hides old ones', () async {
    await setup(
      invites: [
        ChallengeInvite(
          fromUid: 'a',
          name: 'Lotte',
          roomCode: 'ABCD',
          sentAt: now.subtract(const Duration(minutes: 1)),
        ),
        ChallengeInvite(
          fromUid: 'b',
          name: 'Jonas',
          roomCode: 'EFGH',
          sentAt: now.subtract(const Duration(seconds: 10)),
        ),
        ChallengeInvite(
          fromUid: 'c',
          name: 'Oud',
          roomCode: 'IJKL',
          sentAt: now.subtract(const Duration(minutes: 10)),
        ),
      ],
    );
    expect(challenges.incoming.map((i) => i.name), ['Jonas', 'Lotte']);
    expect(push.registered, ['mock-me']);

    await challenges.dismiss(challenges.incoming.first);
    await pumpEventQueue();
    expect(challenges.incoming.map((i) => i.name), ['Lotte']);
  });

  test('a sent invite is taken back once the friend joins', () async {
    await setup();
    final code = await game.createRoom('Maarten');
    const friend = Friend(uid: 'mock-bot', name: 'Bot');
    final msg = await challenges.send(friend, code!);
    expect(msg, contains('Bot'));
    expect(backend.sentInvites, {'mock-bot': 'TEST'});
    expect(push.notified, ['mock-bot']);
    expect(challenges.waitingFor, 'Bot');

    // The mock bot joins after 30 ms.
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(backend.sentInvites, isEmpty);
    expect(challenges.waitingFor, isNull);
    await game.leave();
  });

  test('leaving the room also takes the invite back', () async {
    await setup();
    final code = await game.createRoom('Maarten');
    await challenges.send(const Friend(uid: 'x', name: 'X'), code!);
    await game.leave();
    await pumpEventQueue(); // the idle state arrives via a stream
    expect(backend.sentInvites, isEmpty);
  });

  test('an idle state before the room shows up keeps the invite', () async {
    await setup();
    // Sent before the backend reported the room (as with Firebase).
    await challenges.send(const Friend(uid: 'x', name: 'X'), 'ABCD');
    game.notifyListeners();
    expect(backend.sentInvites, {'x': 'ABCD'});
    expect(challenges.outgoing?.name, 'X');
    expect(challenges.outgoingExpiresAt, now.add(ChallengeProvider.maxAge));

    await challenges.cancelOutgoing();
    expect(backend.sentInvites, isEmpty);
    expect(challenges.outgoing, isNull);
  });
}
