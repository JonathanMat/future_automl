/// Who is signed in on this phone.
class AccountInfo {
  const AccountInfo({this.uid, this.isGuest = true, this.email, this.name});

  /// Null before the first sign-in.
  final String? uid;

  /// Anonymous account: only on this install, lost on reinstall.
  final bool isGuest;

  /// Google account details, null for guests.
  final String? email;
  final String? name;
}

enum GoogleSignInOutcome {
  /// The guest account is now linked to Google. Same uid, nothing lost.
  linked,

  /// That Google account already had Spell Duel data: switched to it.
  /// The guest's friends and scores stay behind.
  switched,

  /// The player closed the Google dialog.
  canceled,
}

/// Guest by default; optionally linked to Google so friends and scores
/// survive a reinstall or a new phone.
abstract class AccountService {
  AccountInfo get current;

  /// Emits on every sign-in, link and sign-out.
  Stream<AccountInfo> get changes;

  /// Links the guest account to Google, or switches to an existing one.
  /// Throws [AccountException] when Google sign-in is not set up or fails.
  Future<GoogleSignInOutcome> signInWithGoogle();

  /// Signs out of Google and continues as a new guest.
  Future<void> signOut();
}

class AccountException implements Exception {
  AccountException(this.message);

  final String message;

  @override
  String toString() => 'AccountException: $message';
}
