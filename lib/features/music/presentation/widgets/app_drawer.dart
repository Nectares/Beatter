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
                colors: [Color(0xFFFFF8F1), Color(0xFFFFF0E0)],
              ),
              border: Border(
                right: BorderSide(
                  color: AppTheme.cardBorder.withValues(alpha: 0.6),
                  width: 1.5,
                ),
              ),
            ),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ──────────────────────────────────────────────
                  _buildHeader(),
                  const SizedBox(height: 8),

                  // ── Divider ─────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Divider(
                      height: 1,
                      color: AppTheme.cardBorder.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Section label ────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 4,
                    ),
                    child: Text(
                      'STRUMENTI',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.8,
                        color: AppTheme.textMuted.withValues(alpha: 0.9),
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

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primaryPurple, Color(0xFFFFC266)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryPurple.withValues(alpha: 0.35),
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
          const SizedBox(width: 14),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Beatter',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.textPrimary,
                  letterSpacing: 0.3,
                ),
              ),
              Text(
                'Rhythm Training',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Opacity(
        opacity: item.isComingSoon ? 0.6 : 1.0,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: item.isComingSoon ? null : () => _navigate(context, item),
            splashColor: AppTheme.primaryPurple.withValues(alpha: 0.1),
            highlightColor: AppTheme.primaryPurple.withValues(alpha: 0.06),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isActive
                    ? AppTheme.primaryPurple.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                border: isActive
                    ? Border.all(
                        color: AppTheme.primaryPurple.withValues(alpha: 0.25),
                        width: 1.2,
                      )
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
                          ? AppTheme.primaryPurple.withValues(alpha: 0.15)
                          : AppTheme.cardBorder.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      item.icon,
                      size: 20,
                      color: isActive
                          ? AppTheme.primaryPurple
                          : AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Labels
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isActive
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isActive
                                ? AppTheme.primaryPurple
                                : AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          item.subtitle,
                          style: TextStyle(
                            fontSize: 11,
                            color: isActive
                                ? AppTheme.primaryPurple.withValues(alpha: 0.7)
                                : AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Active indicator dot or Soon badge
                  if (item.isComingSoon)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.cardBorder.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: AppTheme.textMuted.withValues(alpha: 0.2),
                        ),
                      ),
                      child: const Text(
                        'Soon',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    )
                  else if (isActive)
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppTheme.primaryPurple,
                        shape: BoxShape.circle,
                      ),
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
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _logout(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.red.withValues(alpha: 0.15), width: 1.2),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  size: 20,
                  color: Colors.redAccent,
                ),
              ),
              const SizedBox(width: 14),
              const Text(
                'Logout',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.redAccent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
