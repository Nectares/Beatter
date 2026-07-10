import 'dart:ui';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'shell_nav_item.dart';

/// Phone navigation chrome: a real, always-modal [Drawer] — opened via
/// [Scaffold.openDrawer] and closed via [Scaffold.closeDrawer], never
/// rendered inline. That distinction matters: a previous version of this
/// drawer was sometimes shown as a permanent inline panel on wide screens,
/// which broke the "close on reselect" tap handler (it called
/// `Navigator.pop`, expecting a modal route to close, and instead popped
/// the current page). This version has exactly one presentation, so that
/// class of bug can't recur.
class ShellNavDrawer extends StatelessWidget {
  final List<ShellNavItem> navItems;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onLogout;

  const ShellNavDrawer({
    super.key,
    required this.navItems,
    required this.selectedIndex,
    required this.onSelect,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: 290,
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.backgroundStart, AppColors.backgroundEnd],
              ),
              border: Border(
                right: BorderSide(color: AppColors.surfaceBorder.withValues(alpha: 0.6), width: 1.5),
              ),
            ),
            // The whole drawer is one scrollable list — including the
            // header and footer — rather than a Column with a fixed
            // header/footer around a scrollable middle section. A fixed
            // header/footer only works as long as their combined height
            // never exceeds the available height; on a short landscape
            // phone combined with a larger system text size, it did
            // ("RenderFlex overflowed... on the bottom"), because there
            // was nothing left to give that extra height to. Making
            // everything scroll together means there is always somewhere
            // for the extra height to go, no matter how extreme the
            // screen size / text scale combination.
            child: SafeArea(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildHeader(context),
                  const SizedBox(height: AppSpacing.xs),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    child: Divider(height: 1, color: AppColors.surfaceBorder.withValues(alpha: 0.8)),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                      vertical: AppSpacing.xxs,
                    ),
                    child: Text(
                      'STRUMENTI',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            letterSpacing: 1.8,
                            color: AppColors.textMuted.withValues(alpha: 0.9),
                          ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(
                      children: [for (final item in navItems) _buildNavItem(context, item)],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    child: Divider(height: 1, color: AppColors.surfaceBorder.withValues(alpha: 0.8)),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                    child: _buildLogoutButton(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.tertiary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppRadius.md),
              boxShadow: [
                BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4)),
              ],
            ),
            child: const Icon(Icons.music_note_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: AppSpacing.sm + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Beatter',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: 0.3),
                ),
                Text(
                  'Rhythm Training',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, ShellNavItem item) {
    final bool isActive = !item.isComingSoon && item.destinationIndex == selectedIndex;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
      child: Opacity(
        opacity: item.isComingSoon ? 0.6 : 1.0,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.md + 2),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.md + 2),
            onTap: item.isComingSoon
                ? null
                : () {
                    onSelect(item.destinationIndex!);
                    Scaffold.of(context).closeDrawer();
                  },
            splashColor: AppColors.primary.withValues(alpha: 0.1),
            highlightColor: AppColors.primary.withValues(alpha: 0.06),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm + 2, vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                color: isActive ? AppColors.primary.withValues(alpha: 0.12) : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.md + 2),
                border: isActive ? Border.all(color: AppColors.primary.withValues(alpha: 0.25), width: 1.2) : null,
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isActive ? AppColors.primary.withValues(alpha: 0.15) : AppColors.surfaceBorder.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(AppRadius.sm + 2),
                    ),
                    child: Icon(
                      isActive ? (item.selectedIcon ?? item.icon) : item.icon,
                      size: 20,
                      color: isActive ? AppColors.primary : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm + 2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodyLarge?.copyWith(
                            fontSize: 14,
                            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                            color: isActive ? AppColors.primary : AppColors.textPrimary,
                          ),
                        ),
                        if (item.subtitle != null)
                          Text(
                            item.subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall?.copyWith(
                              color: isActive ? AppColors.primary.withValues(alpha: 0.7) : AppColors.textMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (item.isComingSoon)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceBorder.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(AppRadius.sm - 2),
                        border: Border.all(color: AppColors.textMuted.withValues(alpha: 0.2)),
                      ),
                      child: Text('Soon', style: textTheme.labelSmall?.copyWith(fontSize: 9)),
                    )
                  else if (isActive)
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.md + 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md + 2),
        onTap: onLogout,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm + 2, vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(AppRadius.md + 2),
            border: Border.all(color: AppColors.error.withValues(alpha: 0.15), width: 1.2),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm + 2),
                ),
                child: const Icon(Icons.logout_rounded, size: 20, color: AppColors.error),
              ),
              const SizedBox(width: AppSpacing.sm + 2),
              Expanded(
                child: Text(
                  'Logout',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyLarge?.copyWith(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.error),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
