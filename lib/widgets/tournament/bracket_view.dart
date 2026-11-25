import 'dart:math';

import 'package:flutter/material.dart';

import '../../models/tournament.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/extensions.dart';

/// The knock-out schema: one column per round, lines between the matches,
/// the winner's path in gold, live matches pulsing and your own matches
/// highlighted. Cards fly in round by round the first time.
class BracketView extends StatefulWidget {
  const BracketView({
    super.key,
    required this.bracket,
    required this.players,
    this.rooms = const {},
    this.myUid,
    this.onTapMatch,
    this.animateIn = true,
    this.scale = 1,
  });

  final Bracket bracket;
  final Map<String, TournamentPlayer> players;

  /// Matches with a room are being played right now.
  final Map<String, String> rooms;
  final String? myUid;
  final ValueChanged<BracketMatch>? onTapMatch;
  final bool animateIn;

  /// Bigger cards and text, for the beamer.
  final double scale;

  static const cardWidth = 164.0;
  static const cardHeight = 66.0;
  static const columnGap = 38.0;
  static const slotHeight = cardHeight + 16;
  static const championWidth = 150.0;

  /// The size the schema needs at [scale] 1.
  static Size sizeFor(Bracket bracket) {
    if (bracket.isEmpty) return Size.zero;
    final rounds = bracket.rounds.length;
    final first = bracket.rounds.first.length;
    return Size(
      rounds * (cardWidth + columnGap) + championWidth,
      max(first * slotHeight, 190) + 34,
    );
  }

  @override
  State<BracketView> createState() => _BracketViewState();
}

class _BracketViewState extends State<BracketView>
    with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 500 + 260 * widget.bracket.rounds.length),
    value: widget.animateIn ? 0 : 1,
  );
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    if (widget.animateIn) _intro.forward();
  }

  @override
  void dispose() {
    _intro.dispose();
    _pulse.dispose();
    super.dispose();
  }

  Offset _cardTopLeft(int round, int index, double top) {
    final span = 1 << round;
    final cy = (index * span + span / 2) * BracketView.slotHeight + top;
    return Offset(
      round * (BracketView.cardWidth + BracketView.columnGap),
      cy - BracketView.cardHeight / 2,
    );
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.bracket;
    if (b.isEmpty) return const SizedBox.shrink();
    final size = BracketView.sizeFor(b);
    const top = 34.0;
    final roundCount = b.rounds.length;
    final champ = b.champion;

    // Centre short brackets vertically.
    final bracketHeight = b.rounds.first.length * BracketView.slotHeight;
    final offsetY = top + max(0, (size.height - top - bracketHeight) / 2);

    final children = <Widget>[];
    for (var r = 0; r < roundCount; r++) {
      final x = r * (BracketView.cardWidth + BracketView.columnGap);
      final current = b.rounds[r].any(
        (m) => m.isReady || (!m.isDone && m.a != null),
      );
      children.add(
        Positioned(
          left: x,
          top: 0,
          width: BracketView.cardWidth,
          child: _fadeIn(
            r,
            0,
            Text(
              Bracket.roundName(r, roundCount).toUpperCase(),
              textAlign: TextAlign.center,
              style: AppTextStyles.overline(
                color: current ? AppColors.gold : AppColors.textMuted,
              ),
            ),
          ),
        ),
      );
      for (final m in b.rounds[r]) {
        final pos = _cardTopLeft(r, m.index, offsetY);
        children.add(
          Positioned(
            left: pos.dx,
            top: pos.dy,
            width: BracketView.cardWidth,
            height: BracketView.cardHeight,
            child: _fadeIn(
              r,
              m.index / max(1, b.rounds[r].length),
              BracketMatchCard(
                match: m,
                players: widget.players,
                live: _isLive(m),
                mine: widget.myUid != null && m.involves(widget.myUid!),
                myUid: widget.myUid,
                pulse: _pulse,
                onTap: widget.onTapMatch == null
                    ? null
                    : () => widget.onTapMatch!(m),
              ),
            ),
          ),
        );
      }
    }

    // The champion at the end of the line.
    final finalPos = _cardTopLeft(roundCount - 1, 0, offsetY);
    children.add(
      Positioned(
        left: roundCount * (BracketView.cardWidth + BracketView.columnGap),
        top: finalPos.dy - 34,
        width: BracketView.championWidth,
        height: BracketView.cardHeight + 68,
        child: _fadeIn(
          roundCount,
          0,
          _ChampionSlot(
            player: champ == null ? null : widget.players[champ],
            mine: champ != null && champ == widget.myUid,
            pulse: _pulse,
          ),
        ),
      ),
    );

    final view = SizedBox(
      width: size.width,
      height: size.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _intro,
              builder: (_, _) => CustomPaint(
                painter: _ConnectorPainter(
                  bracket: b,
                  cardTopLeft: (r, i) => _cardTopLeft(r, i, offsetY),
                  progress: _intro.value,
                ),
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
    if (widget.scale == 1) return view;
    return SizedBox(
      width: size.width * widget.scale,
      height: size.height * widget.scale,
      child: FittedBox(child: view),
    );
  }

  bool _isLive(BracketMatch m) => m.isReady && widget.rooms.containsKey(m.id);

  /// Round [round] slides in after the one before it.
  Widget _fadeIn(int round, double within, Widget child) {
    final rounds = widget.bracket.rounds.length + 1;
    final start = (round / rounds) * 0.7 + within * 0.12;
    final anim = CurvedAnimation(
      parent: _intro,
      curve: Interval(
        start.clamp(0.0, 0.85),
        (start + 0.3).clamp(0.0, 1.0),
        curve: Curves.easeOutBack,
      ),
    );
    return AnimatedBuilder(
      animation: anim,
      child: child,
      builder: (_, child) {
        final t = anim.value;
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(-24 * (1 - t), 0),
            child: Transform.scale(scale: 0.85 + 0.15 * t, child: child),
          ),
        );
      },
    );
  }
}

