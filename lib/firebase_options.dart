// PLACEHOLDER – replace by running, in the project root:
//
//   dart pub global activate flutterfire_cli
//   flutterfire configure
//
// That command overwrites this file with the real keys of your Firebase
// project (and adds google-services.json / GoogleService-Info.plist).
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => throw UnsupportedError(
        'Firebase is not configured yet. Run `flutterfire configure` in the '
        'project root, or start with --dart-define=BACKEND=mock.',
      );
}
