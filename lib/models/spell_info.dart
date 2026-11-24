import 'package:flutter/material.dart';

import 'game_rules.dart';

/// How a spell looks and is cast. Rules themselves live in `game_rules.dart`.
extension SpellInfo on Spell {
  String get label => switch (this) {
    Spell.vuur => 'Vuur',
    Spell.ijs => 'IJs',
    Spell.bliksem => 'Bliksem',
    Spell.schild => 'Schild',
  };

  /// The hand gesture the model is trained on.
  String get gesture => switch (this) {
    Spell.vuur => 'open hand',
    Spell.ijs => 'vuist',
    Spell.bliksem => '2 vingers',
    Spell.schild => 'handen omhoog',
  };

  IconData get icon => switch (this) {
    Spell.vuur => Icons.local_fire_department_rounded,
    Spell.ijs => Icons.ac_unit_rounded,
    Spell.bliksem => Icons.bolt_rounded,
    Spell.schild => Icons.shield_rounded,
  };

  /// Light → mid → dark, for the radial "orb" gradient.
  List<Color> get orbColors => switch (this) {
    Spell.vuur => const [
      Color(0xFFFFC79A),
      Color(0xFFFF7A2F),
      Color(0xFFA8360A),
    ],
    Spell.ijs => const [
      Color(0xFFD4F3FF),
      Color(0xFF4FC3F7),
      Color(0xFF1769AA),
    ],
    Spell.bliksem => const [
      Color(0xFFFFF4B8),
      Color(0xFFFFD23F),
      Color(0xFFB88600),
    ],
    Spell.schild => const [
      Color(0xFFDCD5FF),
      Color(0xFF8B7CFF),
      Color(0xFF4A3BC2),
    ],
  };

  Color get color => orbColors[1];

  /// Icon colour on top of the orb (dark on yellow for contrast).
  Color get iconColor =>
      this == Spell.bliksem ? const Color(0xFF5A3E00) : Colors.white;

  /// Short verb for "winner VERB loser", matching the rules in game_rules.
  String verbAgainst(Spell loser) => switch ((this, loser)) {
    (Spell.ijs, Spell.vuur) => 'dooft',
    (Spell.vuur, Spell.bliksem) => 'slorpt',
    (Spell.bliksem, Spell.ijs) => 'breekt',
    (Spell.bliksem, Spell.schild) => 'breekt',
    (Spell.schild, _) => 'blokt',
    _ => 'verslaat',
  };
}

/// One line summary of the rules, built from [Spell.beats] so it can never
/// drift from the real game logic. For example
/// "IJs › Vuur › Bliksem › IJs · Schild blokt Vuur en IJs (1×)".
String rulesSummary(GameConfig config) {
  // Follow the cycle of attack spells, starting at IJs.
  final cycle = <Spell>[Spell.ijs];
  var current = Spell.ijs;
  for (var i = 0; i < 3; i++) {
    final next = current.beats.firstWhere(
      (s) => s != Spell.schild,
      orElse: () => current,
    );
    if (next == current) break;
    cycle.add(next);
    current = next;
  }
  final blocked = Spell.schild.beats.map((s) => s.label).join(' en ');
  return '${cycle.map((s) => s.label).join(' › ')} · '
      'Schild blokt $blocked (${config.shieldUses}×)';
}
