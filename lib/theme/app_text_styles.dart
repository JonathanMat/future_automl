import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Typography: Lilita One for display text, Nunito for everything else.
///
/// Fonts come from `google_fonts`. Drop `LilitaOne-Regular.ttf` and the
/// `Nunito-*.ttf` files in `assets/fonts/` to bundle them offline; the
/// package picks them up automatically.
abstract final class AppTextStyles {
  /// Turned off in widget tests, which can't download fonts.
  static bool useGoogleFonts = true;

  static TextStyle display(double size, {Color color = AppColors.text}) {
    final base = TextStyle(
      fontSize: size,
      color: color,
      height: 1.1,
      letterSpacing: 0.5,
      fontWeight: FontWeight.w400,
    );
    return useGoogleFonts ? GoogleFonts.lilitaOne(textStyle: base) : base;
  }

  static TextStyle body(
    double size, {
    FontWeight weight = FontWeight.w800,
    Color color = AppColors.text,
    double? height,
    double? letterSpacing,
  }) {
    final base = TextStyle(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
    return useGoogleFonts ? GoogleFonts.nunito(textStyle: base) : base;
  }

  /// Small caps labels such as "SEIZOEN 1" or "KAMERCODE".
  static TextStyle overline({Color color = AppColors.textMuted}) =>
      body(12, weight: FontWeight.w900, color: color, letterSpacing: 2);

  static TextStyle caption({Color color = AppColors.textMuted}) =>
      body(12, weight: FontWeight.w800, color: color);

  static TextTheme textTheme() {
    final base = ThemeData.dark().textTheme.apply(
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
    );
    return useGoogleFonts ? GoogleFonts.nunitoTextTheme(base) : base;
  }
}
