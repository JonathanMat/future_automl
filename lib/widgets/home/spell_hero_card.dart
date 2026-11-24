import 'package:flutter/material.dart';

import '../../models/game_rules.dart';
import '../../models/spell_info.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_theme.dart';
import '../../utils/constants.dart';
import '../generic/app_card.dart';
import '../generic/app_logo.dart';
import '../generic/spell_orb.dart';

/// Title card with the four spells and a one-line rules summary.
class SpellHeroCard extends StatelessWidget {
  const SpellHeroCard({super.key, this.config = const GameConfig()});

  final GameConfig config;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: AppRadii.hero,
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
      child: Column(
        children: [
          const AppLogo(size: 92),
          const SizedBox(height: 10),
          Text(AppConstants.season, style: AppTextStyles.overline()),
          const SizedBox(height: 6),
          Semantics(
            header: true,
            child: Text(
              'SPELL DUEL',
              style: AppTextStyles.display(48).copyWith(height: 1),
            ),
          ),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 270),
            child: Text(
              'Cast spreuken met je hand en versla je vriend in een live duel.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body(
                15,
                weight: FontWeight.w700,
                color: AppColors.textSoft,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              for (final spell in Spell.values)
                Expanded(
                  child: Column(
                    children: [
                      SpellOrb(spell: spell),
                      const SizedBox(height: 8),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          spell.label,
                          style: AppTextStyles.body(
                            12,
                            weight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            rulesSummary(config),
            textAlign: TextAlign.center,
            style: AppTextStyles.caption(),
          ),
        ],
      ),
    );
  }
}
