import 'package:flutter/foundation.dart';

import 'audio_scheduler.dart';
import 'figuration.dart';
import 'figuration_audio_cache.dart';
import 'figuration_library.dart';
import 'flow_sequence_generator.dart';

/// Sound source for Flow Mode.
enum FlowSoundMode {
  /// Play each figuration's own WAV rendering.
  beatter,

  /// Play nothing; the timeline, metronome and highlight advance identically.
  silence,
}

/// One entry on the merged playback timeline: either a figuration onset or a
/// metronome tick. Kept parallel to the scheduler's offset list.
class _FlowEvent {
  const _FlowEvent.figuration(this.offset, this.figIndex)
      : isMetronome = false,
        isAccent = false;
  const _FlowEvent.metronome(this.offset, this.isAccent)
      : isMetronome = true,
        figIndex = -1;

  final double offset;
  final bool isMetronome;
  final bool isAccent;
  final int figIndex;
}

/// Orchestrates Flow Mode playback on top of the figurations layer.
///
/// A Flow sequence is a chain of "movimenti", each one figuration tile drawn
/// from a single set (1/4 cells or eighths cells, per [ottaveMode]). On top of
/// the figurations runs an optional metronome on the beat grid.
class FlowPlaybackController extends ChangeNotifier {
  // Metronome samples (audioplayers asset form — relative to `assets/`).
  static const String _accentAsset = 'audio/metronome_accent.wav';
  static const String _clickAsset = 'audio/metronome_click.wav';

  static const int kMinBpm = 40;
  static const int kMaxBpm = 180;
  static const int kDefaultBpm = 70;
  static const int kMinCount = 1;
  static const int kMaxCount = 12;

  final FigurationAudioCache _cache = FigurationAudioCache();
  late final AudioScheduler _scheduler = AudioScheduler(onEvent: _onEvent);
  final FlowSequenceGenerator _generator = FlowSequenceGenerator();

  FigurationLibrary? _library;

  bool _ready = false;
  bool _audioReady = false;
  int _bpm = kDefaultBpm;
  bool _ottaveMode = false;
  FlowSoundMode _soundMode = FlowSoundMode.beatter;
  bool _metronomeEnabled = true;
  int _count = 4;

  /// Enabled figuration ids per selectable set (1/4 and eighths).
  final Map<FigurationCategory, Set<String>> _enabled = {
    FigurationCategory.quarter: <String>{},
    FigurationCategory.eighths: <String>{},
  };

  FlowSequence _sequence = FlowSequence.empty;
  List<_FlowEvent> _events = const [];
  int _activeIndex = -1;

  // ── State exposed to the UI ────────────────────────────────────────────
  bool get isReady => _ready;
  bool get isAudioReady => _audioReady;
  int get bpm => _bpm;
  bool get ottaveMode => _ottaveMode;
  FlowSoundMode get soundMode => _soundMode;
  bool get metronomeEnabled => _metronomeEnabled;
  int get count => _count;
  List<PlacedFiguration> get sequence => _sequence.items;
  int get activeIndex => _activeIndex;
  bool get hasSequence => _sequence.items.isNotEmpty;

  bool get isPlaying => _scheduler.isRunning && !_scheduler.isPaused;
  bool get isPaused => _scheduler.isPaused;

  /// The category currently driving generation and the picker.
  FigurationCategory get activeCategory =>
      _ottaveMode ? FigurationCategory.eighths : FigurationCategory.quarter;

  /// Every figuration of the active set, for the settings-sheet picker.
  List<Figuration> get pickerFigurations =>
      _library?.byCategory(activeCategory) ?? const [];

  bool isEnabled(Figuration figuration) =>
      _enabled[figuration.category]?.contains(figuration.id) ?? false;

  /// Loads the library, seeds the picker (all enabled) and generates the first
  /// sequence so tiles appear immediately, then preloads audio in background.
  Future<void> init() async {
    _library = await FigurationLibrary.load();
    for (final category in _enabled.keys) {
      _enabled[category] =
          _library!.byCategory(category).map((f) => f.id).toSet();
    }
    _ready = true;
    _regenerate();
    notifyListeners();

    // Load the metronome FIRST and independently: it must never be starved or
    // delayed behind the 71 figuration players. It is re-triggered every beat,
    // so it gets a small voice pool to avoid dropping clicks on rapid restarts.
    await _cache.preload([_accentAsset, _clickAsset], voices: 3);
    await _cache.preload(_library!.wavAssets);
    _audioReady = true;
    notifyListeners();
  }

