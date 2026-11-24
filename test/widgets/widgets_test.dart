import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spell_duel/main.dart';
import 'package:spell_duel/models/game_rules.dart';
import 'package:spell_duel/providers/profile_provider.dart';
import 'package:spell_duel/services/game/mock_game_backend.dart';
import 'package:spell_duel/services/storage/local_storage_service.dart';

import '../services/game_provider_test.dart' show FakeCameraPermission;
import 'package:spell_duel/services/permissions/camera_permission_service.dart';
import 'package:spell_duel/theme/app_text_styles.dart';
import 'package:spell_duel/widgets/duel/spell_card_grid.dart';
import 'package:spell_duel/widgets/generic/chunky_button.dart';

/// Pumps frames for [d] without waiting for endless spinners to settle.
Future<void> _pumpFor(WidgetTester tester, Duration d) async {
  const step = Duration(milliseconds: 100);
  for (var t = Duration.zero; t < d; t += step) {
    await tester.pump(step);
  }
}

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

void main() {
  setUpAll(() => AppTextStyles.useGoogleFonts = false);

  testWidgets('ChunkyButton calls onPressed, not when disabled', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      _wrap(
        Column(
          children: [
            ChunkyButton(label: 'GO', onPressed: () => taps++),
            const ChunkyButton(label: 'NO', onPressed: null),
          ],
        ),
      ),
    );
    await tester.tap(find.text('GO'));
    await tester.tap(find.text('NO'));
    expect(taps, 1);
  });

  testWidgets('SpellCardGrid disables a used shield', (tester) async {
    final cast = <Spell>[];
    await tester.pumpWidget(
      _wrap(
        SizedBox(
          width: 360,
          child: SpellCardGrid(enabled: true, shieldsLeft: 0, onCast: cast.add),
        ),
      ),
    );
    await tester.tap(find.text('Vuur'));
    await tester.tap(find.text('Schild'));
    expect(cast, [Spell.vuur]);
    expect(find.text('0×'), findsOneWidget);
  });

  group('app', () {
    Future<ProfileProvider> profileWith(Map<String, Object> prefs) async {
      SharedPreferences.setMockInitialValues(prefs);
      final p = ProfileProvider(LocalStorageService());
      await p.load();
      return p;
    }

    Future<void> pumpApp(
      WidgetTester tester,
      ProfileProvider profile, {
      CameraPermissionService camera = const CameraPermissionService(
        enabled: false,
      ),
    }) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        SpellDuelApp(
          backend: MockGameBackend(
            useCamera: false,
            botJoinDelay: const Duration(seconds: 1),
          ),
          profile: profile,
          cameraPermission: camera,
        ),
      );
      await tester.pump();
    }

    testWidgets('first launch asks for a name, then shows home', (
      tester,
    ) async {
      final profile = await profileWith({});
      await pumpApp(tester, profile);

      expect(find.text('AAN DE SLAG'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), 'Jonathan');
      await tester.ensureVisible(find.text('AAN DE SLAG'));
      await tester.tap(find.text('AAN DE SLAG'));
      await tester.pumpAndSettle();

      expect(find.text('DUEL STARTEN'), findsOneWidget);
      expect(find.text('Jonathan'), findsOneWidget);
      expect(profile.profile.name, 'Jonathan');
    });

    testWidgets('start a duel: lobby shows the code, then the duel opens', (
      tester,
    ) async {
      final profile = await profileWith({});
      await profile.setName('Jonathan');
      await pumpApp(tester, profile);

      await tester.tap(find.text('DUEL STARTEN'));
      await _pumpFor(tester, const Duration(milliseconds: 600));
      expect(find.text('Duel-kamer'), findsOneWidget);
      expect(find.text('WACHTEN OP TEGENSTANDER'), findsOneWidget);
      expect(find.text('KAMERCODE'), findsOneWidget);
      expect(find.text('T'), findsNWidgets(2));
      expect(find.text('E'), findsOneWidget);
      expect(find.text('S'), findsOneWidget);

      // The bot joins after 1 s and the first round starts.
      await _pumpFor(tester, const Duration(seconds: 1));
      expect(find.text('MAAK JE GEBAAR'), findsOneWidget);
      expect(find.text('Bot'), findsWidgets);

      // Leave cleanly so no timers are left running.
      await tester.binding.handlePopRoute();
      await _pumpFor(tester, const Duration(milliseconds: 500));
      await tester.tap(find.text('Verlaten'));
      await _pumpFor(tester, const Duration(milliseconds: 600));
      expect(find.text('DUEL STARTEN'), findsOneWidget);
    });

    testWidgets('a room that shows up late is not reported as closed', (
      tester,
    ) async {
      // Like Firebase: createRoom returns before the room is reported.
      final profile = await profileWith({});
      await profile.setName('Jonathan');
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        SpellDuelApp(backend: _SlowRoomBackend(), profile: profile),
      );
      await tester.pump();

      await tester.tap(find.text('DUEL STARTEN'));
      await _pumpFor(tester, const Duration(milliseconds: 300));
      expect(find.text('Kamer openen…'), findsOneWidget);
      expect(find.text('De kamer is gesloten.'), findsNothing);

      await _pumpFor(tester, const Duration(seconds: 1));
      expect(find.text('KAMERCODE'), findsOneWidget);
      expect(find.text('Duel-kamer'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await _pumpFor(tester, const Duration(milliseconds: 600));
      expect(find.text('DUEL STARTEN'), findsOneWidget);
    });

    testWidgets('a refused camera shows the settings dialog', (tester) async {
      final profile = await profileWith({});
      await profile.setName('Jonathan');
      await pumpApp(
        tester,
        profile,
        camera: const FakeCameraPermission(MediaAccess.denied),
      );

      await tester.tap(find.text('DUEL STARTEN'));
      await _pumpFor(tester, const Duration(milliseconds: 400));
      expect(find.text('Camera en microfoon nodig'), findsOneWidget);
      expect(find.text('Instellingen openen'), findsOneWidget);
      expect(find.text('Duel-kamer'), findsNothing);

      await tester.tap(find.text('Annuleren'));
      await _pumpFor(tester, const Duration(milliseconds: 400));
      expect(find.text('DUEL STARTEN'), findsOneWidget);
    });

    testWidgets('a bad room code shows a validation error', (tester) async {
      final profile = await profileWith({});
      await profile.setName('Jonathan');
      await pumpApp(tester, profile);

      await tester.enterText(find.byType(TextFormField), 'AB');
      await tester.tap(find.text('Join'));
      await tester.pump();
      expect(find.text('Een kamercode heeft 4 tekens.'), findsOneWidget);
    });
  });
}

/// Reports the new room only after a delay, as Firebase does.
class _SlowRoomBackend extends MockGameBackend {
  _SlowRoomBackend()
    : super(useCamera: false, botJoinDelay: const Duration(minutes: 1));

  @override
  Future<String> createRoom({required String playerName}) async {
    Future<void>.delayed(
      const Duration(milliseconds: 600),
      () => super.createRoom(playerName: playerName),
    );
    return 'TEST';
  }
}
