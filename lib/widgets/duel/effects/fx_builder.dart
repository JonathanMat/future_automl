import 'dart:math';
import 'dart:ui';

import '../../../models/game_rules.dart';
import 'clash_layer.dart';
import 'explosion_layer.dart';
import 'freeze_layer.dart';
import 'fx_core.dart';
import 'fx_plan.dart';
import 'lightning_layer.dart';
import 'projectile_layer.dart';
import 'shield_layer.dart';

/// Colour filter laid over the real video of one camera.
enum FxTintKind {
  /// Cold blue-grey: the camera looks frozen.
  ice,

  /// Warm orange after an explosion.
  heat,

  /// Negative image during a lightning flash.
  invert,
}

class FxTint {
  const FxTint({
    required this.kind,
    required this.side,
    required this.start,
    required this.end,
    this.fade = .2,
  });

  final FxTintKind kind;
  final FxSide side;
  final double start;
  final double end;
  final double fade;

  /// 0–1 at time [t].
  double strength(double t) {
    if (t < start || t > end) return 0;
    return clamp01((t - start) / fade) * clamp01((end - t) / fade);
  }

  ColorFilter filter(double t) {
    final k = strength(t);
    final target = switch (kind) {
      FxTintKind.ice => _ice,
      FxTintKind.heat => _heat,
      FxTintKind.invert => _invert,
    };
    return ColorFilter.matrix([
      for (var i = 0; i < 20; i++)
        _identity[i] + (target[i] - _identity[i]) * k,
    ]);
  }

  static const _identity = <double>[
    1, 0, 0, 0, 0, //
    0, 1, 0, 0, 0, //
    0, 0, 1, 0, 0, //
    0, 0, 0, 1, 0,
  ];
  static const _ice = <double>[
    .22, .44, .08, 0, 10, //
    .26, .52, .10, 0, 35, //
    .30, .60, .12, 0, 70, //
    0, 0, 0, 1, 0,
  ];
  static const _heat = <double>[
    1.15, .1, 0, 0, 25, //
    0, .95, 0, 0, 5, //
    0, 0, .7, 0, 0, //
    0, 0, 0, 1, 0,
  ];
  static const _invert = <double>[
    -1, 0, 0, 0, 255, //
    0, -1, 0, 0, 255, //
    0, 0, -1, 0, 255, //
    0, 0, 0, 1, 0,
  ];
}

/// A [SpellFx] with the colour filters that go with it.
class PlannedFx {
  PlannedFx(this.fx, [this.tints = const []]);

  final SpellFx fx;
  final List<FxTint> tints;
}

