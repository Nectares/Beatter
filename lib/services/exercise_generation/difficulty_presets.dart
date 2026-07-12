import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'beat_figurations.dart';

/// Una figurazione (per id, vedi [kBeatFigurations]) con la frequenza
/// relativa con cui il generatore deve sceglierla nello stesso preset.
class WeightedFiguration {
  final String figurationId;
  final int weight;

  const WeightedFiguration(this.figurationId, this.weight);

  BeatFiguration get figuration => figurationById(figurationId);
}

/// A code-defined difficulty preset: quali figurazioni un esercizio può
/// contenere e con che pesi. Puramente dichiarativo — la logica di
/// generazione in `RhythmEngine` non nomina mai una difficoltà specifica.
class DifficultyPreset {
  final String id;
  final String label;
  final String description;
  final List<WeightedFiguration> figurations;
  final Color accentColor;

  const DifficultyPreset({
    required this.id,
    required this.label,
    required this.description,
    required this.figurations,
    required this.accentColor,
  });
}

/// ─────────────────────────────────────────────────────────────────────────
/// THE single place to tune what each difficulty is allowed to generate.
/// Ogni battito è sempre una figurazione reale da 1/4 (mai una croma o una
/// semicroma isolata), oppure una semiminima/minima/semibreve semplice.
/// ─────────────────────────────────────────────────────────────────────────
const List<DifficultyPreset> kDifficultyPresets = [
  DifficultyPreset(
    id: 'easy',
    label: 'Easy',
    description: 'Semibrevi, minime, semiminime e pause di semiminima.',
    accentColor: AppColors.success,
    figurations: [
      WeightedFiguration('whole', 1),
      WeightedFiguration('half', 3),
      WeightedFiguration('A1', 6),
      WeightedFiguration('A2', 2),
    ],
  ),
  DifficultyPreset(
    id: 'intermediate',
    label: 'Intermediate',
    description: 'Aggiunge le coppie di crome e la pausa di croma.',
    accentColor: AppColors.tertiary,
    figurations: [
      WeightedFiguration('half', 2),
      WeightedFiguration('A1', 5),
      WeightedFiguration('A2', 2),
      WeightedFiguration('B1', 5),
      WeightedFiguration('B2', 2),
    ],
  ),
  DifficultyPreset(
    id: 'medium',
    label: 'Medium',
    description: 'Aggiunge le figurazioni di semicrome e la croma puntata.',
    accentColor: AppColors.warning,
    figurations: [
      WeightedFiguration('A1', 3),
      WeightedFiguration('A2', 1),
      WeightedFiguration('B1', 4),
      WeightedFiguration('B2', 2),
      WeightedFiguration('C1', 3),
      WeightedFiguration('C2', 3),
      WeightedFiguration('C3', 3),
      WeightedFiguration('C5', 2),
      WeightedFiguration('C6', 1),
      WeightedFiguration('C9', 1),
    ],
  ),
  DifficultyPreset(
    id: 'hard',
    label: 'Hard',
    description: 'Sincopi, terzine e pause interne al battito.',
    accentColor: AppColors.secondary,
    figurations: [
      WeightedFiguration('A1', 2),
      WeightedFiguration('B1', 3),
      WeightedFiguration('B2', 2),
      WeightedFiguration('C1', 2),
      WeightedFiguration('C2', 2),
      WeightedFiguration('C3', 2),
      WeightedFiguration('C4', 3),
      WeightedFiguration('C5', 2),
      WeightedFiguration('C7', 2),
      WeightedFiguration('C8', 1),
      WeightedFiguration('C9', 1),
      WeightedFiguration('C10', 2),
      WeightedFiguration('C11', 2),
      WeightedFiguration('C12', 1),
      WeightedFiguration('D1', 3),
      WeightedFiguration('D2', 1),
      WeightedFiguration('D3', 1),
      WeightedFiguration('D4', 1),
    ],
  ),
  DifficultyPreset(
    id: 'hardcore',
    label: 'Hardcore',
    description:
        'Densità massima: quintine, sestine, biscrome e terzine variate.',
    accentColor: AppColors.error,
    figurations: [
      WeightedFiguration('B1', 2),
      WeightedFiguration('C1', 3),
      WeightedFiguration('C2', 2),
      WeightedFiguration('C3', 2),
      WeightedFiguration('C4', 3),
      WeightedFiguration('C5', 1),
      WeightedFiguration('C7', 2),
      WeightedFiguration('C8', 2),
      WeightedFiguration('C10', 2),
      WeightedFiguration('C11', 2),
      WeightedFiguration('C12', 2),
      WeightedFiguration('D1', 2),
      WeightedFiguration('D2', 1),
      WeightedFiguration('D3', 1),
      WeightedFiguration('D4', 1),
      WeightedFiguration('D5', 1),
      WeightedFiguration('D6', 1),
      WeightedFiguration('D7', 1),
      WeightedFiguration('E1', 2),
      WeightedFiguration('F1', 2),
      WeightedFiguration('G1', 1),
      WeightedFiguration('H1', 2),
      WeightedFiguration('H2', 2),
      WeightedFiguration('L1', 1),
      WeightedFiguration('L2', 1),
      WeightedFiguration('L3', 1),
      WeightedFiguration('L4', 1),
      WeightedFiguration('L5', 1),
      WeightedFiguration('L6', 1),
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
