import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../../utils/db_values.dart';
import '../../utils/player_tag.dart';
import 'tournament_backend.dart';

/// Tournaments in the Firebase Realtime Database.
///
/// ```
/// tournaments/{code}:                     (5 characters)
///   hostUid, status: lobby|running|finished|cancelled, createdAt, startedAt
///   players/{uid}: {name, tag, joinedAt, online}
///   seeds: [uid | "_bye", …]               the draw, written at the start
///   rooms/{matchId}: roomCode              by the first player of a match
///   readyAt/{matchId}/{uid}: server timestamp of acceptance
///   results/{matchId}: {winner, at, walkover, noShow?}
/// ```
/// The bracket is never stored: every phone computes it from `seeds` and
/// `results` (see `Bracket`). The rules let only players write rooms and
/// results, a result only once (the host may overrule), and nobody join
/// after the start.
class FirebaseTournamentBackend extends TournamentBackend {
  FirebaseTournamentBackend({FirebaseAuth? auth, FirebaseDatabase? database})
    : _auth = auth ?? FirebaseAuth.instance,
      _db = database ?? FirebaseDatabase.instance {
    _offsetSub = _db.ref('.info/serverTimeOffset').onValue.listen((e) {
      _offsetMs = DbValues.integer(e.snapshot.value);
    });
  }

  final FirebaseAuth _auth;
  final FirebaseDatabase _db;
  static const _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  int _offsetMs = 0;
  StreamSubscription<DatabaseEvent>? _offsetSub;
  StreamSubscription<DatabaseEvent>? _presenceSub;
  DatabaseReference? _onlineRef;

  @override
  Duration get serverOffset => Duration(milliseconds: _offsetMs);

  DatabaseReference _ref(String code) => _db.ref('tournaments/$code');

  Future<String> _signedIn() async {
    final restored = await _auth.authStateChanges().first;
    final user = restored ?? (await _auth.signInAnonymously()).user;
    if (user == null) throw TournamentException('Inloggen mislukt.');
    return user.uid;
  }

  Map<String, Object> _player(TournamentMe me) => {
    'name': me.name.trim().isEmpty ? 'Speler' : me.name.trim(),
    'tag': ?me.tag,
    'joinedAt': ServerValue.timestamp,
    'online': true,
  };

  @override
  Future<String> create(TournamentMe me) async {
    final uid = await _signedIn();
    final random = Random.secure();
    for (var attempt = 0; attempt < 10; attempt++) {
      final code = List.generate(
        5,
        (_) => _alphabet[random.nextInt(_alphabet.length)],
      ).join();
      try {
        // Fails with permission-denied when the code is taken.
        await _ref(code).set({
          'hostUid': uid,
          'status': 'lobby',
          'createdAt': ServerValue.timestamp,
          'players': {uid: _player(me)},
        });
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied') continue;
        rethrow;
      }
      _keepOnline(code, uid);
      return code;
    }
    throw TournamentException('Kon geen vrije toernooicode vinden.');
  }

