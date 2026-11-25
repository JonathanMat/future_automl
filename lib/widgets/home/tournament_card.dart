import 'dart:math';

import 'package:flutter/material.dart';

import '../../models/tournament.dart';
import '../../providers/tournament_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// Home: "TOERNOOI" to start or join one, or — while you are in one — the
/// way back, glowing when your duel is ready.
class TournamentCard extends StatefulWidget {
  const TournamentCard({super.key, required this.t, required this.onOpen});

  final TournamentProvider t;
  final VoidCallback onOpen;

  @override
  State<TournamentCard> createState() => _TournamentCardState();
}

class _TournamentCardState extends State<TournamentCard>
    with SingleTickerProviderStateMixin {
  // Only glows (and ticks) while your duel is ready, so home stays idle.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  void _syncPulse(bool ready) {
    if (ready && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!ready && _pulse.isAnimating) {
      _pulse.stop();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final d = t.data;
    final ready = t.myMatch?.isReady ?? false;
    _syncPulse(ready);

    final (String title, String text) = switch (d?.status) {
      null => ('TOERNOOI', 'Speel met de hele klas, knock-out tot 16 spelers'),
      TournamentStatus.lobby => (
        'TERUG NAAR TOERNOOI',
        'Wachtkamer ${d!.code} · ${d.players.length} spelers',
      ),
      _ when t.champion != null => (
        'TOERNOOI AFGELOPEN',
        '${t.player(t.champion)?.name} is kampioen!',
      ),
      _ when ready => (
        'JOUW DUEL IS KLAAR!',
        'Tegen ${t.myOpponent?.name ?? 'je tegenstander'} · tik om te spelen',
      ),
      _ when t.isEliminated => ('TOERNOOI', 'Je ligt eruit · kijk live mee'),
      _ => ('TERUG NAAR TOERNOOI', 'Je zit nog in de race!'),
    };

    return Semantics(
      button: true,
      label: '$title. $text',
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: widget.onOpen,
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (_, child) {
              final glow = ready ? 0.25 + 0.35 * _pulse.value : 0.0;
              return Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    colors: [
                      AppColors.surfaceRaised,
                      Color.lerp(
                        AppColors.surfaceRaised,
                        AppColors.gold,
                        ready ? 0.25 : 0.08,
                      )!,
                    ],
                  ),
                  border: Border.all(
                    color: ready
                        ? AppColors.gold
                        : AppColors.gold.withValues(alpha: 0.3),
                    width: ready ? 2 : 1,
                  ),
                  boxShadow: [
                    const BoxShadow(
                      color: AppColors.surfaceRaisedShadow,
                      offset: Offset(0, 5),
                    ),
                    if (ready)
                      BoxShadow(
                        color: AppColors.gold.withValues(alpha: glow),
                        blurRadius: 22,
                      ),
                  ],
                ),
                child: child,
              );
            },
            child: Row(
              children: [
                Transform.rotate(
                  angle: -pi / 24,
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppColors.gold,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [
                        BoxShadow(
                          color: AppColors.goldShadow,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.emoji_events_rounded,
                      color: AppColors.goldInk,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.display(
                          20,
                          color: ready ? AppColors.goldNumber : AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption(color: AppColors.textSoft),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSoft,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
