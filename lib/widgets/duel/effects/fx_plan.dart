import '../../../models/game_rules.dart';
import '../../../models/game_state.dart';

/// Which camera an effect is about. Top = the opponent, bottom = you.
enum FxSide {
  top,
  bottom;

  FxSide get other => this == top ? bottom : top;
}

/// What a round result looks like on screen.
enum FxKind {
  /// Nobody cast anything: no effect.
  none,

  /// Fireball from the winner that explodes on the loser.
  fireball,

  /// The loser's camera freezes, then shatters.
  freeze,

  /// Lightning strikes the loser.
  lightning,

  /// The winner's shield bounces the loser's fire or ice back to them.
  shieldReflect,

  /// Lightning smashes the loser's shield and strikes.
  lightningBreaksShield,

  /// Shield against nothing: the dome pulses and slams the other camera.
  shieldBash,

  /// Same spell on both sides: they collide in the middle.
  clash,

  /// Shield against shield: two domes, nobody hurt.
  doubleShield,
}

class FxPlan {
  const FxPlan(this.kind, {this.winner, this.spell, this.reflected});

  static const nothing = FxPlan(FxKind.none);

  final FxKind kind;

  /// Side that won the round (null for a draw).
  final FxSide? winner;

  /// The spell the effect is about (the winner's, or the clashing one).
  final Spell? spell;

  /// For [FxKind.shieldReflect]: the spell that bounced back.
  final Spell? reflected;

  FxSide? get loser => winner?.other;
}

/// Turns a round result (seen from this phone) into an effect.
FxPlan planFor(RoundResult result) {
  final mine = result.mySpell;
  final theirs = result.opponentSpell;

  if (result.outcome == RoundOutcome.draw) {
    if (mine == null || theirs == null || mine != theirs) return FxPlan.nothing;
    return mine == Spell.schild
        ? const FxPlan(FxKind.doubleShield, spell: Spell.schild)
        : FxPlan(FxKind.clash, spell: mine);
  }

  final winner = result.outcome == RoundOutcome.win
      ? FxSide.bottom
      : FxSide.top;
  final w = winner == FxSide.bottom ? mine : theirs;
  final l = winner == FxSide.bottom ? theirs : mine;

  switch (w) {
    case null:
      return FxPlan.nothing;
    case Spell.schild:
      if (l == Spell.vuur || l == Spell.ijs) {
        return FxPlan(
          FxKind.shieldReflect,
          winner: winner,
          spell: Spell.schild,
          reflected: l,
        );
      }
      return FxPlan(FxKind.shieldBash, winner: winner, spell: Spell.schild);
    case Spell.bliksem when l == Spell.schild:
      return FxPlan(
        FxKind.lightningBreaksShield,
        winner: winner,
        spell: Spell.bliksem,
      );
    case Spell.bliksem:
      return FxPlan(FxKind.lightning, winner: winner, spell: Spell.bliksem);
    case Spell.vuur:
      return FxPlan(FxKind.fireball, winner: winner, spell: Spell.vuur);
    case Spell.ijs:
      return FxPlan(FxKind.freeze, winner: winner, spell: Spell.ijs);
  }
}
