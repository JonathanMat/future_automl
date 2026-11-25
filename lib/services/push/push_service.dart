import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';

import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Registers this phone for push notifications (challenges).
///
/// The token is stored at `fcmTokens/{uid}/{token}`. After writing an
/// invite the app asks the push worker (`cloudflare/push-worker`) to send
/// the notification; the app never holds the FCM server key.
abstract class PushService {
  /// Asks for permission (Android 13+, iOS) and stores the token for [uid].
  Future<void> register(String uid);

  /// Removes this phone's token from [uid], e.g. before signing out.
  Future<void> unregister(String uid);

  /// Asks the push worker to notify [toUid] about the invite just written.
  Future<void> notifyChallenge(String toUid);

  /// Emits when the player opened the app by tapping a challenge
  /// notification (also when that started the app).
  Stream<void> get openedChallenge;
}

class NoPushService implements PushService {
  const NoPushService();

  @override
  Future<void> register(String uid) async {}

  @override
  Future<void> unregister(String uid) async {}

  @override
  Future<void> notifyChallenge(String toUid) async {}

  @override
  Stream<void> get openedChallenge => const Stream.empty();
}

class FirebasePushService implements PushService {
  FirebasePushService({
    FirebaseMessaging? messaging,
    FirebaseDatabase? db,
    FirebaseAuth? auth,
    this.workerUrl = const String.fromEnvironment('PUSH_WORKER_URL'),
  }) : _messaging = messaging ?? FirebaseMessaging.instance,
       _db = db ?? FirebaseDatabase.instance,
       _auth = auth ?? FirebaseAuth.instance;

  final FirebaseMessaging _messaging;
  final FirebaseDatabase _db;
  final FirebaseAuth _auth;

  /// e.g. `https://spell-duel-push.<you>.workers.dev` (from config.json).
  /// Empty: no push, the in-app banner still works.
  final String workerUrl;
  StreamSubscription<String>? _refresh;
  String? _token;

  @override
  Stream<void> get openedChallenge async* {
    bool isChallenge(RemoteMessage m) => m.data['type'] == 'challenge';
    try {
      // The app was closed and this tap started it.
      final initial = await _messaging.getInitialMessage();
      if (initial != null && isChallenge(initial)) yield null;
    } catch (e) {
      debugPrint('push initial message: $e');
    }
    yield* FirebaseMessaging.onMessageOpenedApp.where(isChallenge);
  }

  @override
  Future<void> register(String uid) async {
    try {
      final settings = await _messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;
      // getToken/onTokenRefresh are deprecated in favour of register(),
      // which returns an installation id instead of a token. The Admin
      // SDK in functions/index.js sends to tokens, so keep these for now.
      // ignore: deprecated_member_use
      final token = _token = await _messaging.getToken();
      if (token != null) await _save(uid, token);
      await _refresh?.cancel();
      // ignore: deprecated_member_use
      _refresh = _messaging.onTokenRefresh.listen((t) async {
        final old = _token;
        _token = t;
        if (old != null) await _db.ref('fcmTokens/$uid/$old').remove();
        await _save(uid, t);
      });
    } catch (e) {
      // No Google Play services, no APNs key… the app works without push.
      debugPrint('push register: $e');
    }
  }

  Future<void> _save(String uid, String token) =>
      _db.ref('fcmTokens/$uid/$token').set(true);

  @override
  Future<void> unregister(String uid) async {
    await _refresh?.cancel();
    _refresh = null;
    final token = _token;
    if (token == null) return;
    try {
      await _db.ref('fcmTokens/$uid/$token').remove();
    } catch (e) {
      debugPrint('push unregister: $e');
    }
  }

  @override
  Future<void> notifyChallenge(String toUid) async {
    if (workerUrl.isEmpty) return;
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final idToken = await _auth.currentUser?.getIdToken();
      if (idToken == null) return;
      final base = workerUrl.endsWith('/')
          ? workerUrl.substring(0, workerUrl.length - 1)
          : workerUrl;
      final req = await client.postUrl(Uri.parse('$base/challenge'));
      req.headers
        ..set(HttpHeaders.authorizationHeader, 'Bearer $idToken')
        ..contentType = ContentType.json;
      req.write(jsonEncode({'toUid': toUid}));
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      if (res.statusCode != 200) {
        debugPrint('push worker ${res.statusCode}: $body');
      }
    } catch (e) {
      debugPrint('push worker: $e');
    } finally {
      client.close();
    }
  }
}
