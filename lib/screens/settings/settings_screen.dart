import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../navigators/app_router.dart';
import '../../providers/account_provider.dart';
import '../../providers/friends_provider.dart';
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
import '../../widgets/settings/account_card.dart'
    show AccountCard, confirmSignOut;

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final ProfileProvider _profile;
  late final TextEditingController _name;

  /// The saved name the field last showed.
  late String _shownName;

  @override
  void initState() {
    super.initState();
    _profile = context.read<ProfileProvider>()..addListener(_onProfile);
    _shownName = _profile.profile.name;
    _name = TextEditingController(text: _shownName);
  }

  /// The name changed elsewhere, e.g. logging in with Google loaded that
  /// account's name: show it, unless you are typing a new one.
  void _onProfile() {
    final name = _profile.profile.name;
    if (name == _shownName) return;
    if (_name.text == _shownName) _name.text = name;
    _shownName = name;
  }

  @override
  void dispose() {
    _profile.removeListener(_onProfile);
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

  Future<void> _deleteAccount() async {
    final account = context.read<AccountProvider>();
    final profile = context.read<ProfileProvider>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Account verwijderen?'),
        content: Text(
          'Alles wordt voor altijd verwijderd: je naam, XP, overwinningen, '
          'badges, vrienden, vriendcode, je plek op het scorebord, recente '
          'tegenstanders en je instellingen'
          '${account.isGuest ? '' : ', en je login met Google'}. '
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
            child: const Text('Verwijderen'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final message = await account.deleteAccount();
    if (message == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
    // Gone: start over with a new name, like a fresh install.
    if (!profile.profile.hasName) {
      nav.pushNamedAndRemoveUntil(AppRoutes.onboarding, (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>();
    final social = context.watch<FriendsProvider>();

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
            if (!context.select<AccountProvider, bool>((a) => a.isGuest))
              ChunkyButton(
                label: 'Uitloggen',
                icon: Icons.logout_rounded,
                display: false,
                height: 52,
                style: ChunkyButtonStyle.secondary,
                loading: context.select<AccountProvider, bool>((a) => a.busy),
                onPressed: () => confirmSignOut(context),
              ),
            const SizedBox(height: 4),
            // Small and red on purpose: it can't be undone.
            Center(
              child: TextButton.icon(
                onPressed: context.select<AccountProvider, bool>((a) => a.busy)
                    ? null
                    : _deleteAccount,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.redSoft,
                  textStyle: AppTextStyles.body(13, weight: FontWeight.w700),
                ),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('Account verwijderen'),
              ),
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
