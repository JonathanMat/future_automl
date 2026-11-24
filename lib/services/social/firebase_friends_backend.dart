import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

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

  String get _me {
    final uid = _uid;
    if (uid == null) throw FriendsException('Nog niet ingelogd.');
    return uid;
  }

  @override
  Future<FriendIdentity> signIn({required String name}) async {
    // Wait for the saved login to be restored, so a returning player
    // doesn't get a fresh anonymous account.
    final restored = await _auth.authStateChanges().first;
    final user = restored ?? (await _auth.signInAnonymously()).user;
    if (user == null) throw FriendsException('Inloggen mislukt.');
    final uid = _uid = user.uid;
    _name = _clean(name);

    final me = _db.ref('users/$uid');
    final existing = (await me.child('friendCode').get()).value;
    if (existing is String && existing.isNotEmpty) {
      await me.child('name').set(_name);
      return FriendIdentity(uid: uid, friendCode: existing);
    }

    final random = Random.secure();
    for (var attempt = 0; attempt < 10; attempt++) {
      final code = FriendCodeValidator.generate(random);
      try {
        // Fails with permission-denied when the code is already taken.
        await _db.ref('friendCodes/$code').set(uid);
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied') continue;
        rethrow;
      }
      await me.set({'name': _name, 'friendCode': code});
      return FriendIdentity(uid: uid, friendCode: code);
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
    final names = <String, String>{};
    final stats = <String, Map<Object?, Object?>>{};
    var uids = <String>[];
    var loaded = false;

    void emit() {
      if (!loaded || ctl.isClosed) return;
      final list = [
        for (final uid in uids)
          Friend(
            uid: uid,
            name: names[uid] ?? stats[uid]?['name'] as String? ?? 'Speler',
            wins: _asInt(stats[uid]?['wins']),
            losses: _asInt(stats[uid]?['losses']),
          ),
      ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      ctl.add(list);
    }

    void watch(String uid) {
      perFriend[uid] = [
        _db.ref('users/$uid/name').onValue.listen((e) {
          final v = e.snapshot.value;
          if (v is String) names[uid] = v;
          emit();
        }, onError: (Object e) => debugPrint('friend name $uid: $e')),
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
      names.remove(uid);
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
                name: _asMap(c.value)?['name'] as String? ?? 'Speler',
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
          name: v['name'] as String? ?? _name,
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
  Future<void> dispose() async {}

  static String _clean(String name) =>
      name.trim().isEmpty ? 'Speler' : name.trim();

  static Map<Object?, Object?>? _asMap(Object? value) =>
      value is Map ? value.cast<Object?, Object?>() : null;

  static int _asInt(Object? value) => value is num ? value.toInt() : 0;
}
