import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'rhythm_figures.dart';

/// A rhythm figure paired with how often the generator should pick it,
/// relative to the other figures in the same preset.
class WeightedFigure {
  final RhythmFigure figure;
  final int weight;

  const WeightedFigure(this.figure, this.weight);
}

/// A code-defined difficulty preset: which figures an exercise may contain
/// and how they're weighted. Purely declarative — the generation logic in
/// `RhythmEngine` never mentions a specific difficulty.
class DifficultyPreset {
  final String id;
  final String label;
  final String description;
  final List<WeightedFigure> figures;
  final Color accentColor;

  const DifficultyPreset({
    required this.id,
    required this.label,
    required this.description,
    required this.figures,
    required this.accentColor,
  });

  List<RhythmFigure> get allowedFigures =>
      figures.map((w) => w.figure).toList();
}

/// ─────────────────────────────────────────────────────────────────────────
/// THE single place to tune what each difficulty is allowed to generate.
/// Add/remove figures or adjust weights here — the generator, the UI and
/// persistence all pick the change up automatically.
/// ─────────────────────────────────────────────────────────────────────────
const List<DifficultyPreset> kDifficultyPresets = [
  DifficultyPreset(
    id: 'easy',
    label: 'Easy',
    description: 'Semibrevi, minime, semiminime e pause di semiminima.',
    accentColor: AppColors.success,
    figures: [
      WeightedFigure(RhythmFigure.whole, 1),
      WeightedFigure(RhythmFigure.half, 3),
      WeightedFigure(RhythmFigure.quarter, 6),
      WeightedFigure(RhythmFigure.quarterRest, 2),
    ],
  ),
  DifficultyPreset(
    id: 'intermediate',
    label: 'Intermediate',
    description: 'Aggiunge le crome e le pause di croma.',
    accentColor: AppColors.tertiary,
    figures: [
      WeightedFigure(RhythmFigure.half, 2),
      WeightedFigure(RhythmFigure.quarter, 5),
      WeightedFigure(RhythmFigure.eighth, 5),
      WeightedFigure(RhythmFigure.quarterRest, 2),
      WeightedFigure(RhythmFigure.eighthRest, 1),
    ],
  ),
  DifficultyPreset(
    id: 'medium',
    label: 'Medium',
    description: 'Aggiunge le semicrome per pattern più fitti.',
    accentColor: AppColors.warning,
    figures: [
      WeightedFigure(RhythmFigure.quarter, 4),
      WeightedFigure(RhythmFigure.eighth, 5),
      WeightedFigure(RhythmFigure.sixteenth, 3),
      WeightedFigure(RhythmFigure.quarterRest, 1),
      WeightedFigure(RhythmFigure.eighthRest, 2),
    ],
  ),
  DifficultyPreset(
    id: 'hard',
    label: 'Hard',
    description: 'Terzine, pause di semicroma e sincopi.',
    accentColor: AppColors.secondary,
    figures: [
      WeightedFigure(RhythmFigure.quarter, 2),
      WeightedFigure(RhythmFigure.eighth, 5),
      WeightedFigure(RhythmFigure.sixteenth, 4),
      WeightedFigure(RhythmFigure.eighthTriplet, 3),
      WeightedFigure(RhythmFigure.eighthRest, 2),
      WeightedFigure(RhythmFigure.sixteenthRest, 2),
    ],
  ),
  DifficultyPreset(
    id: 'hardcore',
    label: 'Hardcore',
    description: 'Densità massima: semicrome, terzine e pause ovunque.',
    accentColor: AppColors.error,
    figures: [
      WeightedFigure(RhythmFigure.eighth, 3),
      WeightedFigure(RhythmFigure.sixteenth, 6),
      WeightedFigure(RhythmFigure.eighthTriplet, 4),
      WeightedFigure(RhythmFigure.eighthRest, 2),
      WeightedFigure(RhythmFigure.sixteenthRest, 3),
    ],
  ),
];

/// Lookup by id, falling back to the first preset for ids persisted by
/// older versions whose preset no longer exists.
DifficultyPreset presetById(String id) {
  return kDifficultyPresets.firstWhere(
    (p) => p.id == id,
    orElse: () => kDifficultyPresets.first,
  );
}
