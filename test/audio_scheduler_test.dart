import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beatter/services/figurations/audio_scheduler.dart';

/// A [SchedulerClock] the test drives by hand, so scheduling can be asserted
/// exactly instead of by sleeping. Mirrors [StopwatchClock]'s contract: it only
/// accumulates while started, and reports whole milliseconds like the real
/// `Stopwatch.elapsedMilliseconds` does.
class TestClock implements SchedulerClock {
  double _elapsed = 0;
  bool _running = false;

  /// Wall time since the test began — keeps advancing even while the clock is
  /// stopped, so a test can tell "when did this fire" from "how far had the
  /// scheduler's own clock got".
  double wallMs = 0;

  void advance(Duration d) {
    final ms = d.inMicroseconds / 1000.0;
    wallMs += ms;
    if (_running) _elapsed += ms;
  }

  @override
  double get elapsedMs => _elapsed.floorToDouble();

  @override
  void start() => _running = true;

  @override
  void stop() => _running = false;

  @override
  void reset() => _elapsed = 0;
}

/// One fired event: which index, and the wall time it fired at.
typedef Fired = ({int index, double atMs});

/// Harness bundling a scheduler, its clock and the events it fired.
class _Rig {
  _Rig({int bpm = 60}) {
    scheduler = AudioScheduler(
      onEvent: (i) => fired.add((index: i, atMs: clock.wallMs)),
      clock: clock,
    )..bpm = bpm;
  }

  final TestClock clock = TestClock();
  final List<Fired> fired = [];
  late final AudioScheduler scheduler;

  List<int> get indices => [for (final f in fired) f.index];
  List<double> get times => [for (final f in fired) f.atMs];

  /// Advances fake time and the scheduler's clock in lockstep, in steps small
  /// enough that every 5 ms poll lands.
  void advance(FakeAsync async, Duration total) {
    const step = Duration(milliseconds: 5);
    var remaining = total;
    while (remaining > Duration.zero) {
      final slice = remaining < step ? remaining : step;
      clock.advance(slice);
      async.elapse(slice);
      remaining -= slice;
    }
  }
}