  @override
  Future<void> join(String code, TournamentMe me) async {
    final uid = await _signedIn();
    final snap = await _ref(code).get();
    final data = _parse(code, snap.value);
    if (data == null) throw TournamentException('Toernooi $code bestaat niet.');
    if (!data.players.containsKey(uid)) {
      if (data.status != TournamentStatus.lobby) {
        throw TournamentException('Dit toernooi is al begonnen.');
      }
      if (data.players.length >= maxTournamentPlayers) {
        throw TournamentException(
          'Dit toernooi is vol ($maxTournamentPlayers).',
        );
      }
      try {
        await _ref(code).child('players/$uid').set(_player(me));
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied') {
          throw TournamentException('Dit toernooi is net begonnen.');
        }
        rethrow;
      }
    }
    _keepOnline(code, uid);
  }

  /// Marks you online, and offline as soon as the connection drops (the
  /// server does that, even if the app is killed).
  void _keepOnline(String code, String uid) {
    _presenceSub?.cancel();
    final online = _onlineRef = _ref(code).child('players/$uid/online');
    _presenceSub = _db.ref('.info/connected').onValue.listen((e) async {
      if (e.snapshot.value != true) return;
      try {
        await online.onDisconnect().set(false);
        await online.set(true);
      } catch (err) {
        debugPrint('tournament presence: $err');
      }
    });
  }

  @override
  Stream<TournamentData?> watch(String code) =>
      _ref(code).onValue.map((e) => _parse(code, e.snapshot.value));

  @override
  Future<void> start(String code, List<String> seeds) => _ref(code).update({
    'seeds': seeds,
    'status': 'running',
    'startedAt': ServerValue.timestamp,
  });

  @override
  Future<void> setRoom(String code, String matchId, String roomCode) =>
      _ref(code).child('rooms/$matchId').set(roomCode);

  @override
  Future<void> setMatchReady(
    String code,
    String matchId,
    String uid, {
    required bool ready,
  }) async {
    final ref = _ref(code).child('readyAt/$matchId/$uid');
    if (ready) {
      await ref.onDisconnect().remove();
      await ref.runTransaction((value) {
        return value == null
            ? Transaction.success(ServerValue.timestamp)
            : Transaction.abort();
      }, applyLocally: false);
    } else {
      await ref.remove();
    }
  }

  @override
  Future<bool> reportResult(
    String code,
    String matchId,
    String winner, {
    bool walkover = false,
    bool force = false,
    String? noShow,
  }) async {
    final ref = _ref(code).child('results/$matchId');
    final result = {
      'winner': winner,
      'at': ServerValue.timestamp,
      'walkover': walkover,
      'noShow': ?noShow,
    };
    if (force) {
      await ref.set(result);
      return true;
    }
    try {
      final transaction = await ref.runTransaction((value) {
        return value == null
            ? Transaction.success(result)
            : Transaction.abort();
      }, applyLocally: false);
      return transaction.committed;
    } on FirebaseException catch (e) {
      // The match may have been decided or the opponent may just have accepted.
      if (e.code == 'permission-denied') return false;
      rethrow;
    }
  }

  @override
  Future<void> finish(String code) =>
      _ref(code).child('status').set('finished');

  @override
  Future<void> leave(String code, String uid, {required bool isHost}) async {
    await _presenceSub?.cancel();
    _presenceSub = null;
    try {
      await _onlineRef?.onDisconnect().cancel();
    } catch (_) {}
    _onlineRef = null;
    try {
      final status = (await _ref(code).child('status').get()).value;
      if (status == 'lobby') {
        if (isHost) {
          await _ref(code).child('status').set('cancelled');
        } else {
          await _ref(code).child('players/$uid').remove();
        }
      } else {
        await _ref(code).child('players/$uid/online').set(false);
      }
    } catch (e) {
      debugPrint('leave tournament: $e');
    }
  }

  @override
  Future<void> dispose() async {
    await _offsetSub?.cancel();
    await _presenceSub?.cancel();
  }

  // ---------------------------------------------------------------------------

  static TournamentData? _parse(String code, Object? value) {
    if (value is! Map) return null;
    final hostUid = DbValues.text(value['hostUid']);
    if (hostUid == null) return null;

    final players = <String, TournamentPlayer>{};
    final rawPlayers = value['players'];
    if (rawPlayers is Map) {
      for (final e in rawPlayers.entries) {
        final p = e.value;
        if (p is! Map) continue;
        final uid = '${e.key}';
        players[uid] = TournamentPlayer(
          uid: uid,
          name: DbValues.text(p['name']) ?? 'Speler',
          tag: PlayerTag.parse(p['tag']),
          online: p['online'] != false,
          joinedAt: DbValues.integer(p['joinedAt']),
        );
      }
    }

    // Arrays come back as a List, or as a Map when the keys have gaps.
    final rawSeeds = value['seeds'];
    final seeds = switch (rawSeeds) {
      final List<Object?> l => [for (final s in l) DbValues.text(s) ?? byeSeat],
      final Map<Object?, Object?> m => [
        for (var i = 0; i < m.length; i++)
          DbValues.text(m['$i'] ?? m[i]) ?? byeSeat,
      ],
      _ => const <String>[],
    };

    final rooms = <String, String>{};
    final rawRooms = value['rooms'];
    if (rawRooms is Map) {
      for (final e in rawRooms.entries) {
        final room = DbValues.text(e.value);
        if (room != null) rooms['${e.key}'] = room;
      }
    }

    final results = <String, MatchResult>{};
    final rawResults = value['results'];
    if (rawResults is Map) {
      for (final e in rawResults.entries) {
        final r = e.value;
        if (r is! Map) continue;
        final winner = DbValues.text(r['winner']);
        if (winner == null) continue;
        results['${e.key}'] = MatchResult(
          winner: winner,
          at: DbValues.integer(r['at']),
          walkover: r['walkover'] == true,
        );
      }
    }

    final readyAt = <String, Map<String, int>>{};
    final rawReadyAt = value['readyAt'];
    if (rawReadyAt is Map) {
      for (final e in rawReadyAt.entries) {
        final times = e.value;
        if (times is! Map) continue;
        readyAt['${e.key}'] = {
          for (final time in times.entries)
            if (time.value is num) '${time.key}': (time.value as num).toInt(),
        };
      }
    }

    final status = switch (value['status']) {
      'running' => TournamentStatus.running,
      'finished' => TournamentStatus.finished,
      'cancelled' => TournamentStatus.cancelled,
      _ => TournamentStatus.lobby,
    };
    final started = value['startedAt'];
    return TournamentData(
      code: code,
      hostUid: hostUid,
      status: status,
      players: players,
      seeds: seeds,
      rooms: rooms,
      readyAt: readyAt,
      results: results,
      startedAt: started is num ? started.toInt() : null,
    );
  }

  /// For tests: parse a database value.
  @visibleForTesting
  static TournamentData? parseForTest(String code, Object? value) =>
      _parse(code, value);
}
