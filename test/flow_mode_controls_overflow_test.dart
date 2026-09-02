// Regression test for the Flow Mode controls bar growing taller than it
// should — the sibling of shell_nav_drawer_overflow_test.dart and
// collapsible_nav_rail_overflow_test.dart.
//
// The bar's two stepper value labels (slot count, BPM) live in fixed-width
// boxes that were sized for the default text scale, and neither Text set
// maxLines/softWrap. A value too wide for its box therefore wrapped onto a
// second line, which made the whole controls bar taller — and since the
// tile grid above it is Expanded, the grid shrank and relaid out purely
// because the tempo changed. Three digits fit at the default scale, but a
// large system text scale reproduces it for real, so this pins both the
// bar's height and the grid's bottom edge across value and text-scale
// changes, plus a plain no-overflow sweep over realistic phone/tablet
// sizes.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beatter/features/music/presentation/pages/flow_mode_page.dart';
import 'package:beatter/theme/app_theme.dart';

/// The page builds a [RhythmPlaybackService], which eagerly creates
/// audioplayers instances; without stub handlers those platform calls throw
/// MissingPluginException and fail the test for reasons unrelated to layout.
void _stubAudioPlayers() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  for (final channel in const [
    MethodChannel('xyz.luan/audioplayers'),
    MethodChannel('xyz.luan/audioplayers.global'),
  ]) {
    messenger.setMockMethodCallHandler(channel, (call) async => null);
  }
}

Future<void> _pumpFlowMode(
  WidgetTester tester,
  Size size, {
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: const FlowModePage(),
    ),
  );
  await tester.pumpAndSettle();
}

/// Drives the quick speed slider the way the user does, without having to
/// hit a pixel: [Slider.onChanged] is exactly what a drag ends up calling.
Future<void> _setBpm(WidgetTester tester, double bpm) async {
  tester.widget<Slider>(find.byType(Slider).first).onChanged!(bpm);
  await tester.pumpAndSettle();
}

void main() {
  setUp(_stubAudioPlayers);

  testWidgets(
      'controls bar height is stable across value changes at textScale 2.0',
      (tester) async {
    await _pumpFlowMode(tester, const Size(411, 891), textScale: 2.0);

    // Baseline at a two-digit tempo: the digit count is exactly what used to
    // decide whether the label fit its box on one line.
    await _setBpm(tester, 90);
    final bar = find.byKey(FlowModePage.controlsBarKey);
    final double barHeight = tester.getSize(bar).height;
    // The bar's top edge is the grid area's bottom edge: if the bar grows,
    // the Expanded grid above it shrinks by the same amount.
    final double gridBottom = tester.getTopLeft(bar).dy;
    final double labelHeight = tester.getSize(find.text('90')).height;

    // Three digits — the tempo that used to wrap inside the 36px box.
    await _setBpm(tester, 180);
    expect(find.text('180'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.text('180')).height, labelHeight,
        reason: 'bpm 180 label wrapped to a second line');
    expect(tester.getSize(bar).height, barHeight, reason: 'bpm 180');
    expect(tester.getTopLeft(bar).dy, gridBottom, reason: 'bpm 180');

    // …and the widest tempo the slider can reach.
    await _setBpm(tester, 240);
    expect(tester.getSize(find.text('240')).height, labelHeight,
        reason: 'bpm 240 label wrapped to a second line');
    expect(tester.getSize(bar).height, barHeight, reason: 'bpm 240');
    expect(tester.getTopLeft(bar).dy, gridBottom, reason: 'bpm 240');

    // Slot count driven to its maximum (7) through the stepper's + button.
    for (var i = 0; i < 10 && find.text('7').evaluate().isEmpty; i++) {
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();
    }
    expect(find.text('7'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(tester.getSize(bar).height, barHeight, reason: 'max slot count');
    expect(tester.getTopLeft(bar).dy, gridBottom, reason: 'max slot count');
  });

  final sizes = <String, Size>{
    '320x568 portrait (iPhone SE)': const Size(320, 568),
    '411x891 portrait (Medium Phone)': const Size(411, 891),
    '800x1280 portrait (tablet)': const Size(800, 1280),
    '640x360 short landscape': const Size(640, 360),
    '1024x768 landscape (tablet)': const Size(1024, 768),
  };

  for (final entry in sizes.entries) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('renders without overflow at ${entry.key}, textScale $scale',
          (tester) async {
        await _pumpFlowMode(tester, entry.value, textScale: scale);
        expect(tester.takeException(), isNull, reason: 'initial');

        await _setBpm(tester, 180);
        expect(tester.takeException(), isNull, reason: 'bpm 180');
      });
    }
  }
}
