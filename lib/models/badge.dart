import 'package:flutter/material.dart';

import 'game_rules.dart';
import 'player_profile.dart';

/// How rare a badge is; sets its colours.
enum BadgeTier {
  brons('Brons'),
  zilver('Zilver'),
  goud('Goud'),
  episch('Episch');

  const BadgeTier(this.label);

  final String label;

  /// Light, mid and dark metal for the medal.
  List<Color> get metal => switch (this) {
    brons => const [Color(0xFFFFD0A0), Color(0xFFCD7F32), Color(0xFF7A4318)],
    zilver => const [Color(0xFFFFFFFF), Color(0xFFC8CCDA), Color(0xFF6E7487)],
    goud => const [Color(0xFFFFF1B8), Color(0xFFFFB020), Color(0xFF9A5A00)],
    episch => const [Color(0xFFFFD6F5), Color(0xFFB36BFF), Color(0xFF4A2BAE)],
  };

  Color get glow => metal[1];
}

/// One badge: what it is for and how far you are.
class BadgeDef {
  const BadgeDef({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.tier,
    required this.target,
    required this.progress,
  });

  /// Stored on the server, so keep it stable: lower case and underscores.
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final BadgeTier tier;

  /// Unlocked when [progress] reaches this.
  final int target;
  final int Function(PlayerProfile p) progress;

  /// 0–1.
  double fraction(PlayerProfile p) => (progress(p) / target).clamp(0.0, 1.0);

  bool reached(PlayerProfile p) => progress(p) >= target;
}

