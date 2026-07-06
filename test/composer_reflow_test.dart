import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:beatter/models/rhythm_element.dart';
import 'package:beatter/models/composition.dart';
import 'package:beatter/services/composition_repository.dart';
import 'package:beatter/widgets/music_staff/staff_geometry.dart' as geometry;

RhythmElement _quarter(String pitch) =>
    RhythmElement(type: RhythmElementType.quarter, duration: 1.0, noteName: pitch);

void main() {
  group('reflowMeasures', () {
    test('packs an exactly-full 4/4 measure into one measure', () {
      final flat = List.generate(4, (_) => _quarter('C4'));
      final measures = geometry.reflowMeasures(flat, '4/4');
      expect(measures.length, 1);
      expect(measures.single.elements.length, 4);
    });

    test('auto-continues into a new measure on overflow, without splitting', () {
      final flat = List.generate(5, (_) => _quarter('C4'));
      final measures = geometry.reflowMeasures(flat, '4/4');
      expect(measures.length, 2);
      expect(measures[0].elements.length, 4);
      expect(measures[1].elements.length, 1);
    });

    test('re-chunks correctly when time signature changes mid-sequence', () {
      final flat = List.generate(8, (_) => _quarter('C4'));

      final measures44 = geometry.reflowMeasures(flat, '4/4');
      expect(measures44.length, 2);

      final measures24 = geometry.reflowMeasures(flat, '2/4');
      expect(measures24.length, 4);
      for (final measure in measures24) {
        expect(measure.elements.length, 2);
      }
    });

    test('2/4 has the correct beat capacity (previously missing)', () {
      expect(geometry.targetBeats('2/4'), 2.0);
    });
  });

  group('computeLayout', () {
    test('lays out elements left-to-right within their measure bounds', () {
      final measures = [
        RhythmMeasure(elements: [_quarter('C4'), _quarter('D4')], timeSignature: '4/4'),
      ];
      final layout = geometry.computeLayout(measures);

      expect(layout.length, 1);
      expect(layout.single.elements.length, 2);
      expect(layout.single.elements[0].x, lessThan(layout.single.elements[1].x));
      expect(layout.single.startX, lessThan(layout.single.elements[0].x));
      expect(layout.single.elements[1].x, lessThan(layout.single.endX));
    });
  });

  group('noteNameFromY', () {
    test('round-trips through noteY for natural notes, including ledger lines', () {
      const double centerY = 80.0;
      const double spacing = geometry.lineSpacing;
      const notes = ['C4', 'D4', 'E4', 'F4', 'G4', 'A4', 'B4', 'C5', 'D5', 'E5', 'F5', 'G3', 'A3', 'C6'];

      for (final name in notes) {
        final y = geometry.noteY(name, centerY, spacing);
        final roundTripped = geometry.noteNameFromY(y, centerY, spacing);
        expect(roundTripped, name, reason: 'round-trip failed for $name');
      }
    });
  });

  group('CompositionRepository', () {
    test('save, overwrite, rename, duplicate and delete', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = CompositionRepository();
      await repo.init();

      expect(repo.compositions, isEmpty);

      final draft = Composition(
        id: '',
        title: 'My Melody',
        createdAt: DateTime(2026, 1, 1),
        modifiedAt: DateTime(2026, 1, 1),
        bpm: 100,
        timeSignature: '4/4',
        notes: const [
          ComposedNote(pitch: 'C4', duration: NoteDuration.quarter, measureIndex: 0, beatPosition: 0.0),
        ],
      );

      final saved = await repo.save(draft);
      expect(saved.id, isNotEmpty);
      expect(repo.compositions.length, 1);

      await repo.save(saved.copyWith(title: 'Renamed Inline'));
      expect(repo.compositions.length, 1);
      expect(repo.compositions.single.title, 'Renamed Inline');

      await repo.rename(saved.id, 'Final Title');
      expect(repo.compositions.single.title, 'Final Title');

      final duplicate = await repo.duplicate(saved.id);
      expect(repo.compositions.length, 2);
      expect(duplicate.id, isNot(saved.id));
      expect(duplicate.title, contains('copia'));

      await repo.delete(duplicate.id);
      expect(repo.compositions.length, 1);

      await repo.delete(saved.id);
      expect(repo.compositions, isEmpty);
    });
  });
}
