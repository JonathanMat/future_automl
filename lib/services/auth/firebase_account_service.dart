import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'account_service.dart';

/// Firebase Auth: anonymous by default, Google linked on request.
///
/// Linking keeps the uid, so rooms, the leaderboard and friends (all keyed
/// by uid) carry over. Needs the Google provider enabled in the Firebase
/// console and the app's SHA-1 added (see docs/BACKEND.md).
class FirebaseAccountService implements AccountService {
  FirebaseAccountService({FirebaseAuth? auth, GoogleSignIn? google})
    : _auth = auth ?? FirebaseAuth.instance,
      _google = google ?? GoogleSignIn.instance;

  final FirebaseAuth _auth;
  final GoogleSignIn _google;
  Future<void>? _googleInit;

  /// Web client id from the Firebase console. Only needed when
  /// google-services.json has no web OAuth client.
  static const _serverClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );

  @override
  AccountInfo get current => _info(_auth.currentUser);

  @override
  Stream<AccountInfo> get changes => _auth.userChanges().map(_info);

  AccountInfo _info(User? user) {
    if (user == null) return const AccountInfo();
    final google = user.providerData
        .where((p) => p.providerId == GoogleAuthProvider.PROVIDER_ID)
        .firstOrNull;
    return AccountInfo(
      uid: user.uid,
      isGuest: user.isAnonymous && google == null,
      email: google?.email ?? user.email,
      name: google?.displayName ?? user.displayName,
    );
  }

  @override
  Future<GoogleSignInOutcome> signInWithGoogle() async {
    await (_googleInit ??= _google.initialize(
      serverClientId: _serverClientId.isEmpty ? null : _serverClientId,
    ));
    if (!_google.supportsAuthenticate()) {
      throw AccountException('Google-login werkt niet op dit toestel.');
    }

    final GoogleSignInAccount account;
    try {
      account = await _google.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return GoogleSignInOutcome.canceled;
      }
      debugPrint('Google sign-in: $e');
      throw AccountException(
        'Inloggen met Google mislukt. Is Google-login ingesteld in Firebase?',
      );
    }

    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw AccountException('Google gaf geen login-token terug.');
    }
    final credential = GoogleAuthProvider.credential(idToken: idToken);

    try {
      final user = _auth.currentUser;
      if (user != null && user.isAnonymous) {
        try {
          await user.linkWithCredential(credential);
          await user.reload();
          return GoogleSignInOutcome.linked;
        } on FirebaseAuthException catch (e) {
          // This Google account already has its own Spell Duel data.
          if (e.code != 'credential-already-in-use') rethrow;
          await _auth.signInWithCredential(e.credential ?? credential);
          return GoogleSignInOutcome.switched;
        }
      }
      await _auth.signInWithCredential(credential);
      return GoogleSignInOutcome.switched;
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase Google sign-in: ${e.code} ${e.message}');
      throw AccountException('Inloggen mislukt (${e.code}).');
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _google.signOut();
    } catch (e) {
      debugPrint('Google signOut: $e');
    }
    await _auth.signOut();
    await _auth.signInAnonymously();
  }
}
