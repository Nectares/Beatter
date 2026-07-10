import 'package:flutter/material.dart';

/// One root destination of the app's [NavigationShell] — the small bit of
/// metadata the adaptive nav chrome (bottom bar / rail) needs, plus the
/// page itself. Kept intentionally minimal: destinations only ever change
/// which index is selected, they never carry navigation behavior of their
/// own.
@immutable
class ShellDestination {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget page;

  const ShellDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.page,
  });
}
