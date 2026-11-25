import 'dart:math';

import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/game_rules.dart';
import '../../models/game_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/round_text.dart';
import '../generic/spell_orb.dart';

/// The strip between the two feeds: "3… 2… 1… CAST!" and, after the
/// round, both spells with "RAAK!" / "AU!" / "GELIJK!".
class DuelCenterBanner extends StatefulWidget {
  const DuelCenterBanner({super.key, required this.state});

  final GameState state;

  @override
  State<DuelCenterBanner> createState() => _DuelCenterBannerState();
}

class _DuelCenterBannerState extends State<DuelCenterBanner> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(DuelCenterBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTicker();
  }

  void _syncTicker() {
    final counting = widget.state.phase == GamePhase.countdown;
    if (counting && _ticker == null) {
      _ticker = Timer.periodic(
        const Duration(milliseconds: 100),
        (_) => setState(() {}),
      );
    } else if (!counting) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final Widget child = switch (s.phase) {
      GamePhase.countdown => _Count(
        key: ValueKey('c${s.round}-${_secondsLeft(s)}'),
        text: '${_secondsLeft(s)}',
        headline: 'MAAK JE GEBAAR',
      ),
      GamePhase.cast => _Count(
        key: ValueKey('cast${s.round}${s.mySpell != null}'),
        text: s.mySpell == null ? 'CAST!' : 'GECAST',
        headline: s.mySpell == null ? 'NU!' : 'WACHTEN OP TEGENSTANDER',
        small: true,
      ),
      GamePhase.resolving => _Count(
        key: ValueKey('res${s.round}'),
        text: '…',
        headline: 'ONTHULLEN',
        small: true,
      ),
      GamePhase.roundResult ||
      GamePhase.finished when s.lastResult != null => _Reveal(
        key: ValueKey('rev${s.lastResult!.round}'),
        result: s.lastResult!,
        opponentName: s.opponent?.name ?? 'Tegenstander',
      ),
      _ => _Count(
        key: const ValueKey('wait'),
        text: '…',
        headline: 'WACHTEN OP TEGENSTANDER',
        small: true,
      ),
    };
    return SizedBox(
      height: 96,
      child: Semantics(
        liveRegion: true,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (child, anim) => ScaleTransition(
            scale: Tween(
              begin: 0.7,
              end: 1.0,
            ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutBack)),
            child: FadeTransition(opacity: anim, child: child),
          ),
          child: child,
        ),
      ),
    );
  }

  int _secondsLeft(GameState s) {
    final castAt = s.castAt;
    if (castAt == null) return s.config.countdown.inSeconds;
    final ms = castAt.difference(DateTime.now()).inMilliseconds;
    final secs = (ms / 1000).ceil();
    // max(): a countdown under a second (tests) would make clamp throw.
    return secs.clamp(1, max(1, s.config.countdown.inSeconds));
  }
}

TextStyle _numberStyle(double size) =>
    AppTextStyles.display(size, color: AppColors.goldNumber).copyWith(
      height: 1,
      shadows: const [
        Shadow(color: AppColors.goldNumberShadow, offset: Offset(0, 3)),
        Shadow(color: AppColors.goldNumberDeep, offset: Offset(0, 6)),
        Shadow(color: Colors.black54, blurRadius: 26, offset: Offset(0, 12)),
      ],
    );

class _Count extends StatelessWidget {
  const _Count({
    super.key,
    required this.text,
    required this.headline,
    this.small = false,
  });

  final String text;
  final String headline;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final line = Expanded(
      child: Container(
        height: 2,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.transparent, Color(0x80FFB020), Colors.transparent],
          ),
        ),
      ),
    );
    return Row(
      children: [
        line,
        const SizedBox(width: 14),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(text, style: _numberStyle(small ? 46 : 60)),
            const SizedBox(height: 4),
            Text(
              headline,
              style: AppTextStyles.body(
                12,
                weight: FontWeight.w900,
                color: AppColors.textFeed,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        const SizedBox(width: 14),
        line,
      ],
    );
  }
}

class _Reveal extends StatelessWidget {
  const _Reveal({super.key, required this.result, required this.opponentName});

  final RoundResult result;
  final String opponentName;

  @override
  Widget build(BuildContext context) {
    final text = roundText(result, opponentName: opponentName);
    final iLost = result.outcome == RoundOutcome.lose;
    final iWon = result.outcome == RoundOutcome.win;

    Widget orb(Spell? spell, {required bool dimmed}) => SizedBox.square(
      dimension: 54,
      child: spell == null
          ? const DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.track,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.close_rounded, color: AppColors.textMuted),
            )
          : SpellOrb(spell: spell, size: 54, dimmed: dimmed),
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _SlideIn(fromLeft: true, child: orb(result.mySpell, dimmed: iLost)),
        const SizedBox(width: 14),
        Flexible(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // One line that shrinks: a long title on a narrow phone
              // must not wrap out of the 96 px banner.
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(text.title, maxLines: 1, style: _numberStyle(40)),
              ),
              const SizedBox(height: 4),
              Text(
                text.subtitle,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body(
                  12,
                  weight: FontWeight.w900,
                  color: AppColors.textFeed,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        _SlideIn(
          fromLeft: false,
          child: orb(result.opponentSpell, dimmed: iWon),
        ),
      ],
    );
  }
}

class _SlideIn extends StatelessWidget {
  const _SlideIn({required this.fromLeft, required this.child});

  final bool fromLeft;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Transform.translate(
        offset: Offset((fromLeft ? -70 : 70) * (1 - t), 0),
        child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
      ),
      child: child,
    );
  }
}
