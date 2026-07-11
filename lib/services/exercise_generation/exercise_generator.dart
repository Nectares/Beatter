import 'dart:math';
import '../../models/rhythm_exercise.dart';
import 'difficulty_presets.dart';
import 'rhythm_engine.dart';

/// Rhythm-reading convention: every generated note sits on middle C.
/// A single constant so orchestrated drum-set mapping can replace it later.
const String kExercisePitch = 'C4';

/// Everything the user chooses on the Generate screen.
class ExerciseGeneratorConfig {
  final DifficultyPreset preset;
  final String timeSignature;
  final int bpm;
  final int measureCount;

  /// Fixing the seed reproduces an exact exercise; leave null for a new one.
  final int? seed;

  const ExerciseGeneratorConfig({
    required this.preset,
    required this.timeSignature,
    required this.bpm,
    required this.measureCount,
    this.seed,
  });
}

/// Turns a [ExerciseGeneratorConfig] into a complete, immutable
/// [RhythmExercise]. Thin by design: all filling logic lives in
/// [RhythmEngine], all tuning in the preset config file.
class ExerciseGenerator {
  final RhythmEngine _engine;

  ExerciseGenerator({RhythmEngine? engine}) : _engine = engine ?? RhythmEngine();

  RhythmExercise generate(ExerciseGeneratorConfig config) {
    final int seed = config.seed ??
        DateTime.now().microsecondsSinceEpoch.remainder(1 << 31);
    final random = Random(seed);

    final measures = _engine.buildMeasures(
      preset: config.preset,
      timeSignature: config.timeSignature,
      measureCount: config.measureCount,
      random: random,
      pitch: kExercisePitch,
    );

    return RhythmExercise(
      id: '',
      title: '',
      createdAt: DateTime.now(),
      difficultyId: config.preset.id,
      bpm: config.bpm,
      timeSignature: config.timeSignature,
      measureCount: config.measureCount,
      seed: seed,
      measures: measures,
    );
  }
}
