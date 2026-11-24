import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_transitions.dart';

enum ChunkyButtonStyle { primary, secondary, success }

/// The game-style button from the design: a solid face on a darker edge
/// that sinks in when pressed.
class ChunkyButton extends StatefulWidget {
  const ChunkyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.style = ChunkyButtonStyle.primary,
    this.icon,
    this.height = 64,
    this.fontSize,
    this.display = true,
    this.loading = false,
    this.semanticLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final ChunkyButtonStyle style;
  final IconData? icon;
  final double height;
  final double? fontSize;

  /// Lilita One (true) or bold Nunito (false).
  final bool display;
  final bool loading;
  final String? semanticLabel;

  @override
  State<ChunkyButton> createState() => _ChunkyButtonState();
}

class _ChunkyButtonState extends State<ChunkyButton> {
  bool _down = false;

  ({Color face, Color edge, Color ink}) get _colors => switch (widget.style) {
    ChunkyButtonStyle.primary => (
      face: AppColors.gold,
      edge: AppColors.goldShadow,
      ink: AppColors.goldInk,
    ),
    ChunkyButtonStyle.secondary => (
      face: AppColors.surfaceRaised,
      edge: AppColors.surfaceRaisedShadow,
      ink: AppColors.text,
    ),
    ChunkyButtonStyle.success => (
      face: AppColors.green,
      edge: AppColors.greenShadow,
      ink: AppColors.greenInk,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.loading;
    final c = _colors;
    final edge = widget.height >= 60 ? 6.0 : 4.0;
    final drop = _down ? edge - 1 : 0.0;
    final fontSize = widget.fontSize ?? (widget.display ? 24.0 : 15.0);
    final textStyle = widget.display
        ? AppTextStyles.display(fontSize, color: c.ink)
        : AppTextStyles.body(fontSize, weight: FontWeight.w900, color: c.ink);

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTapCancel: enabled ? () => setState(() => _down = false) : null,
        onTap: enabled ? widget.onPressed : null,
        child: Opacity(
          opacity: enabled || widget.loading ? 1 : 0.45,
          child: SizedBox(
            height: widget.height + edge,
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: widget.height,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: c.edge,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                AnimatedPositioned(
                  duration: AppTransitions.fast ~/ 3,
                  left: 0,
                  right: 0,
                  top: drop,
                  height: widget.height,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: c.face,
                      borderRadius: BorderRadius.circular(
                        widget.height >= 60 ? 20 : 16,
                      ),
                    ),
                    child: Center(
                      child: widget.loading
                          ? SizedBox.square(
                              dimension: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: c.ink,
                              ),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (widget.icon != null) ...[
                                  Icon(
                                    widget.icon,
                                    color: c.ink,
                                    size: fontSize,
                                  ),
                                  const SizedBox(width: 10),
                                ],
                                Flexible(
                                  child: Text(
                                    widget.label,
                                    style: textStyle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
