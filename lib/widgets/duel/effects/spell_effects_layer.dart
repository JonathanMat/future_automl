import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../../models/game_state.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import 'fx_builder.dart';
import 'fx_core.dart';
import 'fx_plan.dart';

/// Plays a spell effect over the duel screen each time a new round result
/// arrives: fireballs fly from one camera to the other, lightning strikes,
/// cameras freeze, shields bounce spells back.
///
/// [topKey] and [bottomKey] are on the two camera feeds, so effects land
/// exactly on them. The whole screen shakes on impact and the phone buzzes.
class SpellEffectsLayer extends StatefulWidget {
  const SpellEffectsLayer({
    super.key,
    required this.result,
    required this.topKey,
    required this.bottomKey,
    required this.child,
    this.scrubTime,
  });

  /// The result being shown, or null between results. A result with a new
  /// round number plays its effect once.
  final RoundResult? result;
  final GlobalKey topKey;
  final GlobalKey bottomKey;
  final Widget child;

  /// For the effects preview: freeze the effect at this time (seconds)
  /// instead of playing it.
  final double? scrubTime;

  @override
  State<SpellEffectsLayer> createState() => _SpellEffectsLayerState();
}

class _SpellEffectsLayerState extends State<SpellEffectsLayer>
    with SingleTickerProviderStateMixin {
  final _stackKey = GlobalKey();
  late final Ticker _ticker;

  PlannedFx? _planned;
  double _t = 0;
  FxContext? _ctx;
  int? _playedRound;
  final Set<int> _firedImpacts = {};

  @override
  void initState() {
    super.initState();
    // Created here, not lazily: creating it in dispose() is not allowed.
    _ticker = createTicker(_tick);
    _check(rebuild: false);
  }

  @override
  void didUpdateWidget(SpellEffectsLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _check(rebuild: false);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _check({required bool rebuild}) {
    final r = widget.result;
    if (r == null) {
      _playedRound = null;
      return;
    }
    if (r.round == _playedRound) return;
    _playedRound = r.round;
    _ticker.stop();
    _planned = buildSpellFx(planFor(r));
    _t = 0;
    _firedImpacts.clear();
    if (_planned != null && widget.scrubTime == null) _ticker.start();
    if (rebuild) setState(() {});
  }

  void _tick(Duration elapsed) {
    final planned = _planned;
    if (planned == null) return;
    _t = elapsed.inMicroseconds / 1e6;
    _ctx = _measure() ?? _ctx;

    final impacts = planned.fx.impacts;
    for (var i = 0; i < impacts.length; i++) {
      if (_t >= impacts[i].time && _firedImpacts.add(i)) {
        impacts[i].damage
            ? HapticFeedback.heavyImpact()
            : HapticFeedback.mediumImpact();
      }
    }

    if (_t > planned.fx.duration) {
      _ticker.stop();
      _planned = null;
    }
    setState(() {});
  }

  /// Where the two cameras are, relative to this layer.
  FxContext? _measure() {
    final stack = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (stack == null || !stack.hasSize) return null;
    Rect? rectOf(GlobalKey key) {
      final box = key.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.attached || !box.hasSize) return null;
      return box.localToGlobal(Offset.zero, ancestor: stack) & box.size;
    }

    final top = rectOf(widget.topKey);
    final bottom = rectOf(widget.bottomKey);
    if (top == null || bottom == null) return null;
    return FxContext(size: stack.size, top: top, bottom: bottom);
  }

  Offset _shake(SpellFx fx, double t) {
    var offset = Offset.zero;
    for (final i in fx.impacts) {
      final dt = t - i.time;
      if (dt < 0 || dt > .5) continue;
      final decay = pow(1 - dt / .5, 2).toDouble();
      offset += Offset(
        sin(dt * 95) * i.shake * decay,
        cos(dt * 71) * i.shake * .6 * decay,
      );
    }
    return offset;
  }

  @override
  Widget build(BuildContext context) {
    final scrub = widget.scrubTime;
    if (scrub != null) {
      _ticker.stop();
      _t = scrub;
      if (_ctx == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _ctx = _measure());
        });
      }
    }
    final planned = _planned;
    final ctx = _ctx;
    final active = planned != null && ctx != null;

    return Transform.translate(
      offset: active ? _shake(planned.fx, _t) : Offset.zero,
      child: Stack(
        key: _stackKey,
        children: [
          widget.child,
          if (active) ...[
            for (final tint in planned.tints)
              if (tint.strength(_t) > 0)
                Positioned.fromRect(
                  rect: ctx.rect(tint.side),
                  child: IgnorePointer(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(FxContext.feedRadius),
                      child: BackdropFilter(
                        filter: tint.filter(_t),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _SpellFxPainter(planned.fx, ctx, _t),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SpellFxPainter extends CustomPainter {
  _SpellFxPainter(this.fx, this.ctx, this.t);

  final SpellFx fx;
  final FxContext ctx;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    for (final layer in fx.layers) {
      final local = t - layer.start;
      if (local < 0 || local > layer.duration) continue;
      layer.paint(canvas, ctx, local);
    }
    for (final impact in fx.impacts) {
      final side = impact.side;
      if (!impact.damage || side == null) continue;
      final dt = t - impact.time;
      if (dt < 0 || dt > SpellFx.damageTime) continue;
      _paintDamage(canvas, side, dt);
    }
  }

  /// Red glow around the edges and a rising "−1".
  void _paintDamage(Canvas canvas, FxSide side, double dt) {
    final rr = ctx.rrect(side);
    final glow = .75 * (1 - span(dt, .05, .6));
    if (glow > 0) {
      canvas
        ..save()
        ..clipRRect(rr)
        ..drawRRect(
          rr,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 34
            ..color = AppColors.red.withValues(alpha: glow)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
        )
        ..restore();
    }
    final rect = ctx.rect(side);
    final pop = dt < .25 ? easeOutBack(dt / .25) : 1.0;
    drawLabel(
      canvas,
      '−1',
      Offset(
        rect.center.dx,
        rect.center.dy - 14 - 40 * easeOut(span(dt, 0, 1.3)),
      ),
      AppTextStyles.display(66, color: AppColors.redSoft).copyWith(
        shadows: const [
          Shadow(color: AppColors.redDeep, offset: Offset(0, 4)),
          Shadow(color: Colors.black54, blurRadius: 24, offset: Offset(0, 10)),
        ],
      ),
      scale: .55 + .45 * pop,
      opacity: 1 - span(dt, .9, 1.3),
    );
  }

  @override
  bool shouldRepaint(_SpellFxPainter old) => true;
}
