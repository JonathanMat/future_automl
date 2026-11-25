import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spell_duel/main.dart';
import 'package:spell_duel/models/duel_summary.dart';
import 'package:spell_duel/models/game_rules.dart';
import 'package:spell_duel/models/game_state.dart';
import 'package:spell_duel/models/player_profile.dart';
import 'package:spell_duel/providers/profile_provider.dart';
import 'package:spell_duel/services/game/mock_game_backend.dart';
import 'package:spell_duel/services/storage/local_storage_service.dart';
import 'package:spell_duel/theme/app_text_styles.dart';
import 'package:spell_duel/models/badge.dart';
import 'package:spell_duel/models/spell_prediction.dart';
import 'package:spell_duel/screens/badges/badges_screen.dart';
import 'package:spell_duel/widgets/badges/badge_unlock_overlay.dart';
import 'package:spell_duel/widgets/duel/duel_intro.dart';
import 'package:spell_duel/widgets/duel/opponent_away_overlay.dart';
import 'package:spell_duel/providers/challenge_provider.dart';
import 'package:spell_duel/widgets/lobby/challenge_waiting_card.dart';
import 'package:provider/provider.dart';
import 'package:spell_duel/widgets/duel/cast_meter.dart';
import 'package:spell_duel/widgets/result/duel_stats_card.dart';
import 'package:spell_duel/widgets/result/result_hero.dart';
import 'package:spell_duel/widgets/result/reward_cards.dart';

