import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:beatter/core/di/service_locator.dart';
import 'package:beatter/services/exercise_generation/difficulty_presets.dart';
import 'package:beatter/services/exercise_generation/exercise_generator.dart';
import 'package:beatter/services/exercise_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ExerciseRepository is a singleton, so all cases share one instance;
  // each test builds on the state left by the previous one, in order.
  final repository = ExerciseRepository();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    // The repository resolves its store through the backend locator.
    ServiceLocator.configureLocal();
  });

  test('save assigns an id, prepends, and persists', () async {
    await repository.init();
    final exercise = ExerciseGenerator().generate(
      ExerciseGeneratorConfig(
        preset: presetById('medium'),
        timeSignature: '3/4',
        bpm: 90,
        measureCount: 4,
        seed: 5,
      ),
    );

    final saved = await repository.save(exercise.copyWith(title: 'Prima'));
    expect(saved.id, isNotEmpty);
    expect(repository.exercises.single.title, 'Prima');

    // The persisted JSON must round-trip through storage.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('sheet_mode.exercises.v1'), contains('"Prima"'));
  });

  test('rename and duplicate update the list', () async {
    final original = repository.exercises.single;
    await repository.rename(original.id, 'Rinominata');
    expect(repository.exercises.single.title, 'Rinominata');

    final copy = await repository.duplicate(original.id);
    expect(copy.id, isNot(original.id));
    expect(copy.title, 'Rinominata (copia)');
    expect(copy.seed, original.seed);
    expect(repository.exercises, hasLength(2));
    // Newest first.
    expect(repository.exercises.first.id, copy.id);
  });

  test('delete removes only the targeted exercise', () async {
    final toDelete = repository.exercises.first;
    await repository.delete(toDelete.id);
    expect(repository.exercises, hasLength(1));
    expect(repository.exercises.single.title, 'Rinominata');
  });
}
