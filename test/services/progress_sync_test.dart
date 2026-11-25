import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spell_duel/models/duel_summary.dart';
import 'package:spell_duel/providers/friends_provider.dart';
import 'package:spell_duel/providers/profile_provider.dart';
import 'package:spell_duel/services/social/friends_backend.dart';
import 'package:spell_duel/services/social/mock_friends_backend.dart';
import 'package:spell_duel/services/storage/local_storage_service.dart';

Future<ProfileProvider> _profile() async {
  SharedPreferences.setMockInitialValues({});
  final p = ProfileProvider(LocalStorageService());
  await p.load();
  await p.setName('Maarten');
  return p;
}

DuelSummary _win() => const DuelSummary(
  opponentName: 'Bot',
  won: true,
  rounds: [],
  xpGained: 120,
);

void main() {
  test('a new install gets its progress back from the server', () async {
    final profile = await _profile();
    final backend = MockFriendsBackend()
      ..savedProgress = {'xp': 900, 'wins': 7, 'losses': 2, 'streak': 3};
    FriendsProvider(backend).attach(profile);
    await pumpEventQueue();

    expect(profile.profile.xp, 900);
    expect(profile.profile.wins, 7);
    expect(profile.profile.name, 'Maarten');
  });

  test('local progress is uploaded, and every game after that', () async {
    final profile = await _profile();
    await profile.recordGame(_win());
    final backend = MockFriendsBackend();
    FriendsProvider(backend).attach(profile);
    await pumpEventQueue();
    expect(backend.savedProgress?['xp'], 120);

    await profile.recordGame(_win());
    await pumpEventQueue();
    expect(backend.savedProgress?['xp'], 240);
    expect(backend.savedProgress?['wins'], 2);
  });

  test('keeps the copy with the most XP', () async {
    final profile = await _profile();
    await profile.recordGame(_win());
    await profile.recordGame(_win());
    final backend = MockFriendsBackend()
      ..savedProgress = {'xp': 120, 'wins': 1, 'losses': 0, 'streak': 1};
    FriendsProvider(backend).attach(profile);
    await pumpEventQueue();
    expect(profile.profile.xp, 240);
    expect(backend.savedProgress?['xp'], 240);
  });

  test('after an account switch the server progress replaces it', () async {
    final profile = await _profile();
    await profile.recordGame(_win());
    final backend = MockFriendsBackend();
    final friends = FriendsProvider(backend)..attach(profile);
    await pumpEventQueue();

    // The other account has no progress yet: fresh start.
    backend.savedProgress = null;
    await friends.restart();
    await pumpEventQueue();
    expect(profile.profile.xp, 0);
    expect(profile.profile.name, 'Maarten');
  });

  test('resetting stats also resets the scorebord', () async {
    final profile = await _profile();
    final backend = MockFriendsBackend()
      ..board = const LeaderboardEntry(
        uid: 'mock-me',
        name: 'Maarten',
        wins: 2,
        losses: 0,
      );
    final friends = FriendsProvider(backend)..attach(profile);
    await pumpEventQueue();

    await profile.resetStats();
    await friends.resetServerStats();
    await pumpEventQueue();
    expect(backend.board?.wins, 0);
    expect(profile.profile.wins, 0);
    expect(backend.savedProgress?['wins'], 0);
  });

  group('recent opponents', () {
    test('a new install gets them back from the server', () async {
      final profile = await _profile();
      final backend = MockFriendsBackend()
        ..savedRecent = [
          {
            'uid': 'u-lotte',
            'name': 'Lotte',
            'wins': 2,
            'losses': 1,
            'lastPlayed': 1000,
          },
        ];
      FriendsProvider(backend).attach(profile);
      await pumpEventQueue();

      expect(profile.friends.single.name, 'Lotte');
      expect(profile.friends.single.wins, 2);
      expect(profile.friends.single.uid, 'u-lotte');
    });

    test('are uploaded and merged with the server copy', () async {
      final profile = await _profile();
      await profile.recordGame(_win());
      final backend = MockFriendsBackend()
        ..savedRecent = [
          {'name': 'Lotte', 'wins': 0, 'losses': 1, 'lastPlayed': 1000},
        ];
      FriendsProvider(backend).attach(profile);
      await pumpEventQueue();

      expect(profile.friends.map((f) => f.name), ['Bot', 'Lotte']);
      expect(backend.savedRecent.map((m) => m['name']), ['Bot', 'Lotte']);

      // Every game after that is saved too.
      await profile.recordGame(_win());
      await pumpEventQueue();
      expect(backend.savedRecent.first['wins'], 2);
    });

    test('resetting stats clears them on the server', () async {
      final profile = await _profile();
      await profile.recordGame(_win());
      final backend = MockFriendsBackend();
      FriendsProvider(backend).attach(profile);
      await pumpEventQueue();
      expect(backend.savedRecent, isNotEmpty);

      await profile.resetStats();
      await pumpEventQueue();
      expect(backend.savedRecent, isEmpty);
    });

    test('after an account switch the server list replaces them', () async {
      final profile = await _profile();
      await profile.recordGame(_win());
      final backend = MockFriendsBackend();
      final friends = FriendsProvider(backend)..attach(profile);
      await pumpEventQueue();

      backend.savedRecent = [];
      await friends.restart();
      await pumpEventQueue();
      expect(profile.friends, isEmpty);
    });
  });
}
