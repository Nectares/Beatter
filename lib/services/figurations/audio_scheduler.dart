import 'dart:async';

/// A small, audio-agnostic beat sequencer.
///
/// It owns a monotonic clock ([Stopwatch]) and a sorted list of beat offsets,
/// and calls [onEvent] the instant each offset comes due. It never touches
/// audio itself — the owner decides what an event means (play a WAV, advance a
/// highlight, …) — which is what lets Sheet/Reading/Polyrhythm reuse it later.
///
/// Timing model (ported from the proven Flow Mode loop, kept drift-free):
///  * Events are scheduled in **absolute beats** from the loop origin.
///  * Each poll converts elapsed wall-clock time to a beat position using the
///    live [bpm], so tempo changes take effect continuously.
///  * On loop, the origin is advanced by exactly one cycle length in
///    milliseconds instead of resetting the stopwatch — so no rounding error
///    accumulates across a long session (no drift).
/// Monotonic time source driving [AudioScheduler].
///
/// Production uses [Stopwatch]: it is monotonic, so it is immune to wall-clock
/// adjustments (an NTP correction, the user changing the device clock) that
/// would otherwise shift every scheduled beat. Tests inject a controllable
/// implementation so timing can be asserted deterministically instead of by
/// sleeping in real time.
abstract class SchedulerClock {
  /// Milliseconds elapsed while started, excluding paused spans.
  double get elapsedMs;

  void start();
  void stop();
  void reset();
}

/// The production clock: a plain monotonic [Stopwatch].
class StopwatchClock implements SchedulerClock {
  final Stopwatch _sw = Stopwatch();

  @override
  double get elapsedMs => _sw.elapsedMilliseconds.toDouble();

  @override
  void start() => _sw.start();

  @override
  void stop() => _sw.stop();

  @override
  void reset() => _sw.reset();
}

class AudioScheduler {
  AudioScheduler({
    required this.onEvent,
    this.pollInterval = _defaultPoll,
    SchedulerClock? clock,
  }) : _clock = clock ?? StopwatchClock();

  static const Duration _defaultPoll = Duration(milliseconds: 5);

  /// Called with the index of each event as it fires (index into the timeline
  /// last passed to [setTimeline] / [updateTimeline]).
  final void Function(int eventIndex) onEvent;

  /// Scheduler poll period. 5 ms gives sub-frame trigger accuracy.
  final Duration pollInterval;

  final List<double> _offsets = [];
  double _totalBeats = 0.0;
  bool _loop = true;

  /// Live tempo, in BPM. Applied on the next poll, so it can be changed
  /// mid-playback (a re-tempo shows up on the very next 5 ms tick).
  int bpm = 120;

  bool _running = false;
  bool _paused = false;
  int _nextIndex = 0;
  double _loopStartMs = 0.0;
  final SchedulerClock _clock;
  Timer? _timer;

  bool get isRunning => _running;
  bool get isPaused => _paused;

  double get _msPerBeat => 60000.0 / bpm;

  /// Current position within the loop, in beats. 0 while stopped.
  double get currentBeat {
    if (!_running) return 0.0;
    return (_clock.elapsedMs - _loopStartMs) / _msPerBeat;
  }

  /// Replaces the timeline while stopped (or before the next [start]).
  void setTimeline(List<double> offsets, double totalBeats) {
    _offsets
      ..clear()
      ..addAll(offsets);
    _totalBeats = totalBeats;
    _nextIndex = 0;
  }

  /// Replaces the timeline **without interrupting** a running loop: the clock
  /// keeps ticking and [_nextIndex] is re-seeked to the current position, so a
  /// regenerated sequence slots in seamlessly.
  void updateTimeline(List<double> offsets, double totalBeats) {
    _offsets
      ..clear()
      ..addAll(offsets);
    _totalBeats = totalBeats;
    if (_running && !_paused) {
      final double now = currentBeat;
      _nextIndex = 0;
      while (_nextIndex < _offsets.length && _offsets[_nextIndex] <= now) {
        _nextIndex++;
      }
    } else {
      _nextIndex = 0;
    }
  }

  /// Starts (or resumes) playback. [loop] repeats the timeline forever.
  void start({bool loop = true}) {
    if (_offsets.isEmpty) return;
    if (_running && !_paused) return;

    if (_paused) {
      _paused = false;
      _running = true;
      _clock.start();
      _spawnTimer();
      return;
    }

    _running = true;
    _paused = false;
    _loop = loop;
    _nextIndex = 0;
    _loopStartMs = 0.0;
    _clock
      ..reset()
      ..start();
    _spawnTimer();
  }

  void pause() {
    if (!_running) return;
    _running = false;
    _paused = true;
    _clock.stop();
    _timer?.cancel();
    _timer = null;
  }

  void stop() {
    _running = false;
    _paused = false;
    _timer?.cancel();
    _timer = null;
    _clock
      ..stop()
      ..reset();
    _nextIndex = 0;
    _loopStartMs = 0.0;
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _clock.stop();
  }

  void _spawnTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(pollInterval, (timer) {
      if (!_running) {
        timer.cancel();
        return;
      }

      final double msPerBeat = _msPerBeat;
      final double elapsedMs = _clock.elapsedMs;
      final double beat = (elapsedMs - _loopStartMs) / msPerBeat;

      _fireDueEvents(beat);

      if (beat >= _totalBeats) {
        if (_loop) {
          // Advance the loop origin by exactly one cycle; do not reset the
          // stopwatch, so no drift accumulates. Then immediately fire any
          // events already due at the top of the new cycle to avoid a
          // one-tick gap between cycles.
          _loopStartMs += _totalBeats * msPerBeat;
          _nextIndex = 0;
          final double nextBeat = (elapsedMs - _loopStartMs) / msPerBeat;
          _fireDueEvents(nextBeat);
        } else {
          timer.cancel();
          stop();
        }
      }
    });
  }

  void _fireDueEvents(double beat) {
    while (_nextIndex < _offsets.length && _offsets[_nextIndex] <= beat) {
      onEvent(_nextIndex);
      _nextIndex++;
    }
  }
}
