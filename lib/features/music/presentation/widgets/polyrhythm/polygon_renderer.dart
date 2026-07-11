import 'package:flutter/material.dart';
import '../../../../../models/polyrhythm/polygon_model.dart';
import '../../../../../models/polyrhythm/visualization_mode.dart';
import 'polyrhythm_geometry.dart';

/// Draws each voice's static shape (a polygon or a circle, per
/// [VisualizationMode]) and the single moving white marker that travels
/// around it — the marker is the *only* thing that moves; the shapes
/// themselves are always stationary. Beat-triggered flashes are layered
/// separately by `PulseRenderer`.
///
/// Stateful by necessity: the marker's short fading trail is a small
/// per-voice position history, so this object must be constructed once
/// and reused across frames rather than rebuilt per `paint()` call — see
/// `PolyrhythmPainter`, which keeps a single instance alive for the
/// page's lifetime.
class PolygonRenderer {
  static const int _maxTrailLength = 14;

  final Map<String, List<Offset>> _trails = {};

  void paint(
    Canvas canvas,
    Size size, {
    required List<PolygonModel> polygons,
    required double cyclePos,
    required VisualizationMode mode,
    required bool glowEnabled,
    required bool trailsEnabled,
  }) {
    final layouts = PolyrhythmGeometry.layoutAll(
      size: size,
      polygons: polygons,
    );
    final bool isCircle = mode == VisualizationMode.circular;
    final Set<String> liveIds = {};
    final int trailCap = trailsEnabled ? _maxTrailLength : 1;

    for (int i = 0; i < polygons.length; i++) {
      final polygon = polygons[i];
      final layout = layouts[i];
      final int n = polygon.subdivisions;
      liveIds.add(polygon.id);

      final vertices = PolyrhythmGeometry.allVertices(
        layout.center,
        layout.radius,
        n,
        rotation: PolyrhythmGeometry.rotationOffset,
      );

      if (isCircle) {
        _drawRing(
          canvas,
          layout.center,
          layout.radius,
          polygon.color,
          glowEnabled,
        );
      } else {
        _drawEdges(canvas, vertices, polygon.color, glowEnabled);
      }
      _drawVertexDots(canvas, vertices, polygon.color, glowEnabled);

      final Offset markerPos = PolyrhythmGeometry.markerPosition(
        center: layout.center,
        radius: layout.radius,
        n: n,
        cyclePos: cyclePos,
        isCircle: isCircle,
        rotation: PolyrhythmGeometry.rotationOffset,
      );

      final trail = _trails.putIfAbsent(polygon.id, () => []);
      trail.add(markerPos);
      while (trail.length > trailCap) {
        trail.removeAt(0);
      }

      _drawTrail(canvas, trail, polygon.color);
      _drawMarker(canvas, markerPos, glowEnabled);
    }

    // Drop trail buffers for voices that no longer exist (subdivisions
    // just changed) so they don't linger as stale ghosts.
    _trails.removeWhere((id, _) => !liveIds.contains(id));
  }

  void _drawEdges(
    Canvas canvas,
    List<Offset> vertices,
    Color color,
    bool glow,
  ) {
    final path = Path()..addPolygon(vertices, true);

    if (glow) {
      canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: 0.28)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..strokeJoin = StrokeJoin.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _drawRing(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
    bool glow,
  ) {
    if (glow) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = color.withValues(alpha: 0.22)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
      );
    }
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3,
    );
  }

  void _drawVertexDots(
    Canvas canvas,
    List<Offset> vertices,
    Color color,
    bool glow,
  ) {
    for (final vertex in vertices) {
      if (glow) {
        canvas.drawCircle(
          vertex,
          7,
          Paint()
            ..color = color.withValues(alpha: 0.20)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
      }
      canvas.drawCircle(
        vertex,
        3.2,
        Paint()..color = color.withValues(alpha: 0.55),
      );
    }
  }

  void _drawTrail(Canvas canvas, List<Offset> trail, Color color) {
    if (trail.length < 2) return;
    // Skip the head — `_drawMarker` draws it on top, brighter.
    for (int i = 0; i < trail.length - 1; i++) {
      final double t = (i + 1) / trail.length; // 0..1, newer points larger t
      canvas.drawCircle(
        trail[i],
        1.2 + 2.6 * t,
        Paint()
          ..color = Color.lerp(
            color,
            Colors.white,
            0.5,
          )!.withValues(alpha: 0.05 + 0.35 * t),
      );
    }
  }

  void _drawMarker(Canvas canvas, Offset position, bool glow) {
    if (glow) {
      canvas.drawCircle(
        position,
        13,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
      );
    }
    canvas.drawCircle(
      position,
      6,
      Paint()..color = Colors.white.withValues(alpha: 0.95),
    );
    canvas.drawCircle(position, 2.4, Paint()..color = Colors.white);
  }
}
