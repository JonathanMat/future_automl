import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../models/face_shape.dart';
import '../../models/game_rules.dart';
import '../../models/game_state.dart';
import '../../models/spell_info.dart';
import '../../services/face/face_finder.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/face_constants.dart';
import '../generic/avatar_tile.dart';
import 'effects/face_fx.dart';
import 'effects/face_layer.dart';
import 'effects/fx_builder.dart';
import 'effects/fx_core.dart';
import 'effects/fx_plan.dart';
import 'effects/spell_effects_layer.dart';
import 'video_feed.dart';

/// Photos of both cameras at the moment a round was revealed: the
/// killcam replays the final spell over them.
class KillcamFrames {
  const KillcamFrames({
    required this.round,
    this.top,
    this.bottom,
    this.topFace,
    this.bottomFace,
  });

  final int round;

  /// The opponent's camera (PNG), or null (no video, capture failed).
  final Uint8List? top;

  /// Your camera (PNG, not mirrored yet).
  final Uint8List? bottom;

  /// The faces in the photos, once found (see [withFaces]).
  final FaceShape? topFace;
  final FaceShape? bottomFace;

  KillcamFrames _with({
    Uint8List? top,
    Uint8List? bottom,
    FaceShape? topFace,
    FaceShape? bottomFace,
  }) => KillcamFrames(
    round: round,
    top: top ?? this.top,
    bottom: bottom ?? this.bottom,
    topFace: topFace ?? this.topFace,
    bottomFace: bottomFace ?? this.bottomFace,
  );

  /// The photos for the killcam, as they get better: first the photos at
  /// the reveal, then with the faces in them, then — for a side where no
  /// face was found (a hand in front of it while casting, the face half
  /// out of view) — a newer photo as soon as one shows a face. Keeps
  /// trying for [within]; the face effects only start at the hit.
  static Stream<KillcamFrames> track({
    required int round,
    MediaStream? opponent,
    MediaStream? mine,
    required FaceFinder finder,
    Duration within = const Duration(milliseconds: 2200),
    Duration every = const Duration(milliseconds: 150),
  }) async* {
    final clock = Stopwatch()..start();
    var frames = await capture(round: round, opponent: opponent, mine: mine);
    yield frames;
    if (finder is NoFaceFinder) return;
    frames = await frames.withFaces(finder);
    yield frames;

    var tries = 0;
    bool needTop() => frames.topFace == null && _hasVideo(opponent);
    bool needBottom() => frames.bottomFace == null && _hasVideo(mine);
    while ((needTop() || needBottom()) && clock.elapsed < within) {
      await Future<void>.delayed(every);
      tries++;
      final wantTop = needTop(), wantBottom = needBottom();
      final again = await capture(
        round: round,
        opponent: wantTop ? opponent : null,
        mine: wantBottom ? mine : null,
      );
      var next = frames;
      final t = again.top, b = again.bottom;
      if (wantTop && t != null) {
        final face = await finder.find(t);
        if (face != null) next = next._with(top: t, topFace: face);
      }
      if (wantBottom && b != null) {
        final face = await finder.find(b);
        if (face != null) next = next._with(bottom: b, bottomFace: face);
      }
      if (!identical(next, frames)) {
        frames = next;
        yield frames;
      }
    }
    debugPrint(
      'killcam: faces top=${frames.topFace != null} '
      'bottom=${frames.bottomFace != null} after ${tries + 1} photo(s), '
      '${clock.elapsedMilliseconds} ms',
    );
  }

  static bool _hasVideo(MediaStream? stream) =>
      stream?.getVideoTracks().isNotEmpty ?? false;

  /// These photos with the faces in them, looked up with [finder]. Never
  /// throws: a face that isn't found stays null.
  Future<KillcamFrames> withFaces(FaceFinder finder) async {
    final t = top, b = bottom;
    final topFace = t == null ? null : await finder.find(t);
    final bottomFace = b == null ? null : await finder.find(b);
    return KillcamFrames(
      round: round,
      top: top,
      bottom: bottom,
      topFace: topFace,
      bottomFace: bottomFace,
    );
  }

