import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Android audio mode for WebRTC.
///
/// flutter_webrtc switches Android to "call mode" (voice-call volume, mic
/// routing) as soon as audio is used, and only switches back when the last
/// peer connection is disposed. These helpers make sure that happens.
abstract final class AudioSession {
  /// Picks call mode (voice chat on) or normal media mode (voice chat off,
  /// volume can go to 0). Must be called before the camera/mic is opened.
  static Future<void> configure({required bool voice}) async {
    if (kIsWeb || !WebRTC.platformIsAndroid) return;
    try {
      await Helper.setAndroidAudioConfiguration(
        voice
            ? AndroidAudioConfiguration.communication
            : AndroidAudioConfiguration.media,
      );
    } catch (e) {
      debugPrint('AudioSession.configure: $e');
    }
  }

  /// Ends call mode when there is no call, e.g. after a quick
  /// getUserMedia() permission check. Creating and disposing an empty peer
  /// connection is the only way flutter_webrtc offers to stop its audio
  /// manager.
  static Future<void> release() async {
    if (kIsWeb || !WebRTC.platformIsAndroid) return;
    try {
      final pc = await createPeerConnection({});
      await pc.close();
      await pc.dispose();
    } catch (e) {
      debugPrint('AudioSession.release: $e');
    }
  }
}
