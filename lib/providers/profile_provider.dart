import 'package:flutter/foundation.dart';

import '../models/duel_summary.dart';
import '../models/friend_record.dart';
import '../models/player_profile.dart';
import '../services/storage/local_storage_service.dart';
import '../utils/constants.dart';
import '../validators/player_name_validator.dart';

/// The local player's profile, recent opponents and settings.
///
/// Real friends (on the server) are in `FriendsProvider`.
class ProfileProvider extends ChangeNotifier {
  ProfileProvider(this._storage);

  final LocalStorageService _storage;

  PlayerProfile _profile = const PlayerProfile();
  List<FriendRecord> _friends = const [];
  bool _shareVideo = true;
  bool _voiceChat = true;
  bool _soundEffects = true;
  bool _loaded = false;

  PlayerProfile get profile => _profile;

  /// Recent opponents, most recently played first. Stored on this phone.
  List<FriendRecord> get friends => _friends;
  bool get shareVideo => _shareVideo;

  /// Talk to your opponent during a duel. Off: no microphone and no sound
  /// from the opponent.
  bool get voiceChat => _voiceChat;

  /// Sounds of the spell effects during a duel.
  bool get soundEffects => _soundEffects;
  bool get isLoaded => _loaded;

  Future<void> load() async {
    _profile = await _storage.loadProfile();
    _friends = await _storage.loadFriends();
    _shareVideo = await _storage.loadShareVideo();
    _voiceChat = await _storage.loadVoiceChat();
    _soundEffects = await _storage.loadSoundEffects();
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

  Future<void> setVoiceChat(bool value) async {
    _voiceChat = value;
    notifyListeners();
    await _storage.saveVoiceChat(value);
  }

  Future<void> setSoundEffects(bool value) async {
    _soundEffects = value;
    notifyListeners();
    await _storage.saveSoundEffects(value);
  }

  /// XP a game is worth, so the result screen can show it before saving.
  static int xpFor({required bool won}) =>
      won ? AppConstants.xpForWin : AppConstants.xpForLoss;

  /// Adds a finished game to the profile and the recent opponents.
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

    // Match on the account id when we have one, otherwise on the name.
    final uid = summary.opponentUid;
    final key = summary.opponentName.trim().toLowerCase();
    bool same(FriendRecord f) => uid != null && f.uid != null
        ? f.uid == uid
        : f.name.trim().toLowerCase() == key;
    final existing = _friends.where(same).firstOrNull;
    final updated =
        (existing ??
                FriendRecord(
                  uid: uid,
                  name: summary.opponentName,
                  lastPlayed: now,
                ))
            .recordGame(
              won: won,
              at: now,
              uid: uid,
              name: summary.opponentName,
            );
    _friends = [updated, ..._friends.where((f) => !same(f))];

    notifyListeners();
    await _storage.saveProfile(_profile);
    await _storage.saveFriends(_friends);
  }

  /// Replaces XP, record and last duel, e.g. with what the server has for
  /// this account. Keeps the name.
  Future<void> replaceProgress(PlayerProfile progress) async {
    _profile = PlayerProfile(
      name: _profile.name,
      xp: progress.xp,
      wins: progress.wins,
      losses: progress.losses,
      streak: progress.streak,
      lastDuel: progress.lastDuel,
    );
    notifyListeners();
    await _storage.saveProfile(_profile);
  }

  /// Clears XP, record and recent opponents. Keeps the name and the
  /// friends on the server.
  Future<void> resetStats() async {
    _profile = PlayerProfile(name: _profile.name);
    _friends = const [];
    notifyListeners();
    await _storage.saveProfile(_profile);
    await _storage.clearStats();
  }
}