  /// One photo of each stream, one after the other (the native capture
  /// writes both to the same temporary file). Never throws: a failed
  /// capture just leaves that side empty (an avatar in the killcam).
  static Future<KillcamFrames> capture({
    required int round,
    MediaStream? opponent,
    MediaStream? mine,
  }) async {
    Future<Uint8List?> grab(MediaStream? stream) async {
      final tracks = stream?.getVideoTracks() ?? const <MediaStreamTrack>[];
      if (tracks.isEmpty) return null;
      try {
        final buffer = await tracks.first.captureFrame().timeout(
          const Duration(seconds: 2),
        );
        final bytes = buffer.asUint8List();
        return bytes.isEmpty ? null : bytes;
      } catch (e) {
        debugPrint('killcam capture: $e');
        return null;
      }
    }

    final top = await grab(opponent);
    final bottom = await grab(mine);
    return KillcamFrames(round: round, top: top, bottom: bottom);
  }
}

/// The final cast in slow motion, like a game's killcam: the two cameras
/// grow to fill the screen, black bars slide in, "KILLCAM" blinks, the
/// picture freezes (the photos taken at the reveal) and the winning spell
/// plays once at 0.4× speed, ending on a big "K.O.!".
///
/// It replaces the normal-speed effect of the last round, so the spell is
/// seen only once.
class KillcamOverlay extends StatefulWidget {
  const KillcamOverlay({
    super.key,
    required this.result,
    required this.frames,
    this.opponentStream,
    this.myStream,
    required this.myName,
    required this.opponentName,
    required this.onDone,
  });

  /// The final round, from this phone's point of view.
  final RoundResult result;
  final KillcamFrames? frames;

  /// Live video until the photos are in (then the picture freezes).
  final MediaStream? opponentStream;
  final MediaStream? myStream;
  final String myName;
  final String opponentName;
  final VoidCallback onDone;

  /// How fast the replay runs.
  static const speed = 0.4;

  /// Bars and title before the spell starts.
  static const lead = Duration(milliseconds: 650);

  /// "K.O.!" after the spell, before it closes.
  static const tail = Duration(milliseconds: 1500);

  /// Whether this round has an effect worth replaying.
  static bool hasReplay(RoundResult result) =>
      planFor(result).kind != FxKind.none &&
      result.outcome != RoundOutcome.draw;

  /// How long the whole killcam takes for [result].
  static Duration lengthFor(RoundResult result) {
    final fx = buildSpellFx(planFor(result))?.fx;
    final seconds = min(fx?.duration ?? 2.0, 3.2) / speed;
    return lead + Duration(milliseconds: (seconds * 1000).round()) + tail;
  }

  @override
  State<KillcamOverlay> createState() => _KillcamOverlayState();
}