/// One match: two seats, the winner in gold.
class BracketMatchCard extends StatelessWidget {
  const BracketMatchCard({
    super.key,
    required this.match,
    required this.players,
    required this.pulse,
    this.live = false,
    this.mine = false,
    this.myUid,
    this.onTap,
  });

  final BracketMatch match;
  final Map<String, TournamentPlayer> players;
  final Animation<double> pulse;
  final bool live;
  final bool mine;
  final String? myUid;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final m = match;
    final border = mine
        ? AppColors.lavender
        : live
        ? AppColors.red
        : m.isDone && !m.isBye
        ? AppColors.gold.withValues(alpha: 0.35)
        : AppColors.borderStrong;

    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      decoration: BoxDecoration(
        color: m.isBye
            ? AppColors.surface.withValues(alpha: 0.55)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border, width: mine || live ? 2 : 1),
        boxShadow: [
          if (mine)
            BoxShadow(
              color: AppColors.lavender.withValues(alpha: 0.35),
              blurRadius: 16,
            ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Expanded(child: _seat(m.a, top: true)),
          Container(height: 1, color: AppColors.border),
          Expanded(child: _seat(m.b, top: false)),
        ],
      ),
    );

    final semantics = _describe();
    Widget result = Semantics(
      label: semantics,
      button: onTap != null,
      child: ExcludeSemantics(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(child: card),
            if (live)
              Positioned(right: -6, top: -9, child: _LiveTag(pulse: pulse)),
            if (m.walkover && !m.isBye)
              const Positioned(right: -6, bottom: -8, child: _WalkoverTag()),
          ],
        ),
      ),
    );
    if (onTap != null && !m.isBye) {
      result = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: result,
      );
    }
    return result;
  }

  String _describe() {
    String name(String? uid) => uid == null
        ? 'nog onbekend'
        : uid == byeSeat
        ? 'vrij'
        : players[uid]?.name ?? 'speler';
    final base = '${name(match.a)} tegen ${name(match.b)}';
    if (match.winner != null) return '$base, ${name(match.winner)} wint';
    if (live) return '$base, nu bezig';
    return base;
  }

  Widget _seat(String? uid, {required bool top}) {
    final m = match;
    final won = uid != null && m.winner == uid;
    final lost = m.isDone && uid != null && uid != byeSeat && !won;
    final isMe = uid != null && uid == myUid;

    if (uid == byeSeat) {
      return _row(
        avatar: const Icon(
          Icons.remove_rounded,
          size: 14,
          color: AppColors.textHint,
        ),
        text: Text(
          'VRIJ',
          style: AppTextStyles.body(
            12,
            weight: FontWeight.w900,
            color: AppColors.textHint,
            letterSpacing: 2,
          ),
        ),
      );
    }
    if (uid == null) {
      return _row(
        avatar: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.trackOff),
          ),
          alignment: Alignment.center,
          child: Text(
            '?',
            style: AppTextStyles.body(11, color: AppColors.textHint),
          ),
        ),
        text: Text(
          'nog onbekend',
          style: AppTextStyles.body(
            12,
            weight: FontWeight.w700,
            color: AppColors.textHint,
          ),
        ),
      );
    }

    final p = players[uid];
    final name = p?.name ?? 'Speler';
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      color: won ? AppColors.gold.withValues(alpha: 0.16) : Colors.transparent,
      child: _row(
        avatar: Opacity(
          opacity: lost ? 0.45 : 1,
          child: Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: name.avatarColor,
              shape: BoxShape.circle,
            ),
            child: Text(
              name.initial,
              style: AppTextStyles.body(11, weight: FontWeight.w900),
            ),
          ),
        ),
        text: Row(
          children: [
            Flexible(
              child: Text(
                isMe ? '$name (jij)' : name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    AppTextStyles.body(
                      13,
                      weight: won ? FontWeight.w900 : FontWeight.w800,
                      color: won
                          ? AppColors.goldLight
                          : lost
                          ? AppColors.textHint
                          : isMe
                          ? AppColors.lavenderLight
                          : AppColors.text,
                    ).copyWith(
                      decoration: lost ? TextDecoration.lineThrough : null,
                      decorationColor: AppColors.textHint,
                    ),
              ),
            ),
            if (p != null && !p.online && !m.isDone) ...[
              const SizedBox(width: 4),
              const Icon(
                Icons.wifi_off_rounded,
                size: 12,
                color: AppColors.redSoft,
              ),
            ],
          ],
        ),
        trailing: won
            ? const Icon(
                Icons.emoji_events_rounded,
                size: 16,
                color: AppColors.gold,
              )
            : null,
      ),
    );
  }

  Widget _row({
    required Widget avatar,
    required Widget text,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 9),
      child: Row(
        children: [
          SizedBox(width: 20, child: Center(child: avatar)),
          const SizedBox(width: 8),
          Expanded(child: text),
          ?trailing,
        ],
      ),
    );
  }
}

