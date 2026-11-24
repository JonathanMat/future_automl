import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'backend/firebase/firebase_game_backend.dart';
import 'backend/game_backend.dart';
import 'backend/mock_game_backend.dart';
import 'debug/backend_debug_page.dart';
import 'firebase_options.dart';

/// Pick the backend at build time:
///   flutter run                               -> mock (bot, no Firebase)
///   flutter run --dart-define=BACKEND=firebase -> real Firebase + WebRTC
const _backendKind = String.fromEnvironment('BACKEND', defaultValue: 'mock');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final GameBackend backend;
  if (_backendKind == 'firebase') {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    backend = FirebaseGameBackend();
  } else {
    backend = MockGameBackend();
  }
  runApp(SpellDuelApp(backend: backend));
}

class SpellDuelApp extends StatelessWidget {
  const SpellDuelApp({super.key, required this.backend});

  final GameBackend backend;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Spell Duel',
      theme: ThemeData(colorSchemeSeed: Colors.deepPurple, useMaterial3: true),
      darkTheme: ThemeData(
          colorSchemeSeed: Colors.deepPurple,
          brightness: Brightness.dark,
          useMaterial3: true),
      // TODO(frontend): replace with the real game UI.
      home: BackendDebugPage(backend: backend),
    );
  }
}
