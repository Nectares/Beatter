import 'dart:math' as math;

import 'figuration.dart';

/// One figuration placed at an absolute beat offset within a sequence.
class PlacedFiguration {
  const PlacedFiguration(this.figuration, this.beatOffset);

  final Figuration figuration;

  /// Onset of this figuration from the start of the sequence, in beats.
  final double beatOffset;

  PlacedFiguration withFiguration(Figuration figuration) =>
      PlacedFiguration(figuration, beatOffset);
}

/// An ordered, loopable list of placed figurations plus its total length.
class FlowSequence {
  const FlowSequence(this.items, this.totalBeats);

  final List<PlacedFiguration> items;

  /// Total length of the sequence in beats — the loop point.
  final double totalBeats;

  bool get isEmpty => items.isEmpty;
  int get length => items.length;

  /// Beat offsets to hand to the [AudioScheduler] timeline.
  List<double> get offsets => [for (final p in items) p.beatOffset];

  static const FlowSequence empty = FlowSequence(<PlacedFiguration>[], 0.0);
}

/// Builds a Flow Mode sequence as a plain chain of "movimenti".
///
/// Every movimento is exactly one figuration tile, drawn at random from a
/// single pool — either the 1/4 set or the eighths (3/8) set, decided by the
/// Ottave switch upstream. The two sets are never mixed. Each figuration
/// advances the timeline by its own musical length (1.0 beat for 1/4 cells,
/// 1.5 beats for eighths cells).
class FlowSequenceGenerator {
  FlowSequenceGenerator({math.Random? random})
      : _rand = random ?? math.Random();

  final math.Random _rand;

  /// Chains [count] random figurations taken from [pool].
  FlowSequence generate({required int count, required List<Figuration> pool}) {
    if (pool.isEmpty || count < 1) return FlowSequence.empty;

    final items = <PlacedFiguration>[];
    double offset = 0.0;
    for (int i = 0; i < count; i++) {
      final figuration = _pick(pool);
      items.add(PlacedFiguration(figuration, offset));
      offset += figuration.beats;
    }
    return FlowSequence(items, offset);
  }

  /// Returns a copy of [sequence] with a single movimento swapped for another
  /// figuration from [pool]. Beat offsets and total length are unchanged, so
  /// the running loop is not disturbed (seamless auto-variation).
  FlowSequence swapOne(FlowSequence sequence, List<Figuration> pool) {
    if (sequence.items.isEmpty || pool.isEmpty) return sequence;

    final index = _rand.nextInt(sequence.items.length);
    final current = sequence.items[index];

    Figuration replacement = _pick(pool);
    if (pool.length > 1) {
      var guard = 0;
      while (replacement.id == current.figuration.id && guard++ < 8) {
        replacement = _pick(pool);
      }
    }

    // Keep the offset even if the replacement has a different length: within a
    // single set every cell shares the same length, so offsets stay valid.
    final items = List<PlacedFiguration>.of(sequence.items);
    items[index] = current.withFiguration(replacement);
    return FlowSequence(items, sequence.totalBeats);
  }

  Figuration _pick(List<Figuration> pool) => pool[_rand.nextInt(pool.length)];
}
