import 'package:flutter/material.dart';

import '../../models/tournament.dart';
import '../../providers/tournament_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../generic/app_card.dart';
import '../generic/chunky_button.dart';

/// Where you stand: your duel is ready, you have a bye, you are waiting
/// for an opponent, you are out, or the tournament is over.
class MatchStatusCard extends StatelessWidget {
  const MatchStatusCard({
    super.key,
    required this.t,
    required this.onPlay,
    required this.onClaim,
    required this.onDone,
  });

  final TournamentProvider t;
  final VoidCallback onPlay;
  final VoidCallback onClaim;

  /// The tournament is over: close it (to make a new one).
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final b = t.bracket;
    final rounds = b.rounds.length;
    final champ = t.champion;
    final me = t.myUid;

    if (champ != null) {
      final p = t.player(champ);
      return _Card(
        color: AppColors.gold,
        icon: Icons.emoji_events_rounded,
        title: t.isChampion ? 'Jij bent kampioen!' : '${p?.name} is kampioen!',
        text: t.isChampion
            ? 'Je hebt het hele toernooi gewonnen. Legendarisch.'
            : 'Het toernooi is afgelopen. Proficiat aan ${p?.name}!',
        child: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: ChunkyButton(
            label: 'Toernooi afsluiten',
            icon: Icons.check_rounded,
            display: false,
            height: 46,
            style: ChunkyButtonStyle.secondary,
            onPressed: onDone,
          ),
        ),
      );
    }

    if (me == null) return const SizedBox.shrink();
    if (t.isEliminated) {
      final reached = b.roundReached(me);
      return _Card(
        color: AppColors.textMuted,
        icon: Icons.visibility_rounded,
        title:
            'Uitgeschakeld in de ${Bracket.roundName(reached, rounds).toLowerCase()}',
        text: 'Goed gestreden! Volg de rest van het toernooi hier live.',
      );
    }

    final m = t.myMatch;
    if (m == null) return const SizedBox.shrink();
    final roundName = Bracket.roundName(m.round, rounds);

    if (!m.isReady) {
      // Your opponent comes from a match that is still going.
      final hadBye = b.rounds.first.any((x) => x.isBye && x.involves(me));
      return _Card(
        color: AppColors.green,
        icon: hadBye && m.round == 1
            ? Icons.fast_forward_rounded
            : Icons.hourglass_top_rounded,
        title: hadBye && m.round == 1
            ? 'Vrijloting: je zit al in ronde 2!'
            : 'Door naar de ${roundName.toLowerCase()}!',
        text:
            'Je wacht op de winnaar van het andere duel. Je telefoon roept '
            'je op zodra je moet spelen.',
      );
    }

    final opp = t.myOpponent;
    final name = opp?.name ?? 'je tegenstander';
    final waited = t.waitingFor;
    final claim = t.canClaimWalkover;
    final left = t.walkoverIn.inSeconds;
    return _Card(
      color: AppColors.lavender,
      icon: Icons.sports_kabaddi_rounded,
      title: '${roundName.toUpperCase()}: tegen $name',
      text: opp != null && !opp.online
          ? '$name is offline. Komt die niet terug, dan win je over $left s.'
          : waited.inSeconds > 30
          ? 'Wacht je op $name? Na ${left}s mag je de winst opeisen.'
          : 'Jouw duel is klaar. Zoek $name op en speel!',
      child: Column(
        children: [
          const SizedBox(height: 12),
          ChunkyButton(
            label: t.inMatch ? 'BEZIG…' : 'SPEEL DUEL',
            height: 54,
            fontSize: 20,
            style: ChunkyButtonStyle.success,
            onPressed: t.inMatch ? null : onPlay,
          ),
          if (claim) ...[
            const SizedBox(height: 8),
            ChunkyButton(
              label: '$name komt niet: ik win (w.o.)',
              display: false,
              height: 46,
              style: ChunkyButtonStyle.secondary,
              onPressed: onClaim,
            ),
          ],
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.color,
    required this.icon,
    required this.title,
    required this.text,
    this.child,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String text;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      transitionBuilder: (c, a) => FadeTransition(
        opacity: a,
        child: SizeTransition(sizeFactor: a, child: c),
      ),
      child: AppCard(
        key: ValueKey(title),
        borderColor: color.withValues(alpha: 0.45),
        borderWidth: 1.5,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppTextStyles.display(19)),
                      const SizedBox(height: 2),
                      Text(
                        text,
                        style: AppTextStyles.body(
                          13,
                          weight: FontWeight.w700,
                          color: AppColors.textSoft,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            ?child,
          ],
        ),
      ),
    );
  }
}
