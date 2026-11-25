import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../models/game_rules.dart';
import '../../models/game_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../models/badge.dart';
import '../../widgets/badges/badge_unlock_overlay.dart';
import '../../widgets/duel/duel_intro.dart';
import '../../widgets/duel/effects/spell_effects_layer.dart';
import '../../widgets/duel/feed_overlays.dart';
import '../../widgets/duel/video_feed.dart';
import '../../widgets/generic/avatar_tile.dart';
import '../../widgets/generic/screen_header.dart';
import '../../widgets/duel/effects/fx_plan.dart';

/// Plays every spell effect on demand, with an optional slow motion, to
/// look at or tune them without playing a duel.
class FxPreviewScreen extends StatefulWidget {
  const FxPreviewScreen({super.key});

  @override
  State<FxPreviewScreen> createState() => _FxPreviewScreenState();
}

class _FxPreviewScreenState extends State<FxPreviewScreen> {
  final _topKey = GlobalKey();
  final _bottomKey = GlobalKey();
  RoundResult? _result;
  int _round = 0;
  bool _slow = false;

  /// Paused at this time, or null to play normally.
  double? _scrub;

  bool _intro = false;

  /// (label, your spell, opponent's spell)
  static const _cases = <(String, Spell?, Spell?)>[
    ('Vuur raakt', Spell.vuur, Spell.bliksem),
    ('Vuur op jou', Spell.bliksem, Spell.vuur),
    ('IJs bevriest', Spell.ijs, Spell.vuur),
    ('Jij bevroren', Spell.vuur, Spell.ijs),
    ('Bliksem slaat in', Spell.bliksem, Spell.ijs),
    ('Bliksem op jou', Spell.ijs, Spell.bliksem),
    ('Schild kaatst vuur', Spell.schild, Spell.vuur),
    ('Schild kaatst ijs', Spell.schild, Spell.ijs),
    ('Bliksem breekt schild', Spell.bliksem, Spell.schild),
    ('Schildslag', Spell.schild, null),
    ('Botsing vuur', Spell.vuur, Spell.vuur),
    ('Botsing ijs', Spell.ijs, Spell.ijs),
    ('Botsing bliksem', Spell.bliksem, Spell.bliksem),
    ('Schild vs schild', Spell.schild, Spell.schild),
  ];

  void _play(Spell? mine, Spell? theirs) {
    final r = resolveRound(hostSpell: mine, guestSpell: theirs);
    setState(() {
      _result = RoundResult(
        round: ++_round,
        mySpell: r.hostSpell,
        opponentSpell: r.guestSpell,
        outcome: r.winner == null
            ? RoundOutcome.draw
            : (r.winner == Side.host ? RoundOutcome.win : RoundOutcome.lose),
        reason: r.reason,
      );
    });
  }

  void _setSlow(bool slow) {
    setState(() => _slow = slow);
    timeDilation = slow ? 4 : 1;
  }

  @override
  void dispose() {
    timeDilation = 1;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _scaffold(context),
        if (_intro)
          Positioned.fill(
            child: DuelIntro(
              me: const IntroPlayer(
                name: 'Jonathan',
                tag: '4821',
                subtitle: 'LVL 7',
              ),
              opponent: const IntroPlayer(
                name: 'Maarten',
                tag: '1203',
                subtitle: '12 WINS',
              ),
              onDone: () => setState(() => _intro = false),
            ),
          ),
      ],
    );
  }

  Widget _scaffold(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SpellEffectsLayer(
          result: _result,
          topKey: _topKey,
          bottomKey: _bottomKey,
          scrubTime: _scrub,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                ScreenHeader(
                  title: 'Effecten',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Slow-mo', style: AppTextStyles.caption()),
                      Switch(
                        value: _slow,
                        onChanged: _setSlow,
                        activeTrackColor: AppColors.green,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: FxTintTarget(
                    side: FxSide.top,
                    child: VideoFeed(
                      key: _topKey,
                      stream: null,
                      placeholder: const Center(
                        child: AvatarTile(name: 'Maarten', size: 72),
                      ),
                      overlays: const [
                        Positioned(
                          top: 12,
                          left: 12,
                          child: FeedLabel('TEGENSTANDER'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 56),
                Expanded(
                  child: FxTintTarget(
                    side: FxSide.bottom,
                    child: VideoFeed(
                      key: _bottomKey,
                      stream: null,
                      borderColor: AppColors.gold,
                      overlays: const [
                        AimBrackets(),
                        Positioned(top: 12, left: 12, child: FeedLabel('JIJ')),
                      ],
                    ),
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      tooltip: _scrub == null ? 'Pauzeren' : 'Afspelen',
                      icon: Icon(
                        _scrub == null
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                      ),
                      onPressed: () =>
                          setState(() => _scrub = _scrub == null ? 0 : null),
                    ),
                    Expanded(
                      child: Slider(
                        value: _scrub ?? 0,
                        max: 3.1,
                        onChanged: (v) => setState(() => _scrub = v),
                      ),
                    ),
                    SizedBox(
                      width: 48,
                      child: Text(
                        _scrub == null ? '' : '${_scrub!.toStringAsFixed(2)}s',
                        style: AppTextStyles.caption(),
                      ),
                    ),
                  ],
                ),
                // Scrolls on small screens instead of squeezing the cameras.
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 150),
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      alignment: WrapAlignment.center,
                      children: [
                        for (final (label, mine, theirs) in _cases)
                          ActionChip(
                            label: Text(label),
                            labelStyle: AppTextStyles.body(
                              12,
                              weight: FontWeight.w900,
                            ),
                            backgroundColor: AppColors.surfaceRaised,
                            side: BorderSide.none,
                            onPressed: () => _play(mine, theirs),
                          ),
                        for (final (label, action) in [
                          ('▶ VS-intro', () => setState(() => _intro = true)),
                          (
                            '🏅 Badge pop-up',
                            () => showBadgeUnlocks(context, [
                              badgeById('eerste_winst')!,
                              badgeById('spiegelmeester')!,
                              badgeById('foutloos')!,
                              badgeById('aartsmagier')!,
                            ]),
                          ),
                        ])
                          ActionChip(
                            label: Text(label),
                            labelStyle: AppTextStyles.body(
                              12,
                              weight: FontWeight.w900,
                              color: AppColors.goldInk,
                            ),
                            backgroundColor: AppColors.gold,
                            side: BorderSide.none,
                            onPressed: action,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
