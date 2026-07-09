import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';
import '../pages/user_home_page.dart';

import '../pages/flow_mode_page.dart';
import '../pages/sheet_mode_page.dart';
import '../pages/composition_library_page.dart';
import '../../../auth/presentation/pages/login_page.dart';

/// Navigation items for the app drawer.
class _DrawerItem {
  final String label;
  final String subtitle;
  final IconData icon;
  final String emoji;
  final Widget Function()? pageBuilder;
  final bool isComingSoon;

  const _DrawerItem({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.emoji,
    this.pageBuilder,
    this.isComingSoon = false,
  });
}

/// Shared left-side navigation drawer for all logged-in screens.
/// Pass [activeLabel] matching one of the item labels to highlight the
/// current route.
class AppDrawer extends StatelessWidget {
  final String activeLabel;

  const AppDrawer({super.key, required this.activeLabel});

  static const List<_DrawerItem> _items = [
    _DrawerItem(
      label: 'Home',
      subtitle: 'Dashboard principale',
      icon: Icons.home_rounded,
      emoji: '🏠',
      pageBuilder: _buildHome,
    ),
    _DrawerItem(
      label: 'Flow Mode',
      subtitle: 'Allenamento ritmico con loop',
      icon: Icons.loop_rounded,
      emoji: '🔄',
      pageBuilder: _buildFlowMode,
    ),
    _DrawerItem(
      label: 'Rhythm Generator',
      subtitle: 'Letture sul pentagramma',
      icon: Icons.music_note_rounded,
      emoji: '🎼',
      isComingSoon: true,
    ),
    _DrawerItem(
      label: 'Sheet Mode',
      subtitle: 'Trascrizioni e partiture',
      icon: Icons.menu_book_rounded,
      emoji: '📄',
      //pageBuilder: _buildSheetMode,
      isComingSoon: true, // TEMPORARILY DISABLED - Needs to be finished
    ),
    _DrawerItem(
      label: 'Composer Mode',
      subtitle: 'Componi le tue melodie',
      icon: Icons.edit_note_rounded,
      emoji: '✍️',
      //pageBuilder: _buildComposerMode,
      isComingSoon: true, // TEMPORARILY DISABLED - Needs to be finished
    ),
    _DrawerItem(
      label: 'Polyrhythms',
      subtitle: 'Allenamento poliritmico',
      icon: Icons.group_work_rounded,
      emoji: '🥁',
      isComingSoon: true,
    ),
    _DrawerItem(
      label: 'Ear Training',
      subtitle: 'Riconosci accordi e intervalli',
      icon: Icons.hearing_rounded,
      emoji: '👂',
      isComingSoon: true,
    ),
    _DrawerItem(
      label: 'Chord Architect',
      subtitle: 'Crea progressioni armoniche',
      icon: Icons.piano_rounded,
      emoji: '🎹',
      isComingSoon: true,
    ),
    _DrawerItem(
      label: 'Scale Explorer',
      subtitle: 'Esplora scale e arpeggi',
      icon: Icons.music_note_rounded,
      emoji: '🎸',
      isComingSoon: true,
    ),
    _DrawerItem(
      label: 'Drum Sequencer',
      subtitle: 'Sequencer multitraccia',
      icon: Icons.album_rounded,
      emoji: '🥁',
      isComingSoon: true,
    ),
  ];

  static Widget _buildHome() => const UserHomePage();
  static Widget _buildFlowMode() => const FlowModePage();
  // ignore: unused_element
  static Widget _buildSheetMode() => const SheetModePage();
  // ignore: unused_element
  static Widget _buildComposerMode() => const CompositionLibraryPage();

  void _navigate(BuildContext context, _DrawerItem item) {
    if (item.isComingSoon || item.pageBuilder == null) return;
    if (item.label == activeLabel) {
      Navigator.pop(context); // already here
      return;
    }
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => item.pageBuilder!(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 220),
      ),
    );
  }

  void _logout(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

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
                right: BorderSide(
                  color: AppColors.surfaceBorder.withValues(alpha: 0.6),
                  width: 1.5,
                ),
              ),
            ),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ──────────────────────────────────────────────
                  _buildHeader(context),
                  const SizedBox(height: AppSpacing.xs),

                  // ── Divider ─────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    child: Divider(
                      height: 1,
                      color: AppColors.surfaceBorder.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // ── Section label ────────────────────────────────────────
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

                  // ── Nav items ────────────────────────────────────────────
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 0,
                      ),
                      children: _items
                          .map((item) => _buildNavItem(context, item))
                          .toList(),
                    ),
                  ),

                  // ── Footer: Logout ───────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
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
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
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
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.music_note_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: AppSpacing.sm + 2),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Beatter',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  letterSpacing: 0.3,
                ),
              ),
              Text(
                'Rhythm Training',
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, _DrawerItem item) {
    final bool isActive = item.label == activeLabel;
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
            onTap: item.isComingSoon ? null : () => _navigate(context, item),
            splashColor: AppColors.primary.withValues(alpha: 0.1),
            highlightColor: AppColors.primary.withValues(alpha: 0.06),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm + 2, vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                color: isActive ? AppColors.primary.withValues(alpha: 0.12) : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.md + 2),
                border: isActive
                    ? Border.all(color: AppColors.primary.withValues(alpha: 0.25), width: 1.2)
                    : null,
              ),
              child: Row(
                children: [
                  // Icon container
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : AppColors.surfaceBorder.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(AppRadius.sm + 2),
                    ),
                    child: Icon(
                      item.icon,
                      size: 20,
                      color: isActive ? AppColors.primary : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm + 2),
                  // Labels
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.label,
                          style: textTheme.bodyLarge?.copyWith(
                            fontSize: 14,
                            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                            color: isActive ? AppColors.primary : AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          item.subtitle,
                          style: textTheme.bodySmall?.copyWith(
                            color: isActive
                                ? AppColors.primary.withValues(alpha: 0.7)
                                : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Active indicator dot or Soon badge
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
        onTap: () => _logout(context),
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
              Text(
                'Logout',
                style: textTheme.bodyLarge?.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
