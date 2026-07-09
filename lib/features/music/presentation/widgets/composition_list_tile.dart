import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';

/// A single row for a saved composition or library pattern, shared by
/// Sheet Mode's "Libreria" tab (with [isSelected] for its landscape
/// master/detail split), Sheet Mode's read-only "Le Mie Composizioni" tab,
/// and Composer Mode's Library (which adds a [trailing] menu for
/// rename/duplicate/delete) — one visual language for all three.
class CompositionListTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;
  final IconData icon;
  final bool isSelected;

  const CompositionListTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
    this.icon = Icons.edit_note_rounded,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
            decoration: AppTheme.glassCardDecoration(borderRadius: AppRadius.lg).copyWith(
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.surfaceBorder,
                width: isSelected ? 2 : 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: AppColors.primary),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(subtitle, style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                trailing ??
                    const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
