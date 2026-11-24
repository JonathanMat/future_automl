import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spell_duel/models/game_rules.dart';
import 'package:spell_duel/models/game_state.dart';
import 'package:spell_duel/theme/app_text_styles.dart';
import 'package:spell_duel/widgets/duel/effects/fx_builder.dart';
import 'package:spell_duel/widgets/duel/effects/fx_plan.dart';
import 'package:spell_duel/widgets/duel/effects/spell_effects_layer.dart';

RoundResult result(int round, Spell? mine, Spell? theirs) {
  final r = resolveRound(hostSpell: mine, guestSpell: theirs);
  return RoundResult(
    round: round,
    mySpell: r.hostSpell,
    opponentSpell: r.guestSpell,
    outcome: r.winner == null
        ? RoundOutcome.draw
        : (r.winner == Side.host ? RoundOutcome.win : RoundOutcome.lose),
    reason: r.reason,
  );
}

void main() {
  setUpAll(() => AppTextStyles.useGoogleFonts = false);

  group('planFor', () {
    test('fire win sends a fireball to the opponent', () {
      final p = planFor(result(1, Spell.vuur, Spell.bliksem));
      expect(p.kind, FxKind.fireball);
      expect(p.winner, FxSide.bottom);
      expect(p.loser, FxSide.top);
    });

    test('losing to ice freezes your own camera', () {
      final p = planFor(result(1, Spell.vuur, Spell.ijs));
      expect(p.kind, FxKind.freeze);
      expect(p.loser, FxSide.bottom);
    });

    test('lightning strikes, and breaks a shield', () {
      expect(
        planFor(result(1, Spell.bliksem, Spell.ijs)).kind,
        FxKind.lightning,
      );
      expect(
        planFor(result(1, Spell.bliksem, Spell.schild)).kind,
        FxKind.lightningBreaksShield,
      );
    });

    test('a shield bounces fire and ice back', () {
      final p = planFor(result(1, Spell.ijs, Spell.schild));
      expect(p.kind, FxKind.shieldReflect);
      expect(p.winner, FxSide.top);
      expect(p.reflected, Spell.ijs);
    });

    test('shield against nothing is a bash', () {
      expect(planFor(result(1, Spell.schild, null)).kind, FxKind.shieldBash);
    });

    test('draws clash, nothing cast shows nothing', () {
      expect(planFor(result(1, Spell.vuur, Spell.vuur)).kind, FxKind.clash);
      expect(
        planFor(result(1, Spell.schild, Spell.schild)).kind,
        FxKind.doubleShield,
      );
      expect(planFor(result(1, null, null)).kind, FxKind.none);
    });

    test('every effect fits in the pause between rounds', () {
      for (final mine in [...Spell.values, null]) {
        for (final theirs in [...Spell.values, null]) {
          final fx = buildSpellFx(planFor(result(1, mine, theirs)));
          if (fx == null) continue;
          expect(
            fx.fx.duration,
            lessThanOrEqualTo(3.1),
            reason: '$mine vs $theirs',
          );
        }
      }
    });
  });

  testWidgets('every effect plays to the end without errors', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final topKey = GlobalKey(), bottomKey = GlobalKey();
    Widget app(RoundResult? r) => MaterialApp(
      home: Scaffold(
        body: SpellEffectsLayer(
          result: r,
          topKey: topKey,
          bottomKey: bottomKey,
          child: Column(
            children: [
              Expanded(child: SizedBox.expand(key: topKey)),
              const SizedBox(height: 90),
              Expanded(child: SizedBox.expand(key: bottomKey)),
            ],
          ),
        ),
      ),
    );

    var round = 0;
    final cases = <(Spell?, Spell?)>[
      (Spell.vuur, Spell.bliksem),
      (Spell.bliksem, Spell.vuur),
      (Spell.ijs, Spell.vuur),
      (Spell.vuur, Spell.ijs),
      (Spell.bliksem, Spell.ijs),
      (Spell.schild, Spell.vuur),
      (Spell.schild, Spell.ijs),
      (Spell.ijs, Spell.schild),
      (Spell.bliksem, Spell.schild),
      (Spell.schild, null),
      (Spell.vuur, Spell.vuur),
      (Spell.ijs, Spell.ijs),
      (Spell.bliksem, Spell.bliksem),
      (Spell.schild, Spell.schild),
    ];
    for (final (mine, theirs) in cases) {
      await tester.pumpWidget(app(result(++round, mine, theirs)));
      // Step through the whole timeline.
      for (var i = 0; i < 70; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(tester.takeException(), isNull, reason: '$mine vs $theirs');
      await tester.pumpWidget(app(null));
    }
    // Nothing is left running.
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
