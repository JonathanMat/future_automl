import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// "DE LOTING": names spin past like a slot machine, slow down and land on
/// your first opponent — or on "VRIJLOTING" when you go straight through.
class DrawRevealOverlay extends StatefulWidget {
  const DrawRevealOverlay({
    super.key,
    required this.names,
    required this.opponent,
    required this.players,
    required this.byes,
    required this.onDone,
  });

  /// Everybody's names, to spin through.
  final List<String> names;

  /// Your first opponent; null means a bye.
  final String? opponent;
  final int players;
  final int byes;
  final VoidCallback onDone;

  static const spinTime = Duration(milliseconds: 2300);
  static const holdTime = Duration(milliseconds: 1700);

  @override
  State<DrawRevealOverlay> createState() => _DrawRevealOverlayState();
}

class _DrawRevealOverlayState extends State<DrawRevealOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: DrawRevealOverlay.spinTime,
  );
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  )..forward();
  late final AnimationController _land = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  Timer? _done;
  int _lastTick = -1;

  /// The reel: shuffled names, ending on the result.
  late final List<String> _reel = () {
    final pool = widget.names.isEmpty ? ['?'] : widget.names;
    final rnd = Random();
    final reel = [for (var i = 0; i < 26; i++) pool[rnd.nextInt(pool.length)]];
    reel.add(widget.opponent ?? 'VRIJLOTING');
    return reel;
  }();

  @override
  void initState() {
    super.initState();
    _spin.addListener(_tick);
    _spin.forward().whenComplete(() {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      _land.forward();
      _done = Timer(DrawRevealOverlay.holdTime, () async {
        if (!mounted) return;
        await _fade.reverse();
        if (mounted) widget.onDone();
      });
    });
  }

  double get _position =>
      Curves.easeOutQuart.transform(_spin.value) * (_reel.length - 1);

  void _tick() {
    final i = _position.floor();
    if (i != _lastTick) {
      _lastTick = i;
      HapticFeedback.selectionClick();
    }
  }

  @override
  void dispose() {
    _done?.cancel();
    _spin.dispose();
    _fade.dispose();
    _land.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bye = widget.opponent == null;
    return Material(
      type: MaterialType.transparency,
      child: FadeTransition(
        opacity: _fade,
        child: GestureDetector(
          onTap: () {
            if (_land.isCompleted) widget.onDone();
          },
          child: ColoredBox(
            color: const Color(0xFA070512),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: AnimatedBuilder(
                  animation: Listenable.merge([_spin, _land]),
                  builder: (context, _) {
                    final land = Curves.elasticOut.transform(_land.value);
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.casino_rounded,
                          size: 46,
                          color: AppColors.lavender,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'DE LOTING',
                          style: AppTextStyles.display(
                            40,
                            color: AppColors.goldNumber,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${widget.players} spelers'
                          '${widget.byes > 0 ? ' · ${widget.byes} ${widget.byes == 1 ? 'vrijloting' : 'vrijlotingen'}' : ''}',
                          style: AppTextStyles.body(
                            14,
                            color: AppColors.textSoft,
                          ),
                        ),
                        const SizedBox(height: 40),
                        Text(
                          bye && _land.value > 0
                              ? 'Geen tegenstander in ronde 1:'
                              : 'Jij speelt tegen',
                          style: AppTextStyles.overline(),
                        ),
                        const SizedBox(height: 14),
                        _Reel(
                          reel: _reel,
                          position: _position,
                          landed: land,
                          bye: bye,
                        ),
                        const SizedBox(height: 18),
                        Opacity(
                          opacity: _land.value,
                          child: Text(
                            bye
                                ? 'Je gaat meteen door naar de volgende ronde!'
                                : 'Veel succes!',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.body(
                              15,
                              color: bye ? AppColors.green : AppColors.textSoft,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Reel extends StatelessWidget {
  const _Reel({
    required this.reel,
    required this.position,
    required this.landed,
    required this.bye,
  });

  final List<String> reel;
  final double position;
  final double landed;
  final bool bye;

  static const itemHeight = 64.0;

  @override
  Widget build(BuildContext context) {
    final i = position.floor();
    final frac = position - i;
    final glow = bye ? AppColors.green : AppColors.gold;
    return Container(
      height: itemHeight * 1.6,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Color.lerp(AppColors.borderStrong, glow, landed.clamp(0, 1))!,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: glow.withValues(alpha: 0.4 * landed.clamp(0, 1)),
            blurRadius: 30,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: ShaderMask(
        shaderCallback: (r) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.white,
            Colors.white,
            Colors.transparent,
          ],
          stops: [0, 0.3, 0.7, 1],
        ).createShader(r),
        child: Stack(
          alignment: Alignment.center,
          children: [
            for (var k = -1; k <= 1; k++)
              if (i + k >= 0 && i + k < reel.length)
                Transform.translate(
                  offset: Offset(0, (k - frac) * itemHeight),
                  child: Transform.scale(
                    scale: k == 0 && frac < 0.01 ? 1 + 0.15 * landed : 1,
                    child: Text(
                      reel[i + k],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.display(
                        40,
                        color: i + k == reel.length - 1 && landed > 0
                            ? (bye ? AppColors.green : AppColors.goldNumber)
                            : AppColors.text,
                      ),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
