// The staff pages read the beat highlight from the engine's listenable.
//
// `RhythmPlaybackService.highlight` moves note by note while the pages'
// own listeners only rebuild on transport changes, so the wiring is easy to
// break without anything failing loudly — the highlight would just stop
// moving. Each page here is played for real and asked which element its
// staff is highlighting.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beatter/features/music/presentation/pages/composer_page.dart';
import 'package:beatter/features/music/presentation/pages/exercise_player_page.dart';
import 'package:beatter/features/music/presentation/pages/sheet_music_viewer_page.dart';
import 'package:beatter/models/composition.dart';
import 'package:beatter/models/rhythm_element.dart';
import 'package:beatter/models/rhythm_exercise.dart';
import 'package:beatter/theme/app_theme.dart';
import 'package:beatter/widgets/music_staff/composer_staff_view.dart';
import 'package:beatter/widgets/music_staff/music_staff_view.dart';
import 'package:beatter/widgets/music_staff/wrapped_staff_view.dart';

import 'support/audio_plugin_stubs.dart';

RhythmMeasure _measure() => RhythmMeasure(
      timeSignature: '4/4',
      elements: [
        for (var i = 0; i < 4; i++)
          RhythmElement(
            type: RhythmElementType.quarter,
            duration: 1.0,
            noteName: 'B4',
          ),
      ],
    );

Future<void> _pump(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(900, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: home));
  await tester.pumpAndSettle();
}

/// Presses play — the shared transport button is an AnimatedIcon, not a
/// plain play glyph — and lets the scheduler fire the events already due.
Future<void> _play(WidgetTester tester) async {
  await tester.tap(find.byType(AnimatedIcon).first);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  setUp(stubAudioPlugins);

  testWidgets('Sheet Mode viewer highlights the element being played',
      (tester) async {
    await _pump(
      tester,
      Scaffold(
        body: SingleChildScrollView(
          child: StaffPlaybackPanel(title: 'Test', measures: [_measure()]),
        ),
      ),
    );

    expect(
      tester.widget<MusicStaffView>(find.byType(MusicStaffView)).activeElementIndex,
      -1,
    );

    await _play(tester);

    expect(
      tester.widget<MusicStaffView>(find.byType(MusicStaffView)).activeElementIndex,
      0,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the exercise player highlights the element being played',
      (tester) async {
    final exercise = RhythmExercise(
      id: '',
      title: 'Esercizio',
      createdAt: DateTime(2026, 1, 1),
      difficultyId: 'facile',
      bpm: 90,
      timeSignature: '4/4',
      measureCount: 1,
      seed: 1,
      measures: [_measure()],
    );

    await _pump(tester, ExercisePlayerPage(exercise: exercise));

    expect(
      tester
          .widget<WrappedStaffView>(find.byType(WrappedStaffView))
          .activeElementIndex,
      -1,
    );

    await _play(tester);

    expect(
      tester
          .widget<WrappedStaffView>(find.byType(WrappedStaffView))
          .activeElementIndex,
      0,
    );

    // I controlli audio stanno nella schermata, non in un pannello a
    // parte: il listener ristretto deve comunque ridisegnarli.
    expect(find.text('100%'), findsNWidgets(2));
    tester
        .widget<Slider>(find.descendant(
          of: find.ancestor(
            of: find.text('Volume metronomo'),
            matching: find.byType(Column),
          ).first,
          matching: find.byType(Slider),
        ))
        .onChanged!(0.4);
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('40%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the composer highlights the element being played',
      (tester) async {
    final composition = Composition(
      id: 'c1',
      title: 'Composizione',
      createdAt: DateTime(2026, 1, 1),
      modifiedAt: DateTime(2026, 1, 1),
      bpm: 90,
      timeSignature: '4/4',
      notes: const [
        ComposedNote(
          pitch: 'C4',
          duration: NoteDuration.quarter,
          measureIndex: 0,
          beatPosition: 0.0,
        ),
        ComposedNote(
          pitch: 'E4',
          duration: NoteDuration.quarter,
          measureIndex: 0,
          beatPosition: 1.0,
        ),
      ],
    );

    await _pump(tester, ComposerPage(existing: composition));

    expect(
      tester
          .widget<ComposerStaffView>(find.byType(ComposerStaffView))
          .activeElementIndex,
      -1,
    );

    await _play(tester);

    expect(
      tester
          .widget<ComposerStaffView>(find.byType(ComposerStaffView))
          .activeElementIndex,
      0,
    );
    expect(tester.takeException(), isNull);
  });
}
