import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/game_provider.dart';
import '../providers/profile_provider.dart';
import '../services/permissions/camera_permission_service.dart';
import '../widgets/generic/camera_permission_dialog.dart';
import 'app_router.dart';

/// Create or join a room, then open the lobby. Shows the camera dialog or
/// an error when that fails. Used by Home and Vrienden.
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
