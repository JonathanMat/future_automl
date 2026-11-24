import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/game_rules.dart';
import '../../models/spell_info.dart';
import '../../navigators/app_router.dart';
import '../../providers/profile_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_theme.dart';
import '../../widgets/generic/chunky_button.dart';
import '../../widgets/generic/name_field.dart';
import '../../widgets/generic/spell_orb.dart';

/// First launch: ask for a name, explain the gestures.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await context.read<ProfileProvider>().setName(_name.text);
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.screen),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                Text(
                  'WELKOM BIJ',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.overline(),
                ),
                const SizedBox(height: 6),
                Text(
                  'SPELL DUEL',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.display(48),
                ),
                const SizedBox(height: 28),
                for (final spell in Spell.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          SpellOrb(spell: spell, size: 44, glow: false),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  spell.label,
                                  style: AppTextStyles.display(18),
                                ),
                                Text(
                                  'Gebaar: ${spell.gesture}',
                                  style: AppTextStyles.caption(),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            'wint van ${spell.beats.map((s) => s.label).join(', ')}',
                            style: AppTextStyles.caption(color: spell.color),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 18),
                NameField(controller: _name, onSubmitted: _save),
                const SizedBox(height: 16),
                ChunkyButton(label: 'AAN DE SLAG', onPressed: _save),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
