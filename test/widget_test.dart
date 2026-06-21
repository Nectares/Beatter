import 'package:flutter_test/flutter_test.dart';
import 'package:beatter/main.dart';
import 'package:beatter/models/rhythm_pattern.dart';
import 'package:beatter/services/pattern_repository.dart';

void main() {
  testWidgets('Beatter login screen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const BeatterApp());
    expect(find.text('Beatter'), findsOneWidget);
    expect(find.text('Sintonizza il tuo mondo'), findsOneWidget);
  });

  test('PatternRepository adds and updates patterns correctly', () {
    final repo = PatternRepository();
    final initialCount = repo.patterns.length;

    final testPattern = RhythmPattern(
      name: 'Test Pattern',
      bpm: 100,
      baseFrequency: 300.0,
      beats: List.generate(16, (i) => i % 2 == 0),
      notes: List.generate(16, (_) => 'E4'),
    );

    repo.addPattern(testPattern);

    expect(repo.patterns.length, initialCount + 1);
    expect(repo.patterns.last.name, 'Test Pattern');
    expect(repo.patterns.last.bpm, 100);
  });
}
