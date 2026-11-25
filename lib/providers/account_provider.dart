import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/auth/account_service.dart';

/// Guest or Google account, for the settings screen.
class AccountProvider extends ChangeNotifier {
  AccountProvider(
    this.service, {
    this.onUserChanged,
    this.beforeSignOut,
    this.deleteData,
    this.onDeleted,
  }) {
    _info = service.current;
    _lastUid = _info.uid;
    _sub = service.changes.listen(_onChange);
  }

  final AccountService service;

  /// Called when a different user is signed in (switched account or signed
  /// out), so uid-based data can be reloaded.
  final VoidCallback? onUserChanged;

  /// Runs while the old user is still signed in (e.g. remove push token).
  final Future<void> Function()? beforeSignOut;

  /// Deletes this user's data on the server, while still signed in.
  final Future<void> Function()? deleteData;

  /// After the account is gone: forget everything on this phone.
  final Future<void> Function()? onDeleted;

  late AccountInfo _info;

  /// The last signed-in uid. Signing in to an existing Google account first
  /// deletes the guest, so there is a moment with no user at all: compare
  /// with the last real uid, not with that empty moment.
  String? _lastUid;
  late final StreamSubscription<AccountInfo> _sub;
  bool _busy = false;
  bool _disposed = false;

  AccountInfo get info => _info;
  bool get isGuest => _info.isGuest;
  bool get busy => _busy;

  void _onChange(AccountInfo next) {
    _info = next;
    _checkUser(next.uid);
    _notify();
  }

  void _checkUser(String? uid) {
    if (uid == null) return;
    final changed = _lastUid != null && uid != _lastUid;
    _lastUid = uid;
    if (changed) onUserChanged?.call();
  }

  /// Returns a message for the user, or null when canceled.
  Future<String?> signInWithGoogle() => _run(() async {
    final outcome = await service.signInWithGoogle();
    return switch (outcome) {
      GoogleSignInOutcome.linked =>
        'Ingelogd. Je vrienden en scores zijn nu bewaard.',
      GoogleSignInOutcome.switched =>
        'Ingelogd. Je bestaande Google-account is geladen.',
      GoogleSignInOutcome.canceled => null,
    };
  });

  Future<String?> signOut() => _run(() async {
    await beforeSignOut?.call();
    await service.signOut();
    return 'Uitgelogd. Je speelt nu als gast.';
  });

  /// Deletes the account and all its data, on the server and on this
  /// phone. Returns null when the Google confirmation was canceled.
  Future<String?> deleteAccount() => _run(() async {
    final deleted = await service.deleteAccount(
      deleteData: () async {
        await beforeSignOut?.call();
        await deleteData?.call();
      },
    );
    if (!deleted) return null;
    // The next sign-in is a brand new guest, not a switch of account.
    _lastUid = null;
    await onDeleted?.call();
    return 'Je account is verwijderd.';
  });

  Future<String?> _run(Future<String?> Function() action) async {
    if (_busy) return null;
    _busy = true;
    _notify();
    try {
      return await action();
    } on AccountException catch (e) {
      return e.message;
    } catch (e) {
      debugPrint('account: $e');
      return 'Er ging iets mis. Probeer opnieuw.';
    } finally {
      _busy = false;
      // userChanges() can lag behind a link: read the latest state.
      _info = service.current;
      _checkUser(_info.uid);
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _sub.cancel();
    super.dispose();
  }
}
