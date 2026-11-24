import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/account_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../generic/app_card.dart';
import '../generic/chunky_button.dart';

/// Guest or Google account, with sign in / sign out.
class AccountCard extends StatelessWidget {
  const AccountCard({super.key});

  Future<void> _run(BuildContext context, Future<String?> action) async {
    final messenger = ScaffoldMessenger.of(context);
    final message = await action;
    if (message == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final account = context.read<AccountProvider>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Uitloggen?'),
        content: const Text(
          'Je vrienden en scores blijven bij je Google-account. Log later '
          'opnieuw in om ze terug te krijgen. Tot dan speel je als nieuwe gast.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuleren'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.redSoft),
            child: const Text('Uitloggen'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await _run(context, account.signOut());
  }

  @override
  Widget build(BuildContext context) {
    final account = context.watch<AccountProvider>();
    final info = account.info;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('ACCOUNT', style: AppTextStyles.overline()),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                info.isGuest
                    ? Icons.person_outline_rounded
                    : Icons.verified_user_rounded,
                color: info.isGuest ? AppColors.textMuted : AppColors.green,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      info.isGuest ? 'Gast' : (info.name ?? 'Google-account'),
                      style: AppTextStyles.body(15, weight: FontWeight.w900),
                    ),
                    if (!info.isGuest && info.email != null)
                      Text(
                        info.email!,
                        style: AppTextStyles.caption(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            info.isGuest
                ? 'Je vrienden en scores staan alleen op deze installatie. Log '
                      'in met Google om ze te bewaren, ook op een nieuwe gsm.'
                : 'Je vrienden en scores zijn bewaard in je Google-account.',
            style: AppTextStyles.body(13, color: AppColors.textSoft),
          ),
          const SizedBox(height: 12),
          if (info.isGuest)
            ChunkyButton(
              label: 'Inloggen met Google',
              icon: Icons.login_rounded,
              display: false,
              height: 48,
              loading: account.busy,
              onPressed: () => _run(context, account.signInWithGoogle()),
            )
          else
            ChunkyButton(
              label: 'Uitloggen',
              display: false,
              height: 48,
              style: ChunkyButtonStyle.secondary,
              loading: account.busy,
              onPressed: () => _confirmSignOut(context),
            ),
        ],
      ),
    );
  }
}
