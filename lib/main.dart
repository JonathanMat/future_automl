import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'navigators/app_router.dart';
import 'providers/account_provider.dart';
import 'providers/challenge_provider.dart';
import 'providers/friends_provider.dart';
import 'providers/game_provider.dart';
import 'providers/profile_provider.dart';
import 'providers/tournament_provider.dart';
import 'services/audio/sfx_service.dart';
import 'services/auth/account_service.dart';
import 'services/auth/firebase_account_service.dart';
import 'services/auth/mock_account_service.dart';
import 'services/face/face_finder.dart';
import 'services/face/mediapipe_face_finder.dart';
import 'services/game/firebase/firebase_game_backend.dart';
import 'services/game/game_backend.dart';
import 'services/game/mock_game_backend.dart';
import 'services/permissions/camera_permission_service.dart';
import 'services/push/push_service.dart';
import 'services/recognition/mediapipe_spell_recognizer.dart';
import 'services/recognition/spell_recognizer.dart';
import 'services/social/firebase_friends_backend.dart';
import 'services/social/friends_backend.dart';
import 'services/social/mock_friends_backend.dart';
import 'services/storage/local_storage_service.dart';
import 'services/tournament/firebase_tournament_backend.dart';
import 'services/tournament/mock_tournament_backend.dart';
import 'services/tournament/tournament_backend.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';
import 'utils/constants.dart';

/// Pick the backend at build time:
///   flutter run                            -> real Firebase + WebRTC
///   flutter run --dart-define=BACKEND=mock -> bot opponent, no Firebase
const _backendKind = String.fromEnvironment(
  'BACKEND',
  defaultValue: 'firebase',
);

/// `--dart-define=CAMERA=off` runs the mock without a camera (simulator,
/// web preview).
const _cameraOn = String.fromEnvironment('CAMERA', defaultValue: 'on') != 'off';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Portrait only: the duel layout (two camera feeds stacked) needs it.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final GameBackend backend;
  final FriendsBackend friends;
  final AccountService account;
  final TournamentBackend tournaments;
  PushService push = const NoPushService();
  if (_backendKind == 'firebase') {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    backend = FirebaseGameBackend();
    final firebaseFriends = FirebaseFriendsBackend();
    friends = firebaseFriends;
    account = FirebaseAccountService(
      discardGuestData: firebaseFriends.deleteMyData,
    );
    push = FirebasePushService();
    tournaments = FirebaseTournamentBackend();
  } else {
    backend = MockGameBackend(useCamera: _cameraOn);
    friends = MockFriendsBackend(seedFriends: MockFriendsBackend.demoFriends);
    account = MockAccountService();
    tournaments = MockTournamentBackend();
  }

  final profile = ProfileProvider(LocalStorageService());
  await profile.load();
  // Loads in the background; effects are silent until it is done.
  SfxService.instance.init();

  final isFirebase = _backendKind == 'firebase';
  // Faces in the killcam photos: only with a real camera.
  if (isFirebase || _cameraOn) FaceFinder.current = MediaPipeFaceFinder();
  runApp(
    SpellDuelApp(
      backend: backend,
      friends: friends,
      account: account,
      tournaments: tournaments,
      push: push,
      profile: profile,
      // The Firebase call sends audio too, so it also needs the microphone.
      cameraPermission: CameraPermissionService(
        enabled: isFirebase || _cameraOn,
        microphone: isFirebase,
      ),
      // The trained MediaPipe model; without a camera, tap to cast.
      recognizer: isFirebase || _cameraOn
          ? MediaPipeSpellRecognizer()
          : const ManualSpellRecognizer(),
    ),
  );
}

class SpellDuelApp extends StatefulWidget {
  const SpellDuelApp({
    super.key,
    required this.backend,
    required this.profile,
    this.friends,
    this.account,
    this.tournaments,
    this.push = const NoPushService(),
    this.recognizer = const ManualSpellRecognizer(),
    this.cameraPermission = const CameraPermissionService(enabled: false),
  });

  final GameBackend backend;
  final ProfileProvider profile;

  /// Defaults to [MockFriendsBackend] (tests, previews).
  final FriendsBackend? friends;

  /// Defaults to [MockAccountService].
  final AccountService? account;

  /// Defaults to [MockTournamentBackend] (with bots).
  final TournamentBackend? tournaments;
  final PushService push;
  final SpellRecognizer recognizer;
  final CameraPermissionService cameraPermission;

