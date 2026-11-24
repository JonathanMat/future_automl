// Renders the logo to PNGs for the app icon and splash screen.
//
//   flutter test tool/render_logo_test.dart
//   dart run flutter_launcher_icons
//   dart run flutter_native_splash:create
//
// Not in test/, so a normal `flutter test` skips it.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spell_duel/widgets/generic/app_logo.dart';

Future<void> _render(String path, int px, SpellDuelLogoPainter painter) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  painter.paint(canvas, Size.square(px.toDouble()));
  final image = await recorder.endRecording().toImage(px, px);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  test('render logo assets', () async {
    // Full icon with background (iOS, legacy Android, store listing).
    await _render(
      'assets/icons/app_icon.png',
      1024,
      const SpellDuelLogoPainter(background: true, scale: 0.9),
    );
    // Adaptive icon foreground. flutter_launcher_icons adds a 16% inset,
    // which keeps it inside the safe zone.
    await _render(
      'assets/icons/app_icon_foreground.png',
      1024,
      const SpellDuelLogoPainter(scale: 0.85),
    );
    // Adaptive icon background: the night sky without the badge.
    await _render(
      'assets/icons/app_icon_background.png',
      1024,
      const SpellDuelLogoPainter(background: true, scale: 0),
    );
    // Splash (Android 12 keeps a 2/3 circle: badge fits in it).
    await _render(
      'assets/icons/splash_logo.png',
      1152,
      const SpellDuelLogoPainter(scale: 0.6),
    );
    // Preview of the badge on its own.
    await _render('assets/images/logo.png', 512, const SpellDuelLogoPainter());
  });
}
