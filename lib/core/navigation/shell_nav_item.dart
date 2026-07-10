import 'package:flutter/material.dart';

/// One entry in the nav chrome's *displayed* list (drawer on phones, rail
/// on tablets) — a strict superset of [ShellDestination]s: it also
/// includes "coming soon" placeholders that have no page and can't be
/// selected. Keeping this separate from [ShellDestination] means the
/// [IndexedStack] never has to carry pageless placeholder widgets.
@immutable
class ShellNavItem {
  final String label;
  final String? subtitle;
  final IconData icon;
  final IconData? selectedIcon;

  /// Index into [NavigationShell.destinations], or `null` for a "coming
  /// soon" entry that's shown but not selectable.
  final int? destinationIndex;

  const ShellNavItem({
    required this.label,
    this.subtitle,
    required this.icon,
    this.selectedIcon,
    this.destinationIndex,
  });

  bool get isComingSoon => destinationIndex == null;
}
