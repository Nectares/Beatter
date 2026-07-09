import 'package:flutter/material.dart';

/// Beatter's color roles. A warm, precise palette built around a single
/// confident orange, with a terracotta secondary and a soft gold tertiary
/// for genuine hue differentiation — plus semantic state colors that stay
/// legible against the warm background instead of fighting it.
class AppColors {
  AppColors._();

  // Backgrounds
  static const Color backgroundStart = Color(0xFFFFF8F1);
  static const Color backgroundEnd = Color(0xFFFFF0E0);

  // Surfaces
  static const Color surface = Color(0xFAFFFFFF);
  static const Color surfaceBorder = Color(0xFFFCD5B5);

  // Text
  static const Color textPrimary = Color(0xFF2D2D2D);
  static const Color textSecondary = Color(0xFF666666);
  static const Color textMuted = Color(0xFF999999);

  // Primary — Beatter Orange
  static const Color primary = Color(0xFFFF7A00);
  static const Color onPrimary = Colors.white;
  static const Color primaryContainer = Color(0xFFFFA347);
  static const Color onPrimaryContainer = Color(0xFF2D2D2D);

  // Secondary — terracotta/rust. Genuinely distinct from primary, still
  // in the warm family. Used wherever a second brand hue is needed to tell
  // two things apart (role toggles, alternate accents).
  static const Color secondary = Color(0xFFC1502E);
  static const Color onSecondary = Colors.white;
  static const Color secondaryContainer = Color(0xFFF5DED2);
  static const Color onSecondaryContainer = Color(0xFF2D2D2D);

  // Tertiary — soft gold. Same value as the app's original "accentPink"
  // (which was never actually pink) — kept identical, just correctly named.
  static const Color tertiary = Color(0xFFFFC266);
  static const Color onTertiary = Color(0xFF2D2D2D);
  static const Color tertiaryContainer = Color(0xFFFFEAD1);
  static const Color onTertiaryContainer = Color(0xFF2D2D2D);

  // Semantic state colors
  static const Color error = Color(0xFFEF4444);
  static const Color onError = Colors.white;
  static const Color errorContainer = Color(0xFFFDE2E2);

  static const Color success = Color(0xFF22C55E);
  static const Color onSuccess = Colors.white;

  static const Color warning = Color(0xFFF59E0B);
  static const Color onWarning = Colors.white;

  // The one deliberately non-warm hue — informational cues need to read as
  // categorically different from the brand color, the same way error=red
  // and success=green are fixed by convention.
  static const Color info = Color(0xFF5B7FDB);
  static const Color onInfo = Colors.white;

  static const Color inactiveTrack = Color(0xFFFFEAD6);
}
