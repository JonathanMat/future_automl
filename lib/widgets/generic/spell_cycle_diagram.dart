import 'dart:math';

import 'package:flutter/material.dart';

import '../../models/game_rules.dart';
import '../../models/spell_info.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_transitions.dart';
import 'spell_orb.dart';

/// "What beats what" as a picture: the attack spells in a circle with
/// arrows going round (IJs › Vuur › Bliksem › IJs) and the shield in the
/// middle, with arrows to what it blocks and from what breaks it.
///
/// Built from [Spell.beats], so it always matches the real rules. Tap a
/// spell to light up its arrows and read what it wins and loses against.
class SpellCycleDiagram extends StatefulWidget {
  const SpellCycleDiagram({
    super.key,
    this.config = const GameConfig(),
    this.showGestures = true,
    this.maxWidth = 330,
  });

  final GameConfig config;

  /// Show the hand gesture under each spell name.
  final bool showGestures;
  final double maxWidth;

  @override
  State<SpellCycleDiagram> createState() => _SpellCycleDiagramState();
}

class _SpellCycleDiagramState extends State<SpellCycleDiagram>
    with SingleTickerProviderStateMixin {
  /// Draws the arrows in when the diagram first shows.
  late final _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward();

  Spell? _selected;

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  void _tap(Spell spell) =>
      setState(() => _selected = _selected == spell ? null : spell);

  @override
  Widget build(BuildContext context) {
    final layout = _Layout.fromRules();
    return Semantics(
      label: 'Spelregels: ${rulesSummary(widget.config)}',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final w = min(constraints.maxWidth, widget.maxWidth);
              final g = _Geometry(layout, w, widget.showGestures);
              return SizedBox(
                width: w,
                height: g.height,
                child: TweenAnimationBuilder<double>(
                  // 0 = nothing selected, 1 = fully highlighted.
                  tween: Tween(end: _selected == null ? 0 : 1),
                  duration: AppTransitions.fast,
                  builder: (context, focus, _) => AnimatedBuilder(
                    animation: _intro,
                    builder: (context, _) =>
                        _diagram(g, _intro.value, focus, layout),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 6),
          AnimatedSwitcher(
            duration: AppTransitions.fast,
            child: _Caption(
              key: ValueKey(_selected),
              spell: _selected,
              config: widget.config,
            ),
          ),
        ],
      ),
    );
  }

  Widget _diagram(_Geometry g, double intro, double focus, _Layout layout) {
    final selected = _selected;
    bool involved(_Arrow a) =>
        selected == null || a.winner == selected || a.loser == selected;
    bool lit(Spell s) =>
        selected == null ||
        s == selected ||
        selected.beats.contains(s) ||
        s.beats.contains(selected);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _ArrowPainter(
              geometry: g,
              arrows: layout.arrows,
              intro: intro,
              focus: focus,
              selected: selected,
            ),
          ),
        ),
        for (final (i, a) in layout.arrows.indexed)
          _centered(
            g.labelPoint(a),
            Opacity(
              opacity:
                  _arrowIntro(intro, i) * (involved(a) ? 1 : 1 - .8 * focus),
              child: _VerbPill(
                text: a.winner.verbAgainst(a.loser),
                color: _arrowColor(a, selected),
              ),
            ),
          ),
        for (final spell in Spell.values)
          _centered(
            g.orbCenter(spell),
            AnimatedOpacity(
              opacity: lit(spell) ? 1 : .35,
              duration: AppTransitions.fast,
              child: _SpellNode(
                spell: spell,
                size: g.orbSize(spell),
                labelAbove: g.labelAbove(spell),
                showGesture: widget.showGestures,
                uses: spell == Spell.schild ? widget.config.shieldUses : null,
                selected: spell == selected,
                onTap: () => _tap(spell),
              ),
            ),
            // The orb sits on the point; its label hangs above or below.
            anchorOrb: g.orbSize(spell),
            labelAbove: g.labelAbove(spell),
            height: g.height,
          ),
      ],
    );
  }

  /// Puts [child] centred on [p]. For a spell node, puts its orb on [p]
  /// instead, with the label hanging below or above it.
  Widget _centered(
    Offset p,
    Widget child, {
    double? anchorOrb,
    bool labelAbove = false,
    double height = 0,
  }) {
    const box = 120.0;
    if (anchorOrb == null) {
      return Positioned(
        left: p.dx - box / 2,
        top: p.dy - 20,
        width: box,
        height: 40,
        child: Center(child: child),
      );
    }
    return Positioned(
      left: p.dx - box / 2,
      width: box,
      top: labelAbove ? null : p.dy - anchorOrb / 2,
      bottom: labelAbove ? height - (p.dy + anchorOrb / 2) : null,
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// Rules → layout
// ---------------------------------------------------------------------------

/// One "winner beats loser" relation.
class _Arrow {
  const _Arrow(this.winner, this.loser, {required this.onCircle});

  final Spell winner;
  final Spell loser;

  /// Between two attack spells (drawn along the circle); otherwise a
  /// straight spoke to or from the shield in the middle.
  final bool onCircle;
}

class _Layout {
  const _Layout(this.ring, this.center, this.arrows);

  /// The attack spells in the order they beat each other, starting at the
  /// top and going clockwise.
  final List<Spell> ring;
  final Spell center;
  final List<_Arrow> arrows;

  factory _Layout.fromRules() {
    const center = Spell.schild;
    // Follow the cycle: each attack spell beats the next one.
    final ring = <Spell>[Spell.ijs];
    while (ring.length < 3) {
      final next = ring.last.beats.firstWhere(
        (s) => s != center && !ring.contains(s),
        orElse: () => ring.first,
      );
      if (ring.contains(next)) break;
      ring.add(next);
    }
    final arrows = <_Arrow>[
      for (final w in Spell.values)
        for (final l in w.beats)
          _Arrow(w, l, onCircle: w != center && l != center),
    ];
    return _Layout(ring, center, arrows);
  }
}

class _Geometry {
  _Geometry(this.layout, this.width, this.gestures) {
    ringRadius = width * .36;
    outerOrb = width * .165;
    centerOrb = width * .17;
    final labelH = gestures ? 34.0 : 20.0;
    // Room for the top label above the top orb.
    center = Offset(width / 2, labelH + 4 + outerOrb / 2 + ringRadius);
    final bottomOrbY = center.dy + ringRadius * sin(pi / 6);
    height = max(
      bottomOrbY + outerOrb / 2 + 6 + labelH,
      center.dy + ringRadius + 16,
    );
  }

  final _Layout layout;
  final double width;
  final bool gestures;
  late final double ringRadius;
  late final double outerOrb;
  late final double centerOrb;
  late final Offset center;
  late final double height;

  /// Angle of a ring spell: the first at the top, then clockwise.
  double angleOf(Spell s) =>
      -pi / 2 + layout.ring.indexOf(s) * 2 * pi / layout.ring.length;

  bool isCenter(Spell s) => s == layout.center;

  Offset orbCenter(Spell s) => isCenter(s)
      ? center
      : center + Offset(cos(angleOf(s)), sin(angleOf(s))) * ringRadius;

  double orbSize(Spell s) => isCenter(s) ? centerOrb : outerOrb;

  /// The top spell has its label above, so it doesn't sit on a spoke.
  bool labelAbove(Spell s) => !isCenter(s) && sin(angleOf(s)) < -.5;

  /// Angle (on the ring) taken up by an orb plus a little gap.
  double get orbGapAngle => 2 * asin((outerOrb / 2 + 8) / (2 * ringRadius)) * 2;

  /// Start and sweep of an arrow along the ring, going clockwise.
  (double start, double sweep) arc(_Arrow a) {
    final from = angleOf(a.winner);
    var to = angleOf(a.loser);
    while (to <= from) {
      to += 2 * pi;
    }
    final gap = orbGapAngle / 2;
    return (from + gap, to - from - 2 * gap);
  }

  /// Start and end of a straight spoke, outside both orbs.
  (Offset from, Offset to) spoke(_Arrow a) {
    final p = orbCenter(a.winner), q = orbCenter(a.loser);
    final dir = (q - p) / (q - p).distance;
    return (
      p + dir * (orbSize(a.winner) / 2 + 7),
      q - dir * (orbSize(a.loser) / 2 + 9),
    );
  }

  /// Where the verb label of an arrow goes: the middle of its line.
  Offset labelPoint(_Arrow a) {
    if (a.onCircle) {
      final (start, sweep) = arc(a);
      final mid = start + sweep / 2;
      return center + Offset(cos(mid), sin(mid)) * ringRadius;
    }
    // Beside the spoke, not on it, so the line stays visible. Take the
    // upper side: the shield's own name hangs below the middle.
    final (from, to) = spoke(a);
    final dir = (to - from) / (to - from).distance;
    var side = Offset(-dir.dy, dir.dx);
    if (side.dy > .01 || (side.dy.abs() <= .01 && side.dx < 0)) side = -side;
    return Offset.lerp(from, to, .5)! + side * 30;
  }
}

// ---------------------------------------------------------------------------
// Painting
// ---------------------------------------------------------------------------

double _arrowIntro(double intro, int i) =>
    Curves.easeOutCubic.transform(((intro - .08 * i) / .45).clamp(0.0, 1.0));

/// Winner's colour; red for a loss of the selected spell.
Color _arrowColor(_Arrow a, Spell? selected) =>
    selected != null && a.loser == selected
    ? AppColors.redSoft
    : a.winner.color;

class _ArrowPainter extends CustomPainter {
  _ArrowPainter({
    required this.geometry,
    required this.arrows,
    required this.intro,
    required this.focus,
    required this.selected,
  });

  final _Geometry geometry;
  final List<_Arrow> arrows;
  final double intro;
  final double focus;
  final Spell? selected;

  @override
  void paint(Canvas canvas, Size size) {
    final g = geometry;
    // Faint guide ring behind everything.
    canvas.drawCircle(
      g.center,
      g.ringRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..color = Colors.white.withValues(alpha: .03),
    );

    for (final (i, a) in arrows.indexed) {
      final p = _arrowIntro(intro, i);
      if (p <= 0) continue;
      final s = selected;
      final involved = s == null || a.winner == s || a.loser == s;
      final alpha = involved ? 1.0 : 1 - .82 * focus;
      final emphasis = involved && s != null ? focus : 0.0;
      final color = _arrowColor(a, s).withValues(alpha: alpha);

      final path = a.onCircle ? _arcPath(a, p) : _spokePath(a, p);
      final width = 3.6 + 1.4 * emphasis;
      canvas
        ..drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = width + 6
            ..strokeCap = StrokeCap.round
            ..color = color.withValues(alpha: alpha * (.18 + .2 * emphasis))
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        )
        ..drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = width
            ..strokeCap = StrokeCap.round
            ..color = color,
        );
      if (p >= .999) _head(canvas, a, color, width);
    }
  }

  Path _arcPath(_Arrow a, double p) {
    final g = geometry;
    final (start, sweep) = g.arc(a);
    return Path()..addArc(
      Rect.fromCircle(center: g.center, radius: g.ringRadius),
      start,
      sweep * p,
    );
  }

  Path _spokePath(_Arrow a, double p) {
    final (from, to) = geometry.spoke(a);
    final end = Offset.lerp(from, to, p)!;
    return Path()
      ..moveTo(from.dx, from.dy)
      ..lineTo(end.dx, end.dy);
  }

  void _head(Canvas canvas, _Arrow a, Color color, double width) {
    final g = geometry;
    Offset tip;
    double dir;
    if (a.onCircle) {
      final (start, sweep) = g.arc(a);
      final end = start + sweep;
      tip = g.center + Offset(cos(end), sin(end)) * g.ringRadius;
      dir = end + pi / 2; // tangent, clockwise
    } else {
      final (from, to) = g.spoke(a);
      tip = to;
      dir = (to - from).direction;
    }
    final len = 9 + width;
    final spread = .5;
    final head = Path()
      ..moveTo(tip.dx + cos(dir) * 3, tip.dy + sin(dir) * 3)
      ..lineTo(
        tip.dx - cos(dir - spread) * len,
        tip.dy - sin(dir - spread) * len,
      )
      ..lineTo(
        tip.dx - cos(dir + spread) * len,
        tip.dy - sin(dir + spread) * len,
      )
      ..close();
    canvas.drawPath(
      head,
      Paint()
        ..color = color
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      head,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_ArrowPainter old) =>
      old.intro != intro ||
      old.focus != focus ||
      old.selected != selected ||
      old.geometry.width != geometry.width;
}

// ---------------------------------------------------------------------------
// Pieces
// ---------------------------------------------------------------------------

class _VerbPill extends StatelessWidget {
  const _VerbPill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
    decoration: BoxDecoration(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: .7), width: 1.4),
    ),
    child: Text(
      text,
      style: AppTextStyles.body(10.5, weight: FontWeight.w900, color: color),
    ),
  );
}

