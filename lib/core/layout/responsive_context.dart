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

  /// Orientation-independent device class, based on the *shortest* side of
  /// the screen. Unlike [screenTier]/[isTablet] (which reflect the current
  /// window width and deliberately reclassify a rotated phone as "medium"
  /// width), this stays stable across rotation — a phone is a phone in
  /// both portrait and landscape. Used to pick navigation chrome: phones
  /// keep bottom navigation in both orientations, tablets get the
  /// collapsible navigation rail in both orientations.
  bool get isTabletDevice => MediaQuery.sizeOf(this).shortestSide >= 600;
}
