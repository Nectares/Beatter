import 'package:flutter/material.dart';
import '../layout/responsive_context.dart';
import 'collapsible_nav_rail.dart';
import 'shell_destination.dart';
import 'shell_nav_drawer.dart';
import 'shell_nav_item.dart';
import 'shell_visibility.dart';

/// The app's single navigation shell: an [IndexedStack] of root destinations
/// plus adaptive chrome — a modal drawer on phones, a collapsible rail on
/// tablets/desktop — that only ever changes which index is selected.
///
/// Every destination page is built exactly once, for the lifetime of this
/// widget, and stays mounted in the tree even while a sibling tab is
/// showing — so switching tabs can never dispose/recreate page state, and
/// can never touch the [Navigator] stack (no push, no pop, no replace).
/// That's deliberate: those two properties are what eliminate the white-
/// screen-on-reselect bug and the state-loss bug at the root, instead of
/// papering over either with a defensive check.
class NavigationShell extends StatefulWidget {
  final List<ShellDestination> destinations;
  final List<ShellNavItem> navItems;
  final int initialIndex;
  final VoidCallback onLogout;

  const NavigationShell({
    super.key,
    required this.destinations,
    required this.navItems,
    required this.onLogout,
    this.initialIndex = 0,
  });

  @override
  State<NavigationShell> createState() => _NavigationShellState();
}

class _NavigationShellState extends State<NavigationShell> {
  late int _selectedIndex;
  bool _railExpanded = true;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // The phone chrome nests the destination stack directly under
  // Scaffold.body; the tablet chrome nests it inside Row > Expanded
  // alongside the rail. Without a GlobalKey, crossing the breakpoint at
  // runtime (a resizable window, a foldable unfolding) would change the
  // stack's position in the tree and Flutter would dispose and recreate
  // it — silently discarding Home/Flow Mode state, the exact bug this
  // shell exists to prevent. The GlobalKey lets Flutter reparent the
  // existing element instead.
  final GlobalKey _stackKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    assert(
      widget.navItems
          .where((item) => !item.isComingSoon)
          .every((item) => item.destinationIndex! >= 0 && item.destinationIndex! < widget.destinations.length),
      'Every non-coming-soon ShellNavItem must point at a valid destination index.',
    );
  }

  void _select(int index) {
    // Bug-3 fix, structurally: re-tapping the current destination is a
    // no-op. There is no route to replace and no stack to touch, so
    // there is nothing that could duplicate.
    if (index == _selectedIndex) return;
    setState(() => _selectedIndex = index);
  }

  void _selectAndCloseDrawer(int index) {
    _select(index);
    _scaffoldKey.currentState?.closeDrawer();
  }

  void _toggleRail() => setState(() => _railExpanded = !_railExpanded);

  @override
  Widget build(BuildContext context) {
    final bool isTabletDevice = context.isTabletDevice;

    final stack = NavigationShellController(
      key: _stackKey,
      selectedIndex: _selectedIndex,
      selectTab: _select,
      openDrawer: isTabletDevice ? null : () => _scaffoldKey.currentState?.openDrawer(),
      child: IndexedStack(
        index: _selectedIndex,
        children: [
          for (int i = 0; i < widget.destinations.length; i++)
            ShellVisibility(
              isActive: i == _selectedIndex,
              child: widget.destinations[i].page,
            ),
        ],
      ),
    );

    final Widget scaffold;
    if (isTabletDevice) {
      scaffold = Scaffold(
        key: _scaffoldKey,
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CollapsibleNavRail(
              navItems: widget.navItems,
              selectedIndex: _selectedIndex,
              onSelect: _select,
              expanded: _railExpanded,
              onToggle: _toggleRail,
              onLogout: widget.onLogout,
            ),
            Expanded(child: stack),
          ],
        ),
      );
    } else {
      scaffold = Scaffold(
        key: _scaffoldKey,
        drawer: ShellNavDrawer(
          navItems: widget.navItems,
          selectedIndex: _selectedIndex,
          onSelect: _selectAndCloseDrawer,
          onLogout: widget.onLogout,
        ),
        body: stack,
      );
    }

    // The shell is the app's root route, so with nothing here the Android
    // system back gesture would exit the app from any tab. Instead, back
    // first returns to the first destination (Home); only from there does
    // it actually leave the app. An open drawer is already handled by the
    // Scaffold itself, which closes it before this PopScope is consulted.
    return PopScope(
      canPop: _selectedIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _select(0);
      },
      child: scaffold,
    );
  }
}
