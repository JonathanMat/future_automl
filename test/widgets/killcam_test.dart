import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spell_duel/models/game_rules.dart';
import 'dart:typed_data';

import 'package:spell_duel/models/face_shape.dart';
import 'package:spell_duel/models/game_state.dart';
import 'package:spell_duel/screens/debug/demo_face.dart';
import 'package:spell_duel/services/face/face_finder.dart';
import 'package:spell_duel/theme/app_text_styles.dart';
import 'package:spell_duel/widgets/duel/killcam.dart';

RoundResult _round(Spell? mine, Spell? theirs) {
  final r = resolveRound(hostSpell: mine, guestSpell: theirs);
  return RoundResult(
    round: 3,
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

void main() {
  setUpAll(() => AppTextStyles.useGoogleFonts = false);

  test('only decisive rounds with a spell get a replay', () {
    expect(KillcamOverlay.hasReplay(_round(Spell.vuur, Spell.bliksem)), isTrue);
    expect(KillcamOverlay.hasReplay(_round(Spell.ijs, Spell.vuur)), isTrue);
    expect(KillcamOverlay.hasReplay(_round(null, Spell.ijs)), isTrue);
    // Nobody cast, or the same spell: nothing to replay.
    expect(KillcamOverlay.hasReplay(_round(null, null)), isFalse);
    expect(KillcamOverlay.hasReplay(_round(Spell.vuur, Spell.vuur)), isFalse);
    // Slow motion: longer than the effect itself, but not forever.
    final len = KillcamOverlay.lengthFor(_round(Spell.vuur, Spell.bliksem));
    expect(len, greaterThan(const Duration(seconds: 3)));
    expect(len, lessThan(const Duration(seconds: 12)));
    // Losing gets the same slow motion as winning.
    final lost = KillcamOverlay.lengthFor(_round(Spell.vuur, Spell.ijs));
    expect(lost, greaterThan(const Duration(seconds: 3)));
  });

  for (final (mine, theirs) in [
    (Spell.vuur, Spell.bliksem),
    (Spell.ijs, Spell.vuur),
    (Spell.bliksem, Spell.schild),
    (Spell.schild, Spell.vuur),
    (Spell.vuur, Spell.ijs),
  ]) {
    testWidgets('killcam ${mine.name} vs ${theirs.name} plays and ends', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final result = _round(mine, theirs);
      var done = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: KillcamOverlay(
            result: result,
            frames: null,
            myName: 'Jonathan',
            opponentName: 'Lotte',
            onDone: () => done++,
          ),
        ),
      );
      final won = result.outcome == RoundOutcome.win;
      expect(find.text('KILLCAM'), findsOneWidget);
      expect(find.text('Lotte'), findsOneWidget);
      // No K.O. before the slow-motion spell has played.
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('K.O.!'), findsNothing);

      final length = KillcamOverlay.lengthFor(result);
      const step = Duration(milliseconds: 50);
      var koSeen = false;
      for (var t = Duration.zero; t < length + step * 4; t += step) {
        await tester.pump(step);
        koSeen |= find.text('K.O.!').evaluate().isNotEmpty;
      }
      expect(koSeen, isTrue);
      expect(find.text(won ? 'JIJ WINT!' : 'LOTTE WINT'), findsOneWidget);
      expect(done, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('skip closes it right away, once', (tester) async {
    var done = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: KillcamOverlay(
          result: _round(Spell.vuur, Spell.bliksem),
          frames: null,
          myName: 'Jonathan',
          opponentName: 'Lotte',
          onDone: () => done++,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 800));
    await tester.tap(find.text('Overslaan ›'));
    await tester.pump();
    expect(done, 1);
    await tester.pump(const Duration(seconds: 12));
    expect(done, 1);
  });

  test('faces are looked up in both photos, and a miss stays empty', () async {
    final photo = Uint8List.fromList([1, 2, 3]);
    final frames = KillcamFrames(round: 2, top: photo, bottom: null);
    final found = await frames.withFaces(_FakeFinder(DemoFace.shape()));
    expect(found.round, 2);
    expect(found.top, same(photo));
    expect(found.topFace, isNotNull);
    expect(found.bottomFace, isNull, reason: 'no photo, no face');
    final none = await frames.withFaces(const NoFaceFinder());
    expect(none.topFace, isNull);
  });

  test('tracking photos: no camera, no retries; no finder, no faces', () async {
    final updates = await KillcamFrames.track(
      round: 4,
      finder: _FakeFinder(DemoFace.shape()),
    ).toList();
    // The photos, then with faces (none without photos); then it stops
    // because there is no video to take a better photo from.
    expect(updates, hasLength(2));
    expect(updates.last.topFace, isNull);
    final plain = await KillcamFrames.track(
      round: 4,
      finder: const NoFaceFinder(),
    ).toList();
    expect(plain, hasLength(1));
  });

  for (final (mine, theirs) in [
    (Spell.ijs, Spell.vuur), // you freeze them
    (Spell.vuur, Spell.ijs), // you get frozen
    (Spell.bliksem, Spell.vuur), // you get burnt
    (Spell.ijs, Spell.bliksem), // you get shocked
    (Spell.schild, null), // shield bash: dizzy
  ]) {
    testWidgets('face effects: ${mine.name} vs ${theirs?.name}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final png = await tester.runAsync(DemoFace.png);
      final result = _round(mine, theirs);
      var done = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: KillcamOverlay(
            result: result,
            frames: KillcamFrames(
              round: 3,
              top: png,
              bottom: png,
              // The opponent's photo came in sideways.
              topFace: DemoFace.shape(turns: 1),
              bottomFace: DemoFace.shape(),
            ),
            myName: 'Jonathan',
            opponentName: 'Lotte',
            onDone: () => done++,
          ),
        ),
      );
      final length = KillcamOverlay.lengthFor(result);
      const step = Duration(milliseconds: 50);
      for (var t = Duration.zero; t < length + step * 4; t += step) {
        await tester.pump(step);
      }
      expect(done, 1);
      expect(tester.takeException(), isNull);
    });
  }
}

class _FakeFinder implements FaceFinder {
  _FakeFinder(this.face);

  final FaceShape face;

  @override
  Future<void> warmUp() async {}

  @override
  Future<FaceShape?> find(Uint8List encodedImage) async => face;
}
