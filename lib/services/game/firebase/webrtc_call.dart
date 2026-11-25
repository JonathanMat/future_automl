import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../../models/game_state.dart';
import 'audio_session.dart';
import 'ice_config.dart';

/// A 1-on-1 video call. Firebase is only used to exchange the connection
/// details ("signaling"); the video itself goes straight from phone to phone
/// (or via TURN), never through Firebase.
///
/// Signaling layout under `rooms/{code}/signaling`:
/// ```
/// offer:  {type, sdp}             written by the caller (host)
/// answer: {type, sdp}             written by the callee (guest)
/// candidates/caller/{push id}:    {candidate, sdpMid, sdpMLineIndex}
/// candidates/callee/{push id}:    ...
/// ```
class WebRtcCall {
  WebRtcCall({
    required this.signaling,
    required this.isCaller,
    this.ice = const IceConfig(),
    this.audio = true,
  });

  final DatabaseReference signaling;
  final bool isCaller;
  final IceConfig ice;

  /// Voice chat. Off: no microphone, the opponent's audio is muted and the
  /// phone stays in normal media mode (volume can go to 0).
  final bool audio;

  MediaStream? _localStream;
  RTCPeerConnection? _pc;
  final _remoteCtl = StreamController<MediaStream?>.broadcast();
  final _statusCtl = StreamController<CallStatus>.broadcast();
  final List<StreamSubscription<Object?>> _subs = [];
  final List<RTCIceCandidate> _pendingCandidates = [];
  bool _remoteDescriptionSet = false;
  bool _closed = false;

  MediaStream? get localStream => _localStream;
  Stream<MediaStream?> get remoteStream => _remoteCtl.stream;
  Stream<CallStatus> get status => _statusCtl.stream;

  String get _myRole => isCaller ? 'caller' : 'callee';
  String get _otherRole => isCaller ? 'callee' : 'caller';

  /// Opens camera + microphone. Call before [connect], so the UI can show
  /// the own camera while waiting for the opponent.
  Future<MediaStream> openCamera() async {
    if (_localStream case final s?) return s;
    await AudioSession.configure(voice: audio);
    return _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': audio,
      'video': {
        'facingMode': 'user',
        // 720p: the feed fills a large part of the screen, 480p looked soft.
        'width': {'ideal': 1280},
        'height': {'ideal': 720},
        'frameRate': {'ideal': 24},
      },
    });
  }

  /// Starts the connection. The caller can call this right after creating
  /// the room: the offer waits in Firebase until the callee joins.
  Future<void> connect() async {
    final stream = await openCamera();
    _statusCtl.add(CallStatus.connecting);

    final pc = _pc = await createPeerConnection(ice.toPeerConnectionConfig());
    for (final track in stream.getTracks()) {
      await pc.addTrack(track, stream);
    }

    pc.onIceCandidate = (candidate) {
      if (candidate.candidate == null) return;
      signaling.child('candidates/$_myRole').push().set({
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    };
    pc.onTrack = (event) {
      // Voice chat off: don't play the opponent's sound.
      if (!audio && event.track.kind == 'audio') event.track.enabled = false;
      if (event.streams.isNotEmpty) _remoteCtl.add(event.streams.first);
    };
    pc.onConnectionState = (state) {
      switch (state) {
        case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
          _statusCtl.add(CallStatus.connected);
          unawaited(_keepVideoSharp());
        case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
          _statusCtl.add(CallStatus.failed);
          // Often a network switch (wifi → 4G): try again.
          if (isCaller) unawaited(_restart());
        case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
          _statusCtl.add(CallStatus.closed);
        default:
          break;
      }
    };

    _subs.add(
      signaling
          .child('candidates/$_otherRole')
          .onChildAdded
          .listen((event) => _onRemoteCandidate(event.snapshot.value)),
    );

    if (isCaller) {
      await _sendOffer();
      _subs.add(
        signaling.child('answer').onValue.listen((event) async {
          final answer = event.snapshot.value;
          if (answer is Map && !_remoteDescriptionSet) {
            await _setRemote(answer);
          }
        }),
      );
    } else {
      _subs.add(
        signaling.child('offer').onValue.listen((event) async {
          final offer = event.snapshot.value;
          if (offer is! Map) return;
          // A new offer (e.g. after an ICE restart) replaces the old one.
          await _setRemote(offer);
          final answer = await pc.createAnswer();
          await pc.setLocalDescription(answer);
          await signaling.child('answer').set({
            'type': answer.type,
            'sdp': answer.sdp,
          });
        }),
      );
    }
  }

  /// Under CPU or network load WebRTC lowers the camera resolution by
  /// default, which also makes the own preview blurry (it shows the same
  /// source). Prefer dropping frames instead, and allow a higher bitrate.
  Future<void> _keepVideoSharp() async {
    final pc = _pc;
    if (pc == null) return;
    try {
      for (final sender in await pc.getSenders()) {
        if (sender.track?.kind != 'video') continue;
        final params = sender.parameters;
        params.degradationPreference =
            RTCDegradationPreference.MAINTAIN_RESOLUTION;
        for (final encoding in params.encodings ?? const <RTCRtpEncoding>[]) {
          encoding.maxBitrate = 1500 * 1000;
        }
        await sender.setParameters(params);
      }
    } catch (e) {
      debugPrint('Setting video parameters failed: $e');
    }
  }

  Future<void> _sendOffer({bool iceRestart = false}) async {
    final pc = _pc!;
    final offer = await pc.createOffer({if (iceRestart) 'iceRestart': true});
    await pc.setLocalDescription(offer);
    _remoteDescriptionSet = false;
    await signaling.child('answer').remove();
    await signaling.child('offer').set({'type': offer.type, 'sdp': offer.sdp});
  }

  Future<void> _restart() async {
    if (_closed) return;
    try {
      await _sendOffer(iceRestart: true);
    } catch (e) {
      debugPrint('ICE restart failed: $e');
    }
  }

  Future<void> _setRemote(Map<Object?, Object?> description) async {
    await _pc!.setRemoteDescription(
      RTCSessionDescription(
        description['sdp'] as String?,
        description['type'] as String?,
      ),
    );
    _remoteDescriptionSet = true;
    for (final c in _pendingCandidates) {
      await _pc!.addCandidate(c);
    }
    _pendingCandidates.clear();
  }

  Future<void> _onRemoteCandidate(Object? value) async {
    if (value is! Map) return;
    final candidate = RTCIceCandidate(
      value['candidate'] as String?,
      value['sdpMid'] as String?,
      (value['sdpMLineIndex'] as num?)?.toInt(),
    );
    // Candidates can arrive before the offer/answer: keep them until then.
    if (_remoteDescriptionSet) {
      await _pc?.addCandidate(candidate);
    } else {
      _pendingCandidates.add(candidate);
    }
  }

  /// Hangs up, closes the camera and removes the signaling data.
  Future<void> close({bool removeSignaling = false}) async {
    if (_closed) return;
    _closed = true;
    for (final sub in _subs) {
      await sub.cancel();
    }
    final pc = _pc;
    _pc = null;
    await pc?.close();
    // dispose() (not only close()) lets flutter_webrtc leave call mode.
    await pc?.dispose();
    final stream = _localStream;
    _localStream = null;
    if (stream != null) {
      for (final track in stream.getTracks()) {
        await track.stop();
      }
      await stream.dispose();
    }
    if (removeSignaling) await signaling.remove();
    _remoteCtl.add(null);
    _statusCtl.add(CallStatus.closed);
    await _remoteCtl.close();
    await _statusCtl.close();
  }
}
