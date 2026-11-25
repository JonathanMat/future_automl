import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../generic/chunky_button.dart';
import '../generic/player_name.dart';

/// The end of the tournament: confetti rain, turning light rays, the trophy
/// slamming in and the champion's name in gold. Everybody sees it; the
/// champion gets "JIJ BENT KAMPIOEN!".
class ChampionOverlay extends StatefulWidget {
  const ChampionOverlay({
    super.key,
    required this.name,
    this.tag,
    required this.isMe,
    required this.players,
    required this.onClose,
    this.xp,
  });

  final String name;
  final String? tag;
  final bool isMe;
  final int players;
  final int? xp;
  final VoidCallback onClose;

  @override
  State<ChampionOverlay> createState() => _ChampionOverlayState();
}

class _ChampionOverlayState extends State<ChampionOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _in = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..forward();
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();
  late final List<_Confetto> _confetti = _Confetto.spawn(Random(7), 150);

  /// Seconds since the overlay opened, for the confetti (never wraps).
  final _time = ValueNotifier<double>(0);
  late final _ticker = createTicker(
    (elapsed) => _time.value = elapsed.inMicroseconds / 1e6,
  );

  @override
  void initState() {
    super.initState();
    _ticker.start();
    HapticFeedback.heavyImpact();
    Future<void>.delayed(const Duration(milliseconds: 520), () {
      if (mounted) HapticFeedback.mediumImpact();
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    _in.dispose();
    _loop.dispose();
    super.dispose();
  }

  Animation<double> _interval(double a, double b, Curve curve) =>
      CurvedAnimation(
        parent: _in,
        curve: Interval(a, b, curve: curve),
      );

  @override
  Widget build(BuildContext context) {
    final fade = _interval(0, 0.25, Curves.easeOut);
    final trophy = _interval(0.1, 0.55, Curves.elasticOut);
    final title = _interval(0.35, 0.7, Curves.easeOutBack);
    final name = _interval(0.5, 0.85, Curves.easeOutBack);
    final rest = _interval(0.7, 1, Curves.easeOut);

    return Semantics(
      liveRegion: true,
      label: widget.isMe
          ? 'Jij bent kampioen!'
          : '${widget.name} is kampioen van het toernooi',
      child: Material(
        type: MaterialType.transparency,
        child: AnimatedBuilder(
          animation: Listenable.merge([_in, _loop, _time]),
          builder: (context, _) {
            return Stack(
              fit: StackFit.expand,
              children: [
                Opacity(
                  opacity: fade.value,
                  child: const ColoredBox(color: Color(0xE6070512)),
                ),
                CustomPaint(
                  painter: _RaysPainter(
                    turn: _loop.value,
                    strength: fade.value,
                  ),
                ),
                CustomPaint(
                  painter: _ConfettiPainter(
                    confetti: _confetti,
                    time: _time.value,
                    opacity: fade.value,
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const Spacer(flex: 3),
                        Transform.scale(
                          scale: trophy.value,
                          child: _Trophy(
                            glow: 0.6 + 0.4 * sin(_loop.value * 2 * pi * 3),
                          ),
                        ),
                        const SizedBox(height: 26),
                        Opacity(
                          opacity: title.value.clamp(0.0, 1.0),
                          child: Transform.translate(
                            offset: Offset(0, 30 * (1 - title.value)),
                            child: Text(
                              widget.isMe ? 'JIJ BENT KAMPIOEN!' : 'KAMPIOEN!',
                              textAlign: TextAlign.center,
                              style:
                                  AppTextStyles.display(
                                    widget.isMe ? 40 : 46,
                                    color: AppColors.goldNumber,
                                  ).copyWith(
                                    shadows: const [
                                      Shadow(
                                        color: AppColors.goldNumberDeep,
                                        offset: Offset(0, 4),
                                      ),
                                      Shadow(
                                        color: AppColors.gold,
                                        blurRadius: 24,
                                      ),
                                    ],
                                  ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Opacity(
                          opacity: name.value.clamp(0.0, 1.0),
                          child: Transform.scale(
                            scale: 0.6 + 0.4 * name.value,
                            child: PlayerName(
                              name: widget.name,
                              tag: widget.tag,
                              textAlign: TextAlign.center,
                              style: AppTextStyles.display(30),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Opacity(
                          opacity: rest.value,
                          child: Text(
                            'wint het toernooi met ${widget.players} spelers',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.body(
                              15,
                              color: AppColors.textSoft,
                            ),
                          ),
                        ),
                        if (widget.xp != null) ...[
                          const SizedBox(height: 14),
                          Opacity(
                            opacity: rest.value,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.gold.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.gold.withValues(alpha: 0.5),
                                ),
                              ),
                              child: Text(
                                '+${widget.xp} XP',
                                style: AppTextStyles.display(
                                  20,
                                  color: AppColors.goldLight,
                                ),
                              ),
                            ),
                          ),
                        ],
                        const Spacer(flex: 4),
                        Opacity(
                          opacity: rest.value,
                          child: ChunkyButton(
                            label: 'BEKIJK SCHEMA',
                            height: 58,
                            fontSize: 20,
                            style: ChunkyButtonStyle.success,
                            onPressed: rest.value > 0.5 ? widget.onClose : null,
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

class _Trophy extends StatelessWidget {
  const _Trophy({required this.glow});

  final double glow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      height: 150,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [AppColors.goldLight, AppColors.gold, AppColors.goldShadow],
          stops: [0, 0.6, 1],
        ),
        border: Border.all(color: AppColors.goldNumber, width: 4),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.5 * glow),
            blurRadius: 60,
            spreadRadius: 10,
          ),
          const BoxShadow(
            color: AppColors.goldNumberDeep,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: const Icon(
        Icons.emoji_events_rounded,
        size: 92,
        color: AppColors.goldInk,
      ),
    );
  }
}

class _RaysPainter extends CustomPainter {
  _RaysPainter({required this.turn, required this.strength});

  final double turn;
  final double strength;

  @override
  void paint(Canvas canvas, Size size) {
    if (strength <= 0) return;
    final c = Offset(size.width / 2, size.height * 0.34);
    final r = size.longestSide;
    canvas
      ..save()
      ..translate(c.dx, c.dy)
      ..rotate(turn * 2 * pi);
    const rays = 18;
    final shader = RadialGradient(
      colors: [
        AppColors.gold.withValues(alpha: 0.32 * strength),
        AppColors.gold.withValues(alpha: 0),
      ],
    ).createShader(Rect.fromCircle(center: Offset.zero, radius: r * 0.7));
    final paint = Paint()..shader = shader;
    for (var i = 0; i < rays; i++) {
      final a = i * 2 * pi / rays;
      canvas.drawPath(
        Path()
          ..moveTo(0, 0)
          ..lineTo(cos(a - 0.07) * r, sin(a - 0.07) * r)
          ..lineTo(cos(a + 0.07) * r, sin(a + 0.07) * r)
          ..close(),
        paint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RaysPainter old) =>
      old.turn != turn || old.strength != strength;
}

/// One piece of confetti, falling and fluttering forever (it wraps).
class _Confetto {
  _Confetto({
    required this.x,
    required this.y,
    required this.speed,
    required this.drift,
    required this.spin,
    required this.size,
    required this.color,
    required this.phase,
    required this.round,
  });

  static List<_Confetto> spawn(Random rnd, int n) => [
    for (var i = 0; i < n; i++)
      _Confetto(
        x: rnd.nextDouble(),
        y: -rnd.nextDouble() * 1.2,
        speed: 0.14 + rnd.nextDouble() * 0.2,
        drift: 0.02 + rnd.nextDouble() * 0.05,
        spin: 2 + rnd.nextDouble() * 6,
        size: 5 + rnd.nextDouble() * 7,
        color: _colors[rnd.nextInt(_colors.length)],
        phase: rnd.nextDouble() * 2 * pi,
        round: rnd.nextInt(4) == 0,
      ),
  ];

  static const _colors = [
    AppColors.gold,
    AppColors.goldLight,
    AppColors.lavender,
    AppColors.violet,
    AppColors.green,
    AppColors.redSoft,
    Colors.white,
  ];

  final double x, y, speed, drift, spin, size, phase;
  final Color color;
  final bool round;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({
    required this.confetti,
    required this.time,
    required this.opacity,
  });

  final List<_Confetto> confetti;
  final double time;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0) return;
    final paint = Paint();
    for (final c in confetti) {
      // y in screens: starts above, falls, wraps around.
      final raw = c.y + c.speed * time;
      final y = ((raw + 0.2) % 1.4 - 0.2) * size.height;
      final x = (c.x + sin(time * 1.3 + c.phase) * c.drift) * size.width;
      final flip = cos(time * c.spin + c.phase);
      paint.color = c.color.withValues(
        alpha: opacity * (0.55 + 0.45 * flip.abs()),
      );
      canvas
        ..save()
        ..translate(x, y)
        ..rotate(time * c.spin * 0.4 + c.phase);
      if (c.round) {
        canvas.drawCircle(Offset.zero, c.size * 0.35, paint);
      } else {
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: c.size,
            height: c.size * 0.45 * flip.abs() + 1,
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) =>
      old.time != time || old.opacity != opacity;
}