void main() {
  // At 60 BPM one beat is exactly 1000 ms, which keeps every expected
  // timestamp in the tests below readable.

  group('AudioScheduler — firing order and placement', () {
    test('fires each offset once, at its beat position', () {
      fakeAsync((async) {
        final rig = _Rig();
        rig.scheduler.setTimeline([0, 1, 2, 3], 4);
        rig.scheduler.start(loop: false);

        rig.advance(async, const Duration(milliseconds: 3500));

        expect(rig.indices, [0, 1, 2, 3]);
        // The offset-0 event fires on the first poll, not at t=0 — the
        // scheduler has no callback before its first tick.
        expect(rig.times, [5, 1000, 2000, 3000]);

        rig.scheduler.dispose();
      });
    });

    test('handles fractional offsets — the 1.5-beat OTTAVI geometry', () {
      fakeAsync((async) {
        final rig = _Rig();
        // Three eighths cells: 1.5 beats each, 4.5 beats total.
        rig.scheduler.setTimeline([0, 1.5, 3.0], 4.5);
        rig.scheduler.start(loop: true);

        rig.advance(async, const Duration(milliseconds: 9000));

        // Two full cycles plus the start of a third, with the loop point at
        // 4500 ms falling between beats rather than on one.
        expect(rig.indices, [0, 1, 2, 0, 1, 2, 0]);
        expect(rig.times, [5, 1500, 3000, 4500, 6000, 7500, 9000]);

        rig.scheduler.dispose();
      });
    });
  });

  group('AudioScheduler — looping', () {
    test('does not drift across many cycles', () {
      fakeAsync((async) {
        // 70 BPM is the tempo every shipped WAV is rendered at, and its beat
        // (857.14 ms) is deliberately *not* a multiple of the 5 ms poll. That
        // matters: at a tempo that divides evenly into the poll this test
        // would pass even for a scheduler that re-anchors the loop origin to
        // the polled time, because there would be no rounding error to
        // accumulate. Here there is one, every single cycle.
        const msPerBeat = 60000 / 70;
        const cycles = 60;

        final rig = _Rig(bpm: 70);
        rig.scheduler.setTimeline([0], 1);
        rig.scheduler.start(loop: true);

        rig.advance(async, const Duration(milliseconds: 52000));

        expect(rig.indices.every((i) => i == 0), isTrue);
        expect(rig.fired.length, greaterThan(cycles));

        // This is the guarantee the class exists for. Each cycle may fire up
        // to one poll late — that is quantization, and it is bounded. What
        // must never happen is the error growing with the cycle count.
        //
        // The bound is inclusive of a whole poll rather than strictly under
        // it: when a cycle boundary lands exactly on a poll tick, the
        // accumulated `_loopStartMs` can sit an ULP below it, so the loop
        // rolls over on the following tick instead. That is a one-off 5 ms
        // shift, not accumulation — the next cycle is back inside the band.
        const pollMs = 5.0;
        var worst = 0.0;
        for (int n = 1; n < cycles; n++) {
          final ideal = n * msPerBeat;
          final lateness = rig.times[n] - ideal;
          if (lateness > worst) worst = lateness;
          expect(lateness, greaterThanOrEqualTo(0));
          expect(lateness, lessThanOrEqualTo(pollMs),
              reason: 'cycle ${n + 1} fired ${lateness.toStringAsFixed(1)} ms '
                  'late — the loop origin is accumulating error');
        }

        // Stated the other way round, so a drifting implementation cannot
        // sneak through on the per-cycle check alone: 60 cycles in, the worst
        // case is still a single poll, not 60 of them.
        expect(worst, lessThanOrEqualTo(pollMs));

        rig.scheduler.dispose();
      });
    });

    test('leaves no gap at the loop point', () {
      fakeAsync((async) {
        final rig = _Rig();
        rig.scheduler.setTimeline([0, 0.5], 1);
        rig.scheduler.start(loop: true);

        rig.advance(async, const Duration(milliseconds: 3000));

        expect(rig.indices, [0, 1, 0, 1, 0, 1, 0]);
        // The first event of each new cycle lands on the cycle boundary
        // itself, not one poll later.
        expect(rig.times, [5, 500, 1000, 1500, 2000, 2500, 3000]);

        rig.scheduler.dispose();
      });
    });

    test('stops at the end when not looping', () {
      fakeAsync((async) {
        final rig = _Rig();
        rig.scheduler.setTimeline([0, 1], 2);
        rig.scheduler.start(loop: false);

        rig.advance(async, const Duration(milliseconds: 5000));

        expect(rig.indices, [0, 1]);
        expect(rig.scheduler.isRunning, isFalse);

        rig.scheduler.dispose();
      });
    });
  });

  group('AudioScheduler — live changes', () {
    test('a tempo change applies from the next poll', () {
      fakeAsync((async) {
        final rig = _Rig();
        rig.scheduler.setTimeline([0, 1], 2);
        rig.scheduler.start(loop: false);

        rig.advance(async, const Duration(milliseconds: 100));
        expect(rig.indices, [0]);

        // Double the tempo: the remaining beat is now 500 ms, so the second
        // event comes due at 500 ms rather than 1000 ms.
        rig.scheduler.bpm = 120;
        rig.advance(async, const Duration(milliseconds: 900));

        expect(rig.indices, [0, 1]);
        expect(rig.times.last, 500);

        rig.scheduler.dispose();
      });
    });

    test('updateTimeline re-seeks instead of replaying the cycle', () {
      fakeAsync((async) {
        final rig = _Rig();
        rig.scheduler.setTimeline([0, 1, 2, 3], 4);
        rig.scheduler.start(loop: true);

        rig.advance(async, const Duration(milliseconds: 1500));
        expect(rig.indices, [0, 1]);

        // Swapping the timeline mid-flight must not re-fire the events the
        // cycle has already passed.
        rig.scheduler.updateTimeline([0, 1, 2, 3], 4);
        rig.advance(async, const Duration(milliseconds: 1000));

        expect(rig.indices, [0, 1, 2]);
        expect(rig.times.last, 2000);

        rig.scheduler.dispose();
      });
    });
  });

  group('AudioScheduler — transport', () {
    test('pause freezes the position and resume continues from it', () {
      fakeAsync((async) {
        final rig = _Rig();
        rig.scheduler.setTimeline([0, 1, 2], 3);
        rig.scheduler.start(loop: false);

        rig.advance(async, const Duration(milliseconds: 1500));
        expect(rig.indices, [0, 1]);

        rig.scheduler.pause();
        expect(rig.scheduler.isPaused, isTrue);

        // Time passing while paused must not advance the sequence.
        rig.advance(async, const Duration(milliseconds: 5000));
        expect(rig.indices, [0, 1]);

        rig.scheduler.start();
        // The third event was 500 ms away when we paused; it stays 500 ms away.
        rig.advance(async, const Duration(milliseconds: 500));

        expect(rig.indices, [0, 1, 2]);

        rig.scheduler.dispose();
      });
    });

    test('stop rewinds, so a restart replays from the top', () {
      fakeAsync((async) {
        final rig = _Rig();
        rig.scheduler.setTimeline([0, 1], 2);
        rig.scheduler.start(loop: false);

        rig.advance(async, const Duration(milliseconds: 1200));
        expect(rig.indices, [0, 1]);

        rig.scheduler.stop();
        expect(rig.scheduler.isRunning, isFalse);
        expect(rig.scheduler.currentBeat, 0);

        rig.scheduler.start(loop: false);
        rig.advance(async, const Duration(milliseconds: 1200));

        expect(rig.indices, [0, 1, 0, 1]);

        rig.scheduler.dispose();
      });
    });

    test('an empty timeline never starts', () {
      fakeAsync((async) {
        final rig = _Rig();
        rig.scheduler.setTimeline([], 0);
        rig.scheduler.start(loop: true);

        rig.advance(async, const Duration(milliseconds: 2000));

        expect(rig.scheduler.isRunning, isFalse);
        expect(rig.fired, isEmpty);

        rig.scheduler.dispose();
      });
    });
  });
}
