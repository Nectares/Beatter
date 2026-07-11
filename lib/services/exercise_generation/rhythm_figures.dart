import '../../models/rhythm_element.dart';

/// The catalog of rhythm figures the exercise generator can place.
///
/// Every figure declares its own duration in [units] (1 unit = one
/// sixteenth = 0.25 quarter-note beats), so the engine can do exact integer
/// arithmetic when filling measures — no floating-point residue can ever
/// leave a measure under- or over-full.
///
/// A figure maps 1:1 onto an existing [RhythmElementType], so anything the
/// generator emits is renderable by `MusicStaffPainter` and playable by
/// `RhythmPlaybackService` with zero extra plumbing. New figures (dotted
/// notes, other tuplets…) get added here first, then taught to the painter.
enum RhythmFigure {
  whole(RhythmElementType.whole, 16),
  half(RhythmElementType.half, 8),
  quarter(RhythmElementType.quarter, 4),
  eighth(RhythmElementType.eighth, 2),
  sixteenth(RhythmElementType.sixteenth, 1),
  quarterRest(RhythmElementType.quarterRest, 4),
  eighthRest(RhythmElementType.eighthRest, 2),
  sixteenthRest(RhythmElementType.sixteenthRest, 1),

  /// Eighth-note triplet: three notes filling exactly one quarter-note beat.
  eighthTriplet(RhythmElementType.triplet, 4);

  final RhythmElementType elementType;

  /// Duration in sixteenth-note units (1 unit = 0.25 beats).
  final int units;

  const RhythmFigure(this.elementType, this.units);

  /// Duration in quarter-note beats, matching [RhythmElement.duration].
  double get beats => units / 4.0;

  bool get isRest =>
      this == RhythmFigure.quarterRest ||
      this == RhythmFigure.eighthRest ||
      this == RhythmFigure.sixteenthRest;

  /// Tuplets must start on a quarter-note beat boundary to stay readable.
  bool get requiresBeatAlignment => this == RhythmFigure.eighthTriplet;

  /// Materializes this figure as a concrete staff/playback element at
  /// [pitch] (e.g. 'C4' for the middle-C rhythm-reading convention).
  RhythmElement toElement(String pitch) {
    return RhythmElement(
      type: elementType,
      duration: beats,
      noteName: pitch,
      tripletNotes: this == RhythmFigure.eighthTriplet
          ? [pitch, pitch, pitch]
          : const ['B4', 'B4', 'B4'],
    );
  }
}
