import 'package:flutter/material.dart';

import '../../services/permissions/camera_permission_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// Explains why the camera is needed and links to the system settings,
/// the only place a refused permission can be turned back on.
Future<void> showCameraPermissionDialog(
  BuildContext context, {
  required CameraPermissionService service,
}) {
  final withMic = service.microphone;
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(
        Icons.videocam_off_rounded,
        color: AppColors.gold,
        size: 40,
      ),
      title: Text(withMic ? 'Camera en microfoon nodig' : 'Camera nodig'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Je camera herkent je spreuk-gebaren en laat je tegenstander '
            'je zien. Beelden worden nergens opgeslagen.',
          ),
          const SizedBox(height: 12),
          Text(
            withMic
                ? 'Zet Camera en Microfoon aan bij Spell Duel in je '
                      'instellingen en probeer opnieuw.'
                : 'Zet Camera aan bij Spell Duel in je instellingen en '
                      'probeer opnieuw.',
            style: AppTextStyles.caption(color: AppColors.textSoft),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(foregroundColor: AppColors.textMuted),
          child: const Text('Annuleren'),
        ),
        TextButton(
          onPressed: () async {
            Navigator.of(context).pop();
            final opened = await service.openAppSettings();
            if (!opened && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Open je instellingen en zoek Spell Duel om de camera aan te zetten.',
                  ),
                ),
              );
            }
          },
          child: const Text('Instellingen openen'),
        ),
      ],
    ),
  );
}
