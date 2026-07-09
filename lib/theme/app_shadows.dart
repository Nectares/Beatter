import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Shared elevation presets. `card` mixes only a warm-tinted glow (matches
/// the app's original glass-card shadow exactly). `raised`/`floating` add a
/// neutral black ambient shadow on top — a single-hue shadow reads flat at
/// higher elevation, real depth needs a neutral component too.
class AppShadows {
  AppShadows._();

  static List<BoxShadow> get card => [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.06),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ];

  static List<BoxShadow> get raised => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 20,
          offset: const Offset(0, 6),
        ),
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.08),
          blurRadius: 28,
          offset: const Offset(0, 14),
        ),
      ];

  static List<BoxShadow> get floating => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.10),
          blurRadius: 32,
          offset: const Offset(0, 10),
        ),
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.10),
          blurRadius: 40,
          offset: const Offset(0, 18),
        ),
      ];
}
