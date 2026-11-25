import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../screens/debug/backend_debug_page.dart';
import '../screens/badges/badges_screen.dart';
import '../screens/debug/fx_preview_screen.dart';
import '../screens/duel/duel_screen.dart';
import '../screens/friends/friends_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/leaderboard/leaderboard_screen.dart';
import '../screens/lobby/lobby_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/result/result_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/tournament/tournament_screen.dart';
import '../providers/tournament_provider.dart';
import '../services/game/game_backend.dart';
import '../theme/app_transitions.dart';

abstract final class AppRoutes {
  static const onboarding = '/welkom';
  static const home = '/';
  static const friends = '/vrienden';
  static const leaderboard = '/scorebord';
  static const lobby = '/kamer';
  static const duel = '/duel';
  static const result = '/resultaat';
  static const settings = '/instellingen';
  static const debug = '/debug';
  static const fxPreview = '/effecten';
  static const badges = '/badges';
  static const tournament = '/toernooi';
  static const profile = '/profiel';
}

/// Named routes for the whole app.
class AppRouter {
  AppRouter(this.backend);

  /// Only needed for the debug page, which talks to the backend directly.
  final GameBackend backend;

  Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.onboarding:
        return AppTransitions.fade(const OnboardingScreen(), settings);
      case AppRoutes.home:
        return AppTransitions.fade(const HomeScreen(), settings);
      case AppRoutes.friends:
        return AppTransitions.fade(const FriendsScreen(), settings);
      case AppRoutes.leaderboard:
        return AppTransitions.fade(const LeaderboardScreen(), settings);
      case AppRoutes.lobby:
        return MaterialPageRoute(
          builder: (_) => const LobbyScreen(),
          settings: settings,
        );
      case AppRoutes.duel:
        return AppTransitions.fadeScale(const DuelScreen(), settings);
      case AppRoutes.result:
        return AppTransitions.reveal(const ResultScreen(), settings);
      case AppRoutes.badges:
        return MaterialPageRoute(
          builder: (_) => const BadgesScreen(),
          settings: settings,
        );
      case AppRoutes.profile:
        final args = settings.arguments;
        return MaterialPageRoute(
          builder: (_) => ProfileScreen(
            args: args is ProfileArgs ? args : const ProfileArgs(name: ''),
          ),
          settings: settings,
        );
      case AppRoutes.tournament:
        return AppTransitions.fade(const TournamentScreen(), settings);
      case AppRoutes.settings:
        return MaterialPageRoute(
          builder: (_) => const SettingsScreen(),
          settings: settings,
        );
      case AppRoutes.debug when kDebugMode:
        return MaterialPageRoute(
          builder: (_) => BackendDebugPage(backend: backend),
          settings: settings,
        );
      case AppRoutes.fxPreview:
        return MaterialPageRoute(
          builder: (_) => const FxPreviewScreen(),
          settings: settings,
        );
      default:
        return AppTransitions.fade(const HomeScreen(), settings);
    }
  }

  /// Back to the home screen, closing everything on top. During a
  /// tournament that is the tournament screen (with home under it).
  static void goHome(BuildContext context) {
    final inTournament =
        context.read<TournamentProvider?>()?.inTournament ?? false;
    if (inTournament) {
      backToTournament(context);
    } else {
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRoutes.home, (_) => false);
    }
  }

  /// Back to the tournament screen after a match.
  static void backToTournament(BuildContext context) {
    final nav = Navigator.of(context);
    var found = false;
    nav.popUntil((route) {
      if (route.settings.name == AppRoutes.tournament) found = true;
      return found || route.isFirst;
    });
    if (!found) {
      nav
        ..pushNamedAndRemoveUntil(AppRoutes.home, (_) => false)
        ..pushNamed(AppRoutes.tournament);
    }
  }
}
