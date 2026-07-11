import 'package:flutter_test/flutter_test.dart';
import 'package:beatter/services/exercise_generation/difficulty_presets.dart';
import 'package:beatter/services/exercise_generation/exercise_generator.dart';
import 'package:beatter/services/exercise_pdf_exporter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('buildPdf produces a valid, non-trivial PDF document',
      (tester) async {
    final exercise = ExerciseGenerator()
        .generate(
          ExerciseGeneratorConfig(
            preset: presetById('hard'),
            timeSignature: '4/4',
            bpm: 120,
            measureCount: 12,
            seed: 11,
          ),
        )
        .copyWith(title: 'Lettura di prova');

    // Real async work (Picture.toImage, asset loading) needs runAsync.
    final bytes = await tester.runAsync(
      () => ExercisePdfExporter().buildPdf(exercise),
    );

    expect(bytes, isNotNull);
    // PDF magic header.
    expect(String.fromCharCodes(bytes!.take(5)), '%PDF-');
    // Trailer marker somewhere near the end.
    final tail = String.fromCharCodes(bytes.skip(bytes.length - 32));
    expect(tail, contains('%%EOF'));
    // A dozen rasterized staff systems cannot fit in a stub-sized file.
    expect(bytes.length, greaterThan(20 * 1024));
  });
}
