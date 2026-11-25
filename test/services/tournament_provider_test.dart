import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spell_duel/models/duel_summary.dart';
import 'package:spell_duel/providers/friends_provider.dart';
import 'package:spell_duel/providers/game_provider.dart';
import 'package:spell_duel/providers/profile_provider.dart';
import 'package:spell_duel/providers/tournament_provider.dart';
import 'package:spell_duel/services/game/mock_game_backend.dart';
import 'package:spell_duel/services/social/friends_backend.dart';
import 'package:spell_duel/services/social/mock_friends_backend.dart';
import 'package:spell_duel/services/storage/local_storage_service.dart';
import 'package:spell_duel/services/tournament/firebase_tournament_backend.dart';
import 'package:spell_duel/services/tournament/tournament_backend.dart';
import 'package:spell_duel/services/tournament/mock_tournament_backend.dart';

const _summary = DuelSummary(
  opponentName: 'Bot',
  won: true,
  rounds: [],
  xpGained: 0,
);

const _opponentUid = 'opponent';

class _OpponentFriendsBackend extends MockFriendsBackend {
  @override
  Future<FriendIdentity> signIn({
    required String name,
    bool keepServerName = false,
  }) async => const FriendIdentity(
    uid: _opponentUid,
    friendCode: 'ABC123',
    tag: '4321',
  );
}

