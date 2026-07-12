import 'dart:math';
import '../../models/rhythm_element.dart';
import '../../widgets/music_staff/staff_geometry.dart' as geometry;
import 'beat_figurations.dart';
import 'difficulty_presets.dart';

/// A pluggable rule the engine consults before placing a figuration. Future
/// generation features (accent patterns, "focus on figure X", swing feel…)
/// slot in as new constraints without touching the filling algorithm itself.
abstract class GenerationConstraint {
  /// Whether [figuration] may start at [positionBeats] into a measure of
  /// [capacityBeats], with [remainingBeats] still to fill (all in
  /// quarter-note beats — figurations always occupy whole beats).
  bool allows({
    required BeatFiguration figuration,
    required int positionBeats,
    required int remainingBeats,
    required int capacityBeats,
  });
}

/// La semibreve vale l'intera misura: può comparire solo come primo (e
/// unico) elemento di una misura da 4/4. Analogamente la minima deve cadere
/// su un battito, cosa garantita a monte dal riempimento per battiti interi.
class WholeMeasureConstraint extends GenerationConstraint {
  @override
  bool allows({
    required BeatFiguration figuration,
    required int positionBeats,
    required int remainingBeats,
    required int capacityBeats,
  }) {
    if (figuration.beats < 4.0) return true;
    return positionBeats == 0 && capacityBeats == 4;
  }
}

/// I battiti di sola pausa (la pausa di semiminima) non aprono mai una
/// misura e non compaiono mai back-to-back — un esercizio pieno di silenzi
/// consecutivi non insegna nulla e si legge malissimo. Le pause *interne*
/// alle figurazioni (es. pausa di croma + croma) restano libere: sono
/// proprio le figurazioni realistiche che vogliamo.
class RestPlacementConstraint extends GenerationConstraint {
  BeatFiguration? _previous;

  @override
  bool allows({
    required BeatFiguration figuration,
    required int positionBeats,
    required int remainingBeats,
    required int capacityBeats,
  }) {
    if (!figuration.isFullRest) return true;
    if (positionBeats == 0) return false;
    return !(_previous?.isFullRest ?? false);
  }

  /// The engine reports each placement so the constraint can track context.
  void onPlaced(BeatFiguration figuration) => _previous = figuration;

  void onMeasureStart() => _previous = null;
}

/// Fills measures exactly to their time signature's capacity, one whole
/// quarter-note beat at a time: ogni battito è una figurazione reale del
/// catalogo (che vale sempre 1/4) oppure una minima/semibreve. Per
/// costruzione una misura non può mai uscire corta, lunga, o con una croma
/// isolata a metà battito.
///
/// Pure and deterministic given a [Random]: the same seed always rebuilds
/// the same exercise, which is what makes saved exercises reproducible from
/// their generation seed alone.
class RhythmEngine {
  final List<GenerationConstraint> _constraints;
  final RestPlacementConstraint _restConstraint;

  RhythmEngine({List<GenerationConstraint>? extraConstraints})
      : _restConstraint = RestPlacementConstraint(),
        _constraints = [WholeMeasureConstraint()] {
    _constraints.add(_restConstraint);
    if (extraConstraints != null) _constraints.addAll(extraConstraints);
  }

  /// Builds [measureCount] measures in [timeSignature], drawing figurations
  /// from [preset] at [pitch].
  List<RhythmMeasure> buildMeasures({
    required DifficultyPreset preset,
    required String timeSignature,
    required int measureCount,
    required Random random,
    required String pitch,
  }) {
    final int capacityBeats = geometry.targetBeats(timeSignature).round();
    return List.generate(measureCount, (_) {
      return RhythmMeasure(
        elements: _fillMeasure(
          preset: preset,
          capacityBeats: capacityBeats,
          random: random,
          pitch: pitch,
        ),
        timeSignature: timeSignature,
      );
    });
  }

  List<RhythmElement> _fillMeasure({
    required DifficultyPreset preset,
    required int capacityBeats,
    required Random random,
    required String pitch,
  }) {
    final elements = <RhythmElement>[];
    int position = 0;
    _restConstraint.onMeasureStart();

    while (position < capacityBeats) {
      final int remaining = capacityBeats - position;
      final figuration =
          _pickFiguration(preset, position, remaining, capacityBeats, random);
      elements.addAll(figuration.toElements(pitch));
      _restConstraint.onPlaced(figuration);
      position += figuration.beats.round();
    }

    return elements;
  }

  BeatFiguration _pickFiguration(
    DifficultyPreset preset,
    int position,
    int remaining,
    int capacityBeats,
    Random random,
  ) {
    final candidates = preset.figurations.where((weighted) {
      final figuration = weighted.figuration;
      if (figuration.beats.round() > remaining) return false;
      return _constraints.every(
        (c) => c.allows(
          figuration: figuration,
          positionBeats: position,
          remainingBeats: remaining,
          capacityBeats: capacityBeats,
        ),
      );
    }).toList();

    if (candidates.isNotEmpty) return _weightedPick(candidates, random);

    // No candidate passes every constraint (e.g. a rest-only preset tail):
    // fall back to any non-rest figuration that still fits, then to
    // anything that fits, then to the plain quarter note, so the measure
    // always completes.
    final fitting = preset.figurations
        .where((w) => w.figuration.beats.round() <= remaining)
        .toList();
    final nonRest =
        fitting.where((w) => !w.figuration.isFullRest).toList();
    if (nonRest.isNotEmpty) return _weightedPick(nonRest, random);
    if (fitting.isNotEmpty) return _weightedPick(fitting, random);
    return figurationById('A1');
  }

  BeatFiguration _weightedPick(
      List<WeightedFiguration> candidates, Random random) {
    final int totalWeight = candidates.fold(0, (sum, w) => sum + w.weight);
    int roll = random.nextInt(totalWeight);
    for (final weighted in candidates) {
      roll -= weighted.weight;
      if (roll < 0) return weighted.figuration;
    }
    return candidates.last.figuration;
  }
}
