import 'dart:math';

import 'package:flutter/material.dart';

import '../../models/tournament.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/extensions.dart';
import '../generic/app_card.dart';
import '../generic/chunky_button.dart';
import '../generic/copy_button.dart';
import '../generic/player_name.dart';

/// Before the start: the big code, everybody who joined (popping in), how
/// the bracket will look, and START for the host.
class WaitingRoom extends StatelessWidget {
  const WaitingRoom({
    super.key,
    required this.data,
    required this.myUid,
    required this.isHost,
    required this.busy,
    required this.onStart,
    this.onAddBots,
  });

  final TournamentData data;
  final String? myUid;
  final bool isHost;
  final bool busy;
  final VoidCallback onStart;

  /// Mock only.
  final VoidCallback? onAddBots;

  @override
  Widget build(BuildContext context) {
    final roster = data.roster;
    final n = roster.length;
    final seats = n < 2 ? 2 : Bracket.seatsFor(n);
    final byes = n < 2 ? 0 : seats - n;
    final rounds = (log(seats) / ln2).round();
    final host = data.players[data.hostUid];

    final info = <Widget>[
      _CodeCard(code: data.code),
      const SizedBox(height: 14),
      Row(
        children: [
          Expanded(
            child: _Fact(value: '$n/$maxTournamentPlayers', label: 'Spelers'),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _Fact(
              value: '$byes',
              label: byes == 1 ? 'Vrijloting' : 'Vrijlotingen',
              color: byes > 0 ? AppColors.green : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _Fact(
              value: '$rounds',
              label: rounds == 1 ? 'Ronde' : 'Rondes',
            ),
          ),
        ],
      ),
      if (byes > 0) ...[
        const SizedBox(height: 10),
        Text(
          '$n spelers is geen macht van 2: $byes '
          '${byes == 1 ? 'speler gaat' : 'spelers gaan'} na de loting '
          'meteen door naar ronde 2.',
          textAlign: TextAlign.center,
          style: AppTextStyles.caption(),
        ),
      ],
      const SizedBox(height: 18),
      Text('IN DE ZAAL', style: AppTextStyles.overline()),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final p in roster)
            _PopIn(
              key: ValueKey(p.uid),
              child: _PlayerChip(
                player: p,
                isHost: p.uid == data.hostUid,
                isMe: p.uid == myUid,
              ),
            ),
        ],
      ),
      if (isHost && onAddBots != null) ...[
        const SizedBox(height: 16),
        ChunkyButton(
          label: '+3 test-bots',
          icon: Icons.smart_toy_rounded,
          display: false,
          height: 48,
          style: ChunkyButtonStyle.secondary,
          onPressed: n >= maxTournamentPlayers ? null : onAddBots,
        ),
      ],
    ];

    // START stays in view however many players join.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            children: info,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: isHost
              ? ChunkyButton(
                  label: n < 2 ? 'WACHTEN OP SPELERS…' : 'START TOERNOOI',
                  icon: n < 2
                      ? Icons.hourglass_top_rounded
                      : Icons.play_arrow_rounded,
                  style: ChunkyButtonStyle.primary,
                  dimWhenDisabled: n >= 2,
                  loading: busy,
                  onPressed: n < 2 || busy ? null : onStart,
                )
              : _WaitingForHost(name: host?.name ?? 'de host'),
        ),
      ],
    );
  }
}

class _CodeCard extends StatelessWidget {
  const _CodeCard({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      borderColor: AppColors.gold.withValues(alpha: 0.35),
      child: Column(
        children: [
          Text('TOERNOOICODE', style: AppTextStyles.overline()),
          const SizedBox(height: 6),
          Semantics(
            label: 'Toernooicode ${code.split('').join(' ')}',
            child: ExcludeSemantics(
              child: FittedBox(
                child: Text(
                  code,
                  style: AppTextStyles.display(58, color: AppColors.goldNumber)
                      .copyWith(
                        letterSpacing: 10,
                        shadows: const [
                          Shadow(
                            color: AppColors.goldNumberDeep,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Iedereen tikt op Toernooi → Meedoen en vult deze code in.',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption(),
          ),
          const SizedBox(height: 10),
          CopyButton(
            text: code,
            tooltip: 'Kopieer de toernooicode',
            label: 'Kopieer',
            message: 'Toernooicode $code gekopieerd.',
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.value, required this.label, this.color});

  final String value;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Column(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, a) =>
                ScaleTransition(scale: a, child: child),
            child: Text(
              value,
              key: ValueKey(value),
              style: AppTextStyles.display(24, color: color ?? AppColors.text),
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.caption()),
        ],
      ),
    );
  }
}

class _PlayerChip extends StatelessWidget {
  const _PlayerChip({
    required this.player,
    required this.isHost,
    required this.isMe,
  });

  final TournamentPlayer player;
  final bool isHost;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final name = player.name;
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isMe ? AppColors.lavender : AppColors.borderStrong,
          width: isMe ? 2 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: name.avatarColor,
              shape: BoxShape.circle,
            ),
            child: player.bot
                ? const Icon(Icons.smart_toy_rounded, size: 15)
                : Text(
                    name.initial,
                    style: AppTextStyles.body(13, weight: FontWeight.w900),
                  ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 190),
            child: PlayerName(
              name: name,
              tag: player.tag,
              suffix: isMe ? ' (jij)' : '',
              style: AppTextStyles.body(14),
            ),
          ),
          if (isHost) ...[
            const SizedBox(width: 6),
            const Tooltip(
              message: 'Host',
              child: Icon(
                Icons.workspace_premium_rounded,
                size: 16,
                color: AppColors.gold,
              ),
            ),
          ],
          if (!player.online) ...[
            const SizedBox(width: 6),
            const Icon(
              Icons.wifi_off_rounded,
              size: 14,
              color: AppColors.redSoft,
            ),
          ],
        ],
      ),
    );
  }
}

/// Pops in with a bounce the first time it is built.
class _PopIn extends StatelessWidget {
  const _PopIn({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 650),
      curve: Curves.elasticOut,
      builder: (_, t, child) => Transform.scale(
        scale: t,
        child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
      ),
      child: child,
    );
  }
}

class _WaitingForHost extends StatefulWidget {
  const _WaitingForHost({required this.name});

  final String name;

  @override
  State<_WaitingForHost> createState() => _WaitingForHostState();
}

class _WaitingForHostState extends State<_WaitingForHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _c,
            builder: (_, _) => Row(
              children: [
                for (var i = 0; i < 3; i++)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(right: 5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.lavender.withValues(
                        alpha:
                            0.25 +
                            0.75 * max(0, sin((_c.value - i * 0.18) * 2 * pi)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Wachten tot ${widget.name} het toernooi start…',
              style: AppTextStyles.body(14, color: AppColors.textSoft),
            ),
          ),
        ],
      ),
    );
  }
}
