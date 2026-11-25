import 'dart:math';
import 'dart:ui';

/// A face found in a photo: MediaPipe's 478 face landmarks, normalised to
/// the photo (0–1), plus how far the photo must turn to be upright.
///
/// [layout] turns it into screen positions for a photo shown with
/// `BoxFit.cover` (optionally mirrored), which is what the face effects
/// draw with.
class FaceShape {
  const FaceShape({
    required this.points,
    required this.imageWidth,
    required this.imageHeight,
    this.turns = 0,
  });

  /// Landmarks in the photo as captured, normalised. At least 468; 478
  /// when the irises are included.
  final List<Offset> points;
  final int imageWidth;
  final int imageHeight;

  /// Clockwise quarter turns that make the photo upright (some phones
  /// capture the camera sideways). The killcam shows the photo turned.
  final int turns;

  // Landmark indices of Google's face mesh.
  static const ovalIndices = [
    10, 338, 297, 332, 284, 251, 389, 356, 454, 323, 361, 288, 397, 365, //
    379, 378, 400, 377, 152, 148, 176, 149, 150, 136, 172, 58, 132, 93, //
    234, 127, 162, 21, 54, 103, 67, 109,
  ];
  static const lipsIndices = [
    61, 146, 91, 181, 84, 17, 314, 405, 321, 375, 291, 409, 270, 269, 267, //
    0, 37, 39, 40, 185,
  ];

  /// The eye on the left of a (non-mirrored) photo: the person's right eye.
  static const eyeAIndices = [
    33, 7, 163, 144, 145, 153, 154, 155, 133, 173, 157, 158, 159, 160, //
    161, 246,
  ];
  static const eyeBIndices = [
    263, 249, 390, 373, 374, 380, 381, 382, 362, 398, 384, 385, 386, 387, //
    388, 466,
  ];
  static const browAIndices = [70, 63, 105, 66, 107];
  static const browBIndices = [336, 296, 334, 293, 300];
  static const irisA = 468;
  static const irisB = 473;
  static const cheekA = 50;
  static const cheekB = 280;
  static const foreheadTop = 10;
  static const forehead = 151;
  static const noseTip = 1;
  static const chin = 152;

  static const minPoints = 468;

  bool get isComplete => points.length >= minPoints;

  /// Clockwise quarter turns that make the face in [points] (normalised to
  /// a [width] × [height] photo) point up, read from the face itself (chin
  /// to forehead). A head tilted less than 60° counts as upright, so a
  /// tilted head never turns the photo.
  static int uprightTurns(List<Offset> points, int width, int height) {
    if (points.length < minPoints) return 0;
    final top = points[foreheadTop], bottom = points[chin];
    var v = Offset((top.dx - bottom.dx) * width, (top.dy - bottom.dy) * height);
    if (v.distance == 0) return 0;
    for (var k = 0; k < 4; k++) {
      // Angle between v and straight up.
      final angle = atan2(v.dx, -v.dy).abs();
      if (angle <= (k == 0 ? pi / 3 : pi / 4)) return k;
      v = Offset(-v.dy, v.dx); // one more clockwise quarter turn
    }
    return 0;
  }

  /// Size of the photo once turned upright.
  Size get uprightSize => turns.isOdd
      ? Size(imageHeight.toDouble(), imageWidth.toDouble())
      : Size(imageWidth.toDouble(), imageHeight.toDouble());

  /// A normalised point of the captured photo in the upright photo.
  static Offset turn(Offset p, int turns) => switch (turns % 4) {
    1 => Offset(1 - p.dy, p.dx),
    2 => Offset(1 - p.dx, 1 - p.dy),
    3 => Offset(p.dy, 1 - p.dx),
    _ => p,
  };

  /// Screen positions of this face for the photo drawn upright with
  /// `BoxFit.cover` in a box of [box], mirrored left-right if [mirror].
  FaceGeometry layout(Size box, {bool mirror = false}) {
    final upright = uprightSize;
    final scale = max(box.width / upright.width, box.height / upright.height);
    final dx = (box.width - upright.width * scale) / 2;
    final dy = (box.height - upright.height * scale) / 2;
    Offset map(Offset p) {
      var u = turn(p, turns);
      if (mirror) u = Offset(1 - u.dx, u.dy);
      return Offset(
        u.dx * upright.width * scale + dx,
        u.dy * upright.height * scale + dy,
      );
    }

    return FaceGeometry._([for (final p in points) map(p)]);
  }
}

/// A face in screen positions (see [FaceShape.layout]).
class FaceGeometry {
  FaceGeometry._(this.points);

  final List<Offset> points;

  Offset operator [](int i) => points[i];

  List<Offset> _pick(List<int> indices) => [for (final i in indices) points[i]];

  List<Offset> get oval => _pick(FaceShape.ovalIndices);
  List<Offset> get lips => _pick(FaceShape.lipsIndices);
  List<Offset> get browA => _pick(FaceShape.browAIndices);
  List<Offset> get browB => _pick(FaceShape.browBIndices);

  Path get ovalPath => _closed(oval);
  Path get lipsPath => _closed(lips);

  static Path _closed(List<Offset> pts) {
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  Rect get bounds {
    final o = oval;
    var r = Rect.fromPoints(o.first, o.first);
    for (final p in o) {
      r = r.expandToInclude(Rect.fromPoints(p, p));
    }
    return r;
  }

  /// Width of the face (cheek to cheek), the scale for every effect.
  double get width => bounds.width;
  double get height => bounds.height;
  Offset get center => bounds.center;

  /// The two eyes: centre (the iris when there is one) and radius.
  ({Offset center, double radius}) get eyeA =>
      _eye(FaceShape.eyeAIndices, FaceShape.irisA);
  ({Offset center, double radius}) get eyeB =>
      _eye(FaceShape.eyeBIndices, FaceShape.irisB);

  ({Offset center, double radius}) _eye(List<int> contour, int iris) {
    final pts = _pick(contour);
    var sum = Offset.zero;
    for (final p in pts) {
      sum += p;
    }
    final mid = sum / pts.length.toDouble();
    final center = points.length > iris ? points[iris] : mid;
    var w = 0.0;
    for (final p in pts) {
      w = max(w, (p - mid).distance);
    }
    return (center: center, radius: max(w * 0.55, 2));
  }

  Offset get cheekA => points[FaceShape.cheekA];
  Offset get cheekB => points[FaceShape.cheekB];
  Offset get foreheadTop => points[FaceShape.foreheadTop];
  Offset get forehead => points[FaceShape.forehead];
  Offset get noseTip => points[FaceShape.noseTip];
  Offset get chin => points[FaceShape.chin];

  /// Which way is "up" on this face (from chin to forehead), normalised.
  Offset get up {
    final v = foreheadTop - chin;
    final d = v.distance;
    return d == 0 ? const Offset(0, -1) : v / d;
  }
}
