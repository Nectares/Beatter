import 'package:flutter_test/flutter_test.dart';
import 'package:beatter/models/rhythm_element.dart';
import 'package:beatter/models/rhythm_exercise.dart';
import 'package:beatter/services/exercise_generation/difficulty_presets.dart';
import 'package:beatter/services/exercise_generation/exercise_generator.dart';
import 'package:beatter/widgets/music_staff/staff_geometry.dart' as geometry;

void main() {
  const timeSignatures = ['2/4', '3/4', '4/4', '6/8'];

  RhythmExercise generate({
    required DifficultyPreset preset,
    required String timeSignature,
    int measureCount = 8,
    int? seed,
  }) {
    return ExerciseGenerator().generate(
      ExerciseGeneratorConfig(
        preset: preset,
        timeSignature: timeSignature,
        bpm: 100,
        measureCount: measureCount,
        seed: seed,
      ),
    );
  }

  group('measure filling', () {
    test('every measure is filled exactly for every preset and signature', () {
      for (final preset in kDifficultyPresets) {
        for (final sig in timeSignatures) {
          for (int seed = 0; seed < 25; seed++) {
            final exercise = generate(
              preset: preset,
              timeSignature: sig,
              seed: seed,
            );
            expect(exercise.measures, hasLength(8));
            for (final measure in exercise.measures) {
              expect(
                measure.totalDuration,
                geometry.targetBeats(sig),
                reason: 'preset=${preset.id} sig=$sig seed=$seed must fill '
                    'the measure exactly — no underflow or overflow',
              );
            }
          }
        }
      }
    });

    test('only figures allowed by the preset are used', () {
      for (final preset in kDifficultyPresets) {
        final allowedTypes =
            preset.allowedFigures.map((f) => f.elementType).toSet();
        for (int seed = 0; seed < 25; seed++) {
          final exercise =
              generate(preset: preset, timeSignature: '4/4', seed: seed);
          for (final measure in exercise.measures) {
            for (final element in measure.elements) {
              expect(
                allowedTypes,
                contains(element.type),
                reason: 'preset=${preset.id} seed=$seed emitted a figure '
                    'outside its centralized configuration',
              );
            }
          }
        }
      }
    });

    test('triplets always start on a quarter-note beat boundary', () {
      final hard = presetById('hard');
      for (int seed = 0; seed < 50; seed++) {
        final exercise =
            generate(preset: hard, timeSignature: '4/4', seed: seed);
        for (final measure in exercise.measures) {
          int positionUnits = 0;
          for (final element in measure.elements) {
            if (element.type == RhythmElementType.triplet) {
              expect(positionUnits % 4, 0,
                  reason: 'seed=$seed: triplet off the beat grid');
            }
            positionUnits += (element.duration * 4).round();
          }
        }
      }
    });

    test('rests never open a measure and never repeat back-to-back', () {
      for (final preset in kDifficultyPresets) {
        for (int seed = 0; seed < 25; seed++) {
          final exercise =
              generate(preset: preset, timeSignature: '4/4', seed: seed);
          for (final measure in exercise.measures) {
            expect(measure.elements.first.isRest, isFalse,
                reason: 'preset=${preset.id} seed=$seed opened with a rest');
            for (int i = 1; i < measure.elements.length; i++) {
              expect(
                measure.elements[i - 1].isRest && measure.elements[i].isRest,
                isFalse,
                reason: 'preset=${preset.id} seed=$seed has adjacent rests',
              );
            }
          }
        }
      }
    });

    test('all notes sit on the configured exercise pitch', () {
      final exercise = generate(
          preset: kDifficultyPresets.first, timeSignature: '4/4', seed: 1);
      for (final measure in exercise.measures) {
        for (final element in measure.elements) {
          if (!element.isRest) {
            expect(element.noteName, kExercisePitch);
          }
        }
      }
    });
  });

  group('reproducibility', () {
    test('the same seed regenerates the identical exercise', () {
      for (final preset in kDifficultyPresets) {
        final a = generate(preset: preset, timeSignature: '3/4', seed: 42);
        final b = generate(preset: preset, timeSignature: '3/4', seed: 42);

        expect(a.seed, b.seed);
        expect(a.measures.length, b.measures.length);
        for (int m = 0; m < a.measures.length; m++) {
          final elementsA = a.measures[m].elements;
          final elementsB = b.measures[m].elements;
          expect(elementsA.length, elementsB.length);
          for (int e = 0; e < elementsA.length; e++) {
            expect(elementsA[e].type, elementsB[e].type);
            expect(elementsA[e].duration, elementsB[e].duration);
          }
        }
      }
    });

    test('without a fixed seed, a fresh seed is recorded on the exercise', () {
      final exercise =
          generate(preset: kDifficultyPresets.first, timeSignature: '4/4');
      expect(exercise.seed, isNonZero);
    });
  });

  group('serialization', () {
    test('RhythmExercise survives a JSON round-trip intact', () {
      final original = generate(
        preset: presetById('hard'),
        timeSignature: '6/8',
        measureCount: 5,
        seed: 7,
      ).copyWith(id: 'test-id', title: 'Lettura Hard');

      final restored = RhythmExercise.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.title, original.title);
      expect(restored.difficultyId, original.difficultyId);
      expect(restored.bpm, original.bpm);
      expect(restored.timeSignature, original.timeSignature);
      expect(restored.measureCount, original.measureCount);
      expect(restored.seed, original.seed);
      expect(restored.createdAt, original.createdAt);
      expect(restored.measures.length, original.measures.length);
      for (int m = 0; m < original.measures.length; m++) {
        final a = original.measures[m];
        final b = restored.measures[m];
        expect(b.timeSignature, a.timeSignature);
        expect(b.totalDuration, a.totalDuration);
        for (int e = 0; e < a.elements.length; e++) {
          expect(b.elements[e].type, a.elements[e].type);
          expect(b.elements[e].duration, a.elements[e].duration);
          expect(b.elements[e].noteName, a.elements[e].noteName);
        }
      }
    });
  });

  group('system wrapping', () {
    test('wrapped systems cover every measure exactly once, in order', () {
      final exercise = generate(
        preset: presetById('medium'),
        timeSignature: '4/4',
        measureCount: 16,
        seed: 3,
      );

      final systems = geometry.computeSystemBreaks(exercise.measures, 600);
      expect(systems.length, greaterThan(1),
          reason: '16 measures of 4/4 cannot fit one 600px row');

      int expectedStart = 0;
      for (final system in systems) {
        expect(system.start, expectedStart);
        expect(system.count, greaterThan(0));
        expectedStart += system.count;
      }
      expect(expectedStart, exercise.measures.length);
    });

    test('a width narrower than one measure still places one per row', () {
      final exercise = generate(
        preset: kDifficultyPresets.first,
        timeSignature: '4/4',
        measureCount: 3,
        seed: 9,
      );
      final systems = geometry.computeSystemBreaks(exercise.measures, 50);
      expect(systems.length, 3);
      for (final system in systems) {
        expect(system.count, 1);
      }
    });
  });
}
