import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:spell_duel/models/gesture_reading.dart';
import 'package:spell_duel/models/spell_prediction.dart';
import 'package:spell_duel/providers/game_provider.dart';
import 'package:spell_duel/services/game/game_backend.dart';
import 'package:spell_duel/services/game/mock_game_backend.dart';
import 'package:spell_duel/services/recognition/gesture_logic.dart';
import 'package:spell_duel/services/recognition/spell_recognizer.dart';

HandReading hand(String label, double score, double x, double y) =>
    HandReading(label: label, score: score, wristX: x, wristY: y);

void main() {
  group('getGesture', () {
    test('two hands with close wrists is shield, even as 2× fire', () {
      final g = getGesture([
        hand('fire', 0.9, 0.40, 0.50),
        hand('fire', 0.8, 0.55, 0.52),
      ]);
      expect(g.label, 'shield');
      expect(g.score, closeTo(0.85, 1e-9));
    });

    test('two hands far apart: best label wins', () {
      final g = getGesture([
        hand('fire', 0.7, 0.10, 0.50),
        hand('ice', 0.9, 0.80, 0.50),
      ]);
      expect(g.label, 'ice');
    });

    test('scores below MIN_SCORE are ignored', () {
      expect(getGesture([hand('lightning', 0.59, 0.5, 0.5)]).label, 'none');
      expect(getGesture([hand('lightning', 0.6, 0.5, 0.5)]).label, 'lightning');
    });

    test('no hands is none', () {
      expect(getGesture(const []).label, 'none');
    });

    test('SHIELD_DISTANCE is configurable', () {
      final hands = [hand('fire', 0.9, 0.3, 0.5), hand('fire', 0.9, 0.6, 0.5)];
      expect(getGesture(hands).label, 'fire'); // 0.30 apart
      expect(getGesture(hands, shieldDistance: 0.35).label, 'shield');
    });
  });

  group('GestureStabilizer', () {
    test('a gesture counts only after STABLE_FRAMES identical frames', () {
      final s = GestureStabilizer(stableFrames: 5);
      for (var i = 0; i < 4; i++) {
        expect(s.add('fire'), 'none');
      }
      expect(s.add('fire'), 'fire');
    });

    test('one odd frame does not change the stable gesture', () {
      final s = GestureStabilizer(stableFrames: 3);
      for (var i = 0; i < 3; i++) {
        s.add('ice');
      }
      expect(s.add('fire'), 'ice');
      expect(s.add('ice'), 'ice');
      expect(s.streak, 1);
    });

    test('reset forgets everything', () {
      final s = GestureStabilizer(stableFrames: 1)..add('fire');
      s.reset();
      expect(s.stable, 'none');
    });
  });

  test('labels map to spells', () {
    expect(spellForLabel('fire'), Spell.vuur);
    expect(spellForLabel('ice'), Spell.ijs);
    expect(spellForLabel('lightning'), Spell.bliksem);
    expect(spellForLabel('shield'), Spell.schild);
    expect(spellForLabel('none'), isNull);
  });

  test('the game casts the first stable gesture of the cast window', () async {
    final recognizer = _ScriptedRecognizer();
    final game = GameProvider(backend: _CameraMock(), recognizer: recognizer);
    await game.createRoom('Jo');
    final cast = await game.backend.gameState
        .firstWhere((s) => s.mySpell != null)
        .timeout(const Duration(seconds: 10));
    expect(cast.mySpell, Spell.ijs);
    expect(recognizer.resets, greaterThan(0));
    game.dispose();
  });
}

/// Mock backend with fast rounds that hands out a fake camera frame.
class _CameraMock extends MockGameBackend {
  _CameraMock()
    : super(
        useCamera: false,
        random: Random(1),
        botJoinDelay: const Duration(milliseconds: 10),
        config: const GameConfig(
          countdown: Duration(milliseconds: 300),
          castWindow: Duration(milliseconds: 1500),
          roundLead: Duration(milliseconds: 10),
        ),
      );

  @override
  Future<Uint8List?> captureLocalFrame() async => Uint8List(1);
}

/// Reports a stable "ice" from the third frame on.
class _ScriptedRecognizer implements SpellRecognizer {
  int frames = 0;
  int resets = 0;

  @override
  bool get isAvailable => true;

  @override
  Future<void> load() async {}

  @override
  Future<SpellPrediction> predict(Uint8List pngFrame) async {
    frames++;
    return frames < 3
        ? SpellPrediction(spell: null, confidence: 0.7, stability: frames / 3)
        : const SpellPrediction(
            spell: Spell.ijs,
            confidence: 0.9,
            stability: 1,
          );
  }

  @override
  void reset() => resets++;

  @override
  Future<void> dispose() async {}
}
