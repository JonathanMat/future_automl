import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// Copies [text] and morphs the copy icon into a green checkmark (with a
/// little pop and spin), then back after a moment.
///
/// [label] shows a pill with text ("Kopieer" → "Gekopieerd!"); without it
/// the button is a round icon.
class CopyButton extends StatefulWidget {
  const CopyButton({
    super.key,
    required this.text,
    required this.tooltip,
    this.label,
    this.message,
  });

  final String text;
  final String tooltip;
  final String? label;

  /// Snackbar after copying, e.g. "Vriendcode K7QX2M gekopieerd."
  final String? message;

  @override
  State<CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<CopyButton> {
  bool _copied = false;
  Timer? _reset;

  @override
  void dispose() {
    _reset?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.text));
    unawaited(HapticFeedback.lightImpact());
    if (!mounted) return;
    setState(() => _copied = true);
    _reset?.cancel();
    _reset = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _copied = false);
    });
    final message = widget.message;
    if (message != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Widget get _icon => AnimatedSwitcher(
    duration: const Duration(milliseconds: 350),
    switchInCurve: Curves.elasticOut,
    switchOutCurve: Curves.easeIn,
    transitionBuilder: (child, anim) => RotationTransition(
      turns: Tween(begin: 0.6, end: 1.0).animate(anim),
      child: ScaleTransition(scale: anim, child: child),
    ),
    child: Icon(
      _copied ? Icons.check_rounded : Icons.copy_rounded,
      key: ValueKey(_copied),
      size: widget.label == null ? 22 : 14,
      color: _copied
          ? (widget.label == null ? AppColors.greenInk : AppColors.green)
          : (widget.label == null ? AppColors.textSoft : AppColors.text),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final label = widget.label;
    if (label == null) {
      return Tooltip(
        message: widget.tooltip,
        child: Semantics(
          button: true,
          label: _copied ? 'Gekopieerd' : widget.tooltip,
          child: GestureDetector(
            onTap: _copy,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _copied ? AppColors.green : Colors.transparent,
              ),
              child: _icon,
            ),
          ),
        ),
      );
    }

    return Tooltip(
      message: widget.tooltip,
      child: Material(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: _copy,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _icon,
                const SizedBox(width: 6),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    _copied ? 'Gekopieerd!' : label,
                    key: ValueKey(_copied),
                    style: AppTextStyles.body(
                      12,
                      weight: FontWeight.w900,
                      color: _copied ? AppColors.green : AppColors.text,
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
