import 'package:flutter/material.dart';

import '../../navigators/app_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

enum AppTab { home, friends, leaderboard }

/// Floating bottom navigation: Home · Vrienden · Scorebord.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key, required this.current});

  final AppTab current;

  static const _items = [
    (
      tab: AppTab.home,
      label: 'Home',
      icon: Icons.home_rounded,
      route: AppRoutes.home,
    ),
    (
      tab: AppTab.friends,
      label: 'Vrienden',
      icon: Icons.group_rounded,
      route: AppRoutes.friends,
    ),
    (
      tab: AppTab.leaderboard,
      label: 'Scorebord',
      icon: Icons.emoji_events_rounded,
      route: AppRoutes.leaderboard,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
      child: Container(
        height: 68,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            for (final item in _items)
              _NavItem(
                label: item.label,
                icon: item.icon,
                selected: item.tab == current,
                onTap: item.tab == current
                    ? null
                    : () => Navigator.of(
                        context,
                      ).pushReplacementNamed(item.route),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.gold : AppColors.textMuted;
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 80,
          height: 62,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                style: AppTextStyles.body(
                  11,
                  weight: FontWeight.w900,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
