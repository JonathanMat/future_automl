import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../generic/app_card.dart';
import '../generic/avatar_tile.dart';

/// Over the duel while the opponent is away: "Lotte heeft het duel
/// verlaten" with a countdown ring. When it runs out you win (the game
/// provider claims it); if they come back the overlay disappears.
class OpponentAwayOverlay extends StatefulWidget {
  const OpponentAwayOverlay({
    super.key,
    required this.name,
    required this.left,
    required this.since,
    required this.deadline,
  });

  final String name;

  /// Left on purpose; otherwise they lost their connection.
  final bool left;
  final DateTime since;
  final DateTime deadline;

  @override
  State<OpponentAwayOverlay> createState() => _OpponentAwayOverlayState();
}

class _OpponentAwayOverlayState extends State<OpponentAwayOverlay> {
  late final Timer _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(
      const Duration(milliseconds: 200),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.deadline.difference(widget.since).inMilliseconds;
    final left = widget.deadline.difference(DateTime.now());
    final seconds = math.max(0, (left.inMilliseconds / 1000).ceil());
    final fraction = total <= 0
        ? 0.0
        : (left.inMilliseconds / total).clamp(0.0, 1.0);
    final title = widget.left
        ? '${widget.name} heeft het duel verlaten'
        : '${widget.name} is de verbinding kwijt';

    return Semantics(
      liveRegion: true,
      label: '$title. Nog $seconds seconden, dan win jij.',
      excludeSemantics: true,
      // On top of the duel, outside its Scaffold: without a Material the
      // text gets the yellow "missing Material" underlines.
      child: Material(
        color: AppColors.overlay,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: AppCard(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              borderColor: AppColors.gold.withValues(alpha: 0.6),
              borderWidth: 2,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox.square(
                    dimension: 104,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox.square(
                          dimension: 104,
                          child: CircularProgressIndicator(
                            value: fraction,
                            strokeWidth: 6,
                            color: AppColors.gold,
                            backgroundColor: AppColors.track,
                          ),
                        ),
                        Opacity(
                          opacity: 0.55,
                          child: AvatarTile(
                            name: widget.name,
                            size: 72,
                            circle: true,
                          ),
                        ),
                        Text(
                          '$seconds',
                          style: AppTextStyles.display(34).copyWith(
                            shadows: const [
                              Shadow(color: Colors.black87, blurRadius: 10),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.display(22),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Komt ${widget.name} niet terug binnen $seconds '
                    '${seconds == 1 ? 'seconde' : 'seconden'}, dan win jij.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body(14, color: AppColors.textSoft),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
