import 'dart:async';

import 'account_service.dart';

/// In-memory account for tests and the mock backend. "Google" always
/// links straight away.
class MockAccountService implements AccountService {
  AccountInfo _current = const AccountInfo(uid: 'mock-me');
  final _ctl = StreamController<AccountInfo>.broadcast();

  @override
  AccountInfo get current => _current;

  @override
  Stream<AccountInfo> get changes => _ctl.stream;

  @override
  Future<GoogleSignInOutcome> signInWithGoogle() async {
    _set(
      AccountInfo(
        uid: _current.uid,
        isGuest: false,
        email: 'speler@example.com',
        name: 'Test Speler',
      ),
    );
    return GoogleSignInOutcome.linked;
  }

  @override
  Future<void> signOut() async => _set(const AccountInfo(uid: 'mock-me'));

  void _set(AccountInfo info) {
    _current = info;
    _ctl.add(info);
  }
}
