import 'package:flutter/material.dart';

import '../../models/game_rules.dart';
import '../../models/game_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_transitions.dart';
import '../generic/avatar_tile.dart';

/// Both players' lives and shields, with the round number in the middle.
class DuelHeader extends StatelessWidget {
  const DuelHeader({
    super.key,
    required this.me,
    required this.opponent,
    required this.round,
    required this.config,
  });

  final PlayerState? me;
  final PlayerState? opponent;
  final int round;
  final GameConfig config;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 84,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _PlayerSide(
              player: me,
              label: 'Jij',
              config: config,
              alignEnd: false,
            ),
          ),
          const SizedBox(width: 10),
          _RoundHex(round: round),
          const SizedBox(width: 10),
          Expanded(
            child: _PlayerSide(
              player: opponent,
              label: opponent?.name ?? 'Tegenstander',
              config: config,
              alignEnd: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerSide extends StatelessWidget {
  const _PlayerSide({
    required this.player,
    required this.label,
    required this.config,
    required this.alignEnd,
  });

  final PlayerState? player;
  final String label;
  final GameConfig config;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final lives = player?.lives ?? config.startLives;
    final shieldsLeft = config.shieldUses - (player?.shieldsUsed ?? 0);
    final avatar = AvatarTile(name: player?.name ?? label, size: 34);
    final info = Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppTextStyles.body(13, weight: FontWeight.w900, height: 1.1),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 3),
        Semantics(
          label: '$shieldsLeft schild over',
          excludeSemantics: true,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < config.shieldUses; i++) ...[
                if (i > 0) const SizedBox(width: 3),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: i < shieldsLeft
                        ? AppColors.shieldPip
                        : AppColors.track,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: alignEnd
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: alignEnd
              ? [Flexible(child: info), const SizedBox(width: 8), avatar]
              : [avatar, const SizedBox(width: 8), Flexible(child: info)],
        ),
        const SizedBox(height: 9),
        LifeBar(
          lives: lives,
          maxLives: config.startLives,
          reversed: alignEnd,
          semanticLabel: '$label: $lives van ${config.startLives} levens',
        ),
      ],
    );
  }
}

/// Skewed red segments, one per life.
class LifeBar extends StatelessWidget {
  const LifeBar({
    super.key,
    required this.lives,
    required this.maxLives,
    required this.semanticLabel,
    this.reversed = false,
  });

  final int lives;
  final int maxLives;
  final bool reversed;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final segments = [
      for (var i = 0; i < maxLives; i++)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.5),
            child: Transform(
              transform: Matrix4.skewX(-0.24),
              alignment: Alignment.center,
              child: AnimatedContainer(
                duration: AppTransitions.medium * 3,
                curve: Curves.easeOut,
                height: 12,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: i < lives ? null : AppColors.track,
                  gradient: i < lives
                      ? const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xFFFF9AAE),
                            Color(0xFFFF3D62),
                            Color(0xFFD81E47),
                          ],
                          stops: [0, 0.55, 1],
                        )
                      : null,
                  boxShadow: i < lives
                      ? [
                          BoxShadow(
                            color: AppColors.red.withValues(alpha: 0.45),
                            blurRadius: 10,
                          ),
                        ]
                      : null,
                ),
              ),
            ),
          ),
        ),
    ];
    return Semantics(
      label: semanticLabel,
      excludeSemantics: true,
      child: Row(children: reversed ? segments.reversed.toList() : segments),
    );
  }
}

class _RoundHex extends StatelessWidget {
  const _RoundHex({required this.round});

  final int round;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Ronde $round',
      excludeSemantics: true,
      child: SizedBox(
        width: 64,
        height: 58,
        child: ClipPath(
          clipper: const _HexClipper(),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.goldLight, AppColors.goldNumberShadow],
              ),
            ),
            padding: const EdgeInsets.all(4),
            child: ClipPath(
              clipper: const _HexClipper(),
              child: Container(
                color: AppColors.hexInner,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'RONDE',
                      style: AppTextStyles.body(
                        9,
                        weight: FontWeight.w900,
                        color: AppColors.lavender,
                        letterSpacing: 1,
                      ),
                    ),
                    Text(
                      '${round < 1 ? 1 : round}',
                      style: AppTextStyles.display(
                        20,
                        color: AppColors.goldLight,
                      ).copyWith(height: 1),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HexClipper extends CustomClipper<Path> {
  const _HexClipper();

  @override
  Path getClip(Size s) => Path()
    ..moveTo(s.width * .25, s.height * .03)
    ..lineTo(s.width * .75, s.height * .03)
    ..lineTo(s.width, s.height * .5)
    ..lineTo(s.width * .75, s.height * .97)
    ..lineTo(s.width * .25, s.height * .97)
    ..lineTo(0, s.height * .5)
    ..close();

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
