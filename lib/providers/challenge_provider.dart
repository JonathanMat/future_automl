import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/game/game_backend.dart';
import '../services/push/push_service.dart';
import '../services/social/friends_backend.dart';
import 'friends_provider.dart';
import 'game_provider.dart';

/// A challenge you sent and are waiting on.
class OutgoingChallenge {
  const OutgoingChallenge({
    required this.uid,
    required this.name,
    this.tag,
    required this.sentAt,
  });

  final String uid;
  final String name;
  final String? tag;
  final DateTime sentAt;
}

/// Challenges between friends: invites you received (shown as a banner on
/// Home, Vrienden and Scorebord) and the one you sent.
///
/// Sending: make a room, then write an invite with its code. The invite is
/// taken back as soon as the friend joins or you leave the room.
class ChallengeProvider extends ChangeNotifier {
  ChallengeProvider({
    required this.backend,
    required this.friends,
    required this.game,
    this.push = const NoPushService(),
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now {
    friends.addListener(_onFriends);
    game.addListener(_onGame);
    _expiry = Timer.periodic(const Duration(seconds: 15), (_) => _notify());
    _onFriends();
  }

  /// Invites older than this are hidden: the room is probably gone.
  static const maxAge = Duration(minutes: 3);

  final FriendsBackend backend;
  final FriendsProvider friends;
  final GameProvider game;
  final PushService push;
  final DateTime Function() _now;

  String? _uid;
  StreamSubscription<List<ChallengeInvite>>? _sub;
  List<ChallengeInvite> _invites = const [];
  final Set<String> _hidden = {};
  OutgoingChallenge? _outgoing;

  /// The room of the outgoing challenge has been seen. Until then an idle
  /// state just means Firebase hasn't reported the new room yet.
  bool _outgoingRoomSeen = false;
  late final Timer _expiry;
  bool _disposed = false;

  /// Fresh invites, newest first.
  List<ChallengeInvite> get incoming {
    final cutoff = _now().subtract(maxAge);
    return _invites
        .where((i) => i.sentAt.isAfter(cutoff) && !_hidden.contains(i.fromUid))
        .toList()
      ..sort((a, b) => b.sentAt.compareTo(a.sentAt));
  }

  /// The friend you are waiting for, if you sent a challenge.
  String? get waitingFor => _outgoing?.name;

  /// The challenge you sent, until the friend joins or you leave.
  OutgoingChallenge? get outgoing => _outgoing;

  /// When the friend's invite stops showing for them.
  DateTime? get outgoingExpiresAt => _outgoing?.sentAt.add(maxAge);

  void _onFriends() {
    final uid = friends.myUid;
    if (uid == _uid) return;
    final old = _uid;
    _uid = uid;
    _sub?.cancel();
    _sub = null;
    _invites = const [];
    _hidden.clear();
    if (old != null) unawaited(push.unregister(old));
    if (uid != null) {
      _sub = backend.invites().listen((list) {
        _invites = list;
        _notify();
      }, onError: (Object e) => debugPrint('invites: $e'));
      unawaited(push.register(uid));
    }
    _notify();
  }

  /// Takes the invite back once the friend is in, or the room is gone.
  void _onGame() {
    final out = _outgoing;
    if (out == null) return;
    final s = game.state;
    if (s.phase != GamePhase.idle) _outgoingRoomSeen = true;
    final left = s.phase == GamePhase.idle && _outgoingRoomSeen;
    if (s.opponent != null || left) {
      _outgoing = null;
      _outgoingRoomSeen = false;
      unawaited(
        backend
            .cancelInvite(out.uid)
            .catchError((Object e) => debugPrint('cancelInvite: $e')),
      );
      _notify();
    }
  }

  /// Sends a challenge for the room you just created. Returns a message.
  Future<String> send(Friend friend, String roomCode) async {
    try {
      await backend.sendInvite(friend.uid, roomCode);
      // Push is a bonus: the banner works without it.
      unawaited(push.notifyChallenge(friend.uid));
      _outgoing = OutgoingChallenge(
        uid: friend.uid,
        name: friend.name,
        tag: friend.tag,
        sentAt: _now(),
      );
      _outgoingRoomSeen = game.state.phase != GamePhase.idle;
      _notify();
      return 'Uitdaging verstuurd naar ${friend.name}.';
    } catch (e) {
      debugPrint('sendInvite: $e');
      return 'Uitdaging versturen mislukt.';
    }
  }

  /// Takes back the challenge you sent, e.g. when you leave the lobby.
  Future<void> cancelOutgoing() async {
    final out = _outgoing;
    if (out == null) return;
    _outgoing = null;
    _outgoingRoomSeen = false;
    _notify();
    try {
      await backend.cancelInvite(out.uid);
    } catch (e) {
      debugPrint('cancelInvite: $e');
    }
  }

  /// Hides and removes an invite (after joining, or when declined).
  Future<void> dismiss(ChallengeInvite invite) async {
    _hidden.add(invite.fromUid);
    _notify();
    try {
      await backend.dismissInvite(invite.fromUid);
    } catch (e) {
      debugPrint('dismissInvite: $e');
    }
  }

  /// Call before signing out, while the old uid may still write.
  Future<void> unregisterPush() async {
    final uid = _uid;
    if (uid != null) await push.unregister(uid);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _expiry.cancel();
    _sub?.cancel();
    friends.removeListener(_onFriends);
    game.removeListener(_onGame);
    super.dispose();
  }
}
