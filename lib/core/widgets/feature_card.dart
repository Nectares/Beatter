import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// A single, consistent "feature entry point" card — used for Home's three
/// primary destinations (Flow Mode, Sheet Mode, Composer Mode) and its
/// "Coming Soon" grid.
///
/// [isAvailable] controls which of the two previously-separate visual
/// languages is used: a bold gradient hero card for real, tappable
/// features, or a visibly muted/badged treatment for stubs — so a feature
/// that isn't wired up yet can no longer look identical to one that is.
/// This widget is purely presentational: it renders whatever [onTap] the
/// caller supplies (e.g. a real navigation, or a "coming soon" toast) —
/// it doesn't decide what tapping an unavailable feature does.
class FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accentColor;
  final VoidCallback onTap;
  final bool isAvailable;

  const FeatureCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.onTap,
    this.isAvailable = true,
  });

  Color _shade(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (!isAvailable) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
            decoration: AppTheme.glassCardDecoration(borderRadius: AppRadius.lg),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: accentColor.withValues(alpha: 0.6), size: 22),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: textTheme.titleLarge?.copyWith(color: AppColors.textSecondary)),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.xxs),
                  decoration: BoxDecoration(
                    color: AppColors.textMuted.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text('Presto', style: textTheme.labelSmall?.copyWith(color: AppColors.textMuted)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [accentColor, _shade(accentColor, 0.12)],
            ),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.30),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: textTheme.titleLarge?.copyWith(color: Colors.white, fontSize: 19)),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      subtitle,
                      style: textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.85)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