/// Builds the effect for a plan. Null when there is nothing to show.
///
/// Every effect ends within ~3 s, the pause between two rounds.
PlannedFx? buildSpellFx(FxPlan plan) {
  // Draws have no winner; their cases don't use these.
  final w = plan.winner ?? FxSide.bottom;
  final l = w.other;
  // Projectiles curve to the right when you shoot, left when you are hit.
  double bendFor(FxSide from) => from == FxSide.bottom ? 70 : -70;

  switch (plan.kind) {
    case FxKind.none:
      return null;

    case FxKind.fireball:
      const hit = .62;
      return PlannedFx(
        SpellFx(
          layers: [
            ProjectileLayer(
              start: 0,
              spell: Spell.vuur,
              from: (c) => c.center(w),
              to: (c) => c.center(l),
              bend: bendFor(w),
            ),
            ExplosionLayer(start: hit, at: (c) => c.center(l), side: l),
          ],
          impacts: [FxImpact(time: hit, side: l, damage: true, shake: 14)],
        ),
        [FxTint(kind: FxTintKind.heat, side: l, start: hit, end: hit + 1.1)],
      );

    case FxKind.freeze:
      const hit = .57;
      final freeze = FreezeLayer(
        start: hit,
        side: l,
        impact: (c) => c.nearEdge(l),
      );
      return PlannedFx(
        SpellFx(
          layers: [
            ProjectileLayer(
              start: 0,
              spell: Spell.ijs,
              from: (c) => c.center(w),
              to: (c) => c.nearEdge(l),
              flight: .45,
              bend: bendFor(w),
            ),
            freeze,
          ],
          impacts: [
            FxImpact(time: hit, side: l, damage: true, shake: 7),
            FxImpact(time: hit + freeze.shatterStart, side: l, shake: 9),
          ],
        ),
        [
          FxTint(
            kind: FxTintKind.ice,
            side: l,
            start: hit + .05,
            end: hit + freeze.shatterStart,
            fade: .35,
          ),
        ],
      );

    case FxKind.lightning:
      const strike = .3;
      return PlannedFx(
        SpellFx(
          layers: [LightningStrikeLayer(start: 0, side: l, strikeAt: strike)],
          impacts: [FxImpact(time: strike, side: l, damage: true, shake: 16)],
        ),
        [
          FxTint(
            kind: FxTintKind.invert,
            side: l,
            start: strike,
            end: strike + .14,
            fade: .02,
          ),
          FxTint(
            kind: FxTintKind.invert,
            side: l,
            start: strike + .25,
            end: strike + .34,
            fade: .02,
          ),
        ],
      );

    case FxKind.lightningBreaksShield:
      const strike = .62;
      return PlannedFx(
        SpellFx(
          layers: [
            ShieldDomeLayer(start: 0, duration: 1.6, side: l, breakAt: strike),
            LightningStrikeLayer(
              start: strike - .3,
              side: l,
              strikeAt: .3,
              seed: 8,
            ),
          ],
          impacts: [FxImpact(time: strike, side: l, damage: true, shake: 18)],
        ),
        [
          FxTint(
            kind: FxTintKind.invert,
            side: l,
            start: strike,
            end: strike + .14,
            fade: .02,
          ),
        ],
      );

    case FxKind.shieldReflect:
      final reflected = plan.reflected!;
      const block = .5;
      const back = block + .36;
      Offset rim(FxContext c) => c.nearEdge(w, inset: -10);
      final layers = <FxLayer>[
        ShieldDomeLayer(
          start: 0,
          duration: 1.5,
          side: w,
          hitAt: block,
          hitPoint: rim,
          label: 'BLOK!',
        ),
        ProjectileLayer(
          start: 0,
          spell: reflected,
          from: (c) => c.center(l),
          to: rim,
          charge: .1,
          flight: .4,
          bend: bendFor(l),
          seed: 11,
        ),
        BurstLayer(
          start: block,
          at: rim,
          palette: shieldPalette,
          count: 30,
          reach: .7,
        ),
        ProjectileLayer(
          start: block,
          spell: reflected,
          from: rim,
          to: (c) => reflected == Spell.ijs ? c.nearEdge(l) : c.center(l),
          charge: 0,
          flight: .36,
          bend: -bendFor(l),
          seed: 12,
        ),
      ];
      final tints = <FxTint>[];
      if (reflected == Spell.ijs) {
        final freeze = FreezeLayer(
          start: back,
          side: l,
          impact: (c) => c.nearEdge(l),
          hold: .85,
          seed: 13,
        );
        layers.add(freeze);
        tints.add(
          FxTint(
            kind: FxTintKind.ice,
            side: l,
            start: back + .05,
            end: back + freeze.shatterStart,
            fade: .35,
          ),
        );
      } else {
        layers.add(
          ExplosionLayer(start: back, at: (c) => c.center(l), side: l),
        );
        tints.add(
          FxTint(kind: FxTintKind.heat, side: l, start: back, end: back + 1.1),
        );
      }
      return PlannedFx(
        SpellFx(
          layers: layers,
          impacts: [
            FxImpact(time: block, side: w, shake: 6),
            FxImpact(time: back, side: l, damage: true, shake: 13),
          ],
        ),
        tints,
      );

    case FxKind.shieldBash:
      const pulse = .4;
      const hit = pulse + .32;
      return PlannedFx(
        SpellFx(
          layers: [
            ShieldDomeLayer(start: 0, duration: 1.3, side: w, pulseAt: pulse),
            ShockwaveLayer(
              start: pulse,
              from: (c) => c.nearEdge(w),
              to: (c) => c.center(l),
            ),
            BurstLayer(
              start: hit,
              at: (c) => c.center(l),
              palette: shieldPalette,
              count: 46,
            ),
          ],
          impacts: [FxImpact(time: hit, side: l, damage: true, shake: 11)],
        ),
      );

    case FxKind.clash:
      final spell = plan.spell!;
      const meet = .45;
      const struggle = .7;
      const burst = meet + struggle;
      Offset middle(FxContext c) => c.middle;
      // Both spells shove the contact point back and forth along the
      // line between the cameras, faster and harder as it builds up.
      Offset push(double t) {
        final k = clamp01(t / struggle);
        return Offset(
          2.5 * sin(t * 37),
          (5 + 5 * k) * sin(t * (18 + 14 * k)) + 4 * sin(t * 7.3),
        );
      }

      // Each spell's centre sits [gap] from the contact point and creeps
      // closer as the pressure rises.
      const gap = 30.0;
      Offset Function(double) hold(double towardsMiddle) =>
          (t) =>
              push(t) + Offset(0, towardsMiddle * 10 * clamp01(t / struggle));

      return PlannedFx(
        SpellFx(
          layers: [
            for (final (side, seed) in [(FxSide.top, 21), (FxSide.bottom, 22)])
              ProjectileLayer(
                start: 0,
                spell: spell,
                from: (c) => c.center(side),
                to: (c) =>
                    c.middle + Offset(0, side == FxSide.top ? -gap : gap),
                charge: .1,
                flight: meet - .1,
                bend: side == FxSide.top ? 40 : -40,
                hold: struggle,
                wobble: hold(side == FxSide.top ? 1 : -1),
                seed: seed,
              ),
            ClashStruggleLayer(
              start: meet,
              duration: struggle,
              spell: spell,
              at: middle,
              push: push,
              gap: gap,
            ),
            switch (spell) {
              Spell.vuur => ExplosionLayer(
                start: burst,
                at: middle,
                scale: .95,
              ),
              Spell.ijs => BurstLayer(
                start: burst,
                at: middle,
                palette: icePalette,
                count: 72,
                reach: 1.25,
                shards: true,
              ),
              _ => BurstLayer(
                start: burst,
                at: middle,
                palette: lightningPalette,
                count: 64,
                reach: 1.25,
                bolts: true,
              ),
            },
          ],
          impacts: [
            const FxImpact(time: meet, shake: 7),
            for (final (dt, shake) in [(.17, 3.0), (.34, 4.0), (.51, 5.0)])
              FxImpact(time: meet + dt, shake: shake),
            const FxImpact(time: burst, shake: 16),
          ],
        ),
      );

    case FxKind.doubleShield:
      return PlannedFx(
        SpellFx(
          layers: [
            for (final side in FxSide.values)
              ShieldDomeLayer(start: 0, duration: 1.5, side: side, pulseAt: .5),
          ],
          impacts: [const FxImpact(time: .5, shake: 4)],
        ),
      );
  }
}
