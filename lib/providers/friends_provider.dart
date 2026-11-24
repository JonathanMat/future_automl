import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/social/friends_backend.dart';
import 'profile_provider.dart';

/// Outcome of a friend action, with a message for a snackbar.
typedef FriendActionResult = ({bool ok, String message});

/// Server-side friends for the UI: your friend code, friends, incoming
/// requests and the "Vrienden" scorebord.
///
/// Signs in as soon as the profile has a name and keeps the name on the
/// server in sync (see [attach]).
class FriendsProvider extends ChangeNotifier {
  FriendsProvider(this.backend);

  final FriendsBackend backend;

  FriendIdentity? _identity;
  List<Friend> _friends = const [];
  List<FriendRequest> _requests = const [];
  LeaderboardEntry? _myStats;
  String? _error;
  bool _connecting = false;
  final Set<String> _sent = {};
  final Set<String> _working = {};
  final List<StreamSubscription<Object?>> _subs = [];
  ProfileProvider? _profile;
  String? _syncedName;
  bool _disposed = false;

  FriendIdentity? get identity => _identity;
  String? get myUid => _identity?.uid;
  String? get friendCode => _identity?.friendCode;
  bool get isReady => _identity != null;
  bool get connecting => _connecting;

  /// Why signing in or loading failed. Null when all is well.
  String? get error => _error;

  /// Sorted by name.
  List<Friend> get friends => _friends;
  List<FriendRequest> get requests => _requests;

  bool isFriend(String uid) => _friends.any((f) => f.uid == uid);

  /// A request to [uid] was sent during this session.
  bool requestSent(String uid) => _sent.contains(uid);

  /// An add/accept/remove for [uid] is running.
  bool isWorking(String uid) => _working.contains(uid);

  /// You and your friends, most wins first.
  List<LeaderboardEntry> get board {
    final me =
        _myStats ??
        LeaderboardEntry(
          uid: myUid ?? '',
          name: _profile?.profile.name ?? 'Jij',
          wins: 0,
          losses: 0,
        );
    return [me, for (final f in _friends) f.toEntry()]
      ..sort((a, b) => b.wins.compareTo(a.wins));
  }

  /// Follows [profile]: signs in once it has a name, and pushes name
  /// changes to the server.
  void attach(ProfileProvider profile) {
    _profile = profile;
    profile.addListener(_onProfile);
    _onProfile();
  }

  void _onProfile() {
    final name = _profile?.profile.name ?? '';
    if (name.trim().isEmpty) return;
    if (_identity == null) {
      if (!_connecting) unawaited(connect());
    } else if (name != _syncedName) {
      _syncedName = name;
      backend.updateName(name).catchError((Object e) {
        debugPrint('friends updateName: $e');
      });
    }
  }

  /// Signs in and starts listening. Safe to call again after an error.
  Future<void> connect() async {
    final name = _profile?.profile.name ?? '';
    if (_connecting || _identity != null) return;
    _connecting = true;
    _error = null;
    _notify();
    try {
      _identity = await backend.signIn(name: name);
      _syncedName = name;
      _listen();
    } catch (e) {
      debugPrint('friends signIn: $e');
      _error = e is FriendsException
          ? e.message
          : 'Vrienden laden mislukt. Controleer je internet.';
    } finally {
      _connecting = false;
      _notify();
    }
  }

  /// Drops everything and signs in again, e.g. after switching account.
  Future<void> restart() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    _identity = null;
    _friends = const [];
    _requests = const [];
    _myStats = null;
    _sent.clear();
    _error = null;
    _notify();
    await connect();
  }

  void _listen() {
    void onError(Object e) {
      debugPrint('friends stream: $e');
      _error = 'Vrienden laden mislukt.';
      _notify();
    }

    _subs.addAll([
      backend.friends().listen((list) {
        _friends = list;
        _sent.removeWhere(isFriend);
        _notify();
      }, onError: onError),
      backend.requests().listen((list) {
        _requests = list;
        _notify();
      }, onError: onError),
      backend.myStats().listen((s) {
        _myStats = s;
        _notify();
      }, onError: onError),
    ]);
  }

  /// Adds by friend code.
  Future<FriendActionResult> addByCode(String code) => _guard(code, () async {
    final r = await backend.addByCode(code);
    return _messageFor(r, null);
  });

  /// Adds a recent opponent.
  Future<FriendActionResult> addByUid(String uid, String name) =>
      _guard(uid, () async {
        final r = await backend.addByUid(uid);
        if (r == AddFriendResult.requested) _sent.add(uid);
        return _messageFor(r, name);
      });

  Future<FriendActionResult> accept(FriendRequest r) =>
      _guard(r.fromUid, () async {
        await backend.accept(r);
        return 'Jij en ${r.name} zijn nu vrienden.';
      });

  Future<FriendActionResult> decline(FriendRequest r) =>
      _guard(r.fromUid, () async {
        await backend.decline(r);
        return 'Verzoek van ${r.name} geweigerd.';
      });

  Future<FriendActionResult> remove(Friend f) => _guard(f.uid, () async {
    await backend.remove(f.uid);
    return '${f.name} is geen vriend meer.';
  });

  String _messageFor(AddFriendResult r, String? name) => switch (r) {
    AddFriendResult.requested =>
      'Verzoek verstuurd${name == null ? '' : ' naar $name'}.',
    AddFriendResult.accepted =>
      name == null ? 'Vriend toegevoegd.' : 'Jij en $name zijn nu vrienden.',
    AddFriendResult.alreadyFriends => 'Jullie zijn al vrienden.',
  };

  Future<FriendActionResult> _guard(
    String key,
    Future<String> Function() action,
  ) async {
    if (!isReady) {
      return (ok: false, message: 'Nog niet verbonden met de server.');
    }
    _working.add(key);
    _notify();
    try {
      return (ok: true, message: await action());
    } on FriendsException catch (e) {
      return (ok: false, message: e.message);
    } catch (e) {
      debugPrint('friends action: $e');
      return (ok: false, message: 'Er ging iets mis. Probeer opnieuw.');
    } finally {
      _working.remove(key);
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _profile?.removeListener(_onProfile);
    for (final s in _subs) {
      s.cancel();
    }
    backend.dispose();
    super.dispose();
  }
}
