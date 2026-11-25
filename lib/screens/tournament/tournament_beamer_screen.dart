import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/tournament.dart';
import '../../providers/tournament_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_theme.dart';
import '../../utils/extensions.dart';
import '../../widgets/generic/icon_square_button.dart';
import '../../widgets/tournament/bracket_view.dart';

/// For the projector in class: the code to join while the waiting room is
/// open, then the whole live schema, scaled to fill the screen.
class TournamentBeamerScreen extends StatefulWidget {
  const TournamentBeamerScreen({super.key});

  @override
  State<TournamentBeamerScreen> createState() => _TournamentBeamerScreenState();
}

class _TournamentBeamerScreenState extends State<TournamentBeamerScreen> {
  @override
  void initState() {
    super.initState();
    // The whole projector, not a phone-width column.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => AppSpacing.fullWidth.value = true,
    );
  }

  @override
  void dispose() {
    // Not while the tree is being torn down: after this frame.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => AppSpacing.fullWidth.value = false,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TournamentProvider>();
    final d = t.data;

    return Scaffold(
      backgroundColor: AppColors.backdrop,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.emoji_events_rounded,
                    color: AppColors.gold,
                    size: 30,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'SPELL DUEL TOERNOOI',
                      style: AppTextStyles.display(26),
                    ),
                  ),
                  if (d != null)
                    Text(
                      d.code,
                      style: AppTextStyles.display(
                        26,
                        color: AppColors.goldNumber,
                      ).copyWith(letterSpacing: 6),
                    ),
                  const SizedBox(width: 12),
                  IconSquareButton(
                    icon: Icons.close_rounded,
                    tooltip: 'Sluiten',
                    color: AppColors.textSoft,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: d == null
                    ? Center(
                        child: Text(
                          'Geen toernooi.',
                          style: AppTextStyles.body(18),
                        ),
                      )
                    : d.status == TournamentStatus.lobby
                    ? _JoinBoard(data: d)
                    : FittedBox(
                        child: BracketView(
                          bracket: t.bracket,
                          players: d.players,
                          rooms: d.rooms,
                          myUid: null,
                          animateIn: false,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JoinBoard extends StatelessWidget {
  const _JoinBoard({required this.data});

  final TournamentData data;

  @override
  Widget build(BuildContext context) {
    final roster = data.roster;
    return FittedBox(
      child: SizedBox(
        width: 900,
        child: Column(
          children: [
            Text(
              'Doe mee: Toernooi → Meedoen',
              style: AppTextStyles.body(28, color: AppColors.textSoft),
            ),
            const SizedBox(height: 12),
            Text(
              data.code,
              style: AppTextStyles.display(150, color: AppColors.goldNumber)
                  .copyWith(
                    letterSpacing: 30,
                    shadows: const [
                      Shadow(
                        color: AppColors.goldNumberDeep,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
            ),
            const SizedBox(height: 20),
            Text(
              '${roster.length} ${roster.length == 1 ? 'speler' : 'spelers'}',
              style: AppTextStyles.display(36),
            ),
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 14,
              runSpacing: 14,
              children: [
                for (final p in roster)
                  TweenAnimationBuilder<double>(
                    key: ValueKey(p.uid),
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.elasticOut,
                    builder: (_, s, child) =>
                        Transform.scale(scale: s, child: child),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: p.name.avatarColor,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(p.name, style: AppTextStyles.display(30)),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
