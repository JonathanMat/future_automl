import 'dart:math';

import 'package:flutter/material.dart';

import '../../../models/emote.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import 'emote_art.dart';

/// An emote popping up over a camera feed: it bounces in with a little
/// wiggle, floats for a moment and drifts up as it fades.
///
/// Give each new emote a new key so the animation starts over.
class EmoteBurst extends StatefulWidget {
  const EmoteBurst({
    super.key,
    required this.emote,
    this.size = 96,
    this.onDone,
  });

  final Emote emote;
  final double size;
  final VoidCallback? onDone;

  static const duration = Duration(milliseconds: 2600);

  @override
  State<EmoteBurst> createState() => _EmoteBurstState();
}

class _EmoteBurstState extends State<EmoteBurst>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: EmoteBurst.duration,
  )..forward().whenComplete(() => widget.onDone?.call());

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.overlay,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        widget.emote.label,
        style: AppTextStyles.display(widget.size * .17),
      ),
    );
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        EmoteIcon(emote: widget.emote, size: widget.size),
        const SizedBox(height: 4),
        label,
      ],
    );

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        child: content,
        builder: (context, child) {
          final t = _c.value * EmoteBurst.duration.inMilliseconds / 1000;
          // Pop in (0–0.5 s), wiggle that settles, float, drift up and fade
          // over the last 0.4 s.
          final pop = Curves.elasticOut.transform((t / .55).clamp(0, 1));
          final wiggle = sin(t * 18) * .16 * exp(-t * 3.2);
          final out = ((t - 2.2) / .4).clamp(0.0, 1.0);
          final bob = sin(t * 4.2) * 3 * (1 - out);
          return Opacity(
            opacity: 1 - out,
            child: Transform.translate(
              offset: Offset(0, bob - 26 * Curves.easeIn.transform(out)),
              child: Transform.rotate(
                angle: wiggle,
                child: Transform.scale(
                  scale: pop * (1 - .15 * out),
                  child: child,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
