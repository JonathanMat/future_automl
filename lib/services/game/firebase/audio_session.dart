import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Android audio mode for WebRTC.
///
/// flutter_webrtc switches Android to "call mode" (voice-call volume, mic
/// routing) as soon as audio is used, and only switches back when the last
/// peer connection is disposed. These helpers make sure that happens.
abstract final class AudioSession {
  /// Voice chat without Android's call mode: the opponent's voice plays
  /// as media (media volume, loudspeaker) and the microphone still works.
  ///
  /// Call mode (`AndroidAudioConfiguration.communication`) cut off the
  /// sound effects on some phones (e.g. Nothing Phone 2a, MediaTek) until
  /// the app was restarted. WebRTC's own echo cancellation stays on.
  static final _voiceAsMedia = AndroidAudioConfiguration(
    manageAudioFocus: true,
    androidAudioMode: AndroidAudioMode.normal,
    androidAudioFocusMode: AndroidAudioFocusMode.gain,
    androidAudioStreamType: AndroidAudioStreamType.music,
    androidAudioAttributesUsageType: AndroidAudioAttributesUsageType.media,
    androidAudioAttributesContentType: AndroidAudioAttributesContentType.speech,
  );

  /// Starts WebRTC with the opponent's voice as media audio. Must run at
  /// app start, before anything else uses WebRTC: its audio engine is made
  /// once, and by default it plays voice as call audio
  /// (`USAGE_VOICE_COMMUNICATION`), which puts Android in call mode no
  /// matter what [configure] says.
  static Future<void> initWebRtc() async {
    if (kIsWeb || !WebRTC.platformIsAndroid) return;
    try {
      await WebRTC.initialize(
        options: {'androidAudioConfiguration': _voiceAsMedia.toMap()},
      );
    } catch (e) {
      debugPrint('AudioSession.initWebRtc: $e');
    }
  }

  /// Sets the audio for a call with ([voice]) or without the microphone.
  /// Both stay in normal media mode, so the sound effects keep working.
  /// Must be called before the camera/mic is opened.
  static Future<void> configure({required bool voice}) async {
    if (kIsWeb || !WebRTC.platformIsAndroid) return;
    try {
      await Helper.setAndroidAudioConfiguration(
        voice ? _voiceAsMedia : AndroidAudioConfiguration.media,
      );
    } catch (e) {
      debugPrint('AudioSession.configure: $e');
    }
  }

  /// After a call: on Android 12+ the call picked a "communication
  /// device" (speaker, earpiece, Bluetooth) that stays set after the call,
  /// so other sound keeps being routed as if the call were still on, or is
  /// lost. Clears it and goes back to normal media audio.
  static Future<void> endCall() async {
    if (kIsWeb || !WebRTC.platformIsAndroid) return;
    try {
      await Helper.clearAndroidCommunicationDevice();
    } catch (e) {
      debugPrint('AudioSession.clearCommunicationDevice: $e');
    }
    await configure(voice: false);
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
