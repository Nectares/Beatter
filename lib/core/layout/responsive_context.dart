import 'package:flutter/material.dart';

/// Shared orientation/size helpers so screens don't each re-derive
/// `MediaQuery.of(context).orientation` on their own.
extension ResponsiveContext on BuildContext {
  Orientation get orientation => MediaQuery.orientationOf(this);

  bool get isLandscape => orientation == Orientation.landscape;

  Size get screenSize => MediaQuery.sizeOf(this);

  /// Picks [portrait] or [landscape] based on the current orientation.
  T responsive<T>({required T portrait, required T landscape}) =>
      isLandscape ? landscape : portrait;
}
