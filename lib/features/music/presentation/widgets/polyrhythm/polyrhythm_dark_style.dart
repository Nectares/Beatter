import 'package:flutter/material.dart';
import '../../../../../theme/app_theme.dart';

/// Polyrhythm Lab's dark, neon-on-black visual language — deliberately
/// kept separate from the shared (warm/light) `AppTheme`, since every
/// other screen in the app stays cream-colored. Mirrors
/// `AppTheme.glassCardDecoration`'s role, but for this one immersive
/// surface. Per-polygon neon colors still come from `SubdivisionModel`
/// (built on the app's real brand hues), so the mode stays on-brand
/// without becoming another light card screen.
class PolyrhythmDarkStyle {
  PolyrhythmDarkStyle._();

  static const Color pureBlack = Color(0xFF050505);
  static const Color graphite = Color(0xFF121317);
  static const Color panelSurface = Color(0xCC101114);
  static const Color panelBorder = Color(0x33FF7A00);
  static const Color textOnDark = Color(0xFFF5F5F5);
  static const Color textOnDarkMuted = Color(0xFF9A9AA0);

  /// Full-bleed canvas background — a very subtle radial bloom rather
  /// than a flat fill, per the spec's "very subtle bloom" note. [graphiteVariant]
  /// is the "Dark Background" toggle: a slightly warmer, lifted-black
  /// alternative to pure black, not a return to the light theme.
  static BoxDecoration backgroundDecoration({required bool graphiteVariant}) =>
      BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.25),
          radius: 1.4,
          colors: graphiteVariant
              ? [graphite, pureBlack]
              : [const Color(0xFF0B0B0C), pureBlack],
        ),
      );

  static BoxDecoration glassPanelDecoration({double radius = AppRadius.xl}) =>
      BoxDecoration(
        color: panelSurface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: panelBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      );
}
