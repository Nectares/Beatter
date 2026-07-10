import 'package:flutter/widgets.dart';

/// Broadcasts whether the nearest [NavigationShell] destination containing
/// this widget is the one currently on-screen.
///
/// Pages inside the shell's `IndexedStack` stay mounted (and keep their
/// state) even while a sibling tab is showing — that's the whole point of
/// using `IndexedStack` instead of `Navigator.pushReplacement`. But a page
/// with a side effect that should only be "live" while actually visible
/// (e.g. [FlowModePage]'s device-orientation lock) can't rely on
/// `initState`/`dispose` anymore, since those now only fire when the shell
/// itself is created/torn down, not on every tab switch. Such pages should
/// read [ShellVisibility.of] from `didChangeDependencies` instead.
class ShellVisibility extends InheritedWidget {
  final bool isActive;

  const ShellVisibility({
    super.key,
    required this.isActive,
    required super.child,
  });

  static bool of(BuildContext context) {
    final widget = context.dependOnInheritedWidgetOfExactType<ShellVisibility>();
    return widget?.isActive ?? true;
  }

  @override
  bool updateShouldNotify(ShellVisibility oldWidget) => isActive != oldWidget.isActive;
}

/// Lets a destination page talk back to the shell — e.g. a "Flow Mode"
/// card on the Home tab selecting the Flow Mode tab, or an `AppBar` opening
/// the phone drawer — without ever touching the [Navigator]. Pushing a
/// second, independent instance of a destination page on top of the shell
/// would silently duplicate it (two separate [State] objects for what the
/// user perceives as one screen); switching the shell's selected index
/// instead just brings the existing instance to the front.
class NavigationShellController extends InheritedWidget {
  final int selectedIndex;
  final ValueChanged<int> selectTab;

  /// Opens the phone drawer, or `null` when the current chrome has no
  /// drawer (tablet/desktop, where the rail is always visible instead).
  /// Pages use this instead of `Scaffold.of(context).openDrawer()` because
  /// they're nested inside their own inner [Scaffold] — the nearest one
  /// from a page's context is never the shell's outer Scaffold that
  /// actually owns the drawer.
  final VoidCallback? openDrawer;

  const NavigationShellController({
    super.key,
    required this.selectedIndex,
    required this.selectTab,
    this.openDrawer,
    required super.child,
  });

  static NavigationShellController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<NavigationShellController>();

  @override
  bool updateShouldNotify(NavigationShellController oldWidget) =>
      selectedIndex != oldWidget.selectedIndex || openDrawer != oldWidget.openDrawer;
}
