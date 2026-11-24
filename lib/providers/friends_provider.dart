import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/player_profile.dart';
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

  /// Progress as last saved to / loaded from the server (JSON string).
  String? _syncedProgress;

  /// Set by [restart]: the next sign-in takes the server's progress.
  bool _adoptRemote = false;
  bool _disposed = false;

  FriendIdentity? get identity => _identity;
  String? get myUid => _identity?.uid;
  String? get friendCode => _identity?.friendCode;

  /// Your public tag ("#4821" after your name).
  String? get myTag => _identity?.tag;
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
          tag: _identity?.tag,
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
    } else {
      if (name != _syncedName) {
        _syncedName = name;
        backend.updateName(name).catchError((Object e) {
          debugPrint('friends updateName: $e');
        });
      }
      _saveProgressIfChanged();
    }
  }

  void _saveProgressIfChanged() {
    final profile = _profile?.profile;
    if (profile == null || _syncedProgress == null) return;
    final progress = profile.progressJson();
    final key = '$progress';
    if (key == _syncedProgress) return;
    _syncedProgress = key;
    backend.saveProgress(progress).catchError((Object e) {
      debugPrint('saveProgress: $e');
    });
  }

  /// Makes this phone and the server agree on XP and record.
  ///
  /// After an account switch the server wins (it is that account's data;
  /// none means a fresh start). Otherwise the copy with the most XP wins,
  /// so nothing is lost when one side is behind.
  Future<void> _syncProgress({required bool adopt}) async {
    final profile = _profile;
    if (profile == null) return;
    final remote = await backend.loadProgress();
    final local = profile.profile;
    final remoteProfile = remote == null ? null : local.withProgress(remote);

    if (adopt) {
      await profile.replaceProgress(remoteProfile ?? const PlayerProfile());
    } else if (remoteProfile != null && remoteProfile.xp > local.xp) {
      await profile.replaceProgress(remoteProfile);
    }

    final now = profile.profile.progressJson();
    if (remote == null ||
        '$now' != '${local.withProgress(remote).progressJson()}') {
      await backend.saveProgress(now);
    }
    _syncedProgress = '$now';
  }

  /// Signs in and starts listening. Safe to call again after an error.
  Future<void> connect() async {
    final name = _profile?.profile.name ?? '';
    if (_connecting || _identity != null) return;
    _connecting = true;
    _error = null;
    _notify();
    try {
      final adopt = _adoptRemote;
      final identity = _identity = await backend.signIn(
        name: name,
        keepServerName: adopt,
      );
      final serverName = identity.name;
      if (adopt && serverName != null && serverName != name) {
        // The account we switched to has its own name: show that one.
        _syncedName = serverName;
        await _profile?.setName(serverName);
      } else {
        _syncedName = name;
      }
      _listen();
      try {
        await _syncProgress(adopt: _adoptRemote);
        _adoptRemote = false;
      } catch (e) {
        debugPrint('syncProgress: $e');
      }
    } catch (e) {
      debugPrint('friends signIn: $e');
      // Firebase errors look like "[firebase_database/permission-denied] …":
      // show the code so a rules problem is easy to spot.
      final code = RegExp(r'\[[^/\]]+/([^\]]+)\]').firstMatch('$e')?.group(1);
      _error = e is FriendsException
          ? e.message
          : code == 'permission-denied'
          ? 'Vrienden laden mislukt: geen toegang. Zijn de nieuwste '
                'database-regels gepubliceerd?'
          : 'Vrienden laden mislukt${code == null ? '' : ' ($code)'}. '
                'Controleer je internet.';
    } finally {
      _connecting = false;
      _notify();
    }
  }

  /// Resets your scorebord entry, e.g. after "Statistieken wissen".
  Future<void> resetServerStats() async {
    if (!isReady) return;
    try {
      await backend.resetStats();
    } catch (e) {
      debugPrint('resetStats: $e');
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
    _syncedProgress = null;
    _adoptRemote = true;
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