class _SpellNode extends StatelessWidget {
  const _SpellNode({
    required this.spell,
    required this.size,
    required this.labelAbove,
    required this.showGesture,
    required this.selected,
    required this.onTap,
    this.uses,
  });

  final Spell spell;
  final double size;
  final bool labelAbove;
  final bool showGesture;
  final bool selected;
  final VoidCallback onTap;

  /// "1×" badge for a spell with limited uses.
  final int? uses;

  @override
  Widget build(BuildContext context) {
    final label = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          spell.label,
          style: AppTextStyles.body(13, weight: FontWeight.w900),
        ),
        if (showGesture)
          Text(
            spell.gesture,
            style: AppTextStyles.body(
              10.5,
              weight: FontWeight.w800,
              color: AppColors.textMuted,
            ),
          ),
      ],
    );
    final orb = AnimatedScale(
      scale: selected ? 1.12 : 1,
      duration: AppTransitions.fast,
      curve: Curves.easeOutBack,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          SpellOrb(spell: spell, size: size, glow: selected),
          if (uses != null)
            Positioned(
              right: -6,
              top: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.shieldPip,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.background, width: 2),
                ),
                child: Text(
                  '$uses×',
                  style: AppTextStyles.body(10, weight: FontWeight.w900),
                ),
              ),
            ),
        ],
      ),
    );
    return Semantics(
      button: true,
      label: spell.label,
      selected: selected,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: labelAbove
              ? [label, const SizedBox(height: 4), orb]
              : [orb, const SizedBox(height: 4), label],
        ),
      ),
    );
  }
}

