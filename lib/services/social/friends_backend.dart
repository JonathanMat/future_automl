import '../../models/game_state.dart';

export '../../models/game_state.dart' show LeaderboardEntry;

/// A confirmed friend (both sides accepted), with their overall record.
class Friend {
  const Friend({
    required this.uid,
    required this.name,
    this.wins = 0,
    this.losses = 0,
  });

  final String uid;
  final String name;

  /// Overall wins and losses on the leaderboard (not only against you).
  final int wins;
  final int losses;

  LeaderboardEntry toEntry() =>
      LeaderboardEntry(uid: uid, name: name, wins: wins, losses: losses);
}

/// Someone who wants to be your friend.
class FriendRequest {
  const FriendRequest({required this.fromUid, required this.name});

  final String fromUid;
  final String name;
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
  const FriendIdentity({required this.uid, required this.friendCode});

  final String uid;

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
  Future<FriendIdentity> signIn({required String name});

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

  Future<void> dispose();
}

class FriendsException implements Exception {
  FriendsException(this.message);

  final String message;

  @override
  String toString() => 'FriendsException: $message';
}
