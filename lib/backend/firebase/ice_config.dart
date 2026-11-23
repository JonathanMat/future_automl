/// STUN/TURN servers for WebRTC.
///
/// STUN (free, Google) lets two phones find each other. On mobile data a
/// direct connection often fails, then the TURN server relays the video.
/// Get free TURN credentials from Metered (metered.ca) or Cloudflare and pass
/// them at build time, so they don't end up in git:
///
/// ```
/// flutter run --dart-define=TURN_URL=turn:global.relay.metered.ca:443?transport=tcp \
///             --dart-define=TURN_USERNAME=xxx --dart-define=TURN_CREDENTIAL=yyy
/// ```
class IceConfig {
  const IceConfig({
    this.stunUrls = const [
      'stun:stun.l.google.com:19302',
      'stun:stun1.l.google.com:19302',
    ],
    this.turnUrl = const String.fromEnvironment('TURN_URL'),
    this.turnUsername = const String.fromEnvironment('TURN_USERNAME'),
    this.turnCredential = const String.fromEnvironment('TURN_CREDENTIAL'),
  });

  final List<String> stunUrls;
  final String turnUrl;
  final String turnUsername;
  final String turnCredential;

  bool get hasTurn => turnUrl.isNotEmpty;

  Map<String, dynamic> toPeerConnectionConfig() => {
        'iceServers': [
          {'urls': stunUrls},
          if (hasTurn)
            {
              'urls': turnUrl.split(','),
              'username': turnUsername,
              'credential': turnCredential,
            },
        ],
        'sdpSemantics': 'unified-plan',
      };
}
