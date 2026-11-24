import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/challenge_provider.dart';
import '../providers/game_provider.dart';
import '../providers/profile_provider.dart';
import '../services/permissions/camera_permission_service.dart';
import '../services/social/friends_backend.dart';
import '../widgets/generic/camera_permission_dialog.dart';
import 'app_router.dart';

/// Create or join a room, then open the lobby. Shows the camera dialog or
/// an error when that fails. Used by Home, Vrienden and challenges.
abstract final class RoomFlow {
  static Future<void> create(BuildContext context) async {
    final game = context.read<GameProvider>();
    final name = context.read<ProfileProvider>().profile.name;
    final code = await game.createRoom(name);
    if (!context.mounted) return;
    if (code != null) {
      Navigator.of(context).pushNamed(AppRoutes.lobby);
    } else {
      await _showFailure(context, game);
    }
  }

  /// Makes a room and invites [friend] to it.
  static Future<void> challenge(BuildContext context, Friend friend) async {
    final game = context.read<GameProvider>();
    final challenges = context.read<ChallengeProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final name = context.read<ProfileProvider>().profile.name;
    final code = await game.createRoom(name);
    if (!context.mounted) return;
    if (code == null) {
      await _showFailure(context, game);
      return;
    }
    Navigator.of(context).pushNamed(AppRoutes.lobby);
    final message = await challenges.send(friend, code);
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  /// Accepts a challenge: joins the friend's room.
  static Future<void> accept(
    BuildContext context,
    ChallengeInvite invite,
  ) async {
    final challenges = context.read<ChallengeProvider>();
    unawaited(challenges.dismiss(invite));
    await join(context, invite.roomCode);
  }

  static Future<void> join(BuildContext context, String code) async {
    final game = context.read<GameProvider>();
    final name = context.read<ProfileProvider>().profile.name;
    final ok = await game.joinRoom(code, name);
    if (!context.mounted) return;
    if (ok) {
      Navigator.of(context).pushNamed(AppRoutes.lobby);
    } else {
      await _showFailure(context, game);
    }
  }

  static Future<void> _showFailure(
    BuildContext context,
    GameProvider game,
  ) async {
    final message = game.actionError ?? 'Er ging iets mis.';
    game.clearError();
    if (game.mediaAccess == MediaAccess.denied) {
      await showCameraPermissionDialog(context, service: game.cameraPermission);
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
