import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart' show AssetManifest, rootBundle;

import 'figuration.dart';

/// Index of every [Figuration] present in the asset bundle, grouped by
/// [FigurationCategory].
///
/// The library is built by scanning the runtime asset manifest for the WAV
/// files under `assets/application/<category>/<category> WAV/`. Only cells that
/// actually ship a WAV are included, so missing renderings (e.g. `M2`, `O8`)
/// are simply absent instead of producing silent tiles.
class FigurationLibrary {
  FigurationLibrary._(this._byCategory);

  /// Builds a library directly from figurations, bypassing the asset manifest.
  /// Intended for tests of the generator/scheduler that must not depend on the
  /// bundle.
  @visibleForTesting
  factory FigurationLibrary.fromFigurations(Iterable<Figuration> figurations) {
    final map = <FigurationCategory, List<Figuration>>{
      for (final c in FigurationCategory.values) c: <Figuration>[],
    };
    for (final f in figurations) {
      map[f.category]!.add(f);
    }
    return FigurationLibrary._(map);
  }

  final Map<FigurationCategory, List<Figuration>> _byCategory;

  /// All figurations of [category] (empty if the category ships nothing).
  List<Figuration> byCategory(FigurationCategory category) =>
      _byCategory[category] ?? const [];

  /// Categories that currently have at least one playable figuration.
  Iterable<FigurationCategory> get availableCategories =>
      _byCategory.entries.where((e) => e.value.isNotEmpty).map((e) => e.key);

  bool hasCategory(FigurationCategory category) =>
      byCategory(category).isNotEmpty;

  /// Every figuration in the library, across all categories.
  Iterable<Figuration> get all => _byCategory.values.expand((l) => l);

  /// WAV asset paths (audioplayers form) to hand to the preloading cache.
  Iterable<String> get wavAssets => all.map((f) => f.wavAsset);

  bool get isEmpty => _byCategory.values.every((l) => l.isEmpty);

  /// Builds the library from the runtime asset manifest. Safe to call once at
  /// mode entry; it performs no audio work.
  static Future<FigurationLibrary> load() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final keys = manifest.listAssets();

    final map = <FigurationCategory, List<Figuration>>{
      for (final c in FigurationCategory.values) c: <Figuration>[],
    };

    for (final key in keys) {
      final figuration = _tryParse(key);
      if (figuration != null) {
        map[figuration.category]!.add(figuration);
      }
    }

    for (final list in map.values) {
      list.sort((a, b) => a.id.compareTo(b.id));
    }

    return FigurationLibrary._(map);
  }

  /// Parses an asset manifest key into a [Figuration], or returns null when the
  /// key is not a figuration WAV.
  ///
  /// Expected shape: `assets/application/<folder>/<folder> WAV/<id>.wav`.
  static Figuration? _tryParse(String assetKey) {
    if (!assetKey.endsWith('.wav')) return null;
    if (!assetKey.startsWith('assets/application/')) return null;

    final segments = assetKey.split('/');
    // assets / application / <folder> / <folder> WAV / <file>.wav
    if (segments.length < 5) return null;
    final folder = segments[2];
    final subFolder = segments[3];
    final fileName = segments.last;

    if (!subFolder.endsWith(' WAV')) return null;

    final category = _categoryForFolder(folder);
    if (category == null) return null;

    final id = fileName.substring(0, fileName.length - '.wav'.length);
    final baseName = _figureBaseName(id);

    return Figuration(
      id: id,
      category: category,
      // audioplayers' AssetSource is relative to `assets/`.
      wavAsset: assetKey.substring('assets/'.length),
      imageAsset:
          'assets/application/$folder/FIGURAZIONI $folder/$baseName.png',
    );
  }

  static FigurationCategory? _categoryForFolder(String folder) {
    for (final c in FigurationCategory.values) {
      if (c.folder == folder) return c;
    }
    return null;
  }

  /// Strips the WAV variant suffix (`_1`, `_2`, …) so the figure maps to its
  /// notation image, e.g. `O26_2` → `O26`, `N1_1` → `N1`.
  static String _figureBaseName(String id) {
    final underscore = id.lastIndexOf('_');
    if (underscore <= 0) return id;
    final suffix = id.substring(underscore + 1);
    final isNumeric = suffix.isNotEmpty && int.tryParse(suffix) != null;
    return isNumeric ? id.substring(0, underscore) : id;
  }
}
