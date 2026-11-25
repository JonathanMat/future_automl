import 'package:flutter/material.dart';

import '../../models/badge.dart';
import '../../models/friend_record.dart';
import '../../models/game_rules.dart';
import '../../models/player_profile.dart';
import '../../models/spell_info.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/constants.dart';
import '../../utils/extensions.dart';
import '../badges/badge_medal.dart';
import '../generic/app_card.dart';
import '../generic/avatar_tile.dart';
import '../generic/pill_badge.dart';
import '../generic/player_name.dart';
import '../generic/progress_bar.dart';
import '../generic/spell_orb.dart';
import '../generic/stat_tile.dart';

/// Big avatar, name with tag, level and XP bar.
class ProfileHero extends StatelessWidget {
  const ProfileHero({
    super.key,
    required this.profile,
    this.tag,
    this.isMe = false,
    this.isFriend = false,
    this.showLevel = true,
  });

  final PlayerProfile profile;
  final String? tag;
  final bool isMe;
  final bool isFriend;

  /// False when only the scorebord record is known (no XP).
  final bool showLevel;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      child: Column(
        children: [
          AvatarTile(name: profile.name, size: 84),
          const SizedBox(height: 14),
          PlayerName(
            name: profile.name,
            tag: tag,
            style: AppTextStyles.display(26),
            textAlign: TextAlign.center,
          ),
          if (isMe || isFriend) ...[
            const SizedBox(height: 8),
            PillBadge(
              label: isMe ? 'JIJ' : 'VRIEND',
              color: isMe ? AppColors.lavender : AppColors.green,
              icon: isMe ? Icons.person_rounded : Icons.people_alt_rounded,
            ),
          ],
          if (showLevel) ...[
            const SizedBox(height: 16),
            Semantics(
              label:
                  'Level ${profile.level}, '
                  '${profile.xpInLevel} van ${AppConstants.xpPerLevel} XP',
              excludeSemantics: true,
              child: Row(
                children: [
                  Text(
                    'LVL ${profile.level}',
                    style: AppTextStyles.body(
                      13,
                      weight: FontWeight.w900,
                      color: AppColors.lavender,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: ProgressBar(value: profile.levelProgress)),
                  const SizedBox(width: 10),
                  Text(
                    '${profile.xpInLevel}/${AppConstants.xpPerLevel} XP',
                    style: AppTextStyles.caption(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text('${profile.xp} XP in totaal', style: AppTextStyles.caption()),
          ],
        ],
      ),
    );
  }
}

/// Wins, losses, win rate, duels and streaks.
class ProfileRecord extends StatelessWidget {
  const ProfileRecord({
    super.key,
    required this.profile,
    this.showStreaks = true,
  });

  final PlayerProfile profile;
  final bool showStreaks;

  @override
  Widget build(BuildContext context) {
    Widget row(List<Widget> tiles) => Row(
      children: [
        for (final (i, t) in tiles.indexed) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(child: t),
        ],
      ],
    );
    return Column(
      children: [
        row([
          StatTile(value: '${profile.wins}', label: 'Gewonnen'),
          StatTile(value: '${profile.losses}', label: 'Verloren'),
          StatTile(
            value: '${profile.winRate}%',
            label: 'Winrate',
            valueColor: AppColors.gold,
          ),
        ]),
        if (showStreaks) ...[
          const SizedBox(height: 10),
          row([
            StatTile(
              compact: true,
              valueSize: 20,
              value: '${profile.gamesPlayed}',
              label: 'Duels',
            ),
            StatTile(
              compact: true,
              valueSize: 20,
              value: '${profile.streak}',
              label: 'Huidige reeks',
              valueColor: profile.streak > 0
                  ? AppColors.orangeText
                  : AppColors.text,
            ),
            StatTile(
              compact: true,
              valueSize: 20,
              value: '${profile.stats.bestStreak}',
              label: 'Beste reeks',
            ),
          ]),
        ],
      ],
    );
  }
}

/// Your record against this player ("Jij 3–2 Lotte").
class HeadToHeadCard extends StatelessWidget {
  const HeadToHeadCard({super.key, required this.record});

  final FriendRecord record;

  @override
  Widget build(BuildContext context) {
    final ahead = record.wins >= record.losses;
    return Semantics(
      label:
          'Jij tegen ${record.name}: ${record.wins} gewonnen, '
          '${record.losses} verloren',
      excludeSemantics: true,
      child: AppCard(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'JIJ VS ${record.name.toUpperCase()}',
                    style: AppTextStyles.overline(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${record.games} ${record.games == 1 ? 'duel' : 'duels'}'
                    ' · laatst ${record.lastPlayed.timeAgo()}',
                    style: AppTextStyles.caption(),
                  ),
                ],
              ),
            ),
            Text(
              '${record.wins}–${record.losses}',
              style: AppTextStyles.display(
                30,
                color: ahead ? AppColors.green : AppColors.redSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Round wins per spell, as bars, with the favourite on top.
class SpellWinsCard extends StatelessWidget {
  const SpellWinsCard({super.key, required this.profile});

  final PlayerProfile profile;

  @override
  Widget build(BuildContext context) {
    final wins = {for (final s in Spell.values) s: profile.stats.roundWins(s)};
    final total = wins.values.fold(0, (a, b) => a + b);
    final best = wins.values.fold(0, (a, b) => a > b ? a : b);
    if (total == 0) {
      return AppCard(
        child: Text(
          'Nog geen rondes gewonnen.',
          style: AppTextStyles.body(
            14,
            weight: FontWeight.w700,
            color: AppColors.textMuted,
          ),
        ),
      );
    }
    final sorted = Spell.values.toList()
      ..sort((a, b) => wins[b]!.compareTo(wins[a]!));
    return AppCard(
      child: Column(
        children: [
          for (final (i, s) in sorted.indexed) ...[
            if (i > 0) const SizedBox(height: 12),
            Semantics(
              label:
                  '${s.label}: ${wins[s]} rondes gewonnen'
                  '${i == 0 ? ', favoriet' : ''}',
              excludeSemantics: true,
              child: Row(
                children: [
                  SpellOrb(spell: s, size: 34, glow: i == 0),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 64,
                    child: Text(
                      s.label,
                      style: AppTextStyles.body(14, weight: FontWeight.w900),
                    ),
                  ),
                  Expanded(
                    child: ProgressBar(
                      value: best == 0 ? 0 : wins[s]! / best,
                      color: s.color,
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    child: Text(
                      '${wins[s]}',
                      textAlign: TextAlign.right,
                      style: AppTextStyles.display(16, color: s.color),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'Rondes gewonnen per spreuk · favoriet: ${sorted.first.label}',
            style: AppTextStyles.caption(),
          ),
        ],
      ),
    );
  }
}

/// Flawless wins, comebacks, fastest cast, tournaments, …
class HighlightsCard extends StatelessWidget {
  const HighlightsCard({super.key, required this.profile});

  final PlayerProfile profile;

  static String _seconds(int ms) =>
      '${(ms / 1000).toStringAsFixed(2).replaceAll('.', ',')} s';

  @override
  Widget build(BuildContext context) {
    final s = profile.stats;
    final items = [
      ('${s.flawless}', 'Foutloos gewonnen', AppColors.gold),
      ('${s.comebacks}', 'Comebacks', AppColors.text),
      ('${s.reflects}', 'Teruggekaatst', Spell.schild.color),
      ('${s.clashes}', 'Botsingen', AppColors.text),
      ('${s.friendWins}', 'Winst op vrienden', AppColors.green),
      (
        s.fastestMs == 0 ? '–' : _seconds(s.fastestMs),
        'Snelste spreuk',
        Spell.bliksem.color,
      ),
      ('${s.tournamentMatches}', 'Toernooiduels', AppColors.text),
      ('${s.tournamentWins}', 'Toernooien gewonnen', AppColors.gold),
    ];
    return AppCard(
      child: LayoutBuilder(
        builder: (context, box) {
          final cell = (box.maxWidth - 12) / 2;
          return Wrap(
            spacing: 12,
            runSpacing: 14,
            children: [
              for (final (value, label, color) in items)
                SizedBox(
                  width: cell,
                  child: InlineStat(
                    value: value,
                    label: label,
                    valueColor: color,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Every badge: unlocked ones in colour, newest first, the rest grey.
class ProfileBadges extends StatelessWidget {
  const ProfileBadges({super.key, required this.profile, this.onOpen});

  final PlayerProfile profile;

  /// Opens the full badges screen (own profile only).
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final earned = [
      for (final b in allBadges)
        if (profile.hasBadge(b.id)) b,
    ]..sort((a, b) => profile.badges[b.id]!.compareTo(profile.badges[a.id]!));
    final locked = [
      for (final b in allBadges)
        if (!profile.hasBadge(b.id)) b,
    ];
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '${earned.length}/${allBadges.length}',
                    style: AppTextStyles.display(22, color: AppColors.gold),
                  ),
                  const SizedBox(width: 8),
                  Text('vrijgespeeld', style: AppTextStyles.caption()),
                  const Spacer(),
                  if (onOpen != null)
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textMuted,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final b in [...earned, ...locked])
                    Tooltip(
                      message: b.title,
                      child: BadgeMedal(
                        badge: b,
                        size: 44,
                        unlocked: profile.hasBadge(b.id),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
