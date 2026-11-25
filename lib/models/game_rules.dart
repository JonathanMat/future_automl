/// Pure game rules for Spell Duel. No Firebase, no Flutter: easy to unit test.
library;

/// The four spells a player can cast. [wire] is the value stored in Firebase.
enum Spell {
  vuur('vuur'),
  ijs('ijs'),
  bliksem('bliksem'),
  schild('schild');

  const Spell(this.wire);

  final String wire;

  static Spell? fromWire(Object? value) {
    for (final spell in Spell.values) {
      if (spell.wire == value) return spell;
    }
    return null;
  }

  /// The spells this spell beats.
  Set<Spell> get beats => _beats[this]!;

  bool beatsSpell(Spell other) => beats.contains(other);
}

const Map<Spell, Set<Spell>> _beats = {
  Spell.ijs: {Spell.vuur}, // ijs dooft vuur
  Spell.vuur: {Spell.bliksem}, // vuur slorpt de energie van bliksem op
  Spell.bliksem: {Spell.ijs, Spell.schild}, // bliksem breekt ijs en schild
  Spell.schild: {Spell.vuur, Spell.ijs}, // schild houdt vuur en ijs tegen
};

/// The two seats in a room. The host created the room, the guest joined it.
enum Side {
  host,
  guest;

  Side get other => this == Side.host ? Side.guest : Side.host;
}

/// Timing and balance constants, shared by the real and the mock backend.
class GameConfig {
  const GameConfig({
    this.startLives = 3,
    this.shieldUses = 1,
    this.countdown = const Duration(seconds: 3),
    this.castWindow = const Duration(seconds: 2),
    this.revealGrace = const Duration(seconds: 3),
    this.resultPause = const Duration(seconds: 3),
    this.roundLead = const Duration(milliseconds: 800),
    this.introLead = const Duration(milliseconds: 2900),
  });

  /// Lives each player starts with.
  final int startLives;

  /// How many times a player may cast [Spell.schild] per game.
  final int shieldUses;

  /// "3… 2… 1…" before CAST.
  final Duration countdown;

  /// After CAST, how long a spell is accepted. Later spells are ignored.
  final Duration castWindow;

  /// Extra time after the cast window for both phones to reveal their spell.
  final Duration revealGrace;

  /// How long the round result is shown before the next countdown starts.
  final Duration resultPause;

  /// Extra delay before the countdown starts, so both phones receive the
  /// round before it begins.
  final Duration roundLead;

  /// Extra delay before the first round of every game, for the "VS" intro
  /// on the duel screen. The countdown starts when the intro is done.
  final Duration introLead;
}

/// Why a round ended the way it did. Useful for UI text and debugging.
enum RoundReason {
  /// One spell beat the other.
  spellBeatsSpell,

  /// Both cast the same spell (including shield vs shield).
  sameSpell,

  /// Only one player cast a valid spell in time.
  opponentNoSpell,

  /// Neither player cast a valid spell in time.
  bothNoSpell,
}

/// Result of resolving one round.
class RoundResolution {
  const RoundResolution({
    required this.winner,
    required this.reason,
    required this.hostSpell,
    required this.guestSpell,
    required this.hostShieldsUsed,
    required this.guestShieldsUsed,
  });

  /// Who wins the round, or null for a draw. The loser loses one life.
  final Side? winner;
  final RoundReason reason;

  /// The spells that counted. Null when the player cast nothing valid (too
  /// late, nothing at all, or a shield they no longer had).
  final Spell? hostSpell;
  final Spell? guestSpell;

  /// Shield uses after this round (a valid shield is used up even in a draw).
  final int hostShieldsUsed;
  final int guestShieldsUsed;

  Spell? spellOf(Side side) => side == Side.host ? hostSpell : guestSpell;
  int shieldsUsedOf(Side side) =>
      side == Side.host ? hostShieldsUsed : guestShieldsUsed;
}

/// Decides one round.
///
/// Rules (agreed with the team):
/// - ijs > vuur > bliksem > ijs; schild > vuur, ijs; bliksem > schild.
/// - Same spell, or shield vs shield: draw, nobody loses a life.
/// - A shield can be used [GameConfig.shieldUses] times; casting it again
///   counts as casting nothing.
/// - Casting nothing (or nothing valid) loses against any valid spell;
///   both casting nothing is a draw.
RoundResolution resolveRound({
  required Spell? hostSpell,
  required Spell? guestSpell,
  int hostShieldsUsed = 0,
  int guestShieldsUsed = 0,
  GameConfig config = const GameConfig(),
}) {
  Spell? valid(Spell? spell, int shieldsUsed) =>
      spell == Spell.schild && shieldsUsed >= config.shieldUses ? null : spell;

  final host = valid(hostSpell, hostShieldsUsed);
  final guest = valid(guestSpell, guestShieldsUsed);

  final Side? winner;
  final RoundReason reason;
  if (host == null && guest == null) {
    winner = null;
    reason = RoundReason.bothNoSpell;
  } else if (host == null) {
    winner = Side.guest;
    reason = RoundReason.opponentNoSpell;
  } else if (guest == null) {
    winner = Side.host;
    reason = RoundReason.opponentNoSpell;
  } else if (host == guest) {
    winner = null;
    reason = RoundReason.sameSpell;
  } else {
    winner = host.beatsSpell(guest) ? Side.host : Side.guest;
    reason = RoundReason.spellBeatsSpell;
  }

  return RoundResolution(
    winner: winner,
    reason: reason,
    hostSpell: host,
    guestSpell: guest,
    hostShieldsUsed: hostShieldsUsed + (host == Spell.schild ? 1 : 0),
    guestShieldsUsed: guestShieldsUsed + (guest == Spell.schild ? 1 : 0),
  );
}
