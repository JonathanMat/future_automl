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
  /// The guest account (and its data) is deleted.
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

  /// Deletes the login itself. [deleteData] runs first, while still signed
  /// in, to remove everything stored for this user on the server.
  ///
  /// A Google account is asked to confirm with Google first (deleting
  /// needs a recent login); returns false when that is canceled, and then
  /// nothing is deleted. Afterwards no one is signed in.
  Future<bool> deleteAccount({required Future<void> Function() deleteData});
}

class AccountException implements Exception {
  AccountException(this.message);

  final String message;

  @override
  String toString() => 'AccountException: $message';
}
