import 'package:flutter/material.dart';

/// One rhythmic voice in Polyrhythm Lab: a regular polygon with
/// [subdivisions] vertices, each vertex representing one beat of that
/// voice's cycle. [PolyrhythmController.activePolygons] holds these in a
/// plain `List<PolygonModel>` (2-3 entries) rather than hardcoded
/// primary/secondary/tertiary fields, so adding a fourth voice later is
/// just allowing a longer list — no model change.
///
/// Immutable by convention (final fields, no setters) — settings changes
/// replace the list entry rather than mutating it in place, matching the
/// rest of the app's model style (see `RhythmPattern.copyWith`).
@immutable
class PolygonModel {
  /// Stable identity across rebuilds/list-order changes — the engine keys
  /// its per-polygon "last fired vertex" state by this, not by list index.
  final String id;

  /// Vertex count, 2-8 (also the rhythmic subdivision: N evenly spaced
  /// beats per shared cycle).
  final int subdivisions;

  /// Neon outline/vertex/particle color for this voice.
  final Color color;

  /// Key into `AudioScheduler`'s instrument map — the single seam future
  /// custom sound packs would swap out.
  final String soundId;

  /// Geometric name shown in Learning Mode ("Triangle") instead of the
  /// raw number ("3").
  final String label;

  const PolygonModel({
    required this.id,
    required this.subdivisions,
    required this.color,
    required this.soundId,
    required this.label,
  });

  PolygonModel copyWith({
    String? id,
    int? subdivisions,
    Color? color,
    String? soundId,
    String? label,
  }) {
    return PolygonModel(
      id: id ?? this.id,
      subdivisions: subdivisions ?? this.subdivisions,
      color: color ?? this.color,
      soundId: soundId ?? this.soundId,
      label: label ?? this.label,
    );
  }
}
