import 'dart:math';
import '../../models/rhythm_element.dart';
import '../../widgets/music_staff/staff_geometry.dart' as geometry;
import 'difficulty_presets.dart';
import 'rhythm_figures.dart';

/// A pluggable rule the engine consults before placing a figure. Future
/// generation features (accent patterns, "focus on figure X", swing feel,
/// max consecutive rests…) slot in as new constraints without touching the
/// filling algorithm itself.
abstract class GenerationConstraint {
  /// Whether [figure] may be placed at [positionUnits] into a measure of
  /// [capacityUnits], with [remainingUnits] still to fill (all in
  /// sixteenth-note units, see [RhythmFigure.units]).
  bool allows({
    required RhythmFigure figure,
    required int positionUnits,
    required int remainingUnits,
    required int capacityUnits,
  });
}

/// Tuplets (and any future figure with [RhythmFigure.requiresBeatAlignment])
/// may only start on a quarter-note beat boundary, keeping them readable.
class BeatAlignmentConstraint extends GenerationConstraint {
  @override
  bool allows({
    required RhythmFigure figure,
    required int positionUnits,
    required int remainingUnits,
    required int capacityUnits,
  }) {
    if (!figure.requiresBeatAlignment) return true;
    return positionUnits % 4 == 0;
  }
}

/// Rests never open a measure and never occur back-to-back — an exercise
/// full of consecutive silence teaches nothing and reads terribly.
class RestPlacementConstraint extends GenerationConstraint {
  RhythmFigure? _previous;

  @override
  bool allows({
    required RhythmFigure figure,
    required int positionUnits,
    required int remainingUnits,
    required int capacityUnits,
  }) {
    if (!figure.isRest) return true;
    if (positionUnits == 0) return false;
    return !(_previous?.isRest ?? false);
  }

  /// The engine reports each placement so the constraint can track context.
  void onPlaced(RhythmFigure figure) => _previous = figure;

  void onMeasureStart() => _previous = null;
}

/// Fills measures exactly to their time signature's capacity using integer
/// sixteenth-note arithmetic — a measure can never come out short or long.
///
/// Pure and deterministic given a [Random]: the same seed always rebuilds
/// the same exercise, which is what makes saved exercises reproducible from
/// their generation seed alone.
class RhythmEngine {
  final List<GenerationConstraint> _constraints;
  final RestPlacementConstraint _restConstraint;

  RhythmEngine({List<GenerationConstraint>? extraConstraints})
      : _restConstraint = RestPlacementConstraint(),
        _constraints = [BeatAlignmentConstraint()] {
    _constraints.add(_restConstraint);
    if (extraConstraints != null) _constraints.addAll(extraConstraints);
  }

  /// Builds [measureCount] measures in [timeSignature], drawing figures
  /// from [preset] at [pitch].
  List<RhythmMeasure> buildMeasures({
    required DifficultyPreset preset,
    required String timeSignature,
    required int measureCount,
    required Random random,
    required String pitch,
  }) {
    final int capacityUnits = (geometry.targetBeats(timeSignature) * 4).round();
    return List.generate(measureCount, (_) {
      return RhythmMeasure(
        elements: _fillMeasure(
          preset: preset,
          capacityUnits: capacityUnits,
          random: random,
          pitch: pitch,
        ),
        timeSignature: timeSignature,
      );
    });
  }

  List<RhythmElement> _fillMeasure({
    required DifficultyPreset preset,
    required int capacityUnits,
    required Random random,
    required String pitch,
  }) {
    final elements = <RhythmElement>[];
    int position = 0;
    _restConstraint.onMeasureStart();

    while (position < capacityUnits) {
      final int remaining = capacityUnits - position;
      final figure = _pickFigure(preset, position, remaining, capacityUnits, random);
      elements.add(figure.toElement(pitch));
      _restConstraint.onPlaced(figure);
      position += figure.units;
    }

    return elements;
  }

  RhythmFigure _pickFigure(
    DifficultyPreset preset,
    int position,
    int remaining,
    int capacityUnits,
    Random random,
  ) {
    final candidates = preset.figures.where((weighted) {
      final figure = weighted.figure;
      if (figure.units > remaining) return false;
      return _constraints.every(
        (c) => c.allows(
          figure: figure,
          positionUnits: position,
          remainingUnits: remaining,
          capacityUnits: capacityUnits,
        ),
      );
    }).toList();

    if (candidates.isNotEmpty) return _weightedPick(candidates, random);

    // No candidate passes every constraint (e.g. a rest-only tail):
    // fall back to any allowed non-rest figure that still fits, then to the
    // largest fitting figure of any kind, so the measure always completes.
    final fitting = preset.figures.where((w) => w.figure.units <= remaining).toList();
    final nonRest = fitting.where((w) => !w.figure.isRest).toList();
    if (nonRest.isNotEmpty) return _weightedPick(nonRest, random);
    if (fitting.isNotEmpty) return _weightedPick(fitting, random);

    // Preset has nothing small enough (misconfigured): pad with the largest
    // standard figure that fits rather than looping forever.
    for (final figure in const [
      RhythmFigure.whole,
      RhythmFigure.half,
      RhythmFigure.quarter,
      RhythmFigure.eighth,
      RhythmFigure.sixteenth,
    ]) {
      if (figure.units <= remaining) return figure;
    }
    return RhythmFigure.sixteenth;
  }

  RhythmFigure _weightedPick(List<WeightedFigure> candidates, Random random) {
    final int totalWeight = candidates.fold(0, (sum, w) => sum + w.weight);
    int roll = random.nextInt(totalWeight);
    for (final weighted in candidates) {
      roll -= weighted.weight;
      if (roll < 0) return weighted.figure;
    }
    return candidates.last.figure;
  }
}
