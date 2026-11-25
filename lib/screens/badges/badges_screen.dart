import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/badge.dart';
import '../../models/player_profile.dart';
import '../../providers/profile_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_theme.dart';
import '../../widgets/badges/badge_medal.dart';
import '../../widgets/generic/app_card.dart';
import '../../widgets/generic/progress_bar.dart';
import '../../widgets/generic/screen_header.dart';

/// All badges: unlocked ones in colour, the rest grey with your progress.
class BadgesScreen extends StatelessWidget {
  const BadgesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>().profile;
    final unlocked = allBadges.where((b) => profile.hasBadge(b.id)).length;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                AppSpacing.screen,
                AppSpacing.screen,
                0,
              ),
              sliver: SliverList.list(
                children: [
                  const ScreenHeader(title: 'Badges'),
                  const SizedBox(height: 16),
                  AppCard(
                    child: Row(
                      children: [
                        const Icon(
                          Icons.military_tech_rounded,
                          color: AppColors.gold,
                          size: 34,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$unlocked van ${allBadges.length} vrijgespeeld',
                                style: AppTextStyles.body(
                                  15,
                                  weight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ProgressBar(
                                value: unlocked / allBadges.length,
                                color: AppColors.gold,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            for (final tier in BadgeTier.values) ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screen,
                  22,
                  AppSpacing.screen,
                  10,
                ),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    tier.label.toUpperCase(),
                    style: AppTextStyles.overline(color: tier.metal[0]),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screen,
                ),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 10,
                    mainAxisExtent: 156,
                  ),
                  delegate: SliverChildListDelegate([
                    for (final b in allBadges.where((b) => b.tier == tier))
                      _BadgeTile(badge: b, profile: profile),
                  ]),
                ),
              ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.badge, required this.profile});

  final BadgeDef badge;
  final PlayerProfile profile;

  @override
  Widget build(BuildContext context) {
    final unlocked = profile.hasBadge(badge.id);
    final progress = badge.progress(profile).clamp(0, badge.target);
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _showDetail(context, badge, profile),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 12, 6, 10),
          child: Column(
            children: [
              BadgeMedal(badge: badge, size: 62, unlocked: unlocked),
              const SizedBox(height: 8),
              Text(
                badge.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body(
                  12,
                  weight: FontWeight.w900,
                  color: unlocked ? AppColors.text : AppColors.textMuted,
                  height: 1.15,
                ),
              ),
              const Spacer(),
              if (!unlocked && badge.target > 1) ...[
                ProgressBar(
                  value: progress / badge.target,
                  height: 4,
                  color: badge.tier.glow,
                ),
                const SizedBox(height: 3),
                Text(
                  '$progress/${badge.target}',
                  style: AppTextStyles.caption().copyWith(fontSize: 10),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

void _showDetail(BuildContext context, BadgeDef badge, PlayerProfile profile) {
  final at = profile.badges[badge.id];
  final unlocked = at != null;
  final progress = badge.progress(profile).clamp(0, badge.target);
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BadgeMedal(badge: badge, size: 110, unlocked: unlocked),
            const SizedBox(height: 16),
            Text(badge.title, style: AppTextStyles.display(26)),
            const SizedBox(height: 6),
            Text(
              badge.description,
              textAlign: TextAlign.center,
              style: AppTextStyles.body(
                14,
                weight: FontWeight.w700,
                color: AppColors.textSoft,
              ),
            ),
            const SizedBox(height: 16),
            if (unlocked)
              Text(
                'Vrijgespeeld op ${_date(DateTime.fromMillisecondsSinceEpoch(at))}',
                style: AppTextStyles.caption(color: badge.tier.metal[0]),
              )
            else ...[
              ProgressBar(
                value: progress / badge.target,
                color: badge.tier.glow,
              ),
              const SizedBox(height: 6),
              Text(
                '$progress van ${badge.target}',
                style: AppTextStyles.caption(),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              badge.tier.label.toUpperCase(),
              style: AppTextStyles.overline(color: badge.tier.metal[0]),
            ),
          ],
        ),
      ),
    ),
  );
}

String _date(DateTime d) {
  const months = [
    'jan',
    'feb',
    'mrt',
    'apr',
    'mei',
    'jun',
    'jul',
    'aug',
    'sep',
    'okt',
    'nov',
    'dec',
  ];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}
