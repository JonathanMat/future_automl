import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/game_rules.dart';
import '../../models/spell_info.dart';
import '../../navigators/app_router.dart';
import '../../providers/friends_provider.dart';
import '../../providers/game_provider.dart';
import '../../providers/profile_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_theme.dart';
import '../../utils/player_tag.dart';
import '../../widgets/generic/app_card.dart';
import '../../widgets/generic/chunky_button.dart';
import '../../widgets/generic/name_field.dart';
import '../../widgets/generic/screen_header.dart';
import '../../widgets/lobby/video_share_card.dart';
import '../../widgets/settings/account_card.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: context.read<ProfileProvider>().profile.name,
  );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    await context.read<ProfileProvider>().setName(_name.text);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Naam opgeslagen.')));
  }

  Future<void> _resetStats() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Statistieken wissen?'),
        content: const Text(
          'Je XP, overwinningen, je plek op het scorebord en recente '
          'tegenstanders worden gewist. Je vrienden blijven bewaard. '
          'Dit kan je niet ongedaan maken.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuleren'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.redSoft),
            child: const Text('Wissen'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      final friends = context.read<FriendsProvider>();
      await context.read<ProfileProvider>().resetStats();
      // Also the scorebord, so it matches the (now empty) progress.
      await friends.resetServerStats();
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>();
    final social = context.watch<FriendsProvider>();
    final config = context.select<GameProvider, GameConfig>(
      (g) => g.state.config,
    );
    final recognition = context.select<GameProvider, bool>(
      (g) => g.recognitionAvailable,
    );

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          children: [
            const ScreenHeader(title: 'Instellingen'),
            const SizedBox(height: 20),
            AppCard(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'PROFIEL',
                            style: AppTextStyles.overline(),
                          ),
                        ),
                        if (social.myTag != null)
                          Text(
                            PlayerTag.format(social.myTag),
                            style: AppTextStyles.body(
                              13,
                              weight: FontWeight.w900,
                              color: AppColors.textMuted,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    NameField(controller: _name, onSubmitted: _saveName),
                    const SizedBox(height: 8),
                    ChunkyButton(
                      label: 'Opslaan',
                      display: false,
                      height: 48,
                      style: ChunkyButtonStyle.secondary,
                      onPressed: _saveName,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            const AccountCard(),
            const SizedBox(height: 14),
            VideoShareCard(
              value: profile.shareVideo,
              onChanged: profile.setShareVideo,
            ),
            const SizedBox(height: 14),
            VoiceChatCard(
              value: profile.voiceChat,
              onChanged: profile.setVoiceChat,
            ),
            const SizedBox(height: 14),
            SoundEffectsCard(
              value: profile.soundEffects,
              onChanged: profile.setSoundEffects,
            ),
            const SizedBox(height: 14),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SPELREGELS', style: AppTextStyles.overline()),
                  const SizedBox(height: 10),
                  Text(
                    rulesSummary(config),
                    style: AppTextStyles.body(14, color: AppColors.textSoft),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Zelfde spreuk: gelijkspel. Niets casten verliest van elke spreuk.',
                    style: AppTextStyles.caption(),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    recognition
                        ? 'Gebarenherkenning: model geladen.'
                        : 'Gebarenherkenning: nog geen model. Tik op een spreuk om te casten.',
                    style: AppTextStyles.caption(
                      color: recognition ? AppColors.green : AppColors.gold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            ChunkyButton(
              label: 'Statistieken wissen',
              display: false,
              height: 52,
              style: ChunkyButtonStyle.secondary,
              onPressed: _resetStats,
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRoutes.fxPreview),
              icon: const Icon(Icons.auto_awesome_rounded),
              label: const Text('Spreuk-effecten bekijken'),
            ),
            if (kDebugMode) ...[
              TextButton.icon(
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRoutes.debug),
                icon: const Icon(Icons.bug_report_outlined),
                label: const Text('Backend debug-scherm'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
