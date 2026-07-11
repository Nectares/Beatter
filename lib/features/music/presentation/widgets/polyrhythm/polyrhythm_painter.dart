import 'package:flutter/material.dart';
import '../../../../../services/polyrhythm/polyrhythm_controller.dart';
import '../../../../../services/polyrhythm/polyrhythm_engine.dart';
import 'polygon_renderer.dart';
import 'pulse_renderer.dart';

/// Root `CustomPainter` for Polyrhythm Lab's canvas. Owns no drawing logic
/// itself — it just reads live state off [engine]/[controller] each frame
/// and dispatches to [polygonRenderer] (the static shapes + moving
/// marker), then layers the beat/pulse overlay on top.
///
/// `repaint: Listenable.merge([engine, controller])` is what makes this
/// work without `setState`: [engine] fires every animation frame while
/// playing (driving the marker's motion), and [controller] fires on
/// setting changes (e.g. toggling glow updates the canvas immediately
/// even while paused). Because the painter instance is never rebuilt
/// during normal playback, [polygonRenderer] can safely keep
/// frame-to-frame trail state.
class PolyrhythmPainter extends CustomPainter {
  final PolyrhythmEngine engine;
  final PolyrhythmController controller;
  final PolygonRenderer polygonRenderer;

  static const PulseRenderer _pulseRenderer = PulseRenderer();

  PolyrhythmPainter({
    required this.engine,
    required this.controller,
    required this.polygonRenderer,
  }) : super(repaint: Listenable.merge([engine, controller]));

  @override
  void paint(Canvas canvas, Size size) {
    final polygons = engine.polygons;
    final double cyclePos = engine.cyclePos;

    polygonRenderer.paint(
      canvas,
      size,
      polygons: polygons,
      cyclePos: cyclePos,
      mode: controller.mode,
      glowEnabled: controller.enableGlow,
      trailsEnabled: controller.enableTrails,
    );

    if (controller.enablePulse) {
      _pulseRenderer.paint(
        canvas,
        size,
        polygons: polygons,
        recentBeatEvents: controller.recentBeatEvents,
        elapsed: engine.elapsed,
        tapFeedback: controller.lastTapFeedback,
      );
    }
  }

  // The painter instance is only ever reconstructed on a genuine widget
  // rebuild (e.g. orientation change) — frame-to-frame updates happen via
  // `repaint`, not by Flutter diffing a new delegate. Always repainting on
  // those rare reconstructions is simplest and cheap.
  @override
  bool shouldRepaint(covariant PolyrhythmPainter oldDelegate) => true;
}
