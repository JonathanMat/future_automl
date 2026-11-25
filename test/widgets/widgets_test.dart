import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spell_duel/models/duel_summary.dart';
import 'package:spell_duel/widgets/generic/avatar_tile.dart';
import 'package:spell_duel/main.dart';
import 'package:spell_duel/models/game_rules.dart';
import 'package:spell_duel/providers/profile_provider.dart';
import 'package:spell_duel/services/game/mock_game_backend.dart';
import 'package:spell_duel/services/social/friends_backend.dart';
import 'package:spell_duel/services/social/mock_friends_backend.dart';
import 'package:spell_duel/services/storage/local_storage_service.dart';

import '../services/game_provider_test.dart' show FakeCameraPermission;
import 'package:spell_duel/services/permissions/camera_permission_service.dart';
import 'package:spell_duel/theme/app_text_styles.dart';
import 'package:spell_duel/widgets/duel/emotes/emote_burst.dart';
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
          friends: MockFriendsBackend(),
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
      expect(
        find.textContaining('Jonathan', findRichText: true),
        findsOneWidget,
      );
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

    testWidgets('send an emote from the duel', (tester) async {
      final profile = await profileWith({});
      await profile.setName('Jonathan');
      await pumpApp(tester, profile);

      await tester.tap(find.text('DUEL STARTEN'));
      await _pumpFor(tester, const Duration(milliseconds: 1600));
      expect(find.text('MAAK JE GEBAAR'), findsOneWidget);
      // Let the "VS" intro finish: it covers the screen until then.
      await _pumpFor(tester, const Duration(seconds: 3));

      await tester.tap(find.byTooltip('Emotes'));
      await _pumpFor(tester, const Duration(milliseconds: 300));
      expect(find.text('Goed gespeeld'), findsOneWidget);
      await tester.tap(find.text('GG'));
      await _pumpFor(tester, const Duration(milliseconds: 300));

      // The picker closed and your emote pops up on your camera.
      expect(find.text('Goed gespeeld'), findsNothing);
      expect(find.byType(EmoteBurst), findsWidgets);
      await _pumpFor(tester, const Duration(seconds: 4));
      expect(tester.takeException(), isNull);

      await tester.binding.handlePopRoute();
      await _pumpFor(tester, const Duration(milliseconds: 500));
      await tester.tap(find.text('Verlaten'));
      await _pumpFor(tester, const Duration(milliseconds: 600));
    });

    testWidgets('after the last round the result opens; rematch needs a yes', (
      tester,
    ) async {
      // The mock times rounds with the real clock (DateTime.now()), so let
      // real time pass along with the test's fake time.
      Future<void> realTime(Duration d) async {
        const step = Duration(milliseconds: 50);
        for (var t = Duration.zero; t < d; t += step) {
          await tester.runAsync(() => Future<void>.delayed(step));
          await tester.pump(step);
        }
      }

      final profile = await profileWith({});
      await profile.setName('Jonathan');
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        SpellDuelApp(
          backend: MockGameBackend(
            useCamera: false,
            botJoinDelay: const Duration(milliseconds: 100),
            botEmotes: false,
            // You ask for the rematch here; the bot asking first would
            // turn the button into "REVANCHE ACCEPTEREN".
            botAsksRematch: false,
            random: Random(2),
            config: const GameConfig(
              countdown: Duration(milliseconds: 300),
              castWindow: Duration(milliseconds: 1200),
              resultPause: Duration(milliseconds: 500),
              roundLead: Duration(milliseconds: 100),
            ),
          ),
          profile: profile,
          friends: MockFriendsBackend(),
        ),
      );
      await tester.pump();

      // Never cast: casting nothing loses every round, so the game ends.
      await tester.tap(find.text('DUEL STARTEN'));
      for (var i = 0; i < 300; i++) {
        if (find.text('Je hebt verloren').evaluate().isNotEmpty) break;
        await realTime(const Duration(milliseconds: 100));
      }
      expect(find.text('Je hebt verloren'), findsOneWidget);

      // No tap needed: the result screen opens after the final effect.
      await realTime(const Duration(seconds: 4));
      expect(find.text('REVANCHE'), findsOneWidget);

      // Asking is not starting: wait for the opponent's yes.
      await tester.tap(find.text('REVANCHE'));
      await tester.pump();
      expect(find.text('WACHTEN…'), findsOneWidget);
      await realTime(const Duration(milliseconds: 1500));
      expect(find.text('REVANCHE'), findsNothing);
      // A clean new game: full lives, no replay of the old final round.
      expect(find.text('Je hebt verloren'), findsNothing);
      expect(find.text('Volgende ronde start zo…'), findsNothing);

      await tester.binding.handlePopRoute();
      await _pumpFor(tester, const Duration(milliseconds: 500));
      await tester.tap(find.text('Verlaten'));
      await _pumpFor(tester, const Duration(milliseconds: 600));
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

    testWidgets('friends page: add by code, then on the scorebord', (
      tester,
    ) async {
      final profile = await profileWith({});
      await profile.setName('Jonathan');
      await pumpApp(tester, profile);

      await tester.tap(find.text('Vrienden').last);
      await tester.pumpAndSettle();
      expect(find.text('JOUW VRIENDCODE'), findsOneWidget);
      expect(find.text('TEST42'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), 'abc234');
      await tester.tap(find.text('Voeg toe'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Vriend ABC234', findRichText: true),
        findsOneWidget,
      );

      await tester.tap(find.text('Scorebord').last);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Vriend ABC234', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('a challenge shows on home and can be declined', (
      tester,
    ) async {
      final profile = await profileWith({});
      await profile.setName('Jonathan');
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        SpellDuelApp(
          backend: MockGameBackend(useCamera: false),
          profile: profile,
          friends: MockFriendsBackend(
            seedInvites: [
              ChallengeInvite(
                fromUid: 'lotte',
                name: 'Lotte',
                roomCode: 'ABCD',
                sentAt: DateTime.now(),
              ),
            ],
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(
        find.textContaining('Lotte daagt je uit!', findRichText: true),
        findsOneWidget,
      );
      await tester.tap(find.text('Weiger'));
      await tester.pump();
      expect(
        find.textContaining('Lotte daagt je uit!', findRichText: true),
        findsNothing,
      );
    });

    testWidgets('challenging a friend shows who you are waiting for', (
      tester,
    ) async {
      final profile = await profileWith({});
      await profile.setName('Jonathan');
      await pumpApp(tester, profile);

      await tester.tap(find.text('Vrienden').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'abc234');
      await tester.tap(find.text('Voeg toe'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Duel'));
      await _pumpFor(tester, const Duration(milliseconds: 500));
      expect(find.text('Uitdaging'), findsOneWidget);
      expect(
        find.textContaining('Wachten op Vriend ABC234', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('UITGENODIGD'), findsOneWidget);
      expect(find.text('WACHTEN OP VRIEND ABC234'), findsOneWidget);

      // Leave before the bot joins.
      await tester.binding.handlePopRoute();
      await _pumpFor(tester, const Duration(milliseconds: 600));
      expect(find.text('Uitdaging'), findsNothing);
    });

    testWidgets('tapping a friend opens their profile with remove', (
      tester,
    ) async {
      final profile = await profileWith({});
      await profile.setName('Jonathan');
      await pumpApp(tester, profile);

      await tester.tap(find.text('Vrienden').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'abc234');
      await tester.tap(find.text('Voeg toe'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.textContaining('Vriend ABC234', findRichText: true),
      );
      await tester.pumpAndSettle();
      expect(find.text('Profiel'), findsOneWidget);
      expect(find.text('VRIEND'), findsOneWidget);
      expect(find.text('DUEL VRIEND ABC234'), findsOneWidget);
      expect(find.text('Verwijder als vriend'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Snelste spreuk'), 200);
      expect(find.text('HOOGTEPUNTEN'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.scrollUntilVisible(find.text('Verwijder als vriend'), -200);
      await tester.tap(find.text('Verwijder als vriend'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Verwijderen'));
      await tester.pumpAndSettle();
      expect(find.text('Vriend ABC234 is geen vriend meer.'), findsOneWidget);
      expect(find.textContaining('Nog geen vrienden.'), findsOneWidget);
    });

    testWidgets('tapping your name on home opens your profile', (tester) async {
      final profile = await profileWith({});
      await profile.setName('Jonathan');
      await pumpApp(tester, profile);

      await tester.tap(find.textContaining('Jonathan', findRichText: true));
      await tester.pumpAndSettle();
      expect(find.text('Jouw profiel'), findsOneWidget);
      expect(find.text('JIJ'), findsOneWidget);
      expect(find.text('RECORD'), findsOneWidget);
      expect(find.text('Verwijder als vriend'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Nog geen duels gespeeld.'),
        200,
        // The profile page's list (home's is still below it).
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('GESCHIEDENIS'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('your profile lists the duels you played', (tester) async {
      final profile = await profileWith({});
      await profile.setName('Jonathan');
      for (var i = 0; i < 7; i++) {
        await profile.recordGame(
          DuelSummary(
            opponentName: 'Tegenstander $i',
            won: i.isEven,
            rounds: const [],
            xpGained: 10,
          ),
          at: DateTime(2026, 11, 1, i),
        );
      }
      await pumpApp(tester, profile);

      // The avatar at the top left of home opens your profile.
      await tester.tap(find.byType(AvatarTile).first);
      await tester.pumpAndSettle();
      expect(find.text('Jouw profiel'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Toon alle 7 duels'),
        200,
        // The profile page's list (home's is still below it).
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('vs Tegenstander 6'), findsOneWidget);
      expect(find.text('vs Tegenstander 0'), findsNothing);

      await tester.ensureVisible(find.text('Toon alle 7 duels'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Toon alle 7 duels'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Toon minder'));
      await tester.pumpAndSettle();
      expect(find.text('vs Tegenstander 0'), findsOneWidget);
      expect(find.text('Toon minder'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the voice chat setting reaches the game backend', (
      tester,
    ) async {
      final profile = await profileWith({});
      await profile.setName('Jonathan');
      final backend = MockGameBackend(useCamera: false);
      await tester.pumpWidget(SpellDuelApp(backend: backend, profile: profile));
      await tester.pump();
      expect(backend.voiceChat, isTrue);
      await profile.setVoiceChat(false);
      expect(backend.voiceChat, isFalse);
    });

    testWidgets('settings shows a name loaded from another account', (
      tester,
    ) async {
      final profile = await profileWith({});
      await profile.setName('Jonathan');
      await pumpApp(tester, profile);

      await tester.tap(find.byTooltip('Instellingen'));
      await _pumpFor(tester, const Duration(milliseconds: 600));
      expect(find.widgetWithText(TextFormField, 'Jonathan'), findsOneWidget);

      // Like logging in with Google into an account with its own name.
      await profile.setName('Lotte');
      await tester.pump();
      expect(find.widgetWithText(TextFormField, 'Lotte'), findsOneWidget);
    });

    testWidgets('deleting the account goes back to the welcome screen', (
      tester,
    ) async {
      final profile = await profileWith({});
      await profile.setName('Jonathan');
      await pumpApp(tester, profile);

      await tester.tap(find.byTooltip('Instellingen'));
      await _pumpFor(tester, const Duration(milliseconds: 600));
      expect(find.text('Statistieken wissen'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Account verwijderen'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Account verwijderen'));
      await tester.pumpAndSettle();
      expect(find.text('Account verwijderen?'), findsOneWidget);

      await tester.tap(find.text('Verwijderen'));
      await _pumpFor(tester, const Duration(milliseconds: 800));
      expect(find.text('AAN DE SLAG'), findsOneWidget);
      expect(find.text('Je account is verwijderd.'), findsOneWidget);
      expect(profile.profile.hasName, isFalse);
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
