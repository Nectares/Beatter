// Native marketing screenshots: opens each practice mode on a real
// device/simulator and captures it, for store listings that require
// device-native captures (the day-to-day pipeline uses the faster
// marketing/automation/capture_real_screens.js against the web build).
//
// Run (device/simulator attached):
//   flutter test integration_test/marketing_screenshots_test.dart \
//     --dart-define=FORCE_LOCAL_BACKEND=true
//
// On Android, screenshots also need the driver:
//   flutter drive --driver=integration_test/driver.dart \
//     --target=integration_test/marketing_screenshots_test.dart \
//     --dart-define=FORCE_LOCAL_BACKEND=true
//
// PNGs are reported through the IntegrationTestWidgetsFlutterBinding and
// written by the driver to marketing/screenshots/native/.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:beatter/core/di/service_locator.dart';
import 'package:beatter/main.dart';

Future<void> _capture(
    IntegrationTestWidgetsFlutterBinding binding, WidgetTester tester, String name) async {
  await tester.pumpAndSettle(const Duration(milliseconds: 600));
  await binding.convertFlutterSurfaceToImage();
  await tester.pump();
  await binding.takeScreenshot(name);
}

Future<void> _login(WidgetTester tester) async {
  await tester.pumpAndSettle(const Duration(seconds: 2));
  final fields = find.byType(TextField);
  await tester.enterText(fields.at(0), 'musicista@beatter.com');
  await tester.enterText(fields.at(1), 'Ritmo2026!');
  await tester.tap(find.text('ACCEDI ORA'));
  await tester.pumpAndSettle(const Duration(seconds: 3));
}

Future<void> _openDrawerDestination(WidgetTester tester, String label) async {
  final menu = find.byTooltip('Menu');
  if (menu.evaluate().isNotEmpty) {
    await tester.tap(menu.first);
    await tester.pumpAndSettle();
  }
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle(const Duration(seconds: 2));
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('capture marketing screenshots', (tester) async {
    // Deterministic local backend (no Firebase) — same as FORCE_LOCAL_BACKEND.
    ServiceLocator.reset();
    ServiceLocator.configureLocal();

    await tester.pumpWidget(const BeatterApp());
    await _login(tester);
    await _capture(binding, tester, 'home');

    await tester.tap(find.textContaining('Flow Mode').first);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    final generate = find.text('Generate');
    if (generate.evaluate().isNotEmpty) {
      await tester.tap(generate.first);
      await tester.pumpAndSettle(const Duration(seconds: 2));
    }
    await _capture(binding, tester, 'flow_mode');

    await _openDrawerDestination(tester, 'Polyrhythm Lab');
    await _capture(binding, tester, 'polyrhythm_lab');

    await _openDrawerDestination(tester, 'Sheet Mode');
    await _capture(binding, tester, 'sheet_generator');
    await tester.tap(find.text('Genera Esercizio'));
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await _capture(binding, tester, 'sheet_mode');
  });
}
