import '../../models/game_state.dart';

export '../../models/game_state.dart' show LeaderboardEntry;

/// A confirmed friend (both sides accepted), with their overall record.
class Friend {
  const Friend({
    required this.uid,
    required this.name,
    this.tag,
    this.wins = 0,
    this.losses = 0,
  });

  final String uid;
  final String name;
  final String? tag;

  /// Overall wins and losses on the leaderboard (not only against you).
  final int wins;
  final int losses;

  LeaderboardEntry toEntry() => LeaderboardEntry(
    uid: uid,
    name: name,
    tag: tag,
    wins: wins,
    losses: losses,
  );
}

/// Someone who wants to be your friend.
class FriendRequest {
  const FriendRequest({required this.fromUid, required this.name, this.tag});

  final String fromUid;
  final String name;
  final String? tag;
}

/// A friend challenges you: join their room to play.
class ChallengeInvite {
  const ChallengeInvite({
    required this.fromUid,
    required this.name,
    this.tag,
    required this.roomCode,
    required this.sentAt,
  });

  final String fromUid;
  final String name;
  final String? tag;
  final String roomCode;
  final DateTime sentAt;
}

/// What happened when you added someone.
enum AddFriendResult {
  /// A request was sent; they still have to accept.
  requested,

  /// They had already sent you a request: you are friends now.
  accepted,

  /// You were already friends.
  alreadyFriends,
}

/// This phone's player on the server.
class FriendIdentity {
  const FriendIdentity({
    required this.uid,
    required this.friendCode,
    required this.tag,
    this.name,
  });

  final String uid;

  /// The name saved in this account (after [FriendsBackend.signIn] with
  /// `keepServerName`), null if it had none.
  final String? name;

  /// Public tag shown after your name ("#4821"). Not the friend code.
  final String tag;

  /// Short code others type in to add you (see [FriendsBackend.addByCode]).
  final String friendCode;
}

/// Friend codes, friend requests and the friend list, stored on the server
/// so they work across phones and show up on the "Vrienden" scorebord.
///
/// Use [FirebaseFriendsBackend] for real use and [MockFriendsBackend]
/// without Firebase.
abstract class FriendsBackend {
  /// Signs in and makes sure this player has a profile and a friend code.
  ///
  /// [keepServerName]: an existing account keeps its saved name (after
  /// switching account) instead of taking [name] from this phone.
  Future<FriendIdentity> signIn({
    required String name,
    bool keepServerName = false,
  });

  /// Updates the name your friends see.
  Future<void> updateName(String name);

  /// Your friends, with name and record. Updates live.
  Stream<List<Friend>> friends();

  /// Requests other players sent you. Updates live.
  Stream<List<FriendRequest>> requests();

  /// Your own leaderboard entry, null before your first finished game.
  Stream<LeaderboardEntry?> myStats();

  /// Adds the player with this friend code.
  /// Throws [FriendsException] if the code is unknown or your own.
  Future<AddFriendResult> addByCode(String code);

  /// Adds a player you know the id of, e.g. a recent opponent.
  Future<AddFriendResult> addByUid(String uid);

  Future<void> accept(FriendRequest request);
  Future<void> decline(FriendRequest request);

  /// Ends the friendship on both sides.
  Future<void> remove(String uid);

  /// Challenges sent to you. Updates live.
  Stream<List<ChallengeInvite>> invites();

  /// Invites friend [toUid] to the room [roomCode] you just made.
  Future<void> sendInvite(String toUid, String roomCode);

  /// Takes back your invite to [toUid] (they joined, or you left).
  Future<void> cancelInvite(String toUid);

  /// Removes an invite sent to you (accepted, declined or expired).
  Future<void> dismissInvite(String fromUid);

  /// Your saved XP and record (`users/{uid}/progress`), null if none yet.
  Future<Map<String, Object?>?> loadProgress();

  Future<void> saveProgress(Map<String, Object?> progress);

  /// Sets your scorebord entry back to 0 wins and 0 losses.
  Future<void> resetStats();

  /// Deletes everything of the signed-in player: profile, friend code,
  /// scorebord entry, friendships and push tokens. Used for a guest that
  /// is left behind when logging into an existing Google account.
  Future<void> deleteMyData();

  Future<void> dispose();
}

class FriendsException implements Exception {
  FriendsException(this.message);

  final String message;

  @override
  String toString() => 'FriendsException: $message';
}