/// Under the diagram: a hint, or what the tapped spell does.
class _Caption extends StatelessWidget {
  const _Caption({super.key, required this.spell, required this.config});

  final Spell? spell;
  final GameConfig config;

  @override
  Widget build(BuildContext context) {
    final s = spell;
    final base = AppTextStyles.body(
      13,
      weight: FontWeight.w800,
      color: AppColors.textSoft,
    );
    if (s == null) {
      return Text(
        'Tik op een spreuk om te zien waar hij van wint.',
        textAlign: TextAlign.center,
        style: AppTextStyles.caption(),
      );
    }
    final beats = s.beats.toList();
    final losesTo = Spell.values.where((o) => o.beats.contains(s)).toList();
    TextSpan names(List<Spell> list, Color color) => TextSpan(
      children: [
        for (final (i, o) in list.indexed) ...[
          if (i > 0) TextSpan(text: i == list.length - 1 ? ' en ' : ', '),
          TextSpan(
            text: o.label,
            style: TextStyle(color: color, fontWeight: FontWeight.w900),
          ),
        ],
      ],
    );
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          TextSpan(
            text: s.label,
            style: TextStyle(color: s.color, fontWeight: FontWeight.w900),
          ),
          const TextSpan(text: ' wint van '),
          names(beats, AppColors.green),
          if (losesTo.isNotEmpty) ...[
            const TextSpan(text: ' · verliest van '),
            names(losesTo, AppColors.redSoft),
          ],
          if (s == Spell.schild)
            TextSpan(text: ' · ${config.shieldUses}× per duel'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
