import 'dart:async';

import '../../validators/friend_code_validator.dart';
import 'friends_backend.dart';

/// In-memory friends for UI work without Firebase.
///
/// Any valid code adds a friend right away. [seedRequests] puts incoming
/// requests in the list, to see that part of the screen.
class MockFriendsBackend implements FriendsBackend {
  MockFriendsBackend({List<FriendRequest> seedRequests = const []})
    : _requests = [...seedRequests];

  static const myCode = 'TEST42';
  static const _myUid = 'mock-me';

  final Map<String, Friend> _friends = {};
  final List<FriendRequest> _requests;
  final _friendsCtl = StreamController<List<Friend>>.broadcast();
  final _requestsCtl = StreamController<List<FriendRequest>>.broadcast();

  @override
  Future<FriendIdentity> signIn({required String name}) async =>
      const FriendIdentity(uid: _myUid, friendCode: myCode);

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

  @override
  Stream<LeaderboardEntry?> myStats() => Stream.value(null);

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
    _friends[uid] = Friend(uid: uid, name: name ?? _nameFor(uid));
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

  void _emit() {
    if (!_friendsCtl.isClosed) _friendsCtl.add(_friendList);
    if (!_requestsCtl.isClosed) _requestsCtl.add(List.of(_requests));
  }

  @override
  Future<void> dispose() async {
    await _friendsCtl.close();
    await _requestsCtl.close();
  }
}
