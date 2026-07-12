// Regression tests for two shell-level behaviors:
//  - the Android system back returns to the first destination (Home)
//    instead of exiting the app from any tab (PopScope in NavigationShell);
//  - Sheet Mode shows the drawer hamburger on phone-sized screens, where
//    the shell's drawer is the only way back to the other destinations.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:beatter/core/di/service_locator.dart';
import 'package:beatter/core/navigation/navigation_shell.dart';
import 'package:beatter/core/navigation/shell_destination.dart';
import 'package:beatter/core/navigation/shell_nav_drawer.dart';
import 'package:beatter/core/navigation/shell_nav_item.dart';
import 'package:beatter/features/music/presentation/pages/sheet_mode_page.dart';
import 'package:beatter/theme/app_theme.dart';

const _destinations = [
  ShellDestination(
    label: 'A',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home_rounded,
    page: Center(child: Text('page-a')),
  ),
  ShellDestination(
    label: 'B',
    icon: Icons.loop_outlined,
    selectedIcon: Icons.loop_rounded,
    page: Center(child: Text('page-b')),
  ),
];

const _navItems = [
  ShellNavItem(label: 'A', icon: Icons.home_outlined, destinationIndex: 0),
  ShellNavItem(label: 'B', icon: Icons.loop_outlined, destinationIndex: 1),
];

void _setScreenSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

/// Simulates the Android system back gesture the way the engine delivers
/// it: a `popRoute` platform message, so the whole PopScope/Navigator
/// chain runs exactly as on device.
Future<void> _systemBack(WidgetTester tester) async {
  final message =
      const JSONMethodCodec().encodeMethodCall(const MethodCall('popRoute'));
  await tester.binding.defaultBinaryMessenger
      .handlePlatformMessage('flutter/navigation', message, (_) {});
  await tester.pumpAndSettle();
}

IndexedStack _stack(WidgetTester tester) =>
    tester.widget<IndexedStack>(find.byType(IndexedStack));

Widget _app({required List<ShellDestination> destinations, required List<ShellNavItem> navItems, int initialIndex = 0}) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    home: NavigationShell(
      destinations: destinations,
      navItems: navItems,
      initialIndex: initialIndex,
      onLogout: () {},
    ),
  );
}

void main() {
  testWidgets('system back returns to the first destination instead of exiting',
      (tester) async {
    _setScreenSize(tester, const Size(400, 800)); // phone chrome
    await tester.pumpWidget(
        _app(destinations: _destinations, navItems: _navItems, initialIndex: 1));
    await tester.pumpAndSettle();
    expect(_stack(tester).index, 1);

    await _systemBack(tester);

    // Back from a non-Home tab selects Home; the shell route is not popped.
    expect(_stack(tester).index, 0);
    expect(find.byType(NavigationShell), findsOneWidget);
  });

  testWidgets('Sheet Mode shows the hamburger on phones and it opens the drawer',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await ServiceLocator.reset();
    ServiceLocator.configureLocal();

    final sheetDestinations = [
      const ShellDestination(
        label: 'Sheet Mode',
        icon: Icons.menu_book_outlined,
        selectedIcon: Icons.menu_book_rounded,
        page: SheetModePage(),
      ),
    ];
    final sheetNavItems = [
      const ShellNavItem(
          label: 'Sheet Mode', icon: Icons.menu_book_outlined, destinationIndex: 0),
    ];

    _setScreenSize(tester, const Size(400, 800)); // phone chrome
    await tester.pumpWidget(
        _app(destinations: sheetDestinations, navItems: sheetNavItems));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.menu_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(ShellNavDrawer), findsOneWidget);
  });
}
