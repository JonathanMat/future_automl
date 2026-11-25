/// App-wide constants that are not game rules (those are in `GameConfig`).
abstract final class AppConstants {
  static const appName = 'Spell Duel';
  static const season = 'SEIZOEN 1';

  // Progression
  static const xpPerLevel = 500;
  static const xpForWin = 120;
  static const xpForLoss = 40;

  // Spell recognition (thresholds: see gesture_constants.dart)
  /// How often a camera frame is sent to the model (at most ~7 per
  /// second; a frame is skipped while the previous one is still running).
  static const recognitionInterval = Duration(milliseconds: 150);

  /// After the last round: time for the final spell effect and the
  /// "GEWONNEN" / "VERLOREN" banner before the result screen opens.
  static const resultScreenDelay = Duration(milliseconds: 3400);

  // Rooms
  static const roomCodeLength = 4;
  static const playerNameMaxLength = 16;
  static const friendCodeLength = 6;

  /// How many entries the global leaderboard shows.
  static const leaderboardSize = 20;

  // Storage keys
  static const profileKey = 'profile.v1';
  static const friendsKey = 'friends.v1';
  static const shareVideoKey = 'settings.shareVideo';
  static const voiceChatKey = 'settings.voiceChat';
  static const soundEffectsKey = 'settings.soundEffects';
}
