import 'package:flutter/material.dart';
import '../../../../../models/polyrhythm/polygon_beat_event.dart';
import '../../../../../models/polyrhythm/polygon_model.dart';
import '../../../../../services/polyrhythm/polyrhythm_controller.dart';
import '../../../../../theme/app_theme.dart';
import 'polyrhythm_geometry.dart';

/// Layered on top of the structural shapes: the momentary "light up" when
/// the moving marker lands on a vertex, a larger synchronized burst at
/// the shared center when two-or-more voices land together, and Practice
/// Mode's correct/wrong/perfect-streak feedback.
///
/// Every flash fades purely from `elapsed - event.timestamp` against
/// [pulseFadeDuration] — no `AnimationController` of its own, so it stays
/// perfectly attached to the same master clock as the marker's motion.
class PulseRenderer {
  const PulseRenderer();

  void paint(
    Canvas canvas,
    Size size, {
    required List<PolygonModel> polygons,
    required List<PolygonBeatEvent> recentBeatEvents,
    required Duration elapsed,
    required TapFeedback? tapFeedback,
  }) {
    if (recentBeatEvents.isEmpty && tapFeedback == null) return;

    final layouts = PolyrhythmGeometry.layoutAll(
      size: size,
      polygons: polygons,
    );
    final Offset mainCenter = Offset(size.width / 2, size.height / 2);

    for (final event in recentBeatEvents) {
      final int index = polygons.indexWhere((p) => p.id == event.polygonId);
      if (index == -1) continue;

      final double fade = _fadeFor(elapsed, event.timestamp);
      if (fade <= 0) continue;

      final polygon = polygons[index];
      final layout = layouts[index];
      final pos = PolyrhythmGeometry.vertexOffset(
        layout.center,
        layout.radius,
        event.vertexIndex,
        polygon.subdivisions,
        rotation: PolyrhythmGeometry.rotationOffset,
      );

      // Colored on purpose, never white — white is reserved for the one
      // continuously moving marker (PolygonRenderer._drawMarker), so a
      // beat flash can never read as a stray extra moving dot.
      canvas.drawCircle(
        pos,
        8 + 16 * (1 - fade),
        Paint()
          ..color = polygon.color.withValues(alpha: 0.55 * fade)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 11),
      );
      canvas.drawCircle(
        pos,
        5,
        Paint()..color = polygon.color.withValues(alpha: 0.9 * fade),
      );

      if (event.isSyncPulse) {
        canvas.drawCircle(
          mainCenter,
          layout.radius * (0.1 + 0.9 * (1 - fade)),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.28 * fade)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
      }
    }

    if (tapFeedback != null && polygons.isNotEmpty) {
      _paintTapFeedback(canvas, tapFeedback, polygons, layouts, elapsed);
    }
  }

  double _fadeFor(Duration elapsed, Duration eventTime) {
    final double age =
        (elapsed - eventTime).inMicroseconds / pulseFadeDuration.inMicroseconds;
    return (1.0 - age).clamp(0.0, 1.0);
  }

  void _paintTapFeedback(
    Canvas canvas,
    TapFeedback tapFeedback,
    List<PolygonModel> polygons,
    List<PolygonLayout> layouts,
    Duration elapsed,
  ) {
    final double fade = _fadeFor(elapsed, tapFeedback.timestamp);
    if (fade <= 0) return;

    final layout = layouts[0];
    final primary = polygons[0];

    if (tapFeedback.isPerfectStreak) {
      canvas.drawCircle(
        layout.center,
        layout.radius + 12,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.4 * fade)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
      );
      return;
    }

    if (tapFeedback.vertexIndex == null) return;
    final pos = PolyrhythmGeometry.vertexOffset(
      layout.center,
      layout.radius,
      tapFeedback.vertexIndex!,
      primary.subdivisions,
      rotation: PolyrhythmGeometry.rotationOffset,
    );
    final Color color = tapFeedback.isCorrect
        ? AppColors.success
        : AppColors.error;
    canvas.drawCircle(
      pos,
      6 + 12 * (1 - fade),
      Paint()
        ..color = color.withValues(alpha: 0.75 * fade)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );
  }
}
