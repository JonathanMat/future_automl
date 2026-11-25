import 'package:flutter/material.dart';

import '../../models/game_rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../generic/spell_cycle_diagram.dart';
import '../generic/spell_orb.dart';

/// One slim row on home: the four spells and "Hoe win je?". Tap it to open
/// the full rules in a sheet, so the home screen stays calm.
class RulesShelf extends StatelessWidget {
  const RulesShelf({super.key, this.config = const GameConfig()});

  final GameConfig config;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Spelregels bekijken',
      excludeSemantics: true,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => showRulesSheet(context, config),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SPELREGELS',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.overline(),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Hoe win je?',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.display(20),
                      ),
                    ],
                  ),
                ),
                // The spells overlap a little, like a hand of cards.
                SizedBox(
                  width: 32 + 3 * 24,
                  height: 32,
                  child: Stack(
                    children: [
                      for (final (i, spell) in Spell.values.indexed)
                        Positioned(
                          left: i * 24,
                          child: SpellOrb(spell: spell, size: 32, glow: false),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The rules: how a round goes in three short steps, then what beats what.
Future<void> showRulesSheet(BuildContext context, GameConfig config) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .9,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textMuted.withValues(alpha: .4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              Semantics(
                header: true,
                child: Text('Spelregels', style: AppTextStyles.display(28)),
              ),
              const SizedBox(height: 16),
              _Step(
                n: 1,
                text:
                    'Bij CAST! maak je binnen '
                    '${config.castWindow.inSeconds} seconden je gebaar.',
              ),
              const _Step(
                n: 2,
                text:
                    'Wint je spreuk? Dan verliest je tegenstander een '
                    'leven. Dezelfde spreuk is gelijk.',
              ),
              _Step(
                n: 3,
                text:
                    'Iedereen start met ${config.startLives} levens. '
                    'Wie eerst op 0 staat, verliest.',
              ),
              const SizedBox(height: 18),
              Text('WIE WINT VAN WIE', style: AppTextStyles.overline()),
              const SizedBox(height: 4),
              Text(
                'De pijl wijst naar wie je verslaat.',
                style: AppTextStyles.caption(),
              ),
              const SizedBox(height: 10),
              SpellCycleDiagram(config: config, maxWidth: 300),
              const SizedBox(height: 16),
              Text(
                'Schild mag maar ${config.shieldUses}× per duel. '
                'Niets casten verliest de ronde.',
                textAlign: TextAlign.center,
                style: AppTextStyles.caption(),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Step extends StatelessWidget {
  const _Step({required this.n, required this.text});

  final int n;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.gold,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$n',
              style: AppTextStyles.body(
                14,
                weight: FontWeight.w900,
                color: AppColors.background,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.body(
                14,
                weight: FontWeight.w700,
                color: AppColors.textSoft,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
