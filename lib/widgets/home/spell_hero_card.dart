import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_theme.dart';
import '../../utils/constants.dart';
import '../generic/app_card.dart';
import '../generic/app_logo.dart';

/// Title card: logo, name and what the game is.
class SpellHeroCard extends StatelessWidget {
  const SpellHeroCard({super.key});

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
        ],
      ),
    );
  }
}
