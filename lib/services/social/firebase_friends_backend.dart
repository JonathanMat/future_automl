import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../../models/player_profile.dart';
import '../../utils/db_values.dart';
import '../../utils/player_tag.dart';
import '../../validators/friend_code_validator.dart';
import 'friends_backend.dart';

/// Friends in the Firebase Realtime Database.
///
/// Layout (see `database.rules.json`):
/// ```
/// users/{uid}: {name, friendCode}
/// friendCodes/{code}: uid
/// friendRequests/{toUid}/{fromUid}: {name, at}
/// friends/{uid}/{friendUid}: <server ms since friends>
/// invites/{toUid}/{fromUid}: {name, roomCode, at}   (challenges)
/// leaderboard/{uid}: {name, wins, losses}   (written by the game backend)
/// ```
/// A friendship is stored on both sides. The rules only allow writing
/// `friends/` entries while there is a matching request, so nobody can add
/// themselves to your list.
class FirebaseFriendsBackend implements FriendsBackend {
  FirebaseFriendsBackend({FirebaseAuth? auth, FirebaseDatabase? database})
    : _auth = auth ?? FirebaseAuth.instance,
      _db = database ?? FirebaseDatabase.instance;

  final FirebaseAuth _auth;
  final FirebaseDatabase _db;

  String? _uid;
  String _name = 'Speler';
  String? _tag;

  /// Server time minus this phone's time, in ms. Invite times are server
  /// times; with this they compare correctly to a phone clock that is off.
  int _serverOffsetMs = 0;
  StreamSubscription<DatabaseEvent>? _offsetSub;

  String get _me {
    final uid = _uid;
    if (uid == null) throw FriendsException('Nog niet ingelogd.');
    return uid;
  }

  @override
  Future<FriendIdentity> signIn({
    required String name,
    bool keepServerName = false,
  }) async {
    // Wait for the saved login to be restored, so a returning player
    // doesn't get a fresh anonymous account.
    final restored = await _auth.authStateChanges().first;
    final user = restored ?? (await _auth.signInAnonymously()).user;
    if (user == null) throw FriendsException('Inloggen mislukt.');
    final uid = _uid = user.uid;
    _name = _clean(name);
    _offsetSub ??= _db
        .ref('.info/serverTimeOffset')
        .onValue
        .listen(
          (e) => _serverOffsetMs = _asInt(e.snapshot.value),
          onError: (Object e) => debugPrint('serverTimeOffset: $e'),
        );

    final me = _db.ref('users/$uid');
    final existing = _asMap((await me.get()).value) ?? const {};
    final random = Random.secure();

    final tag = PlayerTag.parse(existing['tag']) ?? PlayerTag.generate(random);
    final serverName = DbValues.text(existing['name']);
    if (keepServerName && serverName != null) _name = serverName;
    await me.update({'name': _name, 'tag': tag});
    _tag = tag;
    // Older leaderboard entries don't have the tag yet.
    final board = _db.ref('leaderboard/$uid');
    if ((await board.child('wins').get()).exists) {
      await board.child('tag').set(tag);
    }

    final code = existing['friendCode'];
    if (code is String && code.isNotEmpty) {
      return FriendIdentity(uid: uid, friendCode: code, tag: tag, name: _name);
    }
    for (var attempt = 0; attempt < 10; attempt++) {
      final code = FriendCodeValidator.generate(random);
      try {
        // Fails with permission-denied when the code is already taken.
        await _db.ref('friendCodes/$code').set(uid);
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied') continue;
        rethrow;
      }
      await me.child('friendCode').set(code);
      return FriendIdentity(uid: uid, friendCode: code, tag: tag, name: _name);
    }
    throw FriendsException('Kon geen vriendcode maken.');
  }

  @override
  Future<void> updateName(String name) async {
    _name = _clean(name);
    if (_uid == null) return;
    await _db.ref('users/$_me/name').set(_name);
  }

