// The beat highlight travels on its own listenable.
//
// `RhythmPlaybackService.highlight` exists so a note change repaints the
// tiles instead of the whole page — the page's own listener now only
// rebuilds on play/pause/stop. That split is easy to break silently (the
// highlight simply stops moving), so this drives a real loop through the
// engine and checks the tile that lights up.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beatter/features/music/presentation/pages/flow_mode_page.dart';
import 'package:beatter/theme/app_theme.dart';

import 'support/audio_plugin_stubs.dart';

/// The tile border is what marks the active beat (primary while playing).
Color? _tileBorderColor(WidgetTester tester, int index) {
  final container = tester.widget<AnimatedContainer>(
    find.descendant(
      of: find.byKey(FlowModePage.slotKey(index)),
      matching: find.byType(AnimatedContainer),
    ),
  );
  final decoration = container.decoration as BoxDecoration?;
  return decoration?.border?.top.color;
}

void main() {
  setUp(stubAudioPlugins);

  testWidgets('playing lights up the beat being played', (tester) async {
    tester.view.physicalSize = const Size(411, 891);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.lightTheme, home: const FlowModePage()),
    );
    await tester.pumpAndSettle();

    expect(_tileBorderColor(tester, 0), isNot(AppColors.primary),
        reason: 'da fermi nessuna tessera è attiva');

    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(_tileBorderColor(tester, 0), AppColors.primary);
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

    // Stop clears the highlight along with the transport state.
    await tester.tap(find.byIcon(Icons.pause_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(_tileBorderColor(tester, 0), isNot(AppColors.primary));
    expect(tester.takeException(), isNull);
  });
}
