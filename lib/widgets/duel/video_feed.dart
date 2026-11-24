import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_transitions.dart';

/// A rounded video panel with overlays. Shows a hand placeholder when
/// there is no stream (no camera, video sharing off, or in tests).
class VideoFeed extends StatefulWidget {
  const VideoFeed({
    super.key,
    required this.stream,
    this.mirror = false,
    this.blurred = false,
    this.borderColor = AppColors.tealBorder,
    this.glowColor,
    this.placeholder,
    this.overlays = const [],
  });

  final MediaStream? stream;
  final bool mirror;

  /// Blur the opponent while spells are being chosen, so nobody can react
  /// to the other's hand.
  final bool blurred;
  final Color borderColor;
  final Color? glowColor;

  /// Shown instead of the video when [stream] is null.
  final Widget? placeholder;
  final List<Widget> overlays;

  @override
  State<VideoFeed> createState() => _VideoFeedState();
}

class _VideoFeedState extends State<VideoFeed> {
  RTCVideoRenderer? _renderer;
  Future<void>? _init;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _attach(widget.stream);
  }

  @override
  void didUpdateWidget(VideoFeed oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stream != widget.stream) _attach(widget.stream);
  }

  Future<void> _attach(MediaStream? stream) async {
    if (stream == null) {
      _renderer?.srcObject = null;
      if (mounted) setState(() => _ready = false);
      return;
    }
    final renderer = _renderer ??= RTCVideoRenderer();
    await (_init ??= renderer.initialize());
    if (!mounted || widget.stream != stream) return;
    renderer.srcObject = stream;
    if (mounted) setState(() => _ready = true);
  }

  @override
  void dispose() {
    final r = _renderer;
    if (r != null) {
      r.srcObject = null;
      r.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showVideo = widget.stream != null && _ready && _renderer != null;
    Widget content = showVideo
        ? RTCVideoView(
            _renderer!,
            mirror: widget.mirror,
            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
          )
        : (widget.placeholder ?? const _HandPlaceholder());

    // Hide at once (a gesture must never show), reveal smoothly.
    final hideNow = widget.blurred ? Duration.zero : AppTransitions.medium;
    content = TweenAnimationBuilder<double>(
      tween: Tween(end: widget.blurred ? _hiddenBlur : 0),
      duration: hideNow,
      builder: (context, sigma, child) => sigma < 0.5
          ? child!
          : ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
              child: child,
            ),
      child: content,
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: widget.borderColor, width: 2),
        boxShadow: widget.glowColor == null
            ? null
            : [
                BoxShadow(
                  color: widget.glowColor!.withValues(alpha: 0.14),
                  spreadRadius: 4,
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-0.4, -0.5),
                  radius: 1.2,
                  colors: [
                    Color(0xFF2E2556),
                    Color(0xFF17122F),
                    Color(0xFF0F0B22),
                  ],
                  stops: [0, 0.55, 1],
                ),
              ),
            ),
            content,
            // Dark veil on top of the blur, so nothing shows through even
            // where a device blurs the video weakly.
            IgnorePointer(
              child: AnimatedOpacity(
                opacity: widget.blurred ? 1 : 0,
                duration: hideNow,
                child: const _HiddenVeil(),
              ),
            ),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 90,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0xD9080614)],
                    ),
                  ),
                ),
              ),
            ),
            ...widget.overlays,
          ],
        ),
      ),
    );
  }
}

const _hiddenBlur = 40.0;

class _HiddenVeil extends StatelessWidget {
  const _HiddenVeil();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xDB0E0B1F),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surfaceRaised,
                border: Border.all(color: AppColors.borderStrong),
              ),
              child: const Icon(
                Icons.lock_rounded,
                color: AppColors.lavender,
                size: 20,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'VERBORGEN TOT DE ONTHULLING',
              style: AppTextStyles.body(
                11,
                weight: FontWeight.w900,
                color: AppColors.textFeed,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HandPlaceholder extends StatelessWidget {
  const _HandPlaceholder();

  @override
  Widget build(BuildContext context) => const Center(
    child: Icon(Icons.back_hand_outlined, size: 72, color: Color(0xFF3B3270)),
  );
}
