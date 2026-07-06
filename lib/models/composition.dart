import 'rhythm_element.dart';
import '../widgets/music_staff/staff_geometry.dart' as geometry;

/// A note duration a user can place in Composer Mode. Kept as its own enum
/// (rather than reusing [RhythmElementType] directly) so the toolbar has an
/// unambiguous "what's selected" identity independent of rendering details
/// like rests/triplets, which Composer Mode doesn't expose yet.
enum NoteDuration {
  whole,
  half,
  quarter,
  eighth,
  sixteenth;

  /// Duration in quarter-note beats (matches [RhythmElement.duration]).
  double get beats {
    switch (this) {
      case NoteDuration.whole:
        return 4.0;
      case NoteDuration.half:
        return 2.0;
      case NoteDuration.quarter:
        return 1.0;
      case NoteDuration.eighth:
        return 0.5;
      case NoteDuration.sixteenth:
        return 0.25;
    }
  }

  String get label {
    switch (this) {
      case NoteDuration.whole:
        return 'Intera';
      case NoteDuration.half:
        return 'Metà';
      case NoteDuration.quarter:
        return 'Quarto';
      case NoteDuration.eighth:
        return 'Ottavo';
      case NoteDuration.sixteenth:
        return 'Sedicesimo';
    }
  }

  RhythmElementType toRhythmElementType() {
    switch (this) {
      case NoteDuration.whole:
        return RhythmElementType.whole;
      case NoteDuration.half:
        return RhythmElementType.half;
      case NoteDuration.quarter:
        return RhythmElementType.quarter;
      case NoteDuration.eighth:
        return RhythmElementType.eighth;
      case NoteDuration.sixteenth:
        return RhythmElementType.sixteenth;
    }
  }

  /// Rests/triplets never appear in a Composer Mode sequence today, so any
  /// such element maps to [quarter] as a safe fallback rather than throwing.
  static NoteDuration fromRhythmElementType(RhythmElementType type) {
    switch (type) {
      case RhythmElementType.whole:
        return NoteDuration.whole;
      case RhythmElementType.half:
        return NoteDuration.half;
      case RhythmElementType.quarter:
        return NoteDuration.quarter;
      case RhythmElementType.eighth:
        return NoteDuration.eighth;
      case RhythmElementType.sixteenth:
        return NoteDuration.sixteenth;
      case RhythmElementType.quarterRest:
      case RhythmElementType.eighthRest:
      case RhythmElementType.sixteenthRest:
      case RhythmElementType.triplet:
        return NoteDuration.quarter;
    }
  }
}

/// A single placed note in a [Composition]. [measureIndex]/[beatPosition]
/// are a derived cache for save/display convenience — never authoritative;
/// they're recomputed by [reflowMeasures] on every load and before every
/// save, so they can never drift from the note sequence's actual order.
class ComposedNote {
  final String pitch;
  final NoteDuration duration;
  final int measureIndex;
  final double beatPosition;

  const ComposedNote({
    required this.pitch,
    required this.duration,
    required this.measureIndex,
    required this.beatPosition,
  });

  Map<String, dynamic> toJson() => {
        'pitch': pitch,
        'duration': duration.name,
        'measureIndex': measureIndex,
        'beatPosition': beatPosition,
      };

  factory ComposedNote.fromJson(Map<String, dynamic> json) => ComposedNote(
        pitch: json['pitch'] as String,
        duration: NoteDuration.values.byName(json['duration'] as String),
        measureIndex: json['measureIndex'] as int,
        beatPosition: (json['beatPosition'] as num).toDouble(),
      );
}

/// A saved composition — the persisted shape. Live editing works with the
/// existing [RhythmElement]/[RhythmMeasure] rendering/playback types instead
/// (see [toRhythmMeasures] and [Composition.fromElements]); this model only
/// exists at the load/save boundary.
class Composition {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime modifiedAt;
  final int bpm;
  final String timeSignature;
  final List<ComposedNote> notes;

  const Composition({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.modifiedAt,
    required this.bpm,
    required this.timeSignature,
    required this.notes,
  });

  Composition copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
    DateTime? modifiedAt,
    int? bpm,
    String? timeSignature,
    List<ComposedNote>? notes,
  }) {
    return Composition(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      bpm: bpm ?? this.bpm,
      timeSignature: timeSignature ?? this.timeSignature,
      notes: notes ?? this.notes,
    );
  }

  /// Total playable duration at this composition's BPM, for library cards.
  Duration get totalDuration {
    final double totalBeats = notes.fold(0.0, (sum, n) => sum + n.duration.beats);
    final double secondsPerBeat = 60.0 / bpm;
    return Duration(milliseconds: (totalBeats * secondsPerBeat * 1000).round());
  }

  /// Converts to renderable/playable measures via the shared reflow packer,
  /// so rendering (`MusicStaffPainter`) and playback (`RhythmPlaybackService`)
  /// need no Composer-specific code path.
  List<RhythmMeasure> toRhythmMeasures() {
    final flat = notes
        .map((n) => RhythmElement(
              type: n.duration.toRhythmElementType(),
              duration: n.duration.beats,
              noteName: n.pitch,
            ))
        .toList();
    return geometry.reflowMeasures(flat, timeSignature);
  }

  /// Builds a [Composition] from a live, flat, ordered edit buffer — the
  /// inverse of [toRhythmMeasures] — recomputing measureIndex/beatPosition
  /// via the same reflow packer so they're always self-consistent.
  factory Composition.fromElements({
    required String id,
    required String title,
    required DateTime createdAt,
    required DateTime modifiedAt,
    required int bpm,
    required String timeSignature,
    required List<RhythmElement> elements,
  }) {
    final measures = geometry.reflowMeasures(elements, timeSignature);
    final notes = <ComposedNote>[];
    for (int m = 0; m < measures.length; m++) {
      double beat = 0.0;
      for (final element in measures[m].elements) {
        notes.add(ComposedNote(
          pitch: element.noteName,
          duration: NoteDuration.fromRhythmElementType(element.type),
          measureIndex: m,
          beatPosition: beat,
        ));
        beat += element.duration;
      }
    }
    return Composition(
      id: id,
      title: title,
      createdAt: createdAt,
      modifiedAt: modifiedAt,
      bpm: bpm,
      timeSignature: timeSignature,
      notes: notes,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'modifiedAt': modifiedAt.toIso8601String(),
        'bpm': bpm,
        'timeSignature': timeSignature,
        'notes': notes.map((n) => n.toJson()).toList(),
      };

  factory Composition.fromJson(Map<String, dynamic> json) => Composition(
        id: json['id'] as String,
        title: json['title'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        modifiedAt: DateTime.parse(json['modifiedAt'] as String),
        bpm: json['bpm'] as int,
        timeSignature: json['timeSignature'] as String,
        notes: (json['notes'] as List)
            .map((n) => ComposedNote.fromJson(n as Map<String, dynamic>))
            .toList(),
      );
}