  @override
  Stream<List<Friend>> friends() {
    late final StreamController<List<Friend>> ctl;
    StreamSubscription<DatabaseEvent>? listSub;
    final perFriend = <String, List<StreamSubscription<DatabaseEvent>>>{};
    final profiles = <String, Map<Object?, Object?>>{};
    final stats = <String, Map<Object?, Object?>>{};
    var uids = <String>[];
    var loaded = false;

    void emit() {
      if (!loaded || ctl.isClosed) return;
      final List<Friend> list;
      try {
        list = [
          for (final uid in uids)
            Friend(
              uid: uid,
              name:
                  DbValues.text(profiles[uid]?['name']) ??
                  DbValues.text(stats[uid]?['name']) ??
                  'Speler',
              tag: PlayerTag.parse(profiles[uid]?['tag']),
              wins: _asInt(stats[uid]?['wins']),
              losses: _asInt(stats[uid]?['losses']),
            ),
        ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      } catch (e) {
        debugPrint('friends emit: $e');
        return;
      }
      ctl.add(list);
    }

    void watch(String uid) {
      perFriend[uid] = [
        _db.ref('users/$uid').onValue.listen((e) {
          final v = _asMap(e.snapshot.value);
          if (v != null) profiles[uid] = v;
          emit();
        }, onError: (Object e) => debugPrint('friend profile $uid: $e')),
        _db.ref('leaderboard/$uid').onValue.listen((e) {
          final v = e.snapshot.value;
          if (v is Map) {
            stats[uid] = v.cast<Object?, Object?>();
          } else {
            stats.remove(uid);
          }
          emit();
        }, onError: (Object e) => debugPrint('friend stats $uid: $e')),
      ];
    }

    Future<void> unwatch(String uid) async {
      for (final s in perFriend.remove(uid) ?? const []) {
        await s.cancel();
      }
      profiles.remove(uid);
      stats.remove(uid);
    }

    ctl = StreamController<List<Friend>>(
      onListen: () {
        listSub = _db.ref('friends/$_me').onValue.listen((event) async {
          final next = [
            for (final c in event.snapshot.children)
              if (c.key != null) c.key!,
          ];
          for (final gone in uids.where((u) => !next.contains(u)).toList()) {
            await unwatch(gone);
          }
          for (final added in next.where((u) => !perFriend.containsKey(u))) {
            watch(added);
          }
          uids = next;
          loaded = true;
          emit();
        }, onError: ctl.addError);
      },
      onCancel: () async {
        await listSub?.cancel();
        for (final uid in perFriend.keys.toList()) {
          await unwatch(uid);
        }
      },
    );
    return ctl.stream;
  }

  @override
  Stream<List<FriendRequest>> requests() =>
      _db.ref('friendRequests/$_me').onValue.map((event) {
        return [
          for (final c in event.snapshot.children)
            if (c.key != null)
              FriendRequest(
                fromUid: c.key!,
                name: DbValues.text(_asMap(c.value)?['name']) ?? 'Speler',
                tag: PlayerTag.parse(_asMap(c.value)?['tag']),
              ),
        ];
      });

  @override
  Stream<LeaderboardEntry?> myStats() =>
      _db.ref('leaderboard/$_me').onValue.map((event) {
        final v = _asMap(event.snapshot.value);
        if (v == null) return null;
        return LeaderboardEntry(
          uid: _me,
          name: DbValues.text(v['name']) ?? _name,
          tag: PlayerTag.parse(v['tag']) ?? _tag,
          wins: _asInt(v['wins']),
          losses: _asInt(v['losses']),
        );
      });

  @override
  Future<AddFriendResult> addByCode(String code) async {
    final normalized = FriendCodeValidator.normalize(code);
    final uid = (await _db.ref('friendCodes/$normalized').get()).value;
    if (uid is! String) {
      throw FriendsException('Geen speler met code $normalized.');
    }
    return addByUid(uid);
  }

  @override
  Future<AddFriendResult> addByUid(String uid) async {
    final me = _me;
    if (uid == me) throw FriendsException('Dat ben je zelf.');
    if ((await _db.ref('friends/$me/$uid').get()).exists) {
      return AddFriendResult.alreadyFriends;
    }
    // They already asked you: accept instead of asking back.
    final incoming = await _db.ref('friendRequests/$me/$uid').get();
    if (incoming.exists) {
      await _accept(uid);
      return AddFriendResult.accepted;
    }
    await _db.ref('friendRequests/$uid/$me').set({
      'name': _name,
      'tag': ?_tag,
      'at': ServerValue.timestamp,
    });
    return AddFriendResult.requested;
  }

  @override
  Future<void> accept(FriendRequest request) => _accept(request.fromUid);

  Future<void> _accept(String uid) => _db.ref().update({
    'friends/$_me/$uid': ServerValue.timestamp,
    'friends/$uid/$_me': ServerValue.timestamp,
    'friendRequests/$_me/$uid': null,
  });

  @override
  Future<void> decline(FriendRequest request) =>
      _db.ref('friendRequests/$_me/${request.fromUid}').remove();

  @override
  Future<void> remove(String uid) =>
      _db.ref().update({'friends/$_me/$uid': null, 'friends/$uid/$_me': null});

  @override
  Stream<List<ChallengeInvite>> invites() =>
      _db.ref('invites/$_me').onValue.map((event) {
        final list = <ChallengeInvite>[];
        for (final c in event.snapshot.children) {
          final v = _asMap(c.value);
          if (c.key == null || v == null) continue;
          list.add(
            ChallengeInvite(
              fromUid: c.key!,
              name: DbValues.text(v['name']) ?? 'Speler',
              tag: PlayerTag.parse(v['tag']),
              roomCode: DbValues.text(v['roomCode']) ?? '',
              sentAt: DateTime.fromMillisecondsSinceEpoch(
                _asInt(v['at']) - _serverOffsetMs,
              ),
            ),
          );
        }
        return list;
      });

  @override
  Future<void> sendInvite(String toUid, String roomCode) =>
      _db.ref('invites/$toUid/$_me').set({
        'name': _name,
        'tag': ?_tag,
        'roomCode': roomCode,
        'at': ServerValue.timestamp,
      });

  @override
  Future<void> refreshInvite(String toUid) async {
    final ref = _db.ref('invites/$toUid/$_me');
    // Only while it is still there: a declined invite stays declined.
    if (!(await ref.child('roomCode').get()).exists) return;
    await ref.child('at').set(ServerValue.timestamp);
  }

  @override
  Future<void> cancelInvite(String toUid) =>
      _db.ref('invites/$toUid/$_me').remove();

  @override
  Future<void> dismissInvite(String fromUid) =>
      _db.ref('invites/$_me/$fromUid').remove();

  @override
  Future<PublicProfile?> loadPlayer(String uid) async {
    final user = _asMap((await _db.ref('users/$uid').get()).value);
    if (user == null) return null;
    final progress = _intsMap(_asMap(user['progress'])) ?? const {};
    return PublicProfile(
      uid: uid,
      tag: PlayerTag.parse(user['tag']),
      profile: PlayerProfile.fromJson({
        ...progress,
        'name': DbValues.text(user['name']) ?? 'Speler',
      }),
    );
  }

  @override
  Future<Map<String, Object?>?> loadProgress() async =>
      _intsMap(_asMap((await _db.ref('users/$_me/progress').get()).value));

  /// [v] with string keys and every number as an int (the database hands
  /// numbers back as num; the profile model wants ints).
  static Map<String, Object?>? _intsMap(Map<Object?, Object?>? v) {
    if (v == null) return null;
    Object? clean(Object? x) => switch (x) {
      final num n => n.toInt(),
      final Map m => {for (final e in m.entries) '${e.key}': clean(e.value)},
      _ => x,
    };
    return {for (final e in v.entries) '${e.key}': clean(e.value)};
  }

  @override
  Future<void> saveProgress(Map<String, Object?> progress) =>
      _db.ref('users/$_me/progress').set(progress);

  @override
  Future<List<Map<String, Object?>>> loadRecent() async {
    final v = (await _db.ref('users/$_me/recent').get()).value;
    // Stored as a list; the database may hand it back as a list or as a
    // map with "0", "1", … keys (when one is missing).
    final items = switch (v) {
      final List l => l,
      final Map m => [
        for (final k
            in m.keys.toList()..sort(
              (a, b) => (int.tryParse('$a') ?? 0) - (int.tryParse('$b') ?? 0),
            ))
          m[k],
      ],
      _ => const [],
    };
    return [
      for (final item in items)
        if (_asMap(item) case final m?)
          {
            for (final e in m.entries)
              '${e.key}': e.value is num ? (e.value as num).toInt() : e.value,
          },
    ];
  }

  @override
  Future<void> saveRecent(List<Map<String, Object?>> recent) {
    final ref = _db.ref('users/$_me/recent');
    return recent.isEmpty ? ref.remove() : ref.set(recent);
  }

  @override
  Future<void> deleteMyData() async {
    final me = _uid;
    if (me == null) return;
    // Separate writes: one that fails (e.g. old rules) must not stop the rest.
    Future<void> run(String what, Future<void> Function() f) async {
      try {
        await f();
      } catch (e) {
        debugPrint('deleteMyData $what: $e');
      }
    }

    Future<List<String>> keys(String path) async => (await _db.ref(path).get())
        .children
        .map((c) => c.key)
        .whereType<String>()
        .toList();

    for (final uid in await keys('friends/$me')) {
      await run('invite', () => cancelInvite(uid));
      await run('friend', () => remove(uid));
    }
    // Requests you sent can't be listed; recent opponents are the players
    // you could have sent one to.
    for (final r in await loadRecent()) {
      if (r['uid'] case final String uid when uid != me) {
        await run(
          'sent request',
          () => _db.ref('friendRequests/$uid/$me').remove(),
        );
      }
    }
    // One by one: the rules only allow removing single requests/invites.
    for (final uid in await keys('friendRequests/$me')) {
      await run('request', () => _db.ref('friendRequests/$me/$uid').remove());
    }
    for (final uid in await keys('invites/$me')) {
      await run('invite', () => dismissInvite(uid));
    }
    final code = (await _db.ref('users/$me/friendCode').get()).value;
    if (code is String) {
      await run('code', () => _db.ref('friendCodes/$code').remove());
    }
    await run('board', () => _db.ref('leaderboard/$me').remove());
    await run('tokens', () => _db.ref('fcmTokens/$me').remove());
    await run('user', () => _db.ref('users/$me').remove());
  }

  @override
  Future<void> dispose() async {
    await _offsetSub?.cancel();
  }

  static String _clean(String name) =>
      name.trim().isEmpty ? 'Speler' : name.trim();

  static Map<Object?, Object?>? _asMap(Object? value) =>
      value is Map ? value.cast<Object?, Object?>() : null;

  static int _asInt(Object? value) => value is num ? value.toInt() : 0;
}
