import 'package:flutter/material.dart';

import '../../models/game_rules.dart';
import '../../models/game_state.dart';
import '../../models/spell_info.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../generic/pill_badge.dart';
import '../generic/spell_orb.dart';

/// "● LIVE" in the top-left corner of a feed.
class LiveBadge extends StatelessWidget {
  const LiveBadge({super.key, required this.status});

  final CallStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, dot) = switch (status) {
      CallStatus.connected => ('LIVE', AppColors.red),
      CallStatus.connecting => ('VERBINDEN', AppColors.gold),
      CallStatus.failed => ('GEEN VIDEO', AppColors.textMuted),
      CallStatus.closed || CallStatus.none => ('OFFLINE', AppColors.textMuted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.overlay,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.body(
              11,
              weight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Three signal bars for the call quality.
class ConnectionBars extends StatelessWidget {
  const ConnectionBars({super.key, required this.status});

  final CallStatus status;

  @override
  Widget build(BuildContext context) {
    final bars = switch (status) {
      CallStatus.connected => 3,
      CallStatus.connecting => 1,
      _ => 0,
    };
    final label = switch (bars) {
      3 => 'Goede verbinding',
      1 => 'Verbinding maken',
      _ => 'Geen verbinding',
    };
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.overlay,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 2),
              Container(
                width: 3,
                height: 5.0 + i * 3,
                decoration: BoxDecoration(
                  color: i < bars ? AppColors.green : AppColors.trackOff,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// What the opponent did: "Kiest…" while hidden, their spell afterwards.
class OpponentSpellChip extends StatelessWidget {
  const OpponentSpellChip({
    super.key,
    required this.spell,
    required this.hidden,
  });

  final Spell? spell;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final Widget icon;
    final String text;
    if (hidden) {
      icon = const SizedBox.square(
        dimension: 32,
        child: Padding(
          padding: EdgeInsets.all(4),
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.shieldPip,
          ),
        ),
      );
      text = 'Kiest…';
    } else if (spell != null) {
      icon = SpellOrb(spell: spell!, size: 32, glow: false);
      text = spell!.label;
    } else {
      icon = const SizedBox.square(
        dimension: 32,
        child: Icon(
          Icons.do_not_disturb_alt_rounded,
          color: AppColors.textMuted,
          size: 22,
        ),
      );
      text = 'Niets';
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
      decoration: BoxDecoration(
        color: const Color(0xBF080614),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(width: 8),
          Text(
            text,
            style: AppTextStyles.body(
              12,
              weight: FontWeight.w900,
              color: AppColors.lavenderLight,
            ),
          ),
        ],
      ),
    );
  }
}

/// Orange corner brackets that frame the hand on your own feed.
class AimBrackets extends StatelessWidget {
  const AimBrackets({super.key, this.color = const Color(0xFFFFB27A)});

  final Color color;

  @override
  Widget build(BuildContext context) {
    const size = 30.0;
    BorderSide side() => BorderSide(color: color, width: 4);
    Widget corner(Alignment a) {
      final top = a.y < 0, left = a.x < 0;
      return Align(
        alignment: a,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            border: Border(
              top: top ? side() : BorderSide.none,
              bottom: top ? BorderSide.none : side(),
              left: left ? side() : BorderSide.none,
              right: left ? BorderSide.none : side(),
            ),
            borderRadius: BorderRadius.only(
              topLeft: top && left ? const Radius.circular(10) : Radius.zero,
              topRight: top && !left ? const Radius.circular(10) : Radius.zero,
              bottomLeft: !top && left
                  ? const Radius.circular(10)
                  : Radius.zero,
              bottomRight: !top && !left
                  ? const Radius.circular(10)
                  : Radius.zero,
            ),
          ),
        ),
      );
    }

    return IgnorePointer(
      child: Align(
        alignment: const Alignment(0, -0.45),
        child: SizedBox(
          width: 164,
          height: 134,
          child: Stack(
            children: [
              corner(Alignment.topLeft),
              corner(Alignment.topRight),
              corner(Alignment.bottomLeft),
              corner(Alignment.bottomRight),
            ],
          ),
        ),
      ),
    );
  }
}

/// "JIJ" label for your own feed.
class FeedLabel extends StatelessWidget {
  const FeedLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) => PillBadge(label: label, solid: true);
}
