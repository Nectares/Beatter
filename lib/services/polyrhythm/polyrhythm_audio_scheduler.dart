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

  /// Alloca i pool dei suoni indicati, se non ci sono già.
  ///
  /// I player nascono qui — al cambio di voci attive — e non nel
  /// costruttore: la pagina resta montata nell'IndexedStack della shell,
  /// quindi allocare tutti e sette gli strumenti all'avvio significava
  /// tenere vivi ventun player nativi per una modalità magari mai aperta.
  /// Nemmeno in [trigger]: creare un player sul colpo vorrebbe dire
  /// caricarne la sorgente in ritardo.
  void prime(Iterable<String> soundIds) {
    for (final soundId in soundIds) {
      final asset = _assetBySoundId[soundId];
      if (asset == null || _pools.containsKey(soundId)) continue;
      _pools[soundId] = AudioPlayerPool(assetPath: asset, size: 3)
        ..setVolume(_masterVolume);
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
    final pool = _pools[soundId];
    if (pool != null) {
      pool.play();
      return;
    }
    // Paracadute: una voce mai preparata suona comunque (il primo colpo
    // può arrivare in ritardo) invece di restare muta per sempre.
    prime([soundId]);
    _pools[soundId]?.play();
  }

  void dispose() {
    for (final pool in _pools.values) {
      pool.dispose();
    }
  }
}
