import 'package:flutter/material.dart';

import '../../models/game_rules.dart';
import '../../models/spell_info.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_transitions.dart';
import '../generic/spell_orb.dart';

/// The four spells with their gesture. Tapping one casts it, which is the
/// fallback when no recognition model is loaded.
class SpellCardGrid extends StatelessWidget {
  const SpellCardGrid({
    super.key,
    required this.enabled,
    required this.onCast,
    required this.shieldsLeft,
    this.selected,
  });

  final bool enabled;
  final ValueChanged<Spell> onCast;
  final int shieldsLeft;
  final Spell? selected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final spell in Spell.values) ...[
          if (spell != Spell.values.first) const SizedBox(width: 8),
          Expanded(
            child: _SpellCard(
              spell: spell,
              selected: selected == spell,
              enabled: enabled && (spell != Spell.schild || shieldsLeft > 0),
              badge: spell == Spell.schild ? '$shieldsLeft×' : null,
              onTap: () => onCast(spell),
            ),
          ),
        ],
      ],
    );
  }
}

class _SpellCard extends StatelessWidget {
  const _SpellCard({
    required this.spell,
    required this.selected,
    required this.enabled,
    required this.onTap,
    this.badge,
  });

  final Spell spell;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final c = spell.color;
    final used = spell == Spell.schild && badge == '0×';
    return Semantics(
      button: true,
      enabled: enabled,
      selected: selected,
      label:
          '${spell.label}, gebaar: ${spell.gesture}'
          '${used ? ', al gebruikt' : ''}',
      excludeSemantics: true,
      child: AnimatedScale(
        duration: AppTransitions.fast,
        scale: selected ? 1.05 : 1,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? onTap : null,
            child: AnimatedContainer(
              duration: AppTransitions.fast,
              height: 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    c.withValues(alpha: selected ? 0.4 : 0.2),
                    c.withValues(alpha: 0.04),
                  ],
                ),
                border: Border.all(
                  color: c.withValues(alpha: selected ? 0.9 : 0.3),
                  width: selected ? 2 : 1,
                ),
              ),
              child: Opacity(
                opacity: used ? 0.4 : 1,
                child: Stack(
                  children: [
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SpellOrb(spell: spell, size: 40, glow: false),
                          const SizedBox(height: 4),
                          Text(spell.label, style: AppTextStyles.display(14)),
                          Text(
                            spell.gesture,
                            style: AppTextStyles.body(
                              10,
                              weight: FontWeight.w800,
                              color: AppColors.textFeed,
                              height: 1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (badge != null)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          height: 20,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.shieldPip,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(badge!, style: AppTextStyles.display(11)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
