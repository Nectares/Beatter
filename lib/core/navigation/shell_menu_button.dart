import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'shell_visibility.dart';

/// Hamburger button that opens the shell's phone drawer. Self-hiding: on
/// tablet/desktop chrome there is no drawer to open (the rail is always
/// visible instead), so [maybe] returns `null` and callers simply omit it
/// rather than every destination page re-deriving "am I on a small screen"
/// on its own.
class ShellMenuButton extends StatelessWidget {
  const ShellMenuButton({super.key});

  /// Returns the button, or `null` if the shell currently has no drawer.
  static Widget? maybe(BuildContext context) {
    final openDrawer = NavigationShellController.maybeOf(context)?.openDrawer;
    return openDrawer == null ? null : const ShellMenuButton();
  }

  @override
  Widget build(BuildContext context) {
    final openDrawer = NavigationShellController.maybeOf(context)!.openDrawer!;
    return IconButton(
      icon: const Icon(Icons.menu_rounded, color: AppColors.textPrimary, size: 26),
      tooltip: 'Menu',
      onPressed: openDrawer,
    );
  }
}
