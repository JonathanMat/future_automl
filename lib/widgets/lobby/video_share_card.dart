import 'package:flutter/material.dart';

import '../generic/toggle_card.dart';

/// "Elkaar zien": whether the opponent's live video is shown during the duel.
class VideoShareCard extends StatelessWidget {
  const VideoShareCard({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => ToggleCard(
    icon: Icons.videocam_rounded,
    title: 'Elkaar zien',
    subtitle: 'Live video van je tegenstander tonen',
    value: value,
    onChanged: onChanged,
    note: value
        ? 'Aan: jullie zien elkaar live (peer-to-peer). Beelden worden '
              'nergens opgeslagen, de spreuk wordt herkend op je eigen gsm.'
        : 'Uit: je ziet je tegenstander als avatar. Je camera blijft '
              'aan op je eigen gsm om je gebaren te herkennen.',
  );
}

/// "Spraakchat": microphone + the opponent's sound during a duel.
class VoiceChatCard extends StatelessWidget {
  const VoiceChatCard({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => ToggleCard(
    icon: value ? Icons.mic_rounded : Icons.mic_off_rounded,
    title: 'Spraakchat',
    subtitle: 'Praten met je tegenstander tijdens een duel',
    value: value,
    onChanged: onChanged,
    note: value
        ? 'Aan: je microfoon staat alleen aan tijdens een duel. Je gsm '
              'gebruikt dan het belvolume.'
        : 'Uit: geen microfoon en geen geluid van je tegenstander. Je '
              'volume werkt gewoon en kan helemaal uit.',
  );
}

/// "Geluidseffecten": the sounds of the spell effects.
class SoundEffectsCard extends StatelessWidget {
  const SoundEffectsCard({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => ToggleCard(
    icon: value ? Icons.volume_up_rounded : Icons.volume_off_rounded,
    title: 'Geluidseffecten',
    subtitle: 'Geluid bij spreuken en emotes',
    value: value,
    onChanged: onChanged,
  );
}
