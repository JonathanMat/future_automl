import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Page transitions and animation timings.
abstract final class AppTransitions {
  static const fast = Duration(milliseconds: 200);
  static const medium = Duration(milliseconds: 400);
  static const pop = Duration(milliseconds: 450);

  static const pageTransitionsTheme = PageTransitionsTheme(
    builders: {
      TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
    },
  );

  /// Fade + slight scale, for screens that should feel like a "moment"
  /// (the duel and the result).
  static Route<T> fadeScale<T>(Widget page, RouteSettings settings) {
    return PageRouteBuilder<T>(
      settings: settings,
      transitionDuration: medium,
      reverseTransitionDuration: fast,
      pageBuilder: (_, _, _) => page,
      transitionsBuilder: (_, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween(begin: 0.96, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  /// Tab switches in the bottom navigation: a quick cross-fade.
  static Route<T> fade<T>(Widget page, RouteSettings settings) {
    return PageRouteBuilder<T>(
      settings: settings,
      transitionDuration: fast,
      reverseTransitionDuration: fast,
      pageBuilder: (_, _, _) => page,
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    );
  }
}
