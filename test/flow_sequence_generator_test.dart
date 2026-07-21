import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:beatter/services/figurations/figuration.dart';
import 'package:beatter/services/figurations/flow_sequence_generator.dart';

Figuration _fig(String id, FigurationCategory category) => Figuration(
      id: id,
      category: category,
      wavAsset: 'application/${category.folder}/x/$id.wav',
      imageAsset: 'assets/application/${category.folder}/y/$id.png',
    );

List<Figuration> _quarterPool() =>
    [for (int i = 1; i <= 6; i++) _fig('q$i', FigurationCategory.quarter)];

List<Figuration> _eighthsPool() =>
    [for (int i = 1; i <= 6; i++) _fig('o$i', FigurationCategory.eighths)];

void main() {
  group('FlowSequenceGenerator - movimenti (1/4 set)', () {
    test('chains N one-beat cells with contiguous offsets', () {
      final gen = FlowSequenceGenerator(random: math.Random(1));
      final pool = _quarterPool();

      for (int count = 1; count <= 8; count++) {
        final seq = gen.generate(count: count, pool: pool);
        expect(seq.items.length, count);
        expect(seq.totalBeats, closeTo(count * 1.0, 1e-9));
        for (int i = 0; i < seq.items.length; i++) {
          expect(seq.items[i].beatOffset, closeTo(i * 1.0, 1e-9));
          expect(seq.items[i].figuration.category,
              FigurationCategory.quarter);
        }
      }
    });
  });

  group('FlowSequenceGenerator - movimenti (eighths/3/8 set)', () {
    test('chains N 1.5-beat cells; sets are never mixed', () {
      final gen = FlowSequenceGenerator(random: math.Random(2));
      final seq = gen.generate(count: 5, pool: _eighthsPool());

      expect(seq.items.length, 5);
      expect(seq.totalBeats, closeTo(5 * 1.5, 1e-9));
      for (int i = 0; i < seq.items.length; i++) {
        expect(seq.items[i].beatOffset, closeTo(i * 1.5, 1e-9));
        expect(seq.items[i].figuration.category, FigurationCategory.eighths);
      }
    });
  });

  group('FlowSequenceGenerator - edge cases', () {
    test('empty pool or zero count yields an empty sequence', () {
      final gen = FlowSequenceGenerator(random: math.Random(7));
      expect(gen.generate(count: 4, pool: const []).isEmpty, isTrue);
      expect(gen.generate(count: 0, pool: _quarterPool()).isEmpty, isTrue);
    });
  });

  group('FlowSequenceGenerator - swapOne (seamless auto-variation)', () {
    test('preserves every offset and the total length', () {
      final gen = FlowSequenceGenerator(random: math.Random(3));
      final pool = _quarterPool();
      final original = gen.generate(count: 5, pool: pool);
      final swapped = gen.swapOne(original, pool);

      expect(swapped.totalBeats, original.totalBeats);
      expect(swapped.offsets, original.offsets);

      var diffs = 0;
      for (int i = 0; i < original.items.length; i++) {
        if (original.items[i].figuration.id != swapped.items[i].figuration.id) {
          diffs++;
        }
      }
      expect(diffs, 1);
    });
  });

  group('FigurationCategory durations', () {
    test('match the verified asset layout', () {
      expect(FigurationCategory.quarter.beats, 1.0);
      expect(FigurationCategory.half.beats, 2.0);
      expect(FigurationCategory.whole.beats, 4.0);
      expect(FigurationCategory.eighths.beats, 1.5);
    });
  });
}
