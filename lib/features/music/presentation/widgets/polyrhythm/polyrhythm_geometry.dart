import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../../models/polyrhythm/polygon_model.dart';

/// Center + radius a polygon/circle is drawn at.
@immutable
class PolygonLayout {
  final Offset center;
  final double radius;

  const PolygonLayout(this.center, this.radius);
}

/// Shared geometry for every Polyrhythm Lab renderer.
///
/// The shapes themselves are perfectly static — they never rotate or
/// move. The only thing that moves is a single marker per voice,
/// traveling around that voice's perimeter and reaching vertex k exactly
/// when `PolyrhythmEngine` fires vertex k's beat (i.e. at `cyclePos ==
/// k/n`). This mirrors `staff_geometry.dart`'s role for
/// `MusicStaffPainter`: every renderer calls [layoutAll]/[allVertices]/
/// [markerPosition] so a beat's flash always lands exactly where the
/// marker visually is.
class PolyrhythmGeometry {
  PolyrhythmGeometry._();

  static Offset pointOnCircle(Offset center, double radius, double angle) {
    return Offset(
      center.dx + radius * math.sin(angle),
      center.dy - radius * math.cos(angle),
    );
  }

  /// Fixed angle (radians, 0 = top/12-o'clock, increasing clockwise) of
  /// vertex [k] of an [n]-vertex shape. Never depends on time. [rotation]
  /// is a constant (non-animated) offset in radians — the one knob that
  /// turns the whole static shape, e.g. `math.pi / n` to land an edge
  /// (instead of a vertex) at 12 o'clock. Defaults to 0 (vertex 0 at top).
  static double vertexAngle(int k, int n, {double rotation = 0}) =>
      rotation + 2 * math.pi * k / n;

  static Offset vertexOffset(
    Offset center,
    double radius,
    int k,
    int n, {
    double rotation = 0,
  }) {
    return pointOnCircle(center, radius, vertexAngle(k, n, rotation: rotation));
  }

  static List<Offset> allVertices(
    Offset center,
    double radius,
    int n, {
    double rotation = 0,
  }) {
    return [
      for (int k = 0; k < n; k++)
        vertexOffset(center, radius, k, n, rotation: rotation),
    ];
  }

  /// Current position of the single moving marker for a voice with [n]
  /// beats, at cycle progress [cyclePos] (0..1).
  ///
  /// [isCircle] picks the motion, not just the shape: `true` sweeps at
  /// constant angular speed around the circumference (an arc); `false`
  /// interpolates in a straight line from vertex to vertex, so the dot
  /// visibly travels *along the sides* of the polygon rather than curving
  /// through its interior.
  static Offset markerPosition({
    required Offset center,
    required double radius,
    required int n,
    required double cyclePos,
    required bool isCircle,
    double rotation = 0,
  }) {
    final double progress = cyclePos * n;
    if (isCircle) {
      return pointOnCircle(
        center,
        radius,
        rotation + 2 * math.pi * progress / n,
      );
    }
    final int segment = progress.floor() % n;
    final double t = progress - progress.floor();
    final Offset p0 = vertexOffset(
      center,
      radius,
      segment,
      n,
      rotation: rotation,
    );
    final Offset p1 = vertexOffset(
      center,
      radius,
      (segment + 1) % n,
      n,
      rotation: rotation,
    );
    return Offset.lerp(p0, p1, t)!;
  }

  // ── Tunable layout knobs ──────────────────────────────────────────────
  // The three things that control where/how big the whole concentric
  // arrangement is drawn. Change these to "recenter" or resize the
  // composition — everything else derives from them.

  /// Extra offset (in logical pixels, added to the canvas's geometric
  /// center) applied to every polygon's center. Positive `dy` moves the
  /// whole arrangement *down*. Use this to compensate for asymmetric
  /// chrome (e.g. a taller bottom control panel than top bar pushing the
  /// visual "free" center above the canvas's literal center).
  static const Offset centerOffset = Offset(0, 0);

  /// Fraction of the canvas's shorter side used for the *outermost*
  /// polygon's radius. 1.0 would touch the edges exactly; kept well under
  /// that so nothing clips and glow blur has room to breathe.
  static const double outerRadiusFactor = 0.86;

  /// Constant rotation (radians) applied to every shape and marker. 0
  /// keeps vertex 0 at 12 o'clock for every voice; e.g. `math.pi / 8` (or
  /// any value) turns the whole static composition without affecting
  /// timing — it's purely a drawing-angle offset, applied identically in
  /// [layoutAll]'s callers via the `rotation` parameter on
  /// [vertexOffset]/[allVertices]/[markerPosition].
  static const double rotationOffset = 0;

  /// Lays out every polygon in [polygons] (same order, same length):
  /// shared center, radius ranked by ascending subdivision count so
  /// fewer-sided voices sit smaller/innermost — used identically by both
  /// visualization modes. The actual center/size come from [centerOffset]
  /// and [outerRadiusFactor] above.
  static List<PolygonLayout> layoutAll({
    required Size size,
    required List<PolygonModel> polygons,
  }) {
    final int count = polygons.length;
    if (count == 0) return const [];

    final Offset mainCenter =
        Offset(size.width / 2, size.height / 2) + centerOffset;
    final double baseRadius =
        math.min(size.width, size.height) / 2 * outerRadiusFactor;

    final List<int> rankOrder = List.generate(count, (i) => i)
      ..sort(
        (a, b) => polygons[a].subdivisions.compareTo(polygons[b].subdivisions),
      );
    final List<PolygonLayout?> result = List.filled(count, null);
    for (int rank = 0; rank < count; rank++) {
      final int originalIndex = rankOrder[rank];
      final double radius = baseRadius * (0.42 + 0.58 * (rank + 1) / count);
      result[originalIndex] = PolygonLayout(mainCenter, radius);
    }
    return result.cast<PolygonLayout>();
  }
}
