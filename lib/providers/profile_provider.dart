import 'package:flutter/foundation.dart';

import '../models/badge.dart';
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
  bool _loaded = false;

  PlayerProfile get profile => _profile;

  /// Recent opponents, most recently played first. Stored on this phone.
  List<FriendRecord> get friends => _friends;
  bool get shareVideo => _shareVideo;

  /// Talk to your opponent during a duel. Off: no microphone and no sound
  /// from the opponent.
  bool get voiceChat => _voiceChat;
  bool get isLoaded => _loaded;

  Future<void> load() async {
    _profile = await _storage.loadProfile();
    _friends = await _storage.loadFriends();
    _shareVideo = await _storage.loadShareVideo();
    _voiceChat = await _storage.loadVoiceChat();
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

  /// XP a game is worth, so the result screen can show it before saving.
  static int xpFor({required bool won}) =>
      won ? AppConstants.xpForWin : AppConstants.xpForLoss;

  /// Adds a finished game to the profile and the recent opponents.
  List<BadgeDef> _newBadges = const [];

  /// Badges unlocked by the last duel(s) that haven't been shown yet.
  List<BadgeDef> get newBadges => _newBadges;

  /// Returns the new badges and forgets them, so the pop-up shows once.
  List<BadgeDef> takeNewBadges() {
    final list = _newBadges;
    _newBadges = const [];
    return list;
  }

  /// XP for winning a whole tournament.
  static const tournamentWinXp = 250;

  /// Unlocks every badge the profile has reached but doesn't hold yet.
  void _unlockBadges(DateTime now) {
    final fresh = [
      for (final b in allBadges)
        if (!_profile.hasBadge(b.id) && b.reached(_profile)) b,
    ];
    if (fresh.isEmpty) return;
    _profile = _profile.copyWith(
      badges: {
        ..._profile.badges,
        for (final b in fresh) b.id: now.millisecondsSinceEpoch,
      },
    );
    _newBadges = [..._newBadges, ...fresh];
  }

  /// A tournament match was played (on top of [recordGame]).
  Future<void> recordTournamentMatch() async {
    _profile = _profile.copyWith(
      stats: _profile.stats.plus('tournamentMatches'),
    );
    _unlockBadges(DateTime.now());
    notifyListeners();
    await _storage.saveProfile(_profile);
  }

  /// You won a tournament: bonus XP and the trophy badge.
  Future<void> recordTournamentWin() async {
    _profile = _profile.copyWith(
      xp: _profile.xp + tournamentWinXp,
      stats: _profile.stats.plus('tournamentWins'),
    );
    _unlockBadges(DateTime.now());
    notifyListeners();
    await _storage.saveProfile(_profile);
  }

  Future<void> recordGame(
    DuelSummary summary, {
    DateTime? at,
    bool vsFriend = false,
  }) async {
    final now = at ?? DateTime.now();
    final won = summary.won;
    final streak = won ? _profile.streak + 1 : 0;
    _profile = _profile.copyWith(
      xp: _profile.xp + summary.xpGained,
      wins: _profile.wins + (won ? 1 : 0),
      losses: _profile.losses + (won ? 0 : 1),
      streak: streak,
      stats: _profile.stats.withDuel(
        summary,
        streakAfter: streak,
        vsFriend: vsFriend,
      ),
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

    // Badges reached with this duel (or earlier, for older profiles).
    _unlockBadges(now);

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
      stats: progress.stats,
      badges: progress.badges,
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
