import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../generic/avatar_tile.dart';
import '../generic/chunky_button.dart';

enum CallUpStage {
  /// Counting down, then the duel starts by itself.
  countdown,

  /// Getting into the room.
  joining,

  /// The opponent opens the room; waiting for it.
  waitingForRoom,
}

/// "JOUW DUEL!": slams in when your match is ready, the two players fly in
/// from both sides with VS between them, and a ring counts down to the duel.
class CallUpOverlay extends StatefulWidget {
  const CallUpOverlay({
    super.key,
    required this.myName,
    required this.opponentName,
    required this.roundName,
    required this.stage,
    required this.secondsLeft,
    required this.onPlay,
    required this.onLater,
    this.opponentOffline = false,
  });

  final String myName;
  final String opponentName;
  final String roundName;
  final CallUpStage stage;

  /// Of the countdown; 0 or less starts.
  final int secondsLeft;
  final VoidCallback onPlay;
  final VoidCallback onLater;
  final bool opponentOffline;

  @override
  State<CallUpOverlay> createState() => _CallUpOverlayState();
}

class _CallUpOverlayState extends State<CallUpOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _in = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward();
  late final AnimationController _beat = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat();

  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact();
  }

  @override
  void didUpdateWidget(CallUpOverlay old) {
    super.didUpdateWidget(old);
    if (old.secondsLeft != widget.secondsLeft && widget.secondsLeft > 0) {
      HapticFeedback.selectionClick();
    }
  }

  @override
  void dispose() {
    _in.dispose();
    _beat.dispose();
    super.dispose();
  }

  Animation<double> _iv(double a, double b, Curve c) => CurvedAnimation(
    parent: _in,
    curve: Interval(a, b, curve: c),
  );

  @override
  Widget build(BuildContext context) {
    final scrim = _iv(0, 0.3, Curves.easeOut);
    final title = _iv(0.05, 0.5, Curves.elasticOut);
    final left = _iv(0.3, 0.75, Curves.easeOutBack);
    final right = _iv(0.35, 0.8, Curves.easeOutBack);
    final vs = _iv(0.6, 1, Curves.elasticOut);

    final status = switch (widget.stage) {
      CallUpStage.countdown => 'Het duel start zo…',
      CallUpStage.joining => 'Kamer openen…',
      CallUpStage.waitingForRoom =>
        'Wachten tot ${widget.opponentName} de kamer opent…',
    };

    return Semantics(
      liveRegion: true,
      label: 'Jouw duel tegen ${widget.opponentName}, ${widget.roundName}',
      child: Material(
        type: MaterialType.transparency,
        child: AnimatedBuilder(
          animation: Listenable.merge([_in, _beat]),
          builder: (context, _) {
            final w = MediaQuery.sizeOf(context).width;
            return Stack(
              fit: StackFit.expand,
              children: [
                Opacity(
                  opacity: scrim.value,
                  child: const ColoredBox(color: Color(0xF2070512)),
                ),
                Opacity(
                  opacity: scrim.value,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0, -0.1),
                        radius: 1.1,
                        colors: [
                          AppColors.purple.withValues(alpha: 0.5),
                          AppColors.purple.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
                CustomPaint(
                  painter: _SpeedLinesPainter(
                    t: _beat.value,
                    strength: scrim.value,
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                    child: Column(
                      children: [
                        const Spacer(flex: 2),
                        Text(
                          widget.roundName.toUpperCase(),
                          style: AppTextStyles.overline(
                            color: AppColors.lavender,
                          ).copyWith(fontSize: 14, letterSpacing: 4),
                        ),
                        const SizedBox(height: 8),
                        Transform.scale(
                          scale: title.value,
                          child: Text(
                            'JOUW DUEL!',
                            style:
                                AppTextStyles.display(
                                  52,
                                  color: AppColors.goldNumber,
                                ).copyWith(
                                  shadows: const [
                                    Shadow(
                                      color: AppColors.goldNumberDeep,
                                      offset: Offset(0, 5),
                                    ),
                                    Shadow(
                                      color: AppColors.gold,
                                      blurRadius: 30,
                                    ),
                                  ],
                                ),
                          ),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Expanded(
                              child: Transform.translate(
                                offset: Offset(-w * (1 - left.value), 0),
                                child: _Fighter(
                                  name: widget.myName,
                                  label: 'JIJ',
                                  color: AppColors.lavender,
                                ),
                              ),
                            ),
                            Transform.scale(
                              scale: vs.value,
                              child: _VsBadge(beat: _beat.value),
                            ),
                            Expanded(
                              child: Transform.translate(
                                offset: Offset(w * (1 - right.value), 0),
                                child: _Fighter(
                                  name: widget.opponentName,
                                  label: widget.opponentOffline
                                      ? 'OFFLINE'
                                      : 'TEGENSTANDER',
                                  color: widget.opponentOffline
                                      ? AppColors.redSoft
                                      : AppColors.orangeText,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        _Countdown(
                          stage: widget.stage,
                          seconds: widget.secondsLeft,
                          beat: _beat.value,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          status,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.body(
                            14,
                            color: AppColors.textSoft,
                          ),
                        ),
                        const Spacer(flex: 2),
                        ChunkyButton(
                          label: 'SPEEL NU',
                          height: 60,
                          fontSize: 22,
                          style: ChunkyButtonStyle.success,
                          loading: widget.stage == CallUpStage.joining,
                          onPressed: widget.stage == CallUpStage.countdown
                              ? widget.onPlay
                              : null,
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: widget.onLater,
                          child: Text(
                            'Nog even niet',
                            style: AppTextStyles.body(
                              14,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Fighter extends StatelessWidget {
  const _Fighter({
    required this.name,
    required this.label,
    required this.color,
  });

  final String name;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 3),
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 22),
            ],
          ),
          child: AvatarTile(name: name, size: 84, circle: true),
        ),
        const SizedBox(height: 12),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.display(22),
        ),
        const SizedBox(height: 2),
        Text(label, style: AppTextStyles.overline(color: color)),
      ],
    );
  }
}

class _VsBadge extends StatelessWidget {
  const _VsBadge({required this.beat});

  final double beat;

  @override
  Widget build(BuildContext context) {
    final pump = 1 + 0.06 * sin(beat * 2 * pi);
    return Transform.scale(
      scale: pump,
      child: Container(
        width: 64,
        height: 64,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.red,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: AppColors.red.withValues(alpha: 0.6),
              blurRadius: 26,
            ),
          ],
        ),
        child: Text('VS', style: AppTextStyles.display(26)),
      ),
    );
  }
}

class _Countdown extends StatelessWidget {
  const _Countdown({
    required this.stage,
    required this.seconds,
    required this.beat,
  });

  final CallUpStage stage;
  final int seconds;
  final double beat;

  @override
  Widget build(BuildContext context) {
    final counting = stage == CallUpStage.countdown;
    return SizedBox.square(
      dimension: 92,
      child: CustomPaint(
        painter: _RingPainter(
          // Within the current second the ring runs down.
          progress: counting ? 1 - beat : beat,
          spinning: !counting,
        ),
        child: Center(
          child: counting
              ? AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (child, a) =>
                      ScaleTransition(scale: a, child: child),
                  child: Text(
                    '${max(seconds, 0)}',
                    key: ValueKey(seconds),
                    style: AppTextStyles.display(44, color: AppColors.gold),
                  ),
                )
              : const Icon(
                  Icons.meeting_room_rounded,
                  color: AppColors.lavender,
                  size: 34,
                ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.spinning});

  final double progress;
  final bool spinning;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final r = rect.deflate(5);
    canvas.drawArc(
      r,
      0,
      2 * pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = AppColors.track,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..color = spinning ? AppColors.lavender : AppColors.gold;
    if (spinning) {
      canvas.drawArc(r, progress * 2 * pi - pi / 2, pi / 2, false, paint);
    } else {
      canvas.drawArc(r, -pi / 2, 2 * pi * progress, false, paint);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.spinning != spinning;
}

/// Streaks rushing towards the middle, like a fighting-game "versus".
class _SpeedLinesPainter extends CustomPainter {
  _SpeedLinesPainter({required this.t, required this.strength});

  final double t;
  final double strength;

  @override
  void paint(Canvas canvas, Size size) {
    if (strength <= 0) return;
    final rnd = Random(3);
    final c = Offset(size.width / 2, size.height * 0.5);
    final paint = Paint()..strokeCap = StrokeCap.round;
    for (var i = 0; i < 38; i++) {
      final a = rnd.nextDouble() * 2 * pi;
      final speed = 0.6 + rnd.nextDouble();
      final phase = (rnd.nextDouble() + t * speed) % 1;
      final far = size.longestSide * (0.75 - 0.5 * phase);
      final len = 40 + 90 * rnd.nextDouble();
      final dir = Offset(cos(a), sin(a));
      paint
        ..strokeWidth = 1 + rnd.nextDouble() * 2
        ..color = Colors.white.withValues(alpha: 0.12 * strength * (1 - phase));
      canvas.drawLine(c + dir * far, c + dir * (far + len), paint);
    }
  }

  @override
  bool shouldRepaint(_SpeedLinesPainter old) =>
      old.t != t || old.strength != strength;
}
