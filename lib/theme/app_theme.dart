import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';
import 'app_transitions.dart';

/// Corner radii and spacing used across the design.
abstract final class AppRadii {
  static const sm = 10.0;
  static const md = 14.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const card = 24.0;
  static const hero = 28.0;
}

abstract final class AppSpacing {
  static const screen = 20.0;
  static const gap = 12.0;

  /// The app is kept phone-width on big screens; the beamer view turns
  /// this on to use the whole screen.
  static final fullWidth = ValueNotifier<bool>(false);
}

abstract final class AppTheme {
  static ThemeData dark() {
    const scheme = ColorScheme.dark(
      primary: AppColors.gold,
      onPrimary: AppColors.goldInk,
      secondary: AppColors.purple,
      onSecondary: AppColors.text,
      surface: AppColors.surface,
      onSurface: AppColors.text,
      error: AppColors.red,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: AppTextStyles.textTheme(),
      splashFactory: InkSparkle.splashFactory,
      pageTransitionsTheme: AppTransitions.pageTransitionsTheme,
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceRaised,
        contentTextStyle: AppTextStyles.body(14),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
        titleTextStyle: AppTextStyles.display(24),
        contentTextStyle: AppTextStyles.body(
          15,
          weight: FontWeight.w700,
          color: AppColors.textSoft,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        hintStyle: AppTextStyles.body(
          16,
          weight: FontWeight.w900,
          color: AppColors.textHint,
          letterSpacing: 1,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: _inputBorder(AppColors.borderInput),
        enabledBorder: _inputBorder(AppColors.borderInput),
        focusedBorder: _inputBorder(AppColors.gold),
        errorBorder: _inputBorder(AppColors.red),
        focusedErrorBorder: _inputBorder(AppColors.red),
        errorStyle: AppTextStyles.body(12, color: AppColors.redSoft),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          // White by default; destructive actions set red themselves.
          foregroundColor: AppColors.text,
          textStyle: AppTextStyles.body(15, weight: FontWeight.w900),
        ),
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadii.lg),
    borderSide: BorderSide(color: color),
  );
}
