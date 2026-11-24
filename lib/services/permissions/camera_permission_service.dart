import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Result of asking for the camera (and microphone).
enum MediaAccess {
  granted,

  /// The player refused, now or earlier. Only the system settings can
  /// change that.
  denied,

  /// No camera on this device (e.g. a simulator).
  unavailable,

  /// Something else went wrong.
  failed,
}

/// Asks for camera (and microphone) access before a room is made, so a
/// refusal gives a clear message instead of a half-created room.
///
/// The system prompt itself comes from `flutter_webrtc`: this opens the
/// camera once and closes it again. The permissions are declared in
/// `AndroidManifest.xml` and `Info.plist`.
class CameraPermissionService {
  const CameraPermissionService({this.enabled = true, this.microphone = false});

  /// False for the mock without a camera: everything counts as granted.
  final bool enabled;

  /// Also ask for the microphone (the Firebase video call uses audio).
  final bool microphone;

  static const _settingsChannel = MethodChannel('spell_duel/app_settings');

  Future<MediaAccess> ensureAccess() async {
    if (!enabled) return MediaAccess.granted;
    try {
      final stream = await navigator.mediaDevices.getUserMedia({
        'audio': microphone,
        'video': {'facingMode': 'user'},
      });
      for (final track in stream.getTracks()) {
        await track.stop();
      }
      await stream.dispose();
      return MediaAccess.granted;
    } catch (e) {
      debugPrint('Camera access: $e');
      return classify(e);
    }
  }

  /// Maps a `getUserMedia` error to a [MediaAccess]. Android and iOS both
  /// report a refusal as `NotAllowedError`, a missing camera as
  /// `NotFoundError`.
  static MediaAccess classify(Object error) {
    final text = error.toString();
    if (text.contains('NotAllowedError') ||
        text.toLowerCase().contains('permission')) {
      return MediaAccess.denied;
    }
    if (text.contains('NotFoundError')) return MediaAccess.unavailable;
    return MediaAccess.failed;
  }

  /// Opens this app's page in the system settings. False if that failed.
  Future<bool> openAppSettings() async {
    try {
      return await _settingsChannel.invokeMethod<bool>('open') ?? false;
    } catch (e) {
      debugPrint('openAppSettings: $e');
      return false;
    }
  }
}
