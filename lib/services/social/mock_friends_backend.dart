import 'dart:async';

import '../../models/player_profile.dart';
import '../../models/player_stats.dart';
import '../../validators/friend_code_validator.dart';
import 'friends_backend.dart';

/// In-memory friends for UI work without Firebase.
///
/// Any valid code adds a friend right away. [seedRequests] puts incoming
/// requests in the list, to see that part of the screen.
class MockFriendsBackend implements FriendsBackend {
  MockFriendsBackend({
    List<FriendRequest> seedRequests = const [],
    List<ChallengeInvite> seedInvites = const [],
    List<Friend> seedFriends = const [],
  }) : _requests = [...seedRequests],
       _invites = [...seedInvites] {
    for (final f in seedFriends) {
      _friends[f.uid] = f;
    }
  }

  /// Demo friends for `--dart-define=BACKEND=mock`, so the "Vrienden"
  /// scorebord has something to show.
  static const demoFriends = [
    Friend(uid: 'demo-0', name: 'Lotte', tag: '2101', wins: 14, losses: 5),
    Friend(uid: 'demo-3', name: 'Daan', tag: '4312', wins: 7, losses: 8),
    Friend(uid: 'demo-5', name: 'Milan', tag: '5786', wins: 4, losses: 6),
  ];

  static const myCode = 'TEST42';
  static const myTag = '1234';
  static const _myUid = 'mock-me';

  final Map<String, Friend> _friends = {};
  final List<FriendRequest> _requests;
  final List<ChallengeInvite> _invites;

  /// Invites this phone sent, by friend uid → room code (for tests).
  final Map<String, String> sentInvites = {};
  final _invitesCtl = StreamController<List<ChallengeInvite>>.broadcast();
  final _friendsCtl = StreamController<List<Friend>>.broadcast();
  final _requestsCtl = StreamController<List<FriendRequest>>.broadcast();

  @override
  Future<FriendIdentity> signIn({
    required String name,
    bool keepServerName = false,
  }) async => const FriendIdentity(uid: _myUid, friendCode: myCode, tag: myTag);

  @override
  Future<void> updateName(String name) async {}

  List<Friend> get _friendList =>
      _friends.values.toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  @override
  Stream<List<Friend>> friends() async* {
    yield _friendList;
    yield* _friendsCtl.stream;
  }

  @override
  Stream<List<FriendRequest>> requests() async* {
    yield List.of(_requests);
    yield* _requestsCtl.stream;
  }

  /// Your scorebord entry (for tests).
  LeaderboardEntry? board;

  @override
  Stream<LeaderboardEntry?> myStats() => Stream.value(board);

  @override
  Future<AddFriendResult> addByCode(String code) async {
    final c = FriendCodeValidator.normalize(code);
    if (c == myCode) throw FriendsException('Dat ben je zelf.');
    return addByUid('mock-$c', name: 'Vriend $c');
  }

  @override
  Future<AddFriendResult> addByUid(String uid, {String? name}) async {
    if (uid == _myUid) throw FriendsException('Dat ben je zelf.');
    if (_friends.containsKey(uid)) return AddFriendResult.alreadyFriends;
    _friends[uid] = Friend(
      uid: uid,
      name: name ?? _nameFor(uid),
      tag: '${1000 + uid.hashCode.abs() % 9000}',
    );
    _emit();
    return AddFriendResult.accepted;
  }

  String _nameFor(String uid) => uid == 'mock-bot' ? 'Bot' : 'Speler';

  @override
  Future<void> accept(FriendRequest request) async {
    _requests.removeWhere((r) => r.fromUid == request.fromUid);
    _friends[request.fromUid] = Friend(
      uid: request.fromUid,
      name: request.name,
      tag: request.tag,
    );
    _emit();
  }

  @override
  Future<void> decline(FriendRequest request) async {
    _requests.removeWhere((r) => r.fromUid == request.fromUid);
    _emit();
  }

