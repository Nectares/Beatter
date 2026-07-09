import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Beatter's type scale — a full Material [TextTheme] on the platform
/// default font (no custom typeface), replacing the ~40 scattered inline
/// `TextStyle`s that previously existed across the app. Every screen should
/// reach for `Theme.of(context).textTheme.<role>` instead of hand-rolling
/// a `TextStyle`.
class AppTypography {
  AppTypography._();

  static TextStyle _style(double size, FontWeight weight, {double letterSpacing = 0, double? height}) {
    return TextStyle(
      fontSize: size,
      fontWeight: weight,
      letterSpacing: letterSpacing,
      height: height,
      color: AppColors.textPrimary,
    );
  }

  static TextTheme get textTheme => TextTheme(
        // Hero numeric readouts (e.g. a giant BPM digit).
        displayLarge: _style(40, FontWeight.w700, letterSpacing: -0.5),
        displayMedium: _style(32, FontWeight.w700, letterSpacing: -0.25),
        displaySmall: _style(26, FontWeight.w700),

        // Section-level headers.
        headlineLarge: _style(22, FontWeight.w700),
        // AppBar titles.
        headlineMedium: _style(20, FontWeight.w700),
        // Card/dialog/form headings.
        headlineSmall: _style(18, FontWeight.w700),

        // Feature-card / list-tile titles.
        titleLarge: _style(17, FontWeight.w600),
        // Chip labels, secondary titles.
        titleMedium: _style(15, FontWeight.w600),
        // Small emphasized labels (e.g. helper-box headers).
        titleSmall: _style(13, FontWeight.w600, letterSpacing: 0.1),

        // Primary paragraph text.
        bodyLarge: _style(16, FontWeight.w400, height: 1.4),
        // List subtitles, dialog content.
        bodyMedium: _style(14, FontWeight.w400, height: 1.4),
        // Fine print, captions.
        bodySmall: _style(12, FontWeight.w400, height: 1.35),

        // Button labels.
        labelLarge: _style(16, FontWeight.w700, letterSpacing: 1.2),
        // Toast/snackbar text.
        labelMedium: _style(13, FontWeight.w600, letterSpacing: 0.5),
        // Badges, eyebrow/overline-style tags.
        labelSmall: _style(11, FontWeight.w600, letterSpacing: 0.5),
      );
}
