import 'package:audioplayers/audioplayers.dart';

/// Preloaded, keyed cache of playback samples (figuration WAVs + metronome).
///
/// Performance is the whole point of this class (see the "Prestazioni"
/// requirement): every asset gets its player(s) prepared **once**, up front.
/// During playback [trigger] only restarts an already prepared player, so there
/// are no runtime asset loads, no disk reads and no per-beat allocations on the
/// audio path.
///
/// Assets can be loaded with more than one voice. A single voice is enough for
/// figurations (consecutive cells are almost always different files, so their
/// decays overlap on separate players). Rapidly **re-triggered** samples — the
/// metronome fires every beat — need a small pool of voices, otherwise
/// `stop()`+`resume()` on one player mid-restart drops clicks. [trigger]
/// round-robins across an asset's voices so every hit lands on an idle player.
class FigurationAudioCache {
  final Map<String, List<AudioPlayer>> _voices = {};
  final Map<String, int> _next = {};
  double _volume = 1.0;
  bool _disposed = false;

  /// Whether [asset] is loaded and ready to [trigger] with zero latency.
  bool isLoaded(String asset) => _voices.containsKey(asset);

  int get loadedCount => _voices.length;

  /// Preloads each asset with [voices] round-robin players, in parallel.
  /// Individual failures are swallowed so one bad file never blocks the rest
  /// (and so headless test environments without an audio backend still finish).
  Future<void> preload(Iterable<String> assets, {int voices = 1}) async {
    await Future.wait(assets.map((a) => _loadOne(a, voices)));
  }

  Future<void> _loadOne(String asset, int voices) async {
    if (_disposed || _voices.containsKey(asset)) return;
    final players = <AudioPlayer>[];
    try {
      for (int i = 0; i < voices; i++) {
        final player = AudioPlayer();
        await player.setReleaseMode(ReleaseMode.stop);
        // A hung setSource must never block the rest of the preload (or, when
        // this asset is loaded before others, the assets queued after it).
        await player
            .setSource(AssetSource(asset))
            .timeout(const Duration(seconds: 5));
        await player.setVolume(_volume);
        players.add(player);
      }
      if (_disposed) {
        await Future.wait(players.map((p) => p.dispose()));
        return;
      }
      _voices[asset] = players;
      _next[asset] = 0;
    } catch (_) {
      // Dispose anything partially created and leave the asset unloaded;
      // trigger() will simply no-op for it.
      for (final p in players) {
        p.dispose();
      }
    }
  }

  /// Fires [asset] immediately on its next voice. Fire-and-forget by design:
  /// awaiting here would add latency to the scheduler's tick. No-op if the
  /// asset is not loaded.
  void trigger(String asset) {
    final players = _voices[asset];
    if (players == null || players.isEmpty) return;
    final index = _next[asset] ?? 0;
    _next[asset] = (index + 1) % players.length;
    final player = players[index];
    // stop()+resume() restarts a decaying/idle player from the top.
    player.stop();
    player.resume();
  }

  /// Master volume applied to every voice (0.0–1.0).
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    await Future.wait(
      _voices.values.expand((v) => v).map((p) => p.setVolume(_volume)),
    );
  }

  Future<void> dispose() async {
    _disposed = true;
    final players = _voices.values.expand((v) => v).toList();
    _voices.clear();
    _next.clear();
    await Future.wait(players.map((p) => p.dispose()));
  }
}
