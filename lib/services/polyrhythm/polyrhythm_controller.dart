import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import '../../models/polyrhythm/polygon_beat_event.dart';
import '../../models/polyrhythm/polygon_model.dart';
import '../../models/polyrhythm/subdivision_model.dart';
import '../../models/polyrhythm/visualization_mode.dart';
import 'polyrhythm_audio_scheduler.dart';
import 'polyrhythm_engine.dart';

/// How long a beat's vertex-glow/sync-pulse stays visible before
/// [PulseRenderer] fades it out. Kept here (not per-renderer) since both
/// [recentBeatEvents] pruning and the renderer's fade math need to agree
/// on the same window.
const Duration pulseFadeDuration = Duration(milliseconds: 260);

/// Consecutive correct taps required for Practice Mode's "perfect streak"
/// full-polygon flash.
const int perfectStreakThreshold = 8;

/// Transient feedback for the most recent Practice Mode tap, consumed by
/// [PulseRenderer] and faded out the same elapsed-time way beat pulses are
/// — no separate `AnimationController`, everything rides the master clock.
@immutable
class TapFeedback {
  final bool isCorrect;
  final int? vertexIndex;
  final bool isPerfectStreak;
  final Duration timestamp;

  const TapFeedback({
    required this.isCorrect,
    required this.vertexIndex,
    required this.isPerfectStreak,
    required this.timestamp,
  });
}

/// Polyrhythm Lab's page-level state: everything a user can configure
/// (rhythm selection, tempo, visualization mode, toggles) plus the derived
/// Practice Mode score. Owns the [PolyrhythmEngine] (timing/rotation) and
/// [AudioScheduler] (sound) and wires them together, but is careful to
/// only call its own [notifyListeners] on genuine setting changes — never
/// per-frame. The canvas repaints straight off the engine (and this
/// controller, for instant toggle feedback) via
/// `Listenable.merge([engine, controller])`; the control panel listens to
/// this controller alone, so it never rebuilds at animation frame rate.
class PolyrhythmController extends ChangeNotifier {
  PolyrhythmController({required TickerProvider vsync})
    : engine = PolyrhythmEngine(
        vsync: vsync,
        bpm: 40,
        polygons: _buildPolygons(const [3, 4]),
      ) {
    activePolygons = engine.polygons;
    engine.addBeatListener(_onBeat);
  }

  final PolyrhythmEngine engine;
  final AudioScheduler audioScheduler = AudioScheduler();

  late List<PolygonModel> activePolygons;
  VisualizationMode mode = VisualizationMode.nested;
  double masterVolume = 0.85;

  bool enableGlow = true;
  bool enableTrails = true;
  bool enablePulse = true;
  bool graphiteBackground = false; // "Dark Background" variant toggle
  bool learningMode = false;
  bool practiceMode = false;
  bool controlsHidden = false;

  /// Recent [PolygonBeatEvent]s within [pulseFadeDuration] — read live by
  /// `PulseRenderer.paint()` each frame, pruned as new events arrive.
  final List<PolygonBeatEvent> recentBeatEvents = [];

  TapFeedback? lastTapFeedback;
  int practiceStreak = 0;
  int practiceHits = 0;
  int practiceMisses = 0;

  /// Ids of voices Learning Mode has silenced — tapping a voice's number
  /// chip toggles membership here. Muting only gates [_onBeat]'s audio
  /// trigger; the marker/flash keep animating normally, so a muted voice
  /// stays visible while the user isolates the others by ear.
  final Set<String> mutedPolygonIds = {};

  void toggleMute(String polygonId) {
    if (!mutedPolygonIds.remove(polygonId)) {
      mutedPolygonIds.add(polygonId);
    }
    notifyListeners();
  }

  double get bpm => engine.bpm;

  bool get isPlaying => engine.isPlaying;

  static List<PolygonModel> _buildPolygons(List<int> subdivisions) {
    final counts = <int, int>{};
    return subdivisions.map((n) {
      final slot = counts.update(n, (v) => v + 1, ifAbsent: () => 0);
      return SubdivisionModel.buildPolygon(n, id: '${n}_$slot');
    }).toList();
  }

  void togglePlayback() {
    if (engine.isPlaying) {
      engine.stop();
    } else {
      engine.play();
    }
    notifyListeners();
  }

