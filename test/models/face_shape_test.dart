import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:spell_duel/models/face_shape.dart';
import 'package:spell_duel/models/game_rules.dart';
import 'package:spell_duel/models/game_state.dart';
import 'package:spell_duel/screens/debug/demo_face.dart';
import 'package:spell_duel/widgets/duel/effects/face_fx.dart';
import 'package:spell_duel/widgets/duel/effects/fx_builder.dart';
import 'package:spell_duel/widgets/duel/effects/fx_plan.dart';

FaceShape _single(Offset p, {int w = 100, int h = 200, int turns = 0}) =>
    FaceShape(
      points: List.filled(478, p),
      imageWidth: w,
      imageHeight: h,
      turns: turns,
    );

void main() {
  group('turning a sideways photo upright', () {
    test('quarter turns move the corners like a clockwise rotation', () {
      // The top-left corner ends up top-right after one clockwise turn.
      expect(FaceShape.turn(Offset.zero, 1), const Offset(1, 0));
      expect(FaceShape.turn(Offset.zero, 2), const Offset(1, 1));
      expect(FaceShape.turn(Offset.zero, 3), const Offset(0, 1));
      expect(FaceShape.turn(const Offset(.2, .3), 0), const Offset(.2, .3));
      // Four turns: back where it started.
      var p = const Offset(.2, .7);
      for (var i = 0; i < 4; i++) {
        p = FaceShape.turn(p, 1);
      }
      expect(p.dx, closeTo(.2, 1e-9));
      expect(p.dy, closeTo(.7, 1e-9));
    });

    test('the face itself says how to turn the photo upright', () {
      int turnsFor(int turns) {
        final f = DemoFace.shape(turns: turns);
        return FaceShape.uprightTurns(f.points, f.imageWidth, f.imageHeight);
      }

      for (final t in [0, 1, 2, 3]) {
        expect(turnsFor(t), t, reason: 'stored with $t turns');
      }
      // A head tilted 40° stays as it is.
      final tilted = List.of(DemoFace.shape().points);
      tilted[FaceShape.foreheadTop] =
          tilted[FaceShape.chin] + const Offset(.3, -.36);
      expect(FaceShape.uprightTurns(tilted, 600, 800), 0);
    });

    test('a sideways photo swaps width and height', () {
      expect(_single(Offset.zero, turns: 1).uprightSize, const Size(200, 100));
      expect(_single(Offset.zero, turns: 2).uprightSize, const Size(100, 200));
    });
  });

  group('layout like BoxFit.cover', () {
    test('a tall photo in a wide box is cropped top and bottom', () {
      // 100x200 photo in a 300x300 box: scale 3, 600 tall, 150 cut off
      // above and below.
      final g = _single(const Offset(.5, .25)).layout(const Size(300, 300));
      expect(g[0], const Offset(150, 0));
      final mid = _single(const Offset(.5, .5)).layout(const Size(300, 300));
      expect(mid[0], const Offset(150, 150));
    });

    test('mirroring flips left and right, not up and down', () {
      final g = _single(
        const Offset(.1, .5),
      ).layout(const Size(100, 200), mirror: true);
      expect(g[0].dx, closeTo(90, 1e-9));
      expect(g[0].dy, closeTo(100, 1e-9));
    });

    test('the demo face survives a round trip through a sideways photo', () {
      final upright = DemoFace.shape().layout(const Size(300, 400));
      for (final turns in [1, 2, 3]) {
        final turned = DemoFace.shape(
          turns: turns,
        ).layout(const Size(300, 400));
        for (final i in [1, 10, 152, 468, 473]) {
          expect(turned[i].dx, closeTo(upright[i].dx, 1e-6));
          expect(turned[i].dy, closeTo(upright[i].dy, 1e-6));
        }
      }
    });
  });

  test('the face geometry finds eyes, cheeks and which way is up', () {
    final g = DemoFace.shape().layout(const Size(600, 800));
    expect(g.eyeA.center.dx, lessThan(g.eyeB.center.dx));
    expect(g.eyeA.radius, greaterThan(5));
    expect(g.chin.dy, greaterThan(g.foreheadTop.dy));
    expect(g.up.dy, lessThan(-.9)); // up is towards the top of the photo
    expect(g.width, closeTo(300, 2));
    expect(g.bounds.contains(g.noseTip), isTrue);
    // Without irises (468 points) the eye centre is the eye's middle.
    final noIris = FaceShape(
      points: DemoFace.shape().points.take(468).toList(),
      imageWidth: DemoFace.width,
      imageHeight: DemoFace.height,
    ).layout(const Size(600, 800));
    expect(noIris.eyeA.center.dx, closeTo(g.eyeA.center.dx, 3));
  });

  group('which face effect a round gets', () {
    FaceFxPlan planOf(Spell? mine, Spell? theirs) {
      final r = resolveRound(hostSpell: mine, guestSpell: theirs);
      final result = RoundResultForTest.from(r);
      final plan = planFor(result);
      return FaceFxPlan.forRound(plan, buildSpellFx(plan)?.fx);
    }

    test('the spell decides what happens to the loser', () {
      expect(planOf(Spell.ijs, Spell.vuur).kind, FaceFxKind.frozen);
      expect(planOf(Spell.vuur, Spell.bliksem).kind, FaceFxKind.burnt);
      expect(planOf(Spell.bliksem, Spell.ijs).kind, FaceFxKind.shocked);
      expect(planOf(Spell.bliksem, Spell.schild).kind, FaceFxKind.shocked);
      expect(planOf(Spell.schild, Spell.ijs).kind, FaceFxKind.frozen);
      expect(planOf(Spell.schild, Spell.vuur).kind, FaceFxKind.burnt);
      expect(planOf(Spell.schild, null).kind, FaceFxKind.dizzy);
      expect(planOf(Spell.vuur, Spell.vuur).kind, FaceFxKind.none);
    });

    test('the loser is the one who got hit, at the hit', () {
      final win = planOf(Spell.ijs, Spell.vuur);
      expect(win.loser, FxSide.top);
      expect(win.winner, FxSide.bottom);
      expect(win.winnerSpell, Spell.ijs);
      expect(win.hitTime, greaterThan(0));
      final lose = planOf(Spell.vuur, Spell.ijs);
      expect(lose.loser, FxSide.bottom);
    });
  });
}

/// A [RoundResult] from this phone's (the host's) point of view.
extension RoundResultForTest on RoundResolution {
  static RoundResult from(RoundResolution r) => RoundResult(
    round: 1,
    mySpell: r.hostSpell,
    opponentSpell: r.guestSpell,
    outcome: switch (r.winner) {
      null => RoundOutcome.draw,
      Side.host => RoundOutcome.win,
      Side.guest => RoundOutcome.lose,
    },
    reason: r.reason,
  );
}
