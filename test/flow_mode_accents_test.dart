// Accents on the Flow Mode loop.
//
// An accented beat marks `isAccent` on both the metronome click (which then
// uses the accent sample) and the note on the strong beat (which plays
// through the full-volume pool while the rest is attenuated). The timeline
// half is pure, so it is checked directly; the UI half is the tap that sets
// the accent, which has to survive a regeneration of the rhythm.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beatter/features/music/presentation/pages/flow_mode_page.dart';
import 'package:beatter/models/rhythm_element.dart';
import 'package:beatter/services/rhythm_playback_service.dart';
import 'package:beatter/theme/app_theme.dart';

import 'support/audio_plugin_stubs.dart';

RhythmSlot _slot({
  List<double> durations = const [1.0],
  List<bool> rests = const [false],
  bool accented = false,
}) =>
    RhythmSlot(
      assetPath: 'assets/icon/whatever.png',
      noteDurations: durations,
      isRestList: rests,
      isAccented: accented,
    );

void main() {
  group('buildSlotTimeline', () {
    test('an unaccented loop marks nothing', () {
      final (events, totalBeats) = RhythmPlaybackService.buildSlotTimeline(
        [_slot(), _slot(), _slot(), _slot()],
      );

      expect(totalBeats, 4.0);
      expect(events.any((e) => e.isAccent), isFalse);
    });

    test('an accented beat accents both its click and its downbeat note', () {
      final (events, _) = RhythmPlaybackService.buildSlotTimeline(
        [_slot(accented: true), _slot(), _slot(), _slot()],
      );

      final accented = events.where((e) => e.isAccent).toList();
      expect(accented.length, 2);
      expect(accented.every((e) => e.beatOffset == 0.0), isTrue);
      expect(accented.where((e) => e.isMetronome).length, 1);
      expect(accented.where((e) => !e.isMetronome).length, 1);
    });

    test('only the downbeat of the accented beat is accented', () {
      final (events, _) = RhythmPlaybackService.buildSlotTimeline([
        _slot(
          durations: const [0.25, 0.25, 0.25, 0.25],
          rests: const [false, false, false, false],
          accented: true,
        ),
      ]);

      final notes = events.where((e) => !e.isMetronome).toList();
      expect(notes.length, 4);
      expect(notes.first.isAccent, isTrue);
      expect(notes.skip(1).any((e) => e.isAccent), isFalse);
    });

    test('a rest on the strong beat leaves only the click accented', () {
      final (events, _) = RhythmPlaybackService.buildSlotTimeline([
        _slot(
          durations: const [0.5, 0.5],
          rests: const [true, false],
          accented: true,
        ),
      ]);

      expect(events.where((e) => e.isMetronome && e.isAccent).length, 1);
      expect(events.where((e) => !e.isMetronome && e.isAccent), isEmpty);
    });

    test('accents land on the beats that carry them', () {
      final (events, _) = RhythmPlaybackService.buildSlotTimeline(
        [_slot(), _slot(accented: true), _slot(), _slot(accented: true)],
      );

      expect(
        events
            .where((e) => e.isMetronome && e.isAccent)
            .map((e) => e.beatOffset),
        [1.0, 3.0],
      );
    });
  });

  group('Flow Mode accent taps', () {
    setUp(stubAudioPlugins);

    Future<void> pumpFlowMode(WidgetTester tester) async {
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
    }

    Finder accentOf(int index) => find.descendant(
          of: find.byKey(FlowModePage.slotKey(index)),
          matching: find.text('>'),
        );

    testWidgets('starts with the downbeat accented', (tester) async {
      await pumpFlowMode(tester);

      expect(accentOf(0), findsOneWidget);
      expect(find.text('>'), findsOneWidget);
    });

    testWidgets('tapping a tile toggles that beat accent', (tester) async {
      await pumpFlowMode(tester);

      await tester.tap(find.byKey(FlowModePage.slotKey(2)));
      await tester.pumpAndSettle();
      expect(accentOf(2), findsOneWidget);
      expect(find.text('>'), findsNWidgets(2));

      await tester.tap(find.byKey(FlowModePage.slotKey(2)));
      await tester.pumpAndSettle();
      expect(accentOf(2), findsNothing);
      expect(find.text('>'), findsOneWidget);
    });

    testWidgets('accents stay put when the rhythm is regenerated',
        (tester) async {
      await pumpFlowMode(tester);

      await tester.tap(find.byKey(FlowModePage.slotKey(3)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Generate'));
      await tester.pumpAndSettle();

      expect(accentOf(0), findsOneWidget);
      expect(accentOf(3), findsOneWidget);
      expect(find.text('>'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });
  });
}