void main() {
  late MockTournamentBackend backend;
  late MockGameBackend gameBackend;
  late ProfileProvider profile;
  late FriendsProvider friends;
  late GameProvider game;
  late TournamentProvider t;
  var now = DateTime.now();
  var ready = false;

  Future<void> setup({
    int seed = 1,
    Duration botJoinDelay = const Duration(milliseconds: 5),
  }) async {
    SharedPreferences.setMockInitialValues({});
    profile = ProfileProvider(LocalStorageService());
    await profile.load();
    await profile.setName('Jonathan');
    friends = FriendsProvider(MockFriendsBackend())..attach(profile);
    gameBackend = MockGameBackend(useCamera: false, botJoinDelay: botJoinDelay);
    game = GameProvider(backend: gameBackend);
    backend = MockTournamentBackend(
      random: Random(seed),
      botMatchTime: (
        min: const Duration(milliseconds: 5),
        max: const Duration(milliseconds: 20),
      ),
      botRoomDelay: const Duration(milliseconds: 5),
    );
    now = DateTime.now();
    t = TournamentProvider(
      backend: backend,
      friends: friends,
      game: game,
      profile: profile,
      random: Random(seed),
      clock: () => now,
    );
    ready = true;
    await pumpEventQueue();
  }

  tearDown(() async {
    if (!ready) return;
    ready = false;
    t.dispose();
    game.dispose();
    await backend.dispose();
  });

  Future<void> waitFor(bool Function() done, {int tries = 400}) async {
    for (var i = 0; i < tries && !done(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(done(), isTrue, reason: 'timed out');
  }

  /// Plays your matches; [win] decides each one. Returns how many you played.
  Future<int> playAll({bool Function(int match)? win}) async {
    var played = 0;
    while (t.myMatch != null) {
      await waitFor(() => t.myMatch == null || t.myMatch!.isReady);
      if (t.myMatch == null) break;
      var outcome = await t.play();
      while (outcome == PlayOutcome.waitForRoom) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
        outcome = await t.play();
      }
      expect(outcome, PlayOutcome.inRoom);
      expect(t.inMatch, isTrue);
      final won = win?.call(played) ?? true;
      await t.onGameFinished(_summary, iWon: won);
      played++;
      await game.leave();
      await pumpEventQueue();
    }
    return played;
  }

  for (final n in [2, 3, 5, 7, 8, 11, 16]) {
    test('$n players: you win every match and become champion', () async {
      await setup(seed: n);
      final code = await t.create();
      expect(code, isNotNull);
      await t.addBots(n - 1);
      await pumpEventQueue();
      expect(t.data!.players, hasLength(n));
      expect(await t.start(), isTrue);
      await pumpEventQueue();
      expect(t.status, TournamentStatus.running);

      final played = await playAll();
      // Rounds = log2(size); a bye in round 1 saves you a match.
      final rounds = (log(n) / ln2).ceil();
      expect(played, inInclusiveRange(rounds - 1, rounds));
      await waitFor(() => t.status == TournamentStatus.finished);
      expect(t.isChampion, isTrue);
      expect(t.bracket.champion, friends.myUid);
      expect(profile.profile.stats.tournamentWins, 1);
      expect(profile.profile.stats.tournamentMatches, played);
      expect(profile.profile.hasBadge('toernooispeler'), isTrue);
      expect(profile.profile.hasBadge('toernooiwinnaar'), isTrue);
    });
  }

  test('losing knocks you out; the bots finish and the host closes', () async {
    await setup(seed: 4);
    await t.create();
    await t.addBots(5);
    await pumpEventQueue();
    await t.start();
    await pumpEventQueue();

    final played = await playAll(win: (_) => false);
    expect(played, 1);
    expect(t.isEliminated, isTrue);
    expect(t.myMatch, isNull);
    await waitFor(() => t.status == TournamentStatus.finished);
    expect(t.champion, isNotNull);
    expect(t.isChampion, isFalse);
    expect(profile.profile.stats.tournamentWins, 0);
  });

  test('the bracket for 6 players has 2 byes and no double bye', () async {
    await setup(seed: 9);
    await t.create();
    await t.addBots(5);
    await pumpEventQueue();
    await t.start();
    await pumpEventQueue();
    final first = t.bracket.rounds.first;
    expect(first, hasLength(4));
    expect(first.where((m) => m.isBye), hasLength(2));
    expect(first.where((m) => m.a == byeSeat && m.b == byeSeat), isEmpty);
    // Bye matches are decided right away.
    expect(first.where((m) => m.isBye).every((m) => m.isDone), isTrue);
  });

  test('opponent left the room: you win by walk-over', () async {
    await setup(seed: 2);
    await t.create();
    await t.addBots(1);
    await pumpEventQueue();
    await t.start();
    await waitFor(() => t.myMatch?.isReady ?? false);
    var outcome = await t.play();
    while (outcome == PlayOutcome.waitForRoom) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
      outcome = await t.play();
    }
    await t.onGameFinished(_summary);
    await pumpEventQueue();
    expect(t.isChampion, isTrue);
    expect(t.bracket.finalMatch!.walkover, isTrue);
  });

  test('offline opponent: claim the walk-over after the wait', () async {
    await setup(seed: 3);
    final code = (await t.create())!;
    await backend.join(
      code,
      const TournamentMe(uid: _opponentUid, name: 'Lotte'),
    );
    await backend.start(code, [_opponentUid, t.myUid!]);
    await pumpEventQueue();
    await backend.leave(code, _opponentUid, isHost: false);
    expect(await t.play(), PlayOutcome.waitForRoom);
    await pumpEventQueue();
    expect(t.myOpponent!.online, isFalse);
    expect(t.canClaimWalkover, isFalse);
    expect(t.walkoverIn.inSeconds, greaterThan(15));

    now = now.add(TournamentProvider.offlineWait + const Duration(seconds: 1));
    expect(t.canClaimWalkover, isTrue);
    await t.claimWalkover();
    await pumpEventQueue();
    expect(t.isChampion, isTrue);
  });

  for (final opensRoom in [true, false]) {
    test(
      'only the player who accepts can claim (opens room: $opensRoom)',
      () async {
        await setup(botJoinDelay: const Duration(minutes: 10));
        final code = (await t.create())!;
        final opponentFriends = FriendsProvider(_OpponentFriendsBackend())
          ..attach(profile);
        final opponentGame = GameProvider(
          backend: MockGameBackend(useCamera: false),
        );
        final opponent = TournamentProvider(
          backend: backend,
          friends: opponentFriends,
          game: opponentGame,
          profile: profile,
          clock: () => now,
        );
        addTearDown(() {
          opponent.dispose();
          opponentGame.dispose();
          opponentFriends.dispose();
        });
        await pumpEventQueue();
        expect(await opponent.join(code), isTrue);
        final me = t.myUid!;
        await backend.start(
          code,
          opensRoom ? [me, _opponentUid] : [_opponentUid, me],
        );
        await pumpEventQueue();
        final id = t.myMatch!.id;

        final outcome = await t.play();
        expect(
          outcome,
          opensRoom ? PlayOutcome.inRoom : PlayOutcome.waitForRoom,
        );
        await pumpEventQueue();
        expect(t.waitingForOpponent, isTrue);
        now = now.add(const Duration(seconds: 30));
        expect(t.canClaimWalkover, isFalse);
        now = now.add(TournamentProvider.walkoverWait);
        expect(t.canClaimWalkover, isTrue);
        expect(opponent.canClaimWalkover, isFalse);
        expect(await opponent.claimWalkover(), isFalse);

        // Acceptance arriving before a claim blocks it.
        await backend.setMatchReady(code, id, _opponentUid, ready: true);
        expect(await t.claimWalkover(), isFalse);
        await pumpEventQueue();
        expect(t.canClaimWalkover, isFalse);
        await opponent.cancelPlay(id);
        await pumpEventQueue();

        expect(await t.claimWalkover(), isTrue);
        await pumpEventQueue();
        expect(t.isChampion, isTrue);
        expect(opponent.isEliminated, isTrue);
        expect(t.bracket.finalMatch!.walkover, isTrue);
      },
    );
  }

  test('the host can overrule a result', () async {
    await setup(seed: 6);
    await t.create();
    await t.addBots(1);
    await pumpEventQueue();
    await t.start();
    await pumpEventQueue();
    final m = t.myMatch!;
    final bot = t.myOpponent!.uid;
    await t.decide(m.id, bot);
    await pumpEventQueue();
    expect(t.champion, bot);
    await t.decide(m.id, friends.myUid!);
    await pumpEventQueue();
    expect(t.champion, friends.myUid);
  });

  test('joining: unknown code, started, full, and lower case', () async {
    await setup();
    expect(await t.join('ZZZZZ'), isFalse);
    expect(t.error, contains('bestaat niet'));

    final code = await backend.create(
      const TournamentMe(uid: 'host', name: 'Juf'),
    );
    expect(await t.join(code.toLowerCase()), isTrue);
    expect(t.inTournament, isTrue);
    expect(t.isHost, isFalse);
    expect(await t.start(), isFalse, reason: 'only the host starts');
    await t.leave();
    await pumpEventQueue();
    expect(backend.watch(code).first, completion(isNotNull));

    await backend.addBots(code, 15);
    expect(await t.join(code), isFalse);
    expect(t.error, contains('vol'));

    final started = await backend.create(
      const TournamentMe(uid: 'host2', name: 'Meester'),
    );
    await backend.addBots(started, 3);
    await backend.start(
      started,
      Bracket.draw(['host2', 'bot-lotte'], Random()),
    );
    expect(await t.join(started), isFalse);
    expect(t.error, contains('begonnen'));
  });

  test('the host leaving the waiting room cancels it for everybody', () async {
    await setup();
    final code = await backend.create(
      const TournamentMe(uid: 'host', name: 'Juf'),
    );
    await t.join(code);
    await pumpEventQueue();
    expect(t.data!.players, hasLength(2));
    await backend.leave(code, 'host', isHost: true);
    await pumpEventQueue();
    expect(t.inTournament, isFalse);
    expect(t.error, contains('gestopt'));
  });

  test('needs at least 2 players to start', () async {
    await setup();
    await t.create();
    await pumpEventQueue();
    expect(await t.start(), isFalse);
    expect(t.error, contains('minstens 2'));
  });

  test('leaving your match room keeps the match open', () async {
    await setup(seed: 8);
    await t.create();
    await t.addBots(1);
    await pumpEventQueue();
    await t.start();
    await waitFor(() => t.myMatch?.isReady ?? false);
    var outcome = await t.play();
    while (outcome == PlayOutcome.waitForRoom) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
      outcome = await t.play();
    }
    expect(t.inMatch, isTrue);
    await game.leave();
    await pumpEventQueue();
    expect(t.inMatch, isFalse);
    expect(t.myMatch?.isReady, isTrue);
  });

  group('Firebase parse', () {
    test('reads players, seeds with gaps, rooms and results', () {
      final d = FirebaseTournamentBackend.parseForTest('ABCDE', {
        'hostUid': 'u1',
        'status': 'running',
        'startedAt': 1000,
        'players': {
          'u1': {'name': 'Juf', 'tag': '1234', 'online': true, 'joinedAt': 5},
          'u2': {'name': 'Lotte', 'online': false},
          'u3': 'kapot',
        },
        'seeds': {'0': 'u1', '1': 'u2', '2': '_bye', '3': 'u3'},
        'rooms': {'r0m0': 'KAMER'},
        'readyAt': {
          'r0m0': {'u1': 1500},
        },
        'results': {
          'r0m0': {'winner': 'u2', 'at': 2000, 'walkover': true},
          'r0m1': {'at': 3},
        },
      })!;
      expect(d.status, TournamentStatus.running);
      expect(d.players.keys, ['u1', 'u2']);
      expect(d.players['u2']!.online, isFalse);
      expect(d.players['u1']!.tag, '1234');
      expect(d.seeds, ['u1', 'u2', byeSeat, 'u3']);
      expect(d.rooms['r0m0'], 'KAMER');
      expect(d.readyAt['r0m0'], {'u1': 1500});
      expect(d.results.keys, ['r0m0']);
      expect(d.results['r0m0']!.walkover, isTrue);
      expect(d.startedAt, 1000);
    });

    test('seeds as a list, unknown status, missing host', () {
      final d = FirebaseTournamentBackend.parseForTest('ABCDE', {
        'hostUid': 'u1',
        'status': 'iets',
        'seeds': ['u1', null],
      })!;
      expect(d.status, TournamentStatus.lobby);
      expect(d.seeds, ['u1', byeSeat]);
      expect(FirebaseTournamentBackend.parseForTest('X', {'a': 1}), isNull);
      expect(FirebaseTournamentBackend.parseForTest('X', null), isNull);
    });
  });
}
