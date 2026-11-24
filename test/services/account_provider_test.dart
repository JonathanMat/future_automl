import 'package:flutter_test/flutter_test.dart';
import 'package:spell_duel/providers/account_provider.dart';
import 'package:spell_duel/services/auth/account_service.dart';
import 'package:spell_duel/services/auth/mock_account_service.dart';

/// Google account that already has data: signing in switches the uid.
class _SwitchingAccount extends MockAccountService {
  @override
  Future<GoogleSignInOutcome> signInWithGoogle() async {
    await super.signInWithGoogle();
    return GoogleSignInOutcome.switched;
  }
}

class _FailingAccount extends MockAccountService {
  @override
  Future<GoogleSignInOutcome> signInWithGoogle() =>
      throw AccountException('Niet ingesteld.');
}

void main() {
  test('linking keeps the user, signing out goes back to guest', () async {
    var changes = 0;
    final account = AccountProvider(
      MockAccountService(),
      onUserChanged: () => changes++,
    );
    expect(account.isGuest, isTrue);

    final msg = await account.signInWithGoogle();
    await pumpEventQueue();
    expect(msg, contains('bewaard'));
    expect(account.isGuest, isFalse);
    expect(account.info.email, 'speler@example.com');
    expect(changes, 0, reason: 'same uid after linking');

    await account.signOut();
    await pumpEventQueue();
    expect(account.isGuest, isTrue);
    account.dispose();
  });

  test('errors become a message', () async {
    final account = AccountProvider(_FailingAccount());
    expect(await account.signInWithGoogle(), 'Niet ingesteld.');
    expect(account.busy, isFalse);
    expect(account.isGuest, isTrue);
    account.dispose();
  });

  test('switched outcome has its own message', () async {
    final account = AccountProvider(_SwitchingAccount());
    expect(await account.signInWithGoogle(), contains('bestaande'));
    account.dispose();
  });
}
