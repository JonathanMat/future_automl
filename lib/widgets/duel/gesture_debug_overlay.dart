import 'package:flutter/material.dart';

import '../../models/gesture_reading.dart';
import '../../utils/gesture_constants.dart';

/// Small monospace box with the raw recognition data, to tune
/// `GestureConstants.shieldDistance`. Shown when `GestureConstants.debug`.
class GestureDebugOverlay extends StatelessWidget {
  const GestureDebugOverlay({super.key, required this.frame});

  final GestureFrame? frame;

  @override
  Widget build(BuildContext context) {
    final f = frame ?? GestureFrame.empty;
    final distance = f.wristDistance;
    final isClose =
        distance != null && distance < GestureConstants.shieldDistance;
    final lines = <String>[
      'handen: ${f.hands.length}',
      for (var i = 0; i < f.hands.length; i++)
        'hand ${i + 1}: ${f.hands[i].label} ${f.hands[i].score.toStringAsFixed(2)}',
      'polsen: ${distance?.toStringAsFixed(3) ?? '–'}'
          ' (< ${GestureConstants.shieldDistance}${isClose ? ' ✓' : ''})',
      'frame: ${f.rawGesture} ${f.rawScore.toStringAsFixed(2)}'
          ' · ${f.streak}/${GestureConstants.stableFrames}',
      'gebaar: ${f.stableGesture}',
    ];
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xCC000000),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          lines.join('\n'),
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 10,
            height: 1.35,
            color: Color(0xFF7CFFB2),
          ),
        ),
      ),
    );
  }
}
