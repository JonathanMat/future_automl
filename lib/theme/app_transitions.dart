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

  /// The result screen after a duel: zooms in from a little smaller with a
  /// slight overshoot, like the "GEWONNEN" banner before it.
  /// How long [reveal] takes.
  static const revealDuration = Duration(milliseconds: 650);

  static Route<T> reveal<T>(Widget page, RouteSettings settings) {
    return PageRouteBuilder<T>(
      settings: settings,
      transitionDuration: revealDuration,
      reverseTransitionDuration: fast,
      pageBuilder: (_, _, _) => page,
      transitionsBuilder: (_, animation, _, child) {
        final fade = CurvedAnimation(
          parent: animation,
          curve: const Interval(0, .6, curve: Curves.easeOut),
        );
        final zoom = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        );
        return FadeTransition(
          opacity: fade,
          child: ScaleTransition(
            scale: Tween(begin: 0.86, end: 1.0).animate(zoom),
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
