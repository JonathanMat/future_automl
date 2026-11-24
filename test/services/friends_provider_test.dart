import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spell_duel/providers/friends_provider.dart';
import 'package:spell_duel/providers/profile_provider.dart';
import 'package:spell_duel/services/social/friends_backend.dart';
import 'package:spell_duel/services/social/mock_friends_backend.dart';
import 'package:spell_duel/services/storage/local_storage_service.dart';
import 'package:spell_duel/validators/friend_code_validator.dart';

Future<(FriendsProvider, ProfileProvider)> _setup({
  String name = 'Maarten',
  List<FriendRequest> requests = const [],
}) async {
  SharedPreferences.setMockInitialValues({});
  final profile = ProfileProvider(LocalStorageService());
  await profile.load();
  if (name.isNotEmpty) await profile.setName(name);
  final friends = FriendsProvider(MockFriendsBackend(seedRequests: requests))
    ..attach(profile);
  await pumpEventQueue();
  return (friends, profile);
}

void main() {
  group('FriendCodeValidator', () {
    test('normalizes and validates', () {
      expect(FriendCodeValidator.normalize(' ab-c 123 '), 'ABC123');
      expect(FriendCodeValidator.validate('abc123'), isNull);
      expect(FriendCodeValidator.validate(''), isNotNull);
      expect(FriendCodeValidator.validate('ABC'), isNotNull);
      expect(FriendCodeValidator.validate('ABC12!'), isNotNull);
    });

    test('generated codes are valid and avoid look-alike characters', () {
      final r = Random(1);
      for (var i = 0; i < 50; i++) {
        final code = FriendCodeValidator.generate(r);
        expect(FriendCodeValidator.validate(code), isNull);
        expect(code, isNot(matches(RegExp('[IO01]'))));
      }
    });
  });

  group('FriendsProvider', () {
    test('signs in once the profile has a name', () async {
      final (friends, profile) = await _setup(name: '');
      expect(friends.isReady, isFalse);
      await profile.setName('Lotte');
      await pumpEventQueue();
      expect(friends.isReady, isTrue);
      expect(friends.friendCode, MockFriendsBackend.myCode);
    });

    test('add by code, then remove', () async {
      final (friends, _) = await _setup();
      final r = await friends.addByCode('abc234');
      await pumpEventQueue();
      expect(r.ok, isTrue);
      expect(friends.friends.single.name, 'Vriend ABC234');

      final again = await friends.addByCode('ABC234');
      expect(again.message, 'Jullie zijn al vrienden.');

      await friends.remove(friends.friends.single);
      await pumpEventQueue();
      expect(friends.friends, isEmpty);
    });

    test('own code is refused', () async {
      final (friends, _) = await _setup();
      final r = await friends.addByCode(MockFriendsBackend.myCode);
      expect(r.ok, isFalse);
      expect(r.message, 'Dat ben je zelf.');
    });

    test('accept and decline requests', () async {
      final (friends, _) = await _setup(
        requests: const [
          FriendRequest(fromUid: 'u1', name: 'Lotte'),
          FriendRequest(fromUid: 'u2', name: 'Jonas'),
        ],
      );
      expect(friends.requests, hasLength(2));

      await friends.accept(friends.requests.first);
      await friends.decline(friends.requests.last);
      await pumpEventQueue();
      expect(friends.requests, isEmpty);
      expect(friends.friends.map((f) => f.name), ['Lotte']);
    });

    test('board has you and your friends, most wins first', () async {
      final (friends, _) = await _setup();
      expect(friends.board.single.name, 'Maarten');
      await friends.addByUid('mock-bot', 'Bot');
      await pumpEventQueue();
      expect(friends.board.map((e) => e.name), containsAll(['Maarten', 'Bot']));
    });
  });
}
