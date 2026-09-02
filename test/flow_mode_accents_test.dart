// Accents on the Flow Mode loop.
//
// An accented beat marks `isAccent` on both the metronome click (which then
// uses the accent sample) and the note on the strong beat (which plays
// through the full-volume pool while the rest is attenuated). The timeline
// half is pure, so it is checked directly; the UI half is the tap that sets
// the accent, which has to survive a regeneration of the rhythm.
import 'dart:math' as math;

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

  group('randomAccentPositions', () {
    test('places exactly the cap, distinct and in range', () {
      final positions = FlowModePage.randomAccentPositions(
        slotCount: 7,
        maxAccents: 3,
        random: math.Random(1),
      );

      expect(positions.length, 3);
      expect(positions.every((i) => i >= 0 && i < 7), isTrue);
    });

    test('never accents more beats than the loop has', () {
      final positions = FlowModePage.randomAccentPositions(
        slotCount: 2,
        maxAccents: 5,
        random: math.Random(2),
      );

      expect(positions.length, 2);
    });

    test('a cap of zero means no accents at all', () {
      expect(
        FlowModePage.randomAccentPositions(slotCount: 4, maxAccents: 0),
        isEmpty,
      );
    });

    test('the positions move around between generations', () {
      final random = math.Random(7);
      final seen = {
        for (var i = 0; i < 20; i++)
          FlowModePage.randomAccentPositions(
            slotCount: 4,
            maxAccents: 1,
            random: random,
          ).single,
      };

      expect(seen.length, greaterThan(1));
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

    int accentedBeat(WidgetTester tester) => List.generate(4, (i) => i)
        .firstWhere((i) => accentOf(i).evaluate().isNotEmpty);

    testWidgets('a generated loop comes out with one accent', (tester) async {
      await pumpFlowMode(tester);

      expect(find.text('>'), findsOneWidget);

      // Regenerating re-rolls the accent with the rhythm — still one, and
      // still inside the loop.
      await tester.tap(find.text('Generate'));
      await tester.pumpAndSettle();
      expect(find.text('>'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping another tile moves the accent when the cap is one',
        (tester) async {
      await pumpFlowMode(tester);
      final int target = (accentedBeat(tester) + 1) % 4;

      await tester.tap(find.byKey(FlowModePage.slotKey(target)));
      await tester.pumpAndSettle();

      expect(accentOf(target), findsOneWidget);
      expect(find.text('>'), findsOneWidget, reason: 'the old accent moved');

      await tester.tap(find.byKey(FlowModePage.slotKey(target)));
      await tester.pumpAndSettle();
      expect(find.text('>'), findsNothing);
    });

    testWidgets('the settings cap decides how many accents a loop carries',
        (tester) async {
      await pumpFlowMode(tester);

      await tester.tap(find.byTooltip('Impostazioni'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final label = find.text('Massimo accenti per giro');
      await tester.scrollUntilVisible(label, 120,
          scrollable: find.byType(Scrollable).last);
      await tester.pump(const Duration(milliseconds: 300));

      final row = find.ancestor(of: label, matching: find.byType(Row)).first;
      final plus = find.descendant(of: row, matching: find.byIcon(Icons.add_rounded));
      await tester.tap(plus);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(plus);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.descendant(of: row, matching: find.text('3')), findsOneWidget);
      expect(find.text('>'), findsNWidgets(3));
    });
  });
}
