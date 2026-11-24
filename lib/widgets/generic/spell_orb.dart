import 'package:flutter/material.dart';

import '../../models/game_rules.dart';
import '../../models/spell_info.dart';

/// Glossy round "orb" with the spell's icon.
class SpellOrb extends StatelessWidget {
  const SpellOrb({
    super.key,
    required this.spell,
    this.size = 60,
    this.glow = true,
    this.dimmed = false,
  });

  final Spell spell;
  final double size;
  final bool glow;

  /// Grey and faded, e.g. the losing spell or a used shield.
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final c = spell.orbColors;
    Widget orb = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.3, -0.44),
          radius: 0.9,
          colors: c,
          stops: const [0, 0.44, 1],
        ),
        boxShadow: [
          if (glow)
            BoxShadow(
              color: c[1].withValues(alpha: 0.35),
              blurRadius: size * 0.37,
              offset: Offset(0, size * 0.13),
            ),
        ],
      ),
      child: Icon(spell.icon, size: size * 0.47, color: spell.iconColor),
    );
    if (dimmed) {
      orb = Opacity(
        opacity: 0.55,
        child: ColorFiltered(
          colorFilter: const ColorFilter.matrix([
            0.6, 0.3, 0.1, 0, 0, //
            0.3, 0.6, 0.1, 0, 0, //
            0.3, 0.3, 0.4, 0, 0, //
            0, 0, 0, 1, 0,
          ]),
          child: orb,
        ),
      );
    }
    return Semantics(label: spell.label, excludeSemantics: true, child: orb);
  }
}
