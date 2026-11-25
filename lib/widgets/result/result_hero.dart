import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../models/game_rules.dart';
import '../../models/spell_info.dart';
import '../../services/audio/sfx_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// The badge and "GEWONNEN!" / "VERLOREN" at the top of the result screen,
/// each with its own animation, timed to its sound:
///
/// * Won, "de-de-duuu!": the trophy jumps up on every note, and on the last
///   one confetti bursts out, light rays start turning and the letters pop
///   in one by one.
/// * Lost, "duh, duh, duuuh": the badge sinks a step on every note, then on
///   the long last note it swings crooked like a sign hanging from one
///   nail, a little cloud rains on it and the word sags.
class ResultHero extends StatefulWidget {
  const ResultHero({
    super.key,
    required this.won,
    required this.opponentName,
    required this.rounds,
    this.playSound = true,
  });

  final bool won;
  final String opponentName;
  final int rounds;
  final bool playSound;

  /// When the notes start, in seconds. Must match `WIN_NOTES` and
  /// `LOSE_NOTES` in `tool/gen_sfx.py`.
  static const winNotes = [0.0, 0.14, 0.28];
  static const loseNotes = [0.0, 0.42, 0.84];

  /// Wait for the screen's own entrance animation first.
  static const startDelay = Duration(milliseconds: 350);

  @override
  State<ResultHero> createState() => _ResultHeroState();
}

