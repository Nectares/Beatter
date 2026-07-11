import 'package:flutter/foundation.dart';

/// Fired by [PolyrhythmEngine] every time a polygon's vertex crosses the
/// 12-o'clock play position. This is the one seam the audio scheduler, the
/// pulse renderer, and (per the spec's future-proofing goals) any future
/// haptics/MIDI-out listener all subscribe to independently — none of them
/// talk to the engine's clock math directly.
@immutable
class PolygonBeatEvent {
  /// Matches [PolygonModel.id].
  final String polygonId;

  /// Which vertex (0-based) just reached the play position.
  final int vertexIndex;

  /// True when two or more polygons crossed a vertex in the same engine
  /// tick — the "larger synchronized pulse" moment the spec calls out.
  final bool isSyncPulse;

  /// Engine-clock timestamp the event fired at (elapsed time since the
  /// engine started running), used by Practice Mode to score taps against.
  final Duration timestamp;

  const PolygonBeatEvent({
    required this.polygonId,
    required this.vertexIndex,
    required this.isSyncPulse,
    required this.timestamp,
  });
}