/// Every badge, in the order the overview shows them.
final List<BadgeDef> allBadges = [
  BadgeDef(
    id: 'eerste_winst',
    title: 'Eerste overwinning',
    description: 'Win je eerste duel.',
    icon: Icons.emoji_events_rounded,
    tier: BadgeTier.brons,
    target: 1,
    progress: (p) => p.wins,
  ),
  BadgeDef(
    id: 'op_dreef',
    title: 'Op dreef',
    description: 'Win 3 duels na elkaar.',
    icon: Icons.trending_up_rounded,
    tier: BadgeTier.brons,
    target: 3,
    progress: (p) => p.stats.bestStreak,
  ),
  BadgeDef(
    id: 'pyromaan',
    title: 'Pyromaan',
    description: 'Win 10 rondes met vuur.',
    icon: Icons.local_fire_department_rounded,
    tier: BadgeTier.brons,
    target: 10,
    progress: (p) => p.stats.roundWins(Spell.vuur),
  ),
  BadgeDef(
    id: 'ijskoning',
    title: 'IJskoning',
    description: 'Win 10 rondes met ijs.',
    icon: Icons.ac_unit_rounded,
    tier: BadgeTier.brons,
    target: 10,
    progress: (p) => p.stats.roundWins(Spell.ijs),
  ),
  BadgeDef(
    id: 'stormheer',
    title: 'Stormheer',
    description: 'Win 10 rondes met bliksem.',
    icon: Icons.bolt_rounded,
    tier: BadgeTier.brons,
    target: 10,
    progress: (p) => p.stats.roundWins(Spell.bliksem),
  ),
  BadgeDef(
    id: 'botsing',
    title: 'Botsing!',
    description: 'Kies 3 keer dezelfde spreuk als je tegenstander.',
    icon: Icons.compare_arrows_rounded,
    tier: BadgeTier.brons,
    target: 3,
    progress: (p) => p.stats.clashes,
  ),
  BadgeDef(
    id: 'vriendenduel',
    title: 'Vriendschappelijk',
    description: 'Win een duel tegen een vriend.',
    icon: Icons.group_rounded,
    tier: BadgeTier.brons,
    target: 1,
    progress: (p) => p.stats.friendWins,
  ),
  BadgeDef(
    id: 'toernooispeler',
    title: 'Toernooispeler',
    description: 'Speel een duel in een toernooi.',
    icon: Icons.account_tree_rounded,
    tier: BadgeTier.brons,
    target: 1,
    progress: (p) => p.stats.tournamentMatches,
  ),
  BadgeDef(
    id: 'duellist',
    title: 'Duellist',
    description: 'Win 10 duels.',
    icon: Icons.military_tech_rounded,
    tier: BadgeTier.zilver,
    target: 10,
    progress: (p) => p.wins,
  ),
  BadgeDef(
    id: 'veteraan',
    title: 'Veteraan',
    description: 'Speel 25 duels.',
    icon: Icons.auto_stories_rounded,
    tier: BadgeTier.zilver,
    target: 25,
    progress: (p) => p.gamesPlayed,
  ),
  BadgeDef(
    id: 'bliksemsnel',
    title: 'Bliksemsnel',
    description: 'Cast een spreuk binnen 0,5 s na CAST.',
    icon: Icons.flash_on_rounded,
    tier: BadgeTier.zilver,
    target: 1,
    progress: (p) {
      final ms = p.stats.fastestMs;
      return ms > 0 && ms <= 500 ? 1 : 0;
    },
  ),
  BadgeDef(
    id: 'spiegelmeester',
    title: 'Spiegelmeester',
    description: 'Kaats vuur of ijs terug met je schild.',
    icon: Icons.shield_rounded,
    tier: BadgeTier.zilver,
    target: 1,
    progress: (p) => p.stats.reflects,
  ),
  BadgeDef(
    id: 'comeback',
    title: 'Comeback',
    description: 'Win een duel met nog maar 1 leven over.',
    icon: Icons.favorite_rounded,
    tier: BadgeTier.zilver,
    target: 1,
    progress: (p) => p.stats.comebacks,
  ),
  BadgeDef(
    id: 'elementalist',
    title: 'Elementalist',
    description: 'Win een ronde met elk van de 4 spreuken.',
    icon: Icons.auto_awesome_rounded,
    tier: BadgeTier.zilver,
    target: 4,
    progress: (p) => Spell.values.where((s) => p.stats.roundWins(s) > 0).length,
  ),
  BadgeDef(
    id: 'magier',
    title: 'Magiër',
    description: 'Bereik level 5.',
    icon: Icons.school_rounded,
    tier: BadgeTier.zilver,
    target: 5,
    progress: (p) => p.level,
  ),
  BadgeDef(
    id: 'foutloos',
    title: 'Foutloos',
    description: 'Win een duel zonder een leven te verliezen.',
    icon: Icons.verified_rounded,
    tier: BadgeTier.goud,
    target: 1,
    progress: (p) => p.stats.flawless,
  ),
  BadgeDef(
    id: 'onstuitbaar',
    title: 'Onstuitbaar',
    description: 'Win 5 duels na elkaar.',
    icon: Icons.whatshot_rounded,
    tier: BadgeTier.goud,
    target: 5,
    progress: (p) => p.stats.bestStreak,
  ),
  BadgeDef(
    id: 'kampioen',
    title: 'Kampioen',
    description: 'Win 50 duels.',
    icon: Icons.workspace_premium_rounded,
    tier: BadgeTier.goud,
    target: 50,
    progress: (p) => p.wins,
  ),
  BadgeDef(
    id: 'toernooiwinnaar',
    title: 'Toernooiwinnaar',
    description: 'Win een toernooi.',
    icon: Icons.emoji_events_rounded,
    tier: BadgeTier.episch,
    target: 1,
    progress: (p) => p.stats.tournamentWins,
  ),
  BadgeDef(
    id: 'aartsmagier',
    title: 'Aartsmagiër',
    description: 'Bereik level 10.',
    icon: Icons.auto_fix_high_rounded,
    tier: BadgeTier.episch,
    target: 10,
    progress: (p) => p.level,
  ),
];

BadgeDef? badgeById(String id) {
  for (final b in allBadges) {
    if (b.id == id) return b;
  }
  return null;
}
