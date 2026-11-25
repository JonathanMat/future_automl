import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../navigators/app_router.dart';
import '../../providers/profile_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_theme.dart';
import '../../widgets/generic/app_logo.dart';
import '../../widgets/generic/chunky_button.dart';
import '../../widgets/generic/name_field.dart';
import '../../widgets/generic/app_card.dart';
import '../../widgets/generic/spell_cycle_diagram.dart';

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
                const SizedBox(height: 24),
                const Center(child: AppLogo(size: 128)),
                const SizedBox(height: 16),
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
                const SizedBox(height: 24),
                AppCard(
                  padding: const EdgeInsets.fromLTRB(14, 18, 14, 16),
                  child: Column(
                    children: [
                      Text('ZO WERKT HET', style: AppTextStyles.overline()),
                      const SizedBox(height: 6),
                      Text(
                        'Maak het gebaar, de pijl wijst naar wie je verslaat.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.body(
                          13,
                          weight: FontWeight.w700,
                          color: AppColors.textSoft,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const SpellCycleDiagram(),
                    ],
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
