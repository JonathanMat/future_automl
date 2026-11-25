import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spell_duel/main.dart';
import 'package:spell_duel/models/tournament.dart';
import 'package:spell_duel/providers/game_provider.dart';
import 'package:spell_duel/providers/profile_provider.dart';
import 'package:spell_duel/providers/tournament_provider.dart';
import 'package:spell_duel/screens/tournament/tournament_screen.dart';
import 'package:spell_duel/services/game/mock_game_backend.dart';
import 'package:spell_duel/services/storage/local_storage_service.dart';
import 'package:spell_duel/services/tournament/mock_tournament_backend.dart';
import 'package:spell_duel/theme/app_text_styles.dart';
import 'package:spell_duel/widgets/tournament/bracket_view.dart';

/// The whole tournament through the UI, on one phone with bots, in debug
/// mode so layout problems fail here: waiting room, odd numbers (a bye),
/// the draw, the call-up, a real room, the host deciding, the champion.
void main() {
  setUpAll(() => AppTextStyles.useGoogleFonts = false);

  Future<void> pumpFor(WidgetTester tester, Duration d) async {
    const step = Duration(milliseconds: 100);
    for (var t = Duration.zero; t < d; t += step) {
      await tester.pump(step);
    }
  }

  Future<void> pumpUntil(
    WidgetTester tester,
    bool Function() done, {
    Duration max = const Duration(seconds: 30),
  }) async {
    const step = Duration(milliseconds: 100);
    for (var t = Duration.zero; t < max && !done(); t += step) {
      await tester.pump(step);
    }
    expect(done(), isTrue, reason: 'timed out');
  }

  void phoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  for (final bots in [6, 4, 1]) {
    testWidgets('${bots + 1} players: lobby, draw, call-up, champion', (
      tester,
    ) async {
      phoneSize(tester);
      SharedPreferences.setMockInitialValues({});
      final profile = ProfileProvider(LocalStorageService());
      await profile.load();
      await profile.setName('Jonathan');
      final tournaments = MockTournamentBackend(
        random: Random(bots),
        botMatchTime: (
          min: const Duration(milliseconds: 800),
          max: const Duration(milliseconds: 1500),
        ),
        botRoomDelay: const Duration(milliseconds: 300),
      );

      await tester.pumpWidget(
        SpellDuelApp(
          backend: MockGameBackend(
            useCamera: false,
            botJoinDelay: const Duration(milliseconds: 300),
          ),
          profile: profile,
          tournaments: tournaments,
        ),
      );
      await pumpFor(tester, const Duration(milliseconds: 500));

      // Home → Toernooi.
      await tester.scrollUntilVisible(
        find.text('TOERNOOI'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('TOERNOOI'));
      await pumpFor(tester, const Duration(milliseconds: 600));
      expect(find.text('Speel met je vrienden'), findsOneWidget);

      await tester.tap(find.text('TOERNOOI MAKEN'));
      await pumpFor(tester, const Duration(milliseconds: 600));
      expect(find.text('TOERNOOICODE'), findsOneWidget);
      expect(find.text('WACHTEN OP SPELERS…'), findsOneWidget);

      final context = tester.element(find.byType(TournamentScreen));
      final t = context.read<TournamentProvider>();
      final game = context.read<GameProvider>();
      final me = t.myUid!;

      for (var added = 0; added < bots; added += 3) {
        await tester.tap(find.text('+3 test-bots'));
        await pumpFor(tester, const Duration(milliseconds: 700));
      }
      if (bots % 3 != 0) {
        // Remove the extra bots again: e.g. 4 bots, not 6.
        final extra = t.data!.players.values.where((p) => p.bot).toList()
          ..sort((a, b) => a.joinedAt.compareTo(b.joinedAt));
        for (final p in extra.skip(bots)) {
          await tournaments.leave(t.code!, p.uid, isHost: false);
        }
        await pumpFor(tester, const Duration(milliseconds: 700));
      }
      final n = bots + 1;
      expect(find.text('$n/$maxTournamentPlayers'), findsOneWidget);
      final byes = Bracket.seatsFor(n) - n;
      expect(find.text('$byes'), findsWidgets);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('START TOERNOOI'));
      await pumpFor(tester, const Duration(milliseconds: 600));
      expect(find.text('DE LOTING'), findsOneWidget);
      await pumpFor(tester, const Duration(seconds: 5));
      expect(find.text('DE LOTING'), findsNothing);
      expect(find.text('SCHEMA'), findsOneWidget);
      expect(find.byType(BracketMatchCard), findsWidgets);
      expect(tester.takeException(), isNull);

      // Wait for the first call-up (after a bye that is round 2).
      await pumpUntil(
        tester,
        () => find.text('JOUW DUEL!').evaluate().isNotEmpty,
      );
      await pumpFor(tester, const Duration(seconds: 6));
      expect(game.inRoom, isFalse);
      expect(find.text('Winst opeisen'), findsNothing);
      expect(tester.takeException(), isNull);

      // Play: a real room opens (the bot may open it first).
      await tester.tap(find.text('SPEEL NU'));
      await pumpUntil(tester, () => game.inRoom);
      await pumpFor(tester, const Duration(milliseconds: 800));
      expect(t.inMatch, isTrue);
      expect(
        find.byType(TournamentScreen, skipOffstage: false),
        findsOneWidget,
      );

      // Leave the room: back on the bracket, the match still open, and no
      // second call-up for it.
      await game.leave();
      await pumpFor(tester, const Duration(seconds: 2));
      expect(t.inMatch, isFalse);
      expect(find.text('SCHEMA'), findsOneWidget);
      expect(find.text('JOUW DUEL!'), findsNothing);
      expect(find.text('SPEEL DUEL'), findsOneWidget);

      // Host: decide your own match with the sheet.
      final card = find.byWidgetPredicate(
        (w) => w is BracketMatchCard && w.mine && w.match.isReady,
      );
      expect(card, findsOneWidget);
      await tester.tap(card, warnIfMissed: false);
      await pumpFor(tester, const Duration(milliseconds: 600));
      expect(find.text('Wie gaat door?'), findsOneWidget);
      await tester.tap(find.text('Jonathan wint'));
      await pumpFor(tester, const Duration(milliseconds: 800));

      // The rest of your matches, until you are champion.
      while (t.champion == null) {
        final m = t.myMatch;
        if (m != null && m.isReady) {
          // Close the call-up and win.
          if (find.text('Nog even niet').evaluate().isNotEmpty) {
            await tester.tap(find.text('Nog even niet'));
          }
          await t.decide(m.id, me);
        }
        await pumpFor(tester, const Duration(milliseconds: 300));
      }
      await pumpUntil(
        tester,
        () => find.text('JIJ BENT KAMPIOEN!').evaluate().isNotEmpty,
      );
      await pumpFor(tester, const Duration(seconds: 2));
      expect(
        find.text('+${ProfileProvider.tournamentWinXp} XP'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      expect(t.status, TournamentStatus.finished);

      await tester.tap(find.text('BEKIJK SCHEMA'));
      await pumpFor(tester, const Duration(seconds: 2));
      expect(find.text('Toernooiwinnaar'), findsWidgets);
      expect(tester.takeException(), isNull);
      expect(profile.profile.stats.tournamentWins, 1);

      // Nothing keeps running after the app goes away.
      await tester.pumpWidget(const SizedBox());
      await tournaments.dispose();
      await pumpFor(tester, const Duration(seconds: 1));
    });
  }

  testWidgets('final decided while you are in a duel: the champion shows '
      'when you come back', (tester) async {
    phoneSize(tester);
    SharedPreferences.setMockInitialValues({});
    final profile = ProfileProvider(LocalStorageService());
    await profile.load();
    await profile.setName('Jonathan');
    final tournaments = MockTournamentBackend(
      random: Random(11),
      botMatchTime: (
        min: const Duration(milliseconds: 500),
        max: const Duration(milliseconds: 900),
      ),
      botRoomDelay: const Duration(milliseconds: 300),
    );
    await tester.pumpWidget(
      SpellDuelApp(
        backend: MockGameBackend(
          useCamera: false,
          botJoinDelay: const Duration(milliseconds: 300),
        ),
        profile: profile,
        tournaments: tournaments,
      ),
    );
    await pumpFor(tester, const Duration(milliseconds: 500));
    Navigator.of(
      tester.element(find.byType(Navigator).first),
    ).pushNamed('/toernooi');
    await pumpFor(tester, const Duration(milliseconds: 600));
    await tester.tap(find.text('TOERNOOI MAKEN'));
    await pumpFor(tester, const Duration(milliseconds: 600));
    final t = tester
        .element(find.byType(TournamentScreen))
        .read<TournamentProvider>();
    final game = tester
        .element(find.byType(TournamentScreen))
        .read<GameProvider>();
    await t.addBots(3);
    await pumpFor(tester, const Duration(milliseconds: 300));
    await tester.tap(find.text('START TOERNOOI'));
    await pumpFor(tester, const Duration(seconds: 5));
    await pumpUntil(
      tester,
      () => find.text('JOUW DUEL!').evaluate().isNotEmpty,
    );
    await tester.tap(find.text('SPEEL NU'));
    await pumpUntil(tester, () => game.inRoom);
    await pumpFor(tester, const Duration(milliseconds: 800));

    // Meanwhile: you lose this one (host decides) and the bots finish.
    final m = t.myMatch!;
    await t.decide(m.id, m.opponentOf(t.myUid!)!);
    await pumpUntil(tester, () => t.champion != null);
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(find.text('KAMPIOEN!'), findsNothing);

    await game.leave();
    await pumpUntil(tester, () => find.text('KAMPIOEN!').evaluate().isNotEmpty);
    await pumpFor(tester, const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('BEKIJK SCHEMA'));
    await pumpFor(tester, const Duration(seconds: 1));
    expect(find.text('KAMPIOEN!'), findsNothing);

    // Leaving and opening the screen again does not celebrate twice.
    Navigator.of(tester.element(find.byType(TournamentScreen))).pop();
    await pumpFor(tester, const Duration(milliseconds: 600));
    await tester.scrollUntilVisible(
      find.text('TOERNOOI AFGELOPEN'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('TOERNOOI AFGELOPEN'), findsOneWidget);
    await tester.tap(find.text('TOERNOOI AFGELOPEN'));
    await pumpFor(tester, const Duration(seconds: 1));
    expect(find.text('KAMPIOEN!'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    await tournaments.dispose();
    await pumpFor(tester, const Duration(seconds: 1));
  });

  testWidgets('beamer view: join board, then the full bracket', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final profile = ProfileProvider(LocalStorageService());
    await profile.load();
    await profile.setName('Juf Ann');
    final tournaments = MockTournamentBackend(random: Random(3));

    await tester.pumpWidget(
      SpellDuelApp(
        backend: MockGameBackend(useCamera: false),
        profile: profile,
        tournaments: tournaments,
      ),
    );
    await pumpFor(tester, const Duration(milliseconds: 500));
    final context = tester.element(find.byType(Navigator).first);
    Navigator.of(context).pushNamed('/toernooi');
    await pumpFor(tester, const Duration(milliseconds: 600));
    await tester.tap(find.text('TOERNOOI MAKEN'));
    await pumpFor(tester, const Duration(milliseconds: 600));
    final t = tester
        .element(find.byType(TournamentScreen))
        .read<TournamentProvider>();
    await t.addBots(10);
    await pumpFor(tester, const Duration(milliseconds: 300));

    await tester.tap(find.byTooltip('Beamer-weergave'));
    await pumpFor(tester, const Duration(seconds: 1));
    expect(find.text('Doe mee: Toernooi → Meedoen'), findsOneWidget);
    expect(find.text('11 spelers'), findsOneWidget);

    await t.start();
    await pumpFor(tester, const Duration(seconds: 1));
    expect(find.byType(BracketView), findsOneWidget);
    expect(find.text('ACHTSTE FINALE'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    await tournaments.dispose();
    await pumpFor(tester, const Duration(seconds: 1));
  });
}