  void setBpm(double value) {
    engine.setBpm(value);
    notifyListeners();
  }

  void setMasterVolume(double value) {
    masterVolume = value.clamp(0.0, 1.0);
    audioScheduler.setMasterVolume(masterVolume);
    notifyListeners();
  }

  void setMode(VisualizationMode value) {
    mode = value;
    notifyListeners();
  }

  /// Rebuilds the active voice list from raw subdivision counts (2-3
  /// entries) — e.g. a preset chip tap (`[3, 4]`) or a rhythm-picker
  /// stepper change. Always a full list replacement, never an in-place
  /// mutation of hardcoded primary/secondary/tertiary fields.
  void setSubdivisions(List<int> subdivisions) {
    activePolygons = _buildPolygons(subdivisions);
    engine.setPolygons(activePolygons);
    recentBeatEvents.clear();
    mutedPolygonIds.clear();
    resetPracticeStats();
    notifyListeners();
  }

  void setToggle({
    bool? glow,
    bool? trails,
    bool? pulse,
    bool? graphiteBg,
    bool? learning,
    bool? practice,
    bool? controlsHiddenValue,
  }) {
    if (glow != null) enableGlow = glow;
    if (trails != null) enableTrails = trails;
    if (pulse != null) enablePulse = pulse;
    if (graphiteBg != null) graphiteBackground = graphiteBg;
    if (learning != null) learningMode = learning;
    if (practice != null) {
      practiceMode = practice;
      if (practice) resetPracticeStats();
    }
    if (controlsHiddenValue != null) controlsHidden = controlsHiddenValue;
    notifyListeners();
  }

  void resetPracticeStats() {
    practiceStreak = 0;
    practiceHits = 0;
    practiceMisses = 0;
    lastTapFeedback = null;
  }

  /// Scores a Practice Mode tap against the *primary* rhythm (the first
  /// active polygon) by finding the analytically-nearest vertex-crossing
  /// time to the current cycle position — no event history needed, the
  /// vertex grid is regular so its nearest point is a closed-form
  /// computation.
  void registerTap() {
    if (!practiceMode || !engine.isPlaying || activePolygons.isEmpty) return;

    final primary = activePolygons.first;
    final int n = primary.subdivisions;
    final double cycleMs = engine.cycleDurationMs;
    final double posMs = (engine.elapsed.inMicroseconds / 1000.0) % cycleMs;
    final double vertexSpacingMs = cycleMs / n;

    final int nearestVertex = (posMs / vertexSpacingMs).round() % n;
    final double nearestVertexMs = nearestVertex * vertexSpacingMs;
    double deltaMs = (posMs - nearestVertexMs).abs();
    deltaMs = math.min(deltaMs, cycleMs - deltaMs); // wraparound distance

    const double hitWindowMs = 140;
    final bool isHit = deltaMs <= hitWindowMs;

    if (isHit) {
      practiceStreak++;
      practiceHits++;
    } else {
      practiceStreak = 0;
      practiceMisses++;
    }

    lastTapFeedback = TapFeedback(
      isCorrect: isHit,
      vertexIndex: nearestVertex,
      isPerfectStreak: isHit && practiceStreak >= perfectStreakThreshold,
      timestamp: engine.elapsed,
    );
    notifyListeners();
  }

  /// Fires at beat-rate (bounded by tempo × subdivisions), which stays well
  /// under animation frame rate — deliberately does *not* call
  /// [notifyListeners]: the engine is already ticking (and repainting)
  /// every frame whenever this can fire, so the mutation below is picked
  /// up by the very next paint pass for free.
  void _onBeat(PolygonBeatEvent event) {
    if (!mutedPolygonIds.contains(event.polygonId)) {
      for (final polygon in activePolygons) {
        if (polygon.id == event.polygonId) {
          audioScheduler.trigger(polygon.soundId);
          break;
        }
      }
    }

    recentBeatEvents.add(event);
    recentBeatEvents.removeWhere(
      (e) => (event.timestamp - e.timestamp) > pulseFadeDuration,
    );
  }

  @override
  void dispose() {
    engine.removeBeatListener(_onBeat);
    engine.dispose();
    audioScheduler.dispose();
    super.dispose();
  }
}
