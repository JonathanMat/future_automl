import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'navigators/app_router.dart';
import 'providers/account_provider.dart';
import 'providers/friends_provider.dart';
import 'providers/game_provider.dart';
import 'providers/profile_provider.dart';
import 'services/auth/account_service.dart';
import 'services/auth/firebase_account_service.dart';
import 'services/auth/mock_account_service.dart';
import 'services/game/firebase/firebase_game_backend.dart';
import 'services/game/game_backend.dart';
import 'services/game/mock_game_backend.dart';
import 'services/permissions/camera_permission_service.dart';
import 'services/recognition/mediapipe_spell_recognizer.dart';
import 'services/recognition/spell_recognizer.dart';
import 'services/social/firebase_friends_backend.dart';
import 'services/social/friends_backend.dart';
import 'services/social/mock_friends_backend.dart';
import 'services/storage/local_storage_service.dart';
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
  final GameBackend backend;
  final FriendsBackend friends;
  final AccountService account;
  if (_backendKind == 'firebase') {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    backend = FirebaseGameBackend();
    friends = FirebaseFriendsBackend();
    account = FirebaseAccountService();
  } else {
    backend = MockGameBackend(useCamera: _cameraOn);
    friends = MockFriendsBackend();
    account = MockAccountService();
  }

  final profile = ProfileProvider(LocalStorageService());
  await profile.load();

  final isFirebase = _backendKind == 'firebase';
  runApp(
    SpellDuelApp(
      backend: backend,
      friends: friends,
      account: account,
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
    this.recognizer = const ManualSpellRecognizer(),
    this.cameraPermission = const CameraPermissionService(enabled: false),
  });

  final GameBackend backend;
  final ProfileProvider profile;

  /// Defaults to [MockFriendsBackend] (tests, previews).
  final FriendsBackend? friends;

  /// Defaults to [MockAccountService].
  final AccountService? account;
  final SpellRecognizer recognizer;
  final CameraPermissionService cameraPermission;

  @override
  State<SpellDuelApp> createState() => _SpellDuelAppState();
}

class _SpellDuelAppState extends State<SpellDuelApp> {
  late final AppRouter _router = AppRouter(widget.backend);
  // Created here (not lazily) so they sign in at startup and requests
  // show up right away.
  late final FriendsProvider _friends = FriendsProvider(
    widget.friends ?? MockFriendsBackend(),
  )..attach(widget.profile);
  late final AccountProvider _account = AccountProvider(
    widget.account ?? MockAccountService(),
    onUserChanged: _friends.restart,
  );

  @override
  void dispose() {
    _account.dispose();
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
        ChangeNotifierProvider(
          create: (_) => GameProvider(
            backend: widget.backend,
            recognizer: widget.recognizer,
            cameraPermission: widget.cameraPermission,
            onGameFinished: widget.profile.recordGame,
          ),
        ),
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
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: child,
            ),
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
