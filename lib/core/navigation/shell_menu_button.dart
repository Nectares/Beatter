import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'shell_visibility.dart';

/// Hamburger button that opens the shell's phone drawer. Self-hiding: on
/// tablet/desktop chrome there is no drawer to open (the rail is always
/// visible instead), so [maybe] returns `null` and callers simply omit it
/// rather than every destination page re-deriving "am I on a small screen"
/// on its own.
class ShellMenuButton extends StatelessWidget {
  final Color color;

  const ShellMenuButton({super.key, this.color = AppColors.textPrimary});

  /// Returns the button, or `null` if the shell currently has no drawer.
  /// [color] lets dark-canvas destinations (e.g. Polyrhythm Lab) keep the
  /// hamburger legible instead of the default dark-on-light icon color.
  static Widget? maybe(BuildContext context, {Color color = AppColors.textPrimary}) {
    final openDrawer = NavigationShellController.maybeOf(context)?.openDrawer;
    return openDrawer == null ? null : ShellMenuButton(color: color);
  }

  @override
  Widget build(BuildContext context) {
    final openDrawer = NavigationShellController.maybeOf(context)!.openDrawer!;
    return IconButton(
      icon: Icon(Icons.menu_rounded, color: color, size: 26),
      tooltip: 'Menu',
      onPressed: openDrawer,
    );
  }
}