class _ResultHeroState extends State<ResultHero>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: widget.won ? 3000 : 3400),
  );
  final _confetti = OverlayPortalController();
  final _anchor = LayerLink();
  Timer? _start;
  bool _scheduled = false;

  /// Seconds since the first note.
  double get _t => _c.value * _c.duration!.inMilliseconds / 1000;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_scheduled) return;
    _scheduled = true;
    // Reduced motion: show the end state, still play the sound.
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _start = Timer(still ? Duration.zero : ResultHero.startDelay, () {
      if (!mounted) return;
      if (widget.playSound) {
        SfxService.instance.play(
          widget.won ? SfxSound.resultWin : SfxSound.resultLose,
          volume: widget.won ? 1 : .85,
        );
      }
      if (still) {
        _c.value = 1;
      } else {
        if (widget.won) _confetti.show();
        _c.forward().whenComplete(() {
          if (mounted && _confetti.isShowing) _confetti.hide();
        });
      }
    });
  }

  @override
  void dispose() {
    _start?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final won = widget.won;
    final rounds = widget.rounds;
    final name = widget.opponentName;
    return OverlayPortal(
      controller: _confetti,
      // Above the whole screen, so it falls over the cards below too.
      overlayChildBuilder: (context) => Positioned.fill(
        child: IgnorePointer(
          child: CompositedTransformFollower(
            link: _anchor,
            targetAnchor: Alignment.center,
            followerAnchor: Alignment.center,
            child: Center(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _c,
                  builder: (context, _) => CustomPaint(
                    size: Size.zero,
                    painter: _ConfettiPainter(_t - ResultHero.winNotes[2]),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.isDismissed ? -1.0 : _t;
          return Column(
            children: [
              SizedBox(
                height: 150,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    if (won)
                      _Rays(t: t - ResultHero.winNotes[2])
                    else
                      Positioned(
                        top: -34,
                        left: 0,
                        right: 0,
                        height: 190,
                        child: _RainCloud(t: t - ResultHero.loseNotes[2]),
                      ),
                    CompositedTransformTarget(
                      link: _anchor,
                      child: won ? _winBadge(t) : _loseBadge(t),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Semantics(
                // Its own node, so the heading isn't merged with the line
                // under it.
                container: true,
                header: true,
                label: won ? 'Gewonnen!' : 'Verloren',
                excludeSemantics: true,
                child: _Title(
                  text: won ? 'GEWONNEN!' : 'VERLOREN',
                  won: won,
                  t: t,
                ),
              ),
              const SizedBox(height: 10),
              Opacity(
                opacity: ((t - (won ? .7 : 1.4)) / .4).clamp(0.0, 1.0),
                child: Text(
                  won
                      ? 'Je versloeg $name in $rounds ${rounds == 1 ? 'ronde' : 'rondes'}.'
                      : '$name won na $rounds ${rounds == 1 ? 'ronde' : 'rondes'}. Revanche?',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body(
                    15,
                    weight: FontWeight.w700,
                    color: AppColors.textSoft,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Grows in three jumps, one per note, then wiggles.
  Widget _winBadge(double t) {
    const steps = [.55, .2, .25];
    var scale = 0.0;
    for (var i = 0; i < 3; i++) {
      final k = ((t - ResultHero.winNotes[i]) / .16).clamp(0.0, 1.0);
      scale += steps[i] * Curves.easeOutBack.transform(k);
    }
    final dt = t - ResultHero.winNotes[2];
    final wiggle = dt < 0 ? 0.0 : sin(dt * 20) * .14 * exp(-dt * 4);
    // A hop on each note.
    var hop = 0.0;
    for (final n in ResultHero.winNotes) {
      final d = t - n;
      if (d >= 0 && d < .14) hop += -10 * sin(pi * d / .14);
    }
    return Transform.translate(
      offset: Offset(0, hop),
      child: Transform.rotate(
        angle: -.105 + wiggle,
        child: Transform.scale(
          scale: max(0, scale),
          child: const _Badge(won: true),
        ),
      ),
    );
  }

  /// Sinks a step per note, then hangs crooked from its top-left corner.
  Widget _loseBadge(double t) {
    const stops = [-46.0, -26.0, -10.0, 0.0];
    var y = stops[0];
    for (var i = 0; i < 3; i++) {
      final k = ((t - ResultHero.loseNotes[i]) / .3).clamp(0.0, 1.0);
      y += (stops[i + 1] - stops[i]) * Curves.easeOutCubic.transform(k);
    }
    final opacity = (t / .2).clamp(0.0, 1.0);
    final dt = t - ResultHero.loseNotes[2];
    final swing = dt < 0
        ? 0.0
        : .26 * (1 - exp(-dt * 3)) + .18 * sin(dt * 7) * exp(-dt * 1.6);
    return Opacity(
      opacity: opacity,
      child: Transform.translate(
        offset: Offset(0, y),
        child: Transform.rotate(
          angle: -.105 + swing,
          alignment: const Alignment(-.8, -.8),
          child: const _Badge(won: false),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.won});

  final bool won;

  @override
  Widget build(BuildContext context) {
    final colors = won
        ? const [AppColors.goldNumber, AppColors.gold, Color(0xFFB86E00)]
        : const [Color(0xFFDCD5FF), Color(0xFF8B7CFF), Color(0xFF4A3BC2)];
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(36),
        gradient: RadialGradient(
          center: const Alignment(-0.3, -0.5),
          radius: 0.95,
          colors: colors,
          stops: const [0, 0.5, 1],
        ),
        boxShadow: [
          BoxShadow(color: colors[1].withValues(alpha: 0.12), spreadRadius: 8),
          BoxShadow(
            color: colors[1].withValues(alpha: 0.35),
            blurRadius: 50,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Icon(
        won ? Icons.emoji_events_rounded : Icons.heart_broken_rounded,
        size: 62,
        color: Colors.white,
      ),
    );
  }
}

/// The title, one letter at a time: popping in (won) or dropping in on
/// the notes and then sagging (lost).
class _Title extends StatelessWidget {
  const _Title({required this.text, required this.won, required this.t});

  final String text;
  final bool won;
  final double t;

  @override
  Widget build(BuildContext context) {
    final color = won ? AppColors.gold : AppColors.lavender;
    final style = AppTextStyles.display(52, color: color).copyWith(
      height: 1,
      shadows: [
        Shadow(
          color: won ? AppColors.goldTitleShadow : AppColors.purpleShadow,
          offset: const Offset(0, 5),
        ),
      ],
    );
    final letters = text.characters.toList();
    final n = letters.length;
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final (i, ch) in letters.indexed)
            won ? _winLetter(ch, i, style) : _loseLetter(ch, i, n, style),
        ],
      ),
    );
  }

  Widget _winLetter(String ch, int i, TextStyle style) {
    final start = ResultHero.winNotes[2] + .035 * i;
    final k = ((t - start) / .3).clamp(0.0, 1.0);
    final scale = Curves.elasticOut.transform(k);
    return Opacity(
      opacity: (k * 4).clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(0, 18 * (1 - Curves.easeOut.transform(k))),
        child: Transform.scale(
          scale: scale,
          child: Text(ch, style: style),
        ),
      ),
    );
  }

  Widget _loseLetter(String ch, int i, int n, TextStyle style) {
    // A third of the letters on each note.
    final note = min(2, i * 3 ~/ n);
    final start = ResultHero.loseNotes[note] + .05 * (i - (note * n / 3));
    final k = ((t - start) / .28).clamp(0.0, 1.0);
    final drop = -30 * (1 - Curves.easeOutCubic.transform(k));
    // After the last note the word sags in the middle, letters tilting.
    final sagK = Curves.easeInOut.transform(
      ((t - ResultHero.loseNotes[2] - .15) / 1.1).clamp(0.0, 1.0),
    );
    final sag = 9 * sin(pi * (i + .5) / n) * sagK;
    final tilt = (i.isEven ? 1 : -1) * .07 * sagK;
    return Opacity(
      opacity: k,
      child: Transform.translate(
        offset: Offset(0, drop + sag),
        child: Transform.rotate(
          angle: tilt,
          child: Text(ch, style: style),
        ),
      ),
    );
  }
}

/// Turning light rays behind the trophy, from the last note on.
class _Rays extends StatelessWidget {
  const _Rays({required this.t});

  /// Seconds since the last note; negative before it.
  final double t;

  @override
  Widget build(BuildContext context) {
    if (t <= 0) return const SizedBox.shrink();
    return IgnorePointer(
      child: CustomPaint(size: const Size(300, 300), painter: _RaysPainter(t)),
    );
  }
}

class _RaysPainter extends CustomPainter {
  _RaysPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final grow = Curves.easeOutBack.transform((t / .5).clamp(0.0, 1.0));
    final r = 150 * grow;
    if (r <= 0) return;
    // Spins fast at first, then slows down.
    final angle = 1.6 * (1 - exp(-t * 1.2)) + .05 * t;
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.goldLight.withValues(alpha: .38),
          AppColors.gold.withValues(alpha: .12),
          AppColors.gold.withValues(alpha: 0),
        ],
        stops: const [0, .55, 1],
      ).createShader(Rect.fromCircle(center: c, radius: r));
    const rays = 12;
    for (var i = 0; i < rays; i++) {
      final a = angle + i * 2 * pi / rays;
      const w = pi / rays * .55;
      canvas.drawPath(
        Path()
          ..moveTo(c.dx, c.dy)
          ..lineTo(c.dx + cos(a - w) * r, c.dy + sin(a - w) * r)
          ..lineTo(c.dx + cos(a + w) * r, c.dy + sin(a + w) * r)
          ..close(),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_RaysPainter old) => old.t != t;
}

/// Confetti bursting out of the trophy and fluttering down.
class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.t);

  /// Seconds since the burst; negative before it.
  final double t;

  static const life = 2.6;
  static final _pieces = _makePieces();

  static List<_Piece> _makePieces() {
    final r = Random(7);
    final colors = [
      for (final s in Spell.values) s.color,
      AppColors.gold,
      AppColors.goldLight,
      Colors.white,
      AppColors.green,
    ];
    return [
      for (var i = 0; i < 90; i++)
        _Piece(
          angle: -pi / 2 + (r.nextDouble() - .5) * pi * 1.5,
          speed: 380 + r.nextDouble() * 520,
          color: colors[r.nextInt(colors.length)],
          w: 6 + r.nextDouble() * 6,
          h: 3 + r.nextDouble() * 4,
          spin: (r.nextDouble() - .5) * 18,
          flutter: 4 + r.nextDouble() * 6,
          phase: r.nextDouble() * 2 * pi,
          round: r.nextDouble() < .25,
        ),
    ];
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t > life) return;
    const drag = 2.6, gravity = 520.0;
    final fade = (1 - (t - (life - .6)) / .6).clamp(0.0, 1.0);
    final decay = (1 - exp(-drag * t)) / drag;
    for (final p in _pieces) {
      final vx = cos(p.angle) * p.speed, vy = sin(p.angle) * p.speed;
      // Air drag on the burst, then a steady fall with a side flutter.
      final x = vx * decay + sin(t * p.flutter + p.phase) * 12 * min(1, t);
      final y = vy * decay + .5 * gravity * t * t * .55;
      final paint = Paint()..color = p.color.withValues(alpha: fade);
      canvas
        ..save()
        ..translate(x, y)
        ..rotate(p.spin * t)
        // Flip like paper: squash one side over time.
        ..scale(1, cos(t * p.flutter * 1.3 + p.phase).abs() * .8 + .2);
      if (p.round) {
        canvas.drawCircle(Offset.zero, p.h * .8, paint);
      } else {
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: p.w, height: p.h),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}

class _Piece {
  const _Piece({
    required this.angle,
    required this.speed,
    required this.color,
    required this.w,
    required this.h,
    required this.spin,
    required this.flutter,
    required this.phase,
    required this.round,
  });

  final double angle, speed, w, h, spin, flutter, phase;
  final Color color;
  final bool round;
}

/// A small grey cloud that rains on the badge for a while.
class _RainCloud extends StatelessWidget {
  const _RainCloud({required this.t});

  /// Seconds since the last note; negative before it.
  final double t;

  @override
  Widget build(BuildContext context) {
    if (t <= 0) return const SizedBox.shrink();
    return IgnorePointer(child: CustomPaint(painter: _RainPainter(t)));
  }
}

class _RainPainter extends CustomPainter {
  _RainPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    // In over 0.4 s, rains, out over the last 0.5 s (gone at 2.5 s).
    final alpha =
        (t / .4).clamp(0.0, 1.0) * (1 - ((t - 2.0) / .5).clamp(0.0, 1.0));
    if (alpha <= 0) return;
    // Right above the badge (its top is ~50 px down), a bit to the side.
    final cloud = Offset(size.width / 2 + 14, 4 + 6 * (1 - alpha));

    // Rain first, so it starts under the cloud. The badge is drawn on top
    // and hides each drop as it "hits" it.
    final rain = Paint()
      ..color = const Color(0xFFA9CCF5).withValues(alpha: .9 * alpha)
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;
    const fall = 70.0;
    for (var i = 0; i < 12; i++) {
      final x = cloud.dx - 30 + i * 5.5;
      final y = (t * 300 + i * 23) % fall;
      final top = cloud.dy + 10 + y;
      canvas.drawLine(
        Offset(x - y * .08, top),
        Offset(x - y * .08 - 2, top + 12),
        rain,
      );
    }

    final fill = Paint()
      ..color = const Color(0xFF6E6896).withValues(alpha: alpha);
    final light = Paint()
      ..color = const Color(0xFF8D86B8).withValues(alpha: alpha);
    for (final (dx, dy, r) in [
      (-26.0, 4.0, 15.0),
      (0.0, -6.0, 21.0),
      (26.0, 4.0, 15.0),
    ]) {
      canvas.drawCircle(cloud + Offset(dx, dy), r, fill);
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: cloud + const Offset(0, 10),
          width: 78,
          height: 18,
        ),
        const Radius.circular(9),
      ),
      fill,
    );
    canvas.drawCircle(cloud + const Offset(-6, -11), 10, light);
  }

  @override
  bool shouldRepaint(_RainPainter old) => old.t != t;
}
