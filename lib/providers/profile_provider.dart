import 'package:flutter/foundation.dart';

import '../models/duel_summary.dart';
import '../models/friend_record.dart';
import '../models/player_profile.dart';
import '../services/storage/local_storage_service.dart';
import '../utils/constants.dart';
import '../validators/player_name_validator.dart';

/// The local player's profile, friends and settings.
class ProfileProvider extends ChangeNotifier {
  ProfileProvider(this._storage);

  final LocalStorageService _storage;

  PlayerProfile _profile = const PlayerProfile();
  List<FriendRecord> _friends = const [];
  bool _shareVideo = true;
  bool _loaded = false;

  PlayerProfile get profile => _profile;

  /// Most recently played first.
  List<FriendRecord> get friends => _friends;
  bool get shareVideo => _shareVideo;
  bool get isLoaded => _loaded;

  Future<void> load() async {
    _profile = await _storage.loadProfile();
    _friends = await _storage.loadFriends();
    _shareVideo = await _storage.loadShareVideo();
    _loaded = true;
    notifyListeners();
  }

  Future<void> setName(String name) async {
    _profile = _profile.copyWith(name: PlayerNameValidator.normalize(name));
    notifyListeners();
    await _storage.saveProfile(_profile);
  }

  Future<void> setShareVideo(bool value) async {
    _shareVideo = value;
    notifyListeners();
    await _storage.saveShareVideo(value);
  }

  /// XP a game is worth, so the result screen can show it before saving.
  static int xpFor({required bool won}) =>
      won ? AppConstants.xpForWin : AppConstants.xpForLoss;

  /// Adds a finished game to the profile and the friend list.
  Future<void> recordGame(DuelSummary summary, {DateTime? at}) async {
    final now = at ?? DateTime.now();
    final won = summary.won;
    _profile = _profile.copyWith(
      xp: _profile.xp + summary.xpGained,
      wins: _profile.wins + (won ? 1 : 0),
      losses: _profile.losses + (won ? 0 : 1),
      streak: won ? _profile.streak + 1 : 0,
      lastDuel: LastDuel(
        opponentName: summary.opponentName,
        won: won,
        roundsWon: summary.roundsWon,
        roundsLost: summary.roundsLost,
        playedAt: now,
      ),
    );

    final key = summary.opponentName.trim().toLowerCase();
    final existing = _friends
        .where((f) => f.name.trim().toLowerCase() == key)
        .firstOrNull;
    final updated =
        (existing ?? FriendRecord(name: summary.opponentName, lastPlayed: now))
            .recordGame(won: won, at: now);
    _friends = [
      updated,
      ..._friends.where((f) => f.name.trim().toLowerCase() != key),
    ];

    notifyListeners();
    await _storage.saveProfile(_profile);
    await _storage.saveFriends(_friends);
  }

  /// Clears XP, record and friends. Keeps the name.
  Future<void> resetStats() async {
    _profile = PlayerProfile(name: _profile.name);
    _friends = const [];
    notifyListeners();
    await _storage.saveProfile(_profile);
    await _storage.clearStats();
  }
}