/// Opens screens the flow tests don't reach, in debug mode, so layout
/// assertions (which release builds skip) fail here instead of on a phone.
void main() {
  setUpAll(() => AppTextStyles.useGoogleFonts = false);

  Future<void> pumpFor(WidgetTester tester, Duration d) async {
    const step = Duration(milliseconds: 100);
    for (var t = Duration.zero; t < d; t += step) {
      await tester.pump(step);
    }
  }

  void phoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  testWidgets('the result screen content lays out', (tester) async {
    phoneSize(tester);
    final r = resolveRound(hostSpell: Spell.vuur, guestSpell: Spell.ijs);
    final summary = DuelSummary(
      opponentName: 'Bot',
      won: false,
      xpGained: 40,
      rounds: [
        RoundRecord(
          result: RoundResult(
            round: 1,
            mySpell: r.hostSpell,
            opponentSpell: r.guestSpell,
            outcome: RoundOutcome.lose,
            reason: r.reason,
          ),
          castLatency: const Duration(milliseconds: 700),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              ResultHero(won: false, opponentName: 'Bot', rounds: 1),
              RewardCards(
                profile: const PlayerProfile(xp: 40, losses: 1),
                xpGained: 40,
                won: false,
              ),
              DuelStatsCard(summary: summary),
            ],
          ),
        ),
      ),
    );
    // Play the whole lose animation (sinking, swinging, rain).
    await pumpFor(tester, const Duration(seconds: 4));
    expect(tester.takeException(), isNull);
    // The title is drawn letter by letter; screen readers get the word.
    final semantics = tester.ensureSemantics();
    await tester.pump();
    expect(find.bySemanticsLabel('Verloren'), findsOneWidget);
    semantics.dispose();
    expect(find.text('+40 XP'), findsOneWidget);
    expect(find.text('JOUW DUEL'), findsOneWidget);
  });

  testWidgets('the win animation plays to the end without errors', (
    tester,
  ) async {
    phoneSize(tester);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: ResultHero(won: true, opponentName: 'Bot', rounds: 3),
          ),
        ),
      ),
    );
    // Confetti, rays and the letters popping in.
    await pumpFor(tester, const Duration(seconds: 4));
    expect(tester.takeException(), isNull);
    final semantics = tester.ensureSemantics();
    await tester.pump();
    expect(find.bySemanticsLabel('Gewonnen!'), findsOneWidget);
    semantics.dispose();
    expect(find.text('Je versloeg Bot in 3 rondes.'), findsOneWidget);
  });

  testWidgets('tabs, settings and the effects preview open cleanly', (
    tester,
  ) async {
    phoneSize(tester);
    SharedPreferences.setMockInitialValues({});
    final profile = ProfileProvider(LocalStorageService());
    await profile.load();
    await profile.setName('Jonathan');

    await tester.pumpWidget(
      SpellDuelApp(
        backend: MockGameBackend(useCamera: false),
        profile: profile,
      ),
    );
    await pumpFor(tester, const Duration(milliseconds: 500));

    await tester.tap(find.text('Vrienden'));
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(find.text('JOUW VRIENDCODE'), findsOneWidget);

    await tester.tap(find.text('Scorebord').last);
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(find.text('Global'), findsOneWidget);
    await tester.tap(find.text('Global'));
    await pumpFor(tester, const Duration(milliseconds: 500));
    // Switching back and forth must not listen to the stream twice.
    await tester.tap(find.text('Vrienden').first);
    await pumpFor(tester, const Duration(milliseconds: 300));
    await tester.tap(find.text('Global'));
    await pumpFor(tester, const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Home'));
    await pumpFor(tester, const Duration(milliseconds: 500));
    await tester.tap(find.byTooltip('Instellingen'));
    await pumpFor(tester, const Duration(milliseconds: 600));
    expect(find.text('PROFIEL'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Spreuk-effecten bekijken'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Spreuk-effecten bekijken'));
    await pumpFor(tester, const Duration(milliseconds: 600));
    await tester.tap(find.text('IJs bevriest'));
    await pumpFor(tester, const Duration(seconds: 4));

    expect(tester.takeException(), isNull);
  });

  testWidgets('the cast meter stays a small pill in every state', (
    tester,
  ) async {
    final states = <(String, CastMeter)>[
      (
        'no model',
        const CastMeter(
          prediction: SpellPrediction.none,
          holdProgress: 0,
          recognitionAvailable: false,
          castSpell: null,
          canCast: true,
        ),
      ),
      (
        'no gesture',
        const CastMeter(
          prediction: SpellPrediction.none,
          holdProgress: 0,
          recognitionAvailable: true,
          castSpell: null,
          canCast: true,
        ),
      ),
      (
        'recognising',
        const CastMeter(
          prediction: SpellPrediction(
            spell: Spell.bliksem,
            confidence: .83,
            stability: .6,
          ),
          holdProgress: .6,
          recognitionAvailable: true,
          castSpell: null,
          canCast: true,
        ),
      ),
      (
        'cast',
        const CastMeter(
          prediction: SpellPrediction.none,
          holdProgress: 1,
          recognitionAvailable: true,
          castSpell: Spell.schild,
          canCast: false,
        ),
      ),
    ];
    for (final (name, meter) in states) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(alignment: Alignment.bottomLeft, child: meter),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull, reason: name);
      final size = tester.getSize(find.byType(CastMeter));
      expect(size.height, lessThanOrEqualTo(40), reason: name);
      expect(size.width, lessThanOrEqualTo(240), reason: name);
    }
  });

  testWidgets('the opponent-away popup counts down', (tester) async {
    phoneSize(tester);
    final now = DateTime.now();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OpponentAwayOverlay(
            name: 'Lotte',
            left: true,
            since: now,
            deadline: now.add(const Duration(seconds: 30)),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Lotte heeft het duel verlaten'), findsOneWidget);
    expect(find.text('30'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a declined challenge offers retry and home', (tester) async {
    phoneSize(tester);
    var retried = 0;
    var home = 0;
    final now = DateTime.now();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              ChallengeWaitingCard(
                challenge: OutgoingChallenge(
                  uid: 'x',
                  name: 'Lotte',
                  sentAt: now,
                  declined: true,
                ),
                expiresAt: now.add(const Duration(minutes: 10)),
                roomCode: 'ABCD',
                onRetry: () => retried++,
                onHome: () => home++,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Lotte heeft geweigerd'), findsOneWidget);
    await tester.tap(find.text('Opnieuw'));
    await tester.tap(find.text('Naar home'));
    await tester.pump(const Duration(milliseconds: 300));
    expect((retried, home), (1, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the badges screen shows progress and details', (tester) async {
    phoneSize(tester);
    SharedPreferences.setMockInitialValues({});
    final profile = ProfileProvider(LocalStorageService());
    await profile.load();
    await profile.setName('Jo');
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: profile,
        child: const MaterialApp(home: BadgesScreen()),
      ),
    );
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(
      find.textContaining('van ${allBadges.length} vrijgespeeld'),
      findsOneWidget,
    );
    await tester.tap(find.text('Eerste overwinning'));
    await pumpFor(tester, const Duration(milliseconds: 600));
    expect(find.text('Win je eerste duel.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the badge pop-up plays through several badges', (tester) async {
    phoneSize(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showBadgeUnlocks(context, [
                  badgeById('eerste_winst')!,
                  badgeById('aartsmagier')!,
                ]),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await pumpFor(tester, const Duration(seconds: 2));
    expect(find.text('Eerste overwinning'), findsOneWidget);
    await tester.tap(find.text('VOLGENDE'));
    await pumpFor(tester, const Duration(seconds: 2));
    expect(find.text('Aartsmagiër'), findsOneWidget);
    await tester.tap(find.text('GEWELDIG!'));
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(find.text('Aartsmagiër'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the VS intro plays and then gets out of the way', (
    tester,
  ) async {
    phoneSize(tester);
    var done = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DuelIntro(
            me: const IntroPlayer(
              name: 'Jonathan',
              tag: '4821',
              subtitle: 'LVL 7',
            ),
            opponent: const IntroPlayer(name: 'Maarten'),
            onDone: () => done = true,
          ),
        ),
      ),
    );
    await pumpFor(tester, const Duration(seconds: 1));
    expect(find.text('VS'), findsOneWidget);
    expect(find.text('JONATHAN'), findsOneWidget);
    await pumpFor(tester, const Duration(seconds: 2));
    expect(done, isTrue);
    expect(tester.takeException(), isNull);
  });
}
