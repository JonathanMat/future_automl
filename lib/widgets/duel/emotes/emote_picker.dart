import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/emote.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../theme/app_transitions.dart';
import 'emote_art.dart';

/// The emote button in a corner of your camera, with the picker that
/// opens above it.
///
/// Put it in a [Positioned.fill] over the feed: it places itself in the
/// bottom-right corner and only takes taps on the button and the open
/// picker (and outside it, to close it).
class EmoteControls extends StatefulWidget {
  const EmoteControls({
    super.key,
    required this.enabled,
    required this.onSend,
    this.cooldown = const Duration(milliseconds: 1800),
  });

  /// False while there is nobody to send to.
  final bool enabled;
  final ValueChanged<Emote> onSend;

  /// Time between two emotes, against spamming.
  final Duration cooldown;

  @override
  State<EmoteControls> createState() => _EmoteControlsState();
}

class _EmoteControlsState extends State<EmoteControls>
    with SingleTickerProviderStateMixin {
  bool _open = false;
  late final _cooldown = AnimationController(
    vsync: this,
    duration: widget.cooldown,
  );

  bool get _coolingDown => _cooldown.isAnimating;

  @override
  void didUpdateWidget(EmoteControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && _open) _open = false;
  }

  @override
  void dispose() {
    _cooldown.dispose();
    super.dispose();
  }

  void _toggle() {
    if (!widget.enabled) return;
    HapticFeedback.selectionClick();
    setState(() => _open = !_open);
  }

  void _send(Emote emote) {
    if (_coolingDown) return;
    HapticFeedback.lightImpact();
    setState(() => _open = false);
    _cooldown.forward(from: 0);
    widget.onSend(emote);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Tap anywhere else to close.
        if (_open)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _open = false),
            ),
          ),
        Positioned(
          right: 10,
          bottom: 62,
          child: AnimatedSwitcher(
            duration: AppTransitions.fast,
            switchInCurve: Curves.easeOutBack,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation.drive(CurveTween(curve: Curves.easeOut)),
              child: ScaleTransition(
                scale: animation.drive(Tween(begin: .6, end: 1)),
                alignment: Alignment.bottomRight,
                child: child,
              ),
            ),
            child: _open
                ? _Picker(key: const ValueKey('picker'), onPick: _send)
                : const SizedBox.shrink(),
          ),
        ),
        Positioned(
          right: 10,
          bottom: 10,
          child: AnimatedBuilder(
            animation: _cooldown,
            builder: (context, _) => _EmoteButton(
              open: _open,
              enabled: widget.enabled,
              cooldown: _coolingDown ? 1 - _cooldown.value : 0,
              onTap: _toggle,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmoteButton extends StatelessWidget {
  const _EmoteButton({
    required this.open,
    required this.enabled,
    required this.cooldown,
    required this.onTap,
  });

  final bool open;
  final bool enabled;

  /// 1 → 0 while you have to wait before the next emote.
  final double cooldown;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final active = open || cooldown > 0;
    return Tooltip(
      message: 'Emotes',
      child: Semantics(
        button: true,
        label: 'Emotes',
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedOpacity(
            opacity: enabled ? 1 : .45,
            duration: AppTransitions.fast,
            child: SizedBox.square(
              dimension: 44,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedContainer(
                    duration: AppTransitions.fast,
                    decoration: BoxDecoration(
                      color: open ? AppColors.gold : AppColors.overlay,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: active ? AppColors.gold : AppColors.borderInput,
                        width: 1.5,
                      ),
                    ),
                  ),
                  Icon(
                    open ? Icons.close_rounded : Icons.add_reaction_rounded,
                    size: 23,
                    color: open ? AppColors.goldInk : AppColors.goldLight,
                  ),
                  if (cooldown > 0)
                    Positioned.fill(
                      child: CustomPaint(painter: _CooldownRing(cooldown)),
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

/// Dims the button and shows the time left as a shrinking ring.
class _CooldownRing extends CustomPainter {
  _CooldownRing(this.left);

  final double left;

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(14),
    );
    canvas.drawRRect(r, Paint()..color = const Color(0x8C080614));
    final rect = (Offset.zero & size).deflate(9);
    canvas.drawArc(
      rect,
      -1.5708,
      6.2832 * left,
      false,
      Paint()
        ..color = AppColors.goldLight
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_CooldownRing old) => old.left != left;
}

class _Picker extends StatelessWidget {
  const _Picker({super.key, required this.onPick});

  final ValueChanged<Emote> onPick;

  @override
  Widget build(BuildContext context) {
    const columns = 3;
    final rows = <List<Emote>>[
      for (var i = 0; i < Emote.values.length; i += columns)
        Emote.values.sublist(i, (i + columns).clamp(0, Emote.values.length)),
    ];
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: .96),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderInput),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final row in rows)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final e in row) _EmoteTile(emote: e, onTap: onPick),
              ],
            ),
        ],
      ),
    );
  }
}

class _EmoteTile extends StatelessWidget {
  const _EmoteTile({required this.emote, required this.onTap});

  final Emote emote;
  final ValueChanged<Emote> onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => onTap(emote),
        child: SizedBox(
          width: 76,
          height: 72,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              EmoteIcon(emote: emote, size: 48),
              const SizedBox(height: 3),
              Text(
                emote.label,
                maxLines: 1,
                overflow: TextOverflow.visible,
                softWrap: false,
                style: AppTextStyles.body(
                  10.5,
                  weight: FontWeight.w900,
                  color: AppColors.textSoft,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
