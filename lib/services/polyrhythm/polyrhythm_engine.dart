import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import '../../models/polyrhythm/polygon_beat_event.dart';
import '../../models/polyrhythm/polygon_model.dart';

typedef PolygonBeatListener = void Function(PolygonBeatEvent event);

/// Polyrhythm Lab's single master timeline. Every voice's beat trigger and
/// every marker's on-screen motion derives from this one clock — never
/// from independent per-voice timers — which is what keeps voices
/// mathematically locked together instead of drifting apart.
///
/// Driven by a [Ticker] (frame-rate, ~60-120Hz) rather than the
/// `Stopwatch + Timer.periodic` scheduler `RhythmPlaybackService` uses:
/// this clock also has to drive smooth per-frame *marker motion*, not
/// just fire discrete audio events, so it needs the frame-accurate
/// elapsed [Duration] a [Ticker] provides for free.
/// [ChangeNotifier.notifyListeners] fires once per tick and is passed
/// straight to `CustomPaint(repaint: engine)`, so the canvas repaints
/// every frame without any `setState` — the widget tree itself never
/// rebuilds during playback.
class PolyrhythmEngine extends ChangeNotifier {
  PolyrhythmEngine({
    required TickerProvider vsync,
    required double bpm,
    required List<PolygonModel> polygons,
  }) : _bpm = bpm,
       _polygons = polygons {
    _ticker = vsync.createTicker(_onTick);
  }

  late final Ticker _ticker;

  double _bpm;
  List<PolygonModel> _polygons;
  bool _isPlaying = false;
  Duration _elapsed = Duration.zero;

  /// Last vertex index fired per polygon id this run — absent until that
  /// polygon has fired its first vertex.
  final Map<String, int> _lastVertexIndex = {};

  final List<PolygonBeatListener> _beatListeners = [];

  bool get isPlaying => _isPlaying;
  Duration get elapsed => _elapsed;
  double get bpm => _bpm;
  List<PolygonModel> get polygons => _polygons;

  /// Quarter-note beats spanned by one full shared rotation: as many as the
  /// densest active voice has vertices. This anchors BPM to the 1/4 note —
  /// the densest polygon fires exactly once per beat and every other voice
  /// spreads its vertices over the same span — so adding voices with more
  /// sides stretches the cycle instead of speeding the hits up.
  int get beatsPerCycle {
    int maxSubdivisions = 1;
    for (final polygon in _polygons) {
      if (polygon.subdivisions > maxSubdivisions) {
        maxSubdivisions = polygon.subdivisions;
      }
    }
    return maxSubdivisions;
  }

  /// "Tempo" — how long one full shared rotation (one cycle) takes. Every
  /// polygon completes exactly one revolution per cycle; a polygon's own
  /// rhythmic subdivision only changes how many vertices land within that
  /// same span, which is the entire mechanism that makes "3 vs 4" etc.
  /// visually/audibly correct.
  double get cycleDurationMs => (60000.0 / _bpm) * beatsPerCycle;

  /// 0..1 progress through the current cycle — a pure function of elapsed
  /// time, so there is zero drift by construction (no incremental
  /// integration to accumulate error).
  double get cyclePos {
    final double cycleMs = cycleDurationMs;
    if (cycleMs <= 0) return 0.0;
    final double elapsedMs = _elapsed.inMicroseconds / 1000.0;
    return (elapsedMs % cycleMs) / cycleMs;
  }

  void addBeatListener(PolygonBeatListener listener) =>
      _beatListeners.add(listener);

  void removeBeatListener(PolygonBeatListener listener) =>
      _beatListeners.remove(listener);

  void setBpm(double bpm) {
    _bpm = bpm.clamp(20.0, 300.0);
    notifyListeners();
  }

  /// Swaps the active voice list (e.g. a new rhythm combination). Clears
  /// stale per-polygon fire state for ids no longer present, and leaves
  /// polygons that persisted (same id) untouched.
  void setPolygons(List<PolygonModel> polygons) {
    _polygons = polygons;
    _lastVertexIndex.removeWhere((id, _) => !polygons.any((p) => p.id == id));
    notifyListeners();
  }

  void play() {
    if (_isPlaying) return;
    _isPlaying = true;
    _elapsed = Duration.zero;
    _lastVertexIndex.clear();
    _ticker.start();
    notifyListeners();
  }

  void stop() {
    if (!_isPlaying) return;
    _isPlaying = false;
    _ticker.stop();
    _elapsed = Duration.zero;
    _lastVertexIndex.clear();
    notifyListeners();
  }

  void _onTick(Duration elapsed) {
    _elapsed = elapsed;
    final double pos = cyclePos;

    final List<String> firedIds = [];
    for (final polygon in _polygons) {
      final int n = polygon.subdivisions;
      if (n <= 0) continue;
      final int currentIndex = (pos * n).floor() % n;
      if (_lastVertexIndex[polygon.id] != currentIndex) {
        _lastVertexIndex[polygon.id] = currentIndex;
        firedIds.add(polygon.id);
      }
    }

    if (firedIds.isNotEmpty && _beatListeners.isNotEmpty) {
      final bool isSyncPulse = firedIds.length >= 2;
      for (final id in firedIds) {
        final event = PolygonBeatEvent(
          polygonId: id,
          vertexIndex: _lastVertexIndex[id]!,
          isSyncPulse: isSyncPulse,
          timestamp: elapsed,
        );
        for (final listener in List<PolygonBeatListener>.of(_beatListeners)) {
          listener(event);
        }
      }
    }

    // Fires every frame while playing — the sole repaint trigger for the
    // canvas (see class doc). Deliberately unconditional: the rotation
    // angle changes every tick even when no vertex fires.
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _beatListeners.clear();
    super.dispose();
  }
}
