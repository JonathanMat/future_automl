import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../models/face_shape.dart';
import '../../../utils/face_constants.dart';
import 'face_fx.dart';
import 'fx_core.dart';
import 'spell_effects_layer.dart';

/// A photo filling its box like the camera did: upright ([turns]),
/// `BoxFit.cover`, mirrored for your own camera. The face effects lay out
/// their landmarks the same way ([FaceShape.layout]).
Widget photoPicture(
  Uint8List bytes, {
  int turns = 0,
  bool mirror = false,
  Widget? fallback,
}) {
  Widget picture = Image.memory(
    bytes,
    fit: BoxFit.cover,
    gaplessPlayback: true,
    errorBuilder: (_, _, _) => fallback ?? const SizedBox.expand(),
  );
  if (turns % 4 != 0) {
    picture = RotatedBox(quarterTurns: turns, child: picture);
  }
  if (mirror) picture = Transform.flip(flipX: true, child: picture);
  return SizedBox.expand(child: picture);
}

/// The face effects on one photo, laid out exactly like the photo
/// (upright, `BoxFit.cover`, mirrored for your own camera).
///
/// On the player who got hit, the face itself shows through the spell
/// (frost, smoke, the flash) a moment after the hit, so you see *their*
/// face freeze, burn or get shocked.
class FaceFxLayer extends StatelessWidget {
  const FaceFxLayer({
    required this.shape,
    required this.photo,
    required this.mirror,
    required this.plan,
    required this.side,
    required this.time,
    this.strength = 1,
  });

  final FaceShape shape;
  final Uint8List? photo;
  final bool mirror;
  final FaceFxPlan plan;
  final FxSide side;
  final double time;

  /// 0–1: fades the whole layer (a hit-freeze ending).
  final double strength;

  /// How much of the face shows through the spell on the camera.
  double get _showThrough {
    if (side != plan.loser || plan.kind == FaceFxKind.dizzy) return 0;
    return span(time - plan.hitTime, .08, .45);
  }

  @override
  Widget build(BuildContext context) {
    // Inside the photo's 2 px border, like the picture itself.
    return Padding(
      padding: const EdgeInsets.all(2),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(FxContext.feedRadius - 2),
        child: LayoutBuilder(
          builder: (context, box) {
            final size = box.biggest;
            final face = shape.layout(size, mirror: mirror);
            final through = _showThrough * strength;
            final p = photo;
            return Stack(
              fit: StackFit.expand,
              children: [
                if (p != null && through > 0)
                  Opacity(
                    opacity: .94 * through,
                    child: FxTintTarget(
                      side: side,
                      child: ClipPath(
                        clipper: _PathClipper(face.ovalPath),
                        child: photoPicture(
                          p,
                          turns: shape.turns,
                          mirror: mirror,
                        ),
                      ),
                    ),
                  ),
                Opacity(
                  opacity: strength.clamp(0.0, 1.0),
                  child: CustomPaint(
                    size: size,
                    painter: FaceFxPainter(
                      face: face,
                      plan: plan,
                      side: side,
                      time: time,
                      debug: FaceConstants.debug,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PathClipper extends CustomClipper<Path> {
  _PathClipper(this.path);

  final Path path;

  @override
  Path getClip(Size size) => path;

  @override
  bool shouldReclip(_PathClipper old) => true;
}
