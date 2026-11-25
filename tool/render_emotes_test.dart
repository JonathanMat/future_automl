// Renders every emote to one PNG sheet, to look at the art while tuning it.
//
//   flutter test tool/render_emotes_test.dart
//
// Writes build/emotes.png. Not in test/, so a normal `flutter test` skips it.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spell_duel/models/emote.dart';
import 'package:spell_duel/theme/app_text_styles.dart';
import 'package:spell_duel/widgets/duel/emotes/emote_art.dart';

void main() {
  test('render emote sheet', () async {
    AppTextStyles.useGoogleFonts = false;
    const cell = 220.0, small = 56.0;
    final emotes = Emote.values;
    final w = cell * emotes.length, h = cell + small + 20;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)
      ..drawRect(
        Rect.fromLTWH(0, 0, w, h),
        Paint()..color = const Color(0xFF0E0B1F),
      );
    for (final (i, e) in emotes.indexed) {
      canvas
        ..save()
        ..translate(i * cell + 10, 10);
      EmotePainter(e).paint(canvas, const Size.square(cell - 20));
      canvas
        ..translate((cell - 20 - small) / 2, cell)
        ..save();
      EmotePainter(e).paint(canvas, const Size.square(small));
      canvas
        ..restore()
        ..restore();
    }
    final image = await recorder.endRecording().toImage(w.toInt(), h.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('build/emotes.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}