  @override
  State<SpellDuelApp> createState() => _SpellDuelAppState();
}

class _SpellDuelAppState extends State<SpellDuelApp>
    with WidgetsBindingObserver {
  late final AppRouter _router = AppRouter(widget.backend);
  // Created here (not lazily) so they sign in at startup and requests
  // show up right away.
  late final FriendsBackend _friendsBackend =
      widget.friends ?? MockFriendsBackend();
  late final FriendsProvider _friends = FriendsProvider(_friendsBackend)
    ..attach(widget.profile);
  late final GameProvider _game = GameProvider(
    backend: widget.backend,
    recognizer: widget.recognizer,
    cameraPermission: widget.cameraPermission,
    onGameFinished: (summary) async {
      // Opponent left: no winner in the room (iWon null).
      final iWon = _game.state.iWon;
      await widget.profile.recordGame(
        summary,
        vsFriend:
            summary.opponentUid != null &&
            _friends.isFriend(summary.opponentUid!),
      );
      await _tournament.onGameFinished(summary, iWon: iWon);
    },
  );
  late final TournamentProvider _tournament = TournamentProvider(
    backend: widget.tournaments ?? MockTournamentBackend(),
    friends: _friends,
    game: _game,
    profile: widget.profile,
  );
  late final ChallengeProvider _challenges = ChallengeProvider(
    backend: _friendsBackend,
    friends: _friends,
    game: _game,
    push: widget.push,
  );
  late final AccountProvider _account = AccountProvider(
    widget.account ?? MockAccountService(),
    onUserChanged: _friends.restart,
    beforeSignOut: _challenges.unregisterPush,
    deleteData: () async {
      try {
        await _friends.deleteServerData();
      } on FriendsException catch (e) {
        throw AccountException(
          'Je gegevens verwijderen lukte niet: ${e.message}',
        );
      }
    },
    onDeleted: () async {
      await _friends.forget();
      await widget.profile.wipe();
    },
  );

  @override
  void initState() {
    super.initState();
    _applySettings();
    widget.profile.addListener(_applySettings);
    WidgetsBinding.instance.addObserver(this);
    _game.addListener(_onGame);
  }

  /// Back from the background: Android may have stopped the sound engine.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      SfxService.instance.ensureRunning();
    }
  }

  bool _wasInRoom = false;
  Timer? _sfxRestart;

  /// A call just ended: restart the sound engine once Android has left
  /// call mode (see [SfxService.restart]).
  void _onGame() {
    final inRoom = _game.inRoom;
    if (_wasInRoom && !inRoom) {
      _sfxRestart?.cancel();
      _sfxRestart = Timer(const Duration(milliseconds: 800), () {
        if (!_game.inRoom) SfxService.instance.restart();
      });
    }
    _wasInRoom = inRoom;
  }

  void _applySettings() {
    widget.backend.voiceChat = widget.profile.voiceChat;
    SfxService.instance.enabled = widget.profile.soundEffects;
  }

  @override
  void dispose() {
    widget.profile.removeListener(_applySettings);
    WidgetsBinding.instance.removeObserver(this);
    _game.removeListener(_onGame);
    _sfxRestart?.cancel();
    _account.dispose();
    _tournament.dispose();
    _challenges.dispose();
    _game.dispose();
    _friends.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: widget.profile),
        ChangeNotifierProvider.value(value: _friends),
        ChangeNotifierProvider.value(value: _account),
        ChangeNotifierProvider.value(value: _game),
        ChangeNotifierProvider.value(value: _challenges),
        ChangeNotifierProvider.value(value: _tournament),
      ],
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.dark,
        initialRoute: widget.profile.profile.hasName
            ? AppRoutes.home
            : AppRoutes.onboarding,
        onGenerateRoute: _router.onGenerateRoute,
        // The design is for phones: keep it phone-width on tablets.
        builder: (context, child) => ColoredBox(
          color: AppColors.backdrop,
          child: ValueListenableBuilder<bool>(
            valueListenable: AppSpacing.fullWidth,
            builder: (context, full, child) => Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: full ? double.infinity : 520,
                ),
                child: child,
              ),
            ),
            child: child,
          ),
        ),
        // One route only: by default "/welkom" would also push "/" under it.
        onGenerateInitialRoutes: (name) => [
          _router.onGenerateRoute(RouteSettings(name: name)),
        ],
      ),
    );
  }
}
