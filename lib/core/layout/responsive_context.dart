import 'package:flutter/material.dart';

/// Material's canonical width-class breakpoints — compact (phones),
/// medium (small/portrait tablets), expanded (large tablets/desktop).
enum ScreenTier { compact, medium, expanded }

/// Shared orientation/size helpers so screens don't each re-derive
/// `MediaQuery.of(context).orientation` on their own.
extension ResponsiveContext on BuildContext {
  Orientation get orientation => MediaQuery.orientationOf(this);

  bool get isLandscape => orientation == Orientation.landscape;

  Size get screenSize => MediaQuery.sizeOf(this);

  /// Picks [portrait] or [landscape] based on the current orientation.
  T responsive<T>({required T portrait, required T landscape}) =>
      isLandscape ? landscape : portrait;

  /// The current width class, per Material's 600/840 breakpoints.
  ScreenTier get screenTier {
    final width = screenSize.width;
    if (width >= 840) return ScreenTier.expanded;
    if (width >= 600) return ScreenTier.medium;
    return ScreenTier.compact;
  }

  /// True on tablet-and-larger widths (medium or expanded tier) — the app
  /// should stop treating these like a stretched phone layout.
  bool get isTablet => screenTier != ScreenTier.compact;
}
