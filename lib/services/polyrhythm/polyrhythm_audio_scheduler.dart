import '../rhythm_playback_service.dart' show AudioPlayerPool;

/// Triggers Polyrhythm Lab's instrument sounds. Deliberately dumb: it only
/// knows how to play a `soundId` and hold a master volume — it never reads
/// engine/controller state itself. [PolyrhythmController] is the glue that
/// listens for [PolygonBeatEvent]s and calls [trigger] with the firing
/// polygon's `soundId`.
///
/// This is the feature's whole "modular sound engine" seam: today
/// [_assetBySoundId] is a fixed map to the generated WAVs under
/// `assets/audio/polyrhythm/`; a future user-assignable sound pack is just
/// a different map (or a per-user override merged on top) feeding the same
/// [AudioPlayerPool]-per-instrument model — no engine/controller changes.
class AudioScheduler {
  static const Map<String, String> _assetBySoundId = {
    'tom': 'audio/polyrhythm/tom.wav',
    'rimshot': 'audio/polyrhythm/rimshot.wav',
    'closed_hihat': 'audio/polyrhythm/closed_hihat.wav',
    'woodblock': 'audio/polyrhythm/woodblock.wav',
    'cowbell': 'audio/polyrhythm/cowbell.wav',
    'click': 'audio/polyrhythm/click.wav',
    'shaker': 'audio/polyrhythm/shaker.wav',
  };

  final Map<String, AudioPlayerPool> _pools = {};
  double _masterVolume = 0.85;

  AudioScheduler() {
    for (final entry in _assetBySoundId.entries) {
      final pool = AudioPlayerPool(assetPath: entry.value, size: 3);
      pool.setVolume(_masterVolume);
      _pools[entry.key] = pool;
    }
  }

  double get masterVolume => _masterVolume;

  void setMasterVolume(double volume) {
    _masterVolume = volume.clamp(0.0, 1.0);
    for (final pool in _pools.values) {
      pool.setVolume(_masterVolume);
    }
  }

  void trigger(String soundId) {
    _pools[soundId]?.play();
  }

  void dispose() {
    for (final pool in _pools.values) {
      pool.dispose();
    }
  }
}
