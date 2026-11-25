import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/friend_record.dart';
import '../../models/player_profile.dart';
import '../../utils/constants.dart';

/// Stores the profile, friends and settings on the phone.
class LocalStorageService {
  LocalStorageService([SharedPreferences? prefs]) : _prefs = prefs;

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _p async =>
      _prefs ??= await SharedPreferences.getInstance();

  Future<PlayerProfile> loadProfile() async {
    final raw = (await _p).getString(AppConstants.profileKey);
    if (raw == null) return const PlayerProfile();
    try {
      return PlayerProfile.fromJson(
        (jsonDecode(raw) as Map).cast<String, Object?>(),
      );
    } catch (e) {
      debugPrint('loadProfile: $e');
      return const PlayerProfile();
    }
  }

  Future<void> saveProfile(PlayerProfile profile) async => (await _p).setString(
    AppConstants.profileKey,
    jsonEncode(profile.toJson()),
  );

  Future<List<FriendRecord>> loadFriends() async {
    final raw = (await _p).getString(AppConstants.friendsKey);
    if (raw == null) return const [];
    try {
      return [
        for (final item in jsonDecode(raw) as List)
          FriendRecord.fromJson((item as Map).cast<String, Object?>()),
      ];
    } catch (e) {
      debugPrint('loadFriends: $e');
      return const [];
    }
  }

  Future<void> saveFriends(List<FriendRecord> friends) async =>
      (await _p).setString(
        AppConstants.friendsKey,
        jsonEncode([for (final f in friends) f.toJson()]),
      );

  Future<bool> loadShareVideo() async =>
      (await _p).getBool(AppConstants.shareVideoKey) ?? true;

  Future<void> saveShareVideo(bool value) async =>
      (await _p).setBool(AppConstants.shareVideoKey, value);

  Future<bool> loadVoiceChat() async =>
      (await _p).getBool(AppConstants.voiceChatKey) ?? true;

  Future<void> saveVoiceChat(bool value) async =>
      (await _p).setBool(AppConstants.voiceChatKey, value);

  Future<bool> loadSoundEffects() async =>
      (await _p).getBool(AppConstants.soundEffectsKey) ?? true;

  Future<void> saveSoundEffects(bool value) async =>
      (await _p).setBool(AppConstants.soundEffectsKey, value);

  /// Removes everything this app stored: profile, recent opponents and
  /// settings.
  Future<void> clearAll() async {
    final p = await _p;
    for (final key in [
      AppConstants.profileKey,
      AppConstants.friendsKey,
      AppConstants.shareVideoKey,
      AppConstants.voiceChatKey,
      AppConstants.soundEffectsKey,
    ]) {
      await p.remove(key);
    }
  }
}
