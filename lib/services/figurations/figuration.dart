/// Real rhythmic figurations shipped under `assets/application/`.
///
/// This is the foundational data layer for figuration-based playback. It is
/// intentionally UI- and audio-agnostic so it can be reused later by Sheet
/// Mode, Reading Mode, Polyrhythm Mode and the Exercises, exactly as planned
/// in `FLOW_AUDIO_ARCHITECTURE.md`.
///
/// A figuration is one complete rhythmic cell that owns:
///  * a WAV rendering of the cell (the only asset used for playback today);
///  * a notation image (PNG) for the tile;
///  * a musical duration expressed in quarter-note beats.
///
/// The WAV files are all authored at a fixed reference tempo (see
/// [referenceBpm]); their on-disk length is the sound's decay, **not** the
/// musical duration. The musical duration is therefore taken from the cell's
/// [FigurationCategory], which the asset folders already encode.
library;

/// Reference tempo (BPM) every shipped WAV was rendered at. Encoded in each
/// file's SMPTE `Tempo` marker. At this tempo consecutive figuration WAVs
/// concatenate seamlessly; away from it they overlap (faster) or leave a small
/// gap (slower) — never drift, because scheduling is always beat-absolute.
const double kFigurationReferenceBpm = 70.0;

/// The rhythmic categories currently available in the asset bundle.
///
/// [folder] is the on-disk category folder under `assets/application/`.
/// [beats] is the fixed musical length of every cell in that category, in
/// quarter-note beats — verified against the bundled MIDI:
///   * `2_4` → all 2.0, `4_4` → all 4.0, `OTTAVI` → all 1.5.
/// (`1_4`'s MIDI is unreliable, so its length comes from the folder alone.)
enum FigurationCategory {
  quarter(folder: '1_4', beats: 1.0),
  half(folder: '2_4', beats: 2.0),
  whole(folder: '4_4', beats: 4.0),
  eighths(folder: 'OTTAVI', beats: 1.5);

  const FigurationCategory({required this.folder, required this.beats});

  /// Category folder name under `assets/application/`.
  final String folder;

  /// Musical length of every cell in this category, in quarter-note beats.
  final double beats;
}

/// One concrete figuration resolved from the asset bundle.
class Figuration {
  const Figuration({
    required this.id,
    required this.category,
    required this.wavAsset,
    required this.imageAsset,
  });

  /// Unique id derived from the WAV filename stem, e.g. `N1_1`, `O26_2`.
  final String id;

  final FigurationCategory category;

  /// Path passed to `AssetSource` (audioplayers strips the leading `assets/`),
  /// e.g. `application/4_4/4_4 WAV/N1_1.wav`.
  final String wavAsset;

  /// Flutter asset key for the notation image (keeps the `assets/` prefix),
  /// e.g. `assets/application/4_4/FIGURAZIONI 4_4/N1.png`.
  final String imageAsset;

  /// Musical length of this figuration, in quarter-note beats.
  double get beats => category.beats;

  @override
  String toString() => 'Figuration($id, ${category.folder}, ${beats}b)';
}
