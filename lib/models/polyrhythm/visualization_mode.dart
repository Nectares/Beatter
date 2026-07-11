/// The visual styles Polyrhythm Lab can render the same underlying
/// [PolygonModel] list in. Purely a rendering choice — it never affects
/// timing or audio, only which shape `PolygonRenderer` draws. Both modes
/// share the same static, concentric layout and the same moving-marker
/// mechanic (see `PolyrhythmGeometry`) — they only differ in whether a
/// voice is drawn as a straight-edged polygon or a circle.
enum VisualizationMode {
  /// Triangle inside square inside pentagon... — concentric, transparent
  /// fill, neon outline. A white marker travels along the straight edges.
  nested,

  /// Concentric rings, one per voice, with N evenly spaced tick marks.
  /// A white marker travels around the circumference.
  circular;

  String get label => switch (this) {
    VisualizationMode.nested => 'Polygons',
    VisualizationMode.circular => 'Circles',
  };
}
