import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'polygon_model.dart';

/// Static catalog for every supported subdivision count (2-8) — the single
/// seam the spec's "make adding more values trivial" requirement points
/// at. Extending the range later means widening [minSubdivisions]/
/// [maxSubdivisions] and adding one entry to each map below; nothing else
/// in the feature hardcodes the 2-8 range.
class SubdivisionModel {
  SubdivisionModel._();

  static const int minSubdivisions = 2;
  static const int maxSubdivisions = 8;

  static List<int> get supportedRange => [
    for (int n = minSubdivisions; n <= maxSubdivisions; n++) n,
  ];

  /// Two extra neon hues beyond the app's three brand accents + semantic
  /// colors, needed because up to 3 simultaneous voices (from a range of
  /// 2-8) can outnumber the brand palette — and `AppColors.error` is
  /// deliberately left free for Practice Mode's "wrong tap" pulse.
  static const Color _violet = Color(0xFFB388FF);
  static const Color _cyan = Color(0xFF33E1E6);

  static const Map<int, String> _shapeNames = {
    2: 'Duo',
    3: 'Triangle',
    4: 'Square',
    5: 'Pentagon',
    6: 'Hexagon',
    7: 'Heptagon',
    8: 'Octagon',
  };

  static const Map<int, Color> _colors = {
    2: AppColors.info,
    3: AppColors.primary,
    4: AppColors.secondary,
    5: AppColors.tertiary,
    6: AppColors.success,
    7: _violet,
    8: _cyan,
  };

  /// Default instrument per subdivision count, per the spec's mapping
  /// (Triangle→Rimshot … Octagon→Shaker), plus Duo→Tom to cover N=2. Keys
  /// into `AudioScheduler`'s sound map and the generated asset basenames
  /// under `assets/audio/polyrhythm/`. This map is the whole "custom sound
  /// pack" hook for future user-assignable instruments.
  static const Map<int, String> _soundIds = {
    2: 'tom',
    3: 'rimshot',
    4: 'closed_hihat',
    5: 'woodblock',
    6: 'cowbell',
    7: 'click',
    8: 'shaker',
  };

  static String shapeName(int n) => _shapeNames[n] ?? '$n-gon';

  static Color colorFor(int n) => _colors[n] ?? AppColors.textSecondary;

  static String soundIdFor(int n) => _soundIds[n] ?? 'click';

  /// Builds a [PolygonModel] for subdivision [n] with default color/sound.
  /// [id] must be unique among the controller's currently active polygons
  /// (callers append a slot index so repeated subdivision counts — e.g. a
  /// hypothetical "4 vs 4" — still key independently in the engine).
  static PolygonModel buildPolygon(int n, {required String id}) {
    return PolygonModel(
      id: id,
      subdivisions: n,
      color: colorFor(n),
      soundId: soundIdFor(n),
      label: shapeName(n),
    );
  }
}

/// A named, quick-select combination of subdivision counts (2-3 voices).
/// Purely a UI convenience over [SubdivisionModel] — selecting one just
/// rebuilds `PolyrhythmController.activePolygons` from [subdivisions].
@immutable
class PolyrhythmPreset {
  final String name;
  final List<int> subdivisions;

  const PolyrhythmPreset(this.name, this.subdivisions);

  static const List<PolyrhythmPreset> all = [
    PolyrhythmPreset('2 : 3', [2, 3]),
    PolyrhythmPreset('3 : 4', [3, 4]),
    PolyrhythmPreset('3 : 5', [3, 5]),
    PolyrhythmPreset('4 : 5', [4, 5]),
    PolyrhythmPreset('5 : 7', [5, 7]),
    PolyrhythmPreset('3 : 4 : 5', [3, 4, 5]),
    PolyrhythmPreset('3 : 5 : 7', [3, 5, 7]),
    PolyrhythmPreset('4 : 5 : 6', [4, 5, 6]),
  ];
}