class _KillcamOverlayState extends State<KillcamOverlay>
    with TickerProviderStateMixin {
  final _topKey = GlobalKey();
  final _bottomKey = GlobalKey();
  late final Duration _length = KillcamOverlay.lengthFor(widget.result);

  /// 0→1 over the whole killcam (zoom, bars, K.O.).
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: _length,
  );
  late final AnimationController _blink = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  bool _playing = false;
  bool _done = false;
  Timer? _start;

  @override
  void initState() {
    super.initState();
    _clock.forward().whenComplete(_finish);
    _start = Timer(KillcamOverlay.lead, () {
      if (mounted) setState(() => _playing = true);
    });
    HapticFeedback.mediumImpact();
  }

  @override
  void dispose() {
    _start?.cancel();
    _clock.dispose();
    _blink.dispose();
    super.dispose();
  }

  void _finish() {
    if (_done || !mounted) return;
    _done = true;
    widget.onDone();
  }

  double get _koAt =>
      1 - KillcamOverlay.tail.inMilliseconds / _length.inMilliseconds;

  /// The part of the timeline the cameras take to grow.
  double get _leadPart =>
      KillcamOverlay.lead.inMilliseconds / _length.inMilliseconds;

  @override
  Widget build(BuildContext context) {
    final won = widget.result.outcome == RoundOutcome.win;
    final spell = won ? widget.result.mySpell : widget.result.opponentSpell;

    return Material(
      type: MaterialType.transparency,
      child: AnimatedBuilder(
        animation: Listenable.merge([_clock, _blink]),
        builder: (context, _) {
          final t = _clock.value;
          final lead = (t / _leadPart).clamp(0.0, 1.0);
          final intro = Curves.easeOutCubic.transform(lead);
          // The cameras grow out of the duel screen.
          final grow = 0.8 + 0.2 * Curves.easeOutBack.transform(lead);
          final ko = Curves.elasticOut.transform(
            ((t - _koAt) / (1 - _koAt) * 1.6).clamp(0, 1),
          );
          // Then a slow push-in while the spell plays.
          final zoom = grow + 0.06 * Curves.easeInOut.transform(t);

          return Stack(
            fit: StackFit.expand,
            children: [
              Opacity(
                opacity: intro,
                child: const ColoredBox(color: Colors.black),
              ),
              Opacity(
                opacity: (lead * 2).clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: zoom,
                  child: SafeArea(child: _stage(spell)),
                ),
              ),
              // Vignette: darker edges, eyes to the middle.
              const IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      radius: 0.95,
                      colors: [Colors.transparent, Color(0xB0000000)],
                      stops: [0.6, 1],
                    ),
                  ),
                ),
              ),
              _bars(intro),
              Positioned(top: 0, left: 0, right: 0, child: _header(intro)),
              if (ko > 0) _ko(ko, won),
            ],
          );
        },
      ),
    );
  }

  /// The two photos where the cameras were, with the spell over them.
  /// The effect's own timeline (seconds since the slow-motion spell
  /// started), for the face effects.
  double get _fxTime {
    final elapsed = _clock.value * _length.inMicroseconds / 1e6;
    final sinceStart = elapsed - KillcamOverlay.lead.inMicroseconds / 1e6;
    return max(0, sinceStart) * KillcamOverlay.speed;
  }

  late final FaceFxPlan _facePlan = () {
    final plan = planFor(widget.result);
    return FaceFxPlan.forRound(plan, buildSpellFx(plan)?.fx);
  }();

  /// The two cameras, as in the duel but bigger. [top] and [bottom] fill
  /// them; the face effects use the same layout to land on the photos.
  static Widget _layout({required Widget top, required Widget bottom}) =>
      Padding(
        // Bigger than in the duel: the cameras fill the screen.
        padding: const EdgeInsets.fromLTRB(10, 62, 10, 50),
        child: Column(
          children: [
            Expanded(flex: 206, child: top),
            const SizedBox(height: 12),
            Expanded(flex: 240, child: bottom),
          ],
        ),
      );

  /// The two photos where the cameras were, with the spell over them and
  /// the face effects on top.
  Widget _stage(Spell? spell) {
    final frames = widget.frames;
    final faces =
        frames != null &&
            (frames.topFace != null || frames.bottomFace != null) &&
            _facePlan.kind != FaceFxKind.none ||
        FaceConstants.debug;
    Widget face(
      FaceShape? shape,
      Uint8List? photo,
      FxSide side, {
      required bool mirror,
    }) => shape == null
        ? const SizedBox.expand()
        : FaceFxLayer(
            shape: shape,
            photo: photo,
            mirror: mirror,
            plan: _facePlan,
            side: side,
            time: _playing ? _fxTime : 0,
          );

    return SpellEffectsLayer(
      result: _playing ? widget.result : null,
      topKey: _topKey,
      bottomKey: _bottomKey,
      timeScale: KillcamOverlay.speed,
      foreground: faces
          ? _layout(
              top: face(
                frames?.topFace,
                frames?.top,
                FxSide.top,
                mirror: false,
              ),
              bottom: face(
                frames?.bottomFace,
                frames?.bottom,
                FxSide.bottom,
                mirror: true,
              ),
            )
          : null,
      child: _layout(
        top: FxTintTarget(
          side: FxSide.top,
          child: _Photo(
            key: _topKey,
            bytes: frames?.top,
            turns: frames?.topFace?.turns ?? 0,
            stream: widget.opponentStream,
            name: widget.opponentName,
            mirror: false,
          ),
        ),
        bottom: FxTintTarget(
          side: FxSide.bottom,
          child: _Photo(
            key: _bottomKey,
            bytes: frames?.bottom,
            turns: frames?.bottomFace?.turns ?? 0,
            stream: widget.myStream,
            name: widget.myName,
            // Like your own preview during the duel.
            mirror: true,
            border: spell?.color,
          ),
        ),
      ),
    );
  }

  Widget _bars(double intro) {
    const h = 58.0;
    return IgnorePointer(
      child: Column(
        children: [
          Transform.translate(
            offset: Offset(0, -h * (1 - intro)),
            child: Container(height: h, color: Colors.black),
          ),
          const Spacer(),
          Transform.translate(
            offset: Offset(0, h * (1 - intro)),
            child: Container(height: h, color: Colors.black),
          ),
        ],
      ),
    );
  }

  Widget _header(double intro) {
    final on = _blink.value < 0.6;
    return SafeArea(
      child: Opacity(
        opacity: intro,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 8, 0),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: on ? AppColors.red : AppColors.redDeep,
                  boxShadow: [
                    if (on)
                      BoxShadow(
                        color: AppColors.red.withValues(alpha: 0.7),
                        blurRadius: 10,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Shrinks on narrow screens instead of overflowing.
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      Text(
                        'KILLCAM',
                        style: AppTextStyles.display(
                          24,
                        ).copyWith(letterSpacing: 3),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${KillcamOverlay.speed}×'.replaceAll('.', ','),
                          style: AppTextStyles.body(
                            13,
                            weight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              TextButton(
                onPressed: _finish,
                child: Text(
                  'Overslaan ›',
                  style: AppTextStyles.body(15, color: AppColors.textSoft),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ko(double ko, bool won) {
    final winner = won ? 'JIJ WINT!' : '${widget.opponentName} wint';
    return IgnorePointer(
      child: Center(
        child: Transform.rotate(
          angle: -0.12,
          child: Transform.scale(
            scale: 0.4 + 0.6 * ko,
            child: Opacity(
              opacity: ko.clamp(0.0, 1.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'K.O.!',
                    style:
                        AppTextStyles.display(
                          96,
                          color: AppColors.goldNumber,
                        ).copyWith(
                          shadows: const [
                            Shadow(
                              color: AppColors.goldNumberDeep,
                              offset: Offset(0, 6),
                            ),
                            Shadow(color: Colors.black, blurRadius: 30),
                          ],
                        ),
                  ),
                  Text(
                    winner.toUpperCase(),
                    style: AppTextStyles.display(26).copyWith(
                      shadows: const [
                        Shadow(color: Colors.black, blurRadius: 16),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A camera photo in the shape of a video feed, or an avatar without one.
class _Photo extends StatelessWidget {
  const _Photo({
    super.key,
    required this.bytes,
    required this.name,
    required this.mirror,
    this.turns = 0,
    this.stream,
    this.border,
  });

  final Uint8List? bytes;

  /// Clockwise quarter turns that make the photo upright.
  final int turns;

  /// Live video while there is no photo yet.
  final MediaStream? stream;
  final String name;
  final bool mirror;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    final b = bytes;
    final avatar = ColoredBox(
      color: AppColors.feedDeep,
      child: Center(child: AvatarTile(name: name, size: 86)),
    );
    Widget picture = b == null
        ? (stream == null
              ? avatar
              : VideoFeed(
                  stream: stream,
                  mirror: mirror,
                  borderColor: Colors.transparent,
                  placeholder: avatar,
                ))
        : photoPicture(b, turns: turns, mirror: mirror, fallback: avatar);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(FxContext.feedRadius),
        border: Border.all(
          color: (border ?? AppColors.borderStrong).withValues(alpha: 0.8),
          width: 2,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Live video, then the frozen photo fades in: time stops.
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            // Fill the camera (the default centres a loose child, which
            // would show the photo "contained" instead of covering).
            layoutBuilder: (current, previous) =>
                Stack(fit: StackFit.expand, children: [...previous, ?current]),
            child: KeyedSubtree(
              key: ValueKey(b == null ? 'live' : 'photo'),
              child: picture,
            ),
          ),
          Positioned(
            left: 14,
            bottom: 12,
            child: Text(
              name,
              style: AppTextStyles.display(20).copyWith(
                shadows: const [Shadow(color: Colors.black, blurRadius: 10)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