  // ── Playback events ────────────────────────────────────────────────────
  void _onEvent(int index) {
    if (index < 0 || index >= _events.length) return;
    final event = _events[index];

    if (event.isMetronome) {
      if (_metronomeEnabled) {
        _cache.trigger(event.isAccent ? _accentAsset : _clickAsset);
      }
      return;
    }

    final items = _sequence.items;
    if (event.figIndex < 0 || event.figIndex >= items.length) return;
    _activeIndex = event.figIndex;
    if (_soundMode == FlowSoundMode.beatter) {
      _cache.trigger(items[event.figIndex].figuration.wavAsset);
    }
    notifyListeners();
  }

  // ── Generation ─────────────────────────────────────────────────────────
  /// The pool the generator draws from: the enabled figurations of the active
  /// set, or the whole set when nothing is enabled.
  List<Figuration> _activePool() {
    final all = pickerFigurations;
    final enabled = all.where(isEnabled).toList();
    return enabled.isEmpty ? all : enabled;
  }

  void generate() => _regenerate();

  void _regenerate() {
    if (_library == null) return;

    _sequence = _generator.generate(count: _count, pool: _activePool());
    _rebuildEvents();
    _activeIndex = -1;

    if (isPlaying) {
      _scheduler.updateTimeline(_offsets(), _sequence.totalBeats);
    } else {
      _scheduler.stop();
      _scheduler.setTimeline(_offsets(), _sequence.totalBeats);
    }
    notifyListeners();
  }

  /// Builds the merged figuration + metronome timeline.
  void _rebuildEvents() {
    final events = <_FlowEvent>[];
    for (int i = 0; i < _sequence.items.length; i++) {
      events.add(_FlowEvent.figuration(_sequence.items[i].beatOffset, i));
    }
    // One click per beat across the whole loop; accent every 4th beat.
    final int beats = _sequence.totalBeats.floor();
    for (int b = 0; b < beats; b++) {
      events.add(_FlowEvent.metronome(b.toDouble(), b % 4 == 0));
    }
    events.sort((a, b) => a.offset.compareTo(b.offset));
    _events = events;
  }

  List<double> _offsets() => [for (final e in _events) e.offset];

  /// Swaps a single figuration in place — offsets unchanged, so the running
  /// loop is not disturbed. The metronome timeline is untouched.
  void autoVary() {
    if (_library == null || _sequence.items.isEmpty) return;
    _sequence = _generator.swapOne(_sequence, _activePool());
    notifyListeners();
  }

  // ── Transport ──────────────────────────────────────────────────────────
  void play() {
    if (_sequence.items.isEmpty) return;
    _scheduler.bpm = _bpm;
    _scheduler.start(loop: true);
    notifyListeners();
  }

  void pause() {
    _scheduler.pause();
    notifyListeners();
  }

  void stop() {
    _scheduler.stop();
    _activeIndex = -1;
    notifyListeners();
  }

  void togglePlay() => isPlaying ? pause() : play();

  // ── Settings ───────────────────────────────────────────────────────────
  set bpm(int value) {
    _bpm = value.clamp(kMinBpm, kMaxBpm);
    _scheduler.bpm = _bpm;
    notifyListeners();
  }

  void setOttaveMode(bool value) {
    if (_ottaveMode == value) return;
    _ottaveMode = value;
    _regenerate();
  }

  void setSoundMode(FlowSoundMode value) {
    if (_soundMode == value) return;
    _soundMode = value;
    notifyListeners();
  }

  void setMetronomeEnabled(bool value) {
    if (_metronomeEnabled == value) return;
    _metronomeEnabled = value;
    notifyListeners();
  }

  void setCount(int value) {
    final clamped = value.clamp(kMinCount, kMaxCount);
    if (_count == clamped) return;
    _count = clamped;
    _regenerate();
  }

  /// Enables/disables a single figuration in its set, then regenerates.
  void toggleEnabled(Figuration figuration) {
    final set = _enabled[figuration.category];
    if (set == null) return;
    if (!set.add(figuration.id)) set.remove(figuration.id);
    _regenerate();
  }

  /// Enables or disables every figuration of the active set at once.
  void setAllEnabled(bool enabled) {
    final set = _enabled[activeCategory];
    if (set == null) return;
    set.clear();
    if (enabled) {
      set.addAll(pickerFigurations.map((f) => f.id));
    }
    _regenerate();
  }

  @override
  void dispose() {
    _scheduler.dispose();
    _cache.dispose();
    super.dispose();
  }
}