  @override
  Future<void> remove(String uid) async {
    _friends.remove(uid);
    _emit();
  }

  @override
  Stream<List<ChallengeInvite>> invites() async* {
    yield List.of(_invites);
    yield* _invitesCtl.stream;
  }

  @override
  Future<void> sendInvite(String toUid, String roomCode) async =>
      sentInvites[toUid] = roomCode;

  /// How often each invite was refreshed (for tests).
  final Map<String, int> refreshedInvites = {};

  @override
  Future<void> refreshInvite(String toUid) async {
    if (!sentInvites.containsKey(toUid)) return;
    refreshedInvites[toUid] = (refreshedInvites[toUid] ?? 0) + 1;
  }

  /// Adds an invite sent to you, as if a friend just challenged you.
  void receiveInvite(ChallengeInvite invite) {
    _invites
      ..removeWhere((i) => i.fromUid == invite.fromUid)
      ..add(invite);
    if (!_invitesCtl.isClosed) _invitesCtl.add(List.of(_invites));
  }

  @override
  Future<void> cancelInvite(String toUid) async => sentInvites.remove(toUid);

  @override
  Future<void> dismissInvite(String fromUid) async {
    _invites.removeWhere((i) => i.fromUid == fromUid);
    if (!_invitesCtl.isClosed) _invitesCtl.add(List.of(_invites));
  }

  void _emit() {
    if (!_friendsCtl.isClosed) _friendsCtl.add(_friendList);
    if (!_requestsCtl.isClosed) _requestsCtl.add(List.of(_requests));
  }

  /// Extra public profiles for [loadPlayer], by uid (for tests).
  final Map<String, PublicProfile> players = {};

  @override
  Future<PublicProfile?> loadPlayer(String uid) async {
    if (players[uid] case final p?) return p;
    final f = _friends[uid];
    if (f == null) return null;
    // Made-up but steady stats, so the profile page has something to show.
    final seed = uid.codeUnits.fold(0, (a, c) => a + c);
    return PublicProfile(
      uid: uid,
      tag: f.tag,
      profile: PlayerProfile(
        name: f.name,
        xp: f.wins * 60 + f.losses * 25,
        wins: f.wins,
        losses: f.losses,
        streak: seed % 3,
        stats: PlayerStats({
          'wins_vuur': f.wins + seed % 5,
          'wins_ijs': f.wins ~/ 2 + seed % 4,
          'wins_bliksem': f.wins ~/ 3 + seed % 3,
          'wins_schild': seed % 6,
          'flawless': f.wins ~/ 4,
          'bestStreak': 1 + seed % 5,
          if (f.wins > 0) 'fastestMs': 420 + seed % 300,
        }),
        badges: {if (f.wins > 0) 'eerste_winst': 0},
      ),
    );
  }

  /// What [saveProgress] stored last (for tests).
  Map<String, Object?>? savedProgress;

  @override
  Future<Map<String, Object?>?> loadProgress() async => savedProgress;

  @override
  Future<void> saveProgress(Map<String, Object?> progress) async =>
      savedProgress = progress;

  /// What [saveRecent] stored last (for tests).
  List<Map<String, Object?>> savedRecent = [];

  @override
  Future<List<Map<String, Object?>>> loadRecent() async => List.of(savedRecent);

  @override
  Future<void> saveRecent(List<Map<String, Object?>> recent) async =>
      savedRecent = List.of(recent);

  /// Set by [deleteMyData] (for tests).
  bool deleted = false;

  @override
  Future<void> deleteMyData() async {
    deleted = true;
    _friends.clear();
    _requests.clear();
    _invites.clear();
    if (!_invitesCtl.isClosed) _invitesCtl.add(const []);
    savedProgress = null;
    savedRecent = [];
    board = null;
    _emit();
  }

  @override
  Future<void> dispose() async {
    await _friendsCtl.close();
    await _requestsCtl.close();
    await _invitesCtl.close();
  }
}
