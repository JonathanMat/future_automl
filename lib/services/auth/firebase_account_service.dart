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
  FirebaseAccountService({
    FirebaseAuth? auth,
    GoogleSignIn? google,
    this.discardGuestData,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _google = google ?? GoogleSignIn.instance;

  final FirebaseAuth _auth;
  final GoogleSignIn _google;

  /// Deletes the guest's server data. Called while still signed in as the
  /// guest, right before switching to an existing Google account.
  final Future<void> Function()? discardGuestData;
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

  /// Shows the Google dialog. Null when the player closed it.
  Future<AuthCredential?> _googleCredential() async {
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
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      debugPrint('Google sign-in: $e');
      throw AccountException(
        'Inloggen met Google mislukt. Is Google-login ingesteld in Firebase?',
      );
    }

    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw AccountException('Google gaf geen login-token terug.');
    }
    return GoogleAuthProvider.credential(idToken: idToken);
  }

  @override
  Future<GoogleSignInOutcome> signInWithGoogle() async {
    final credential = await _googleCredential();
    if (credential == null) return GoogleSignInOutcome.canceled;

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
          // Clean up the guest we are leaving, so it doesn't linger in the
          // database and on the scorebord.
          try {
            await discardGuestData?.call();
            await user.delete();
          } catch (e) {
            debugPrint('discard guest: $e');
          }
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
  Future<bool> deleteAccount({
    required Future<void> Function() deleteData,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      await deleteData();
      return true;
    }
    final google = !current.isGuest;
    try {
      // Deleting a login needs a recent sign-in. Confirm before anything is
      // deleted, so canceling leaves the account as it was.
      if (google) {
        final credential = await _googleCredential();
        if (credential == null) return false;
        await user.reauthenticateWithCredential(credential);
      }
      await deleteData();
      await user.delete();
    } on FirebaseAuthException catch (e) {
      debugPrint('delete account: ${e.code} ${e.message}');
      throw AccountException(
        e.code == 'requires-recent-login'
            ? 'Log opnieuw in en probeer het nog eens.'
            : 'Account verwijderen mislukt (${e.code}).',
      );
    }
    if (google) {
      try {
        await _google.signOut();
      } catch (e) {
        debugPrint('Google signOut: $e');
      }
    }
    // Normally already signed out by delete(); makes sure no one is left.
    if (_auth.currentUser != null) await _auth.signOut();
    return true;
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
