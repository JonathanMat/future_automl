import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/auth/account_service.dart';

/// Guest or Google account, for the settings screen.
class AccountProvider extends ChangeNotifier {
  AccountProvider(this.service, {this.onUserChanged}) {
    _info = service.current;
    _sub = service.changes.listen(_onChange);
  }

  final AccountService service;

  /// Called when a different user is signed in (switched account or signed
  /// out), so uid-based data can be reloaded.
  final VoidCallback? onUserChanged;

  late AccountInfo _info;
  late final StreamSubscription<AccountInfo> _sub;
  bool _busy = false;
  bool _disposed = false;

  AccountInfo get info => _info;
  bool get isGuest => _info.isGuest;
  bool get busy => _busy;

  void _onChange(AccountInfo next) {
    final changedUser =
        _info.uid != null && next.uid != null && next.uid != _info.uid;
    _info = next;
    if (changedUser) onUserChanged?.call();
    _notify();
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
    await service.signOut();
    return 'Uitgelogd. Je speelt nu als gast.';
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