class _LiveTag extends StatelessWidget {
  const _LiveTag({required this.pulse});

  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (_, _) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.red,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: AppColors.red.withValues(alpha: 0.3 + 0.4 * pulse.value),
              blurRadius: 6 + 8 * pulse.value,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.5 + 0.5 * pulse.value),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              'LIVE',
              style: AppTextStyles.body(
                9,
                weight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WalkoverTag extends StatelessWidget {
  const _WalkoverTag();

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Gewonnen zonder te spelen (walk-over)',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.surfaceRaised,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          'W.O.',
          style: AppTextStyles.body(
            9,
            weight: FontWeight.w900,
            color: AppColors.textSoft,
          ),
        ),
      ),
    );
  }
}

class _ChampionSlot extends StatelessWidget {
  const _ChampionSlot({
    required this.player,
    required this.mine,
    required this.pulse,
  });

  final TournamentPlayer? player;
  final bool mine;
  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    final p = player;
    return Semantics(
      label: p == null ? 'Kampioen nog onbekend' : 'Kampioen: ${p.name}',
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: pulse,
          builder: (_, _) {
            final glow = p == null ? 0.0 : 0.35 + 0.35 * pulse.value;
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: p == null
                        ? null
                        : const RadialGradient(
                            colors: [AppColors.goldLight, AppColors.gold],
                          ),
                    color: p == null ? AppColors.surface : null,
                    border: Border.all(
                      color: p == null
                          ? AppColors.trackOff
                          : AppColors.goldLight,
                      width: 2,
                    ),
                    boxShadow: [
                      if (p != null)
                        BoxShadow(
                          color: AppColors.gold.withValues(alpha: glow),
                          blurRadius: 24,
                          spreadRadius: 2,
                        ),
                    ],
                  ),
                  child: Icon(
                    Icons.emoji_events_rounded,
                    size: 34,
                    color: p == null ? AppColors.trackOff : AppColors.goldInk,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  p == null ? 'KAMPIOEN' : (mine ? 'JIJ!' : p.name),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: p == null
                      ? AppTextStyles.overline(color: AppColors.textHint)
                      : AppTextStyles.display(20, color: AppColors.goldNumber),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ConnectorPainter extends CustomPainter {
  _ConnectorPainter({
    required this.bracket,
    required this.cardTopLeft,
    required this.progress,
  });

  final Bracket bracket;
  final Offset Function(int round, int index) cardTopLeft;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final idle = Paint()
      ..color = AppColors.trackOff
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final gold = Paint()
      ..color = AppColors.gold
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final goldGlow = Paint()
      ..color = AppColors.gold.withValues(alpha: 0.25)
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    const w = BracketView.cardWidth, h = BracketView.cardHeight;
    const gap = BracketView.columnGap;
    final rounds = bracket.rounds.length;

    for (var r = 0; r < rounds; r++) {
      // Lines appear after their round's cards.
      final t = ((progress - (r + 0.6) / (rounds + 1) * 0.7) * 4).clamp(
        0.0,
        1.0,
      );
      if (t <= 0) continue;
      for (final m in bracket.rounds[r]) {
        final from = cardTopLeft(r, m.index) + const Offset(w, h / 2);
        final Offset to;
        if (r == rounds - 1) {
          to = from + const Offset(gap, 0);
        } else {
          final next = cardTopLeft(r + 1, m.index ~/ 2);
          to = next + const Offset(0, h / 2);
        }
        final midX = from.dx + gap / 2;
        final path = Path()
          ..moveTo(from.dx, from.dy)
          ..lineTo(midX, from.dy)
          ..lineTo(midX, to.dy)
          ..lineTo(to.dx, to.dy);
        final metric = path.computeMetrics().first;
        final part = metric.extractPath(0, metric.length * t);
        final won = m.winner != null;
        if (won) {
          canvas.drawPath(part, goldGlow);
          canvas.drawPath(part, gold);
        } else {
          canvas.drawPath(part, idle);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_ConnectorPainter old) =>
      old.progress != progress || old.bracket != bracket;
}
