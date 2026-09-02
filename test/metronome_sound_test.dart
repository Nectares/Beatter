// The metronome's two selectable sounds.
//
// `RhythmPlaybackService` plays the tick from a pair of WAV pools looked up
// by id, so a sound only works if its assets both exist on disk and are
// declared in pubspec.yaml — a missing declaration fails at runtime, when
// the player silently finds nothing to load. This pins that, plus the
// switching contract the settings dropdowns rely on.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beatter/features/music/presentation/pages/flow_mode_page.dart';
import 'package:beatter/features/music/presentation/widgets/metronome_sound_dropdown.dart';
import 'package:beatter/services/rhythm_playback_service.dart';
import 'package:beatter/theme/app_theme.dart';

import 'support/audio_plugin_stubs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('metronome sound catalog', () {
    test('ships the classic click and the Beatter beep', () {
      expect(
        RhythmPlaybackService.metronomeSounds.keys,
        containsAll(<String>['classic', 'beatter']),
      );
      expect(
        RhythmPlaybackService.metronomeSounds
            .containsKey(RhythmPlaybackService.defaultMetronomeSound),
        isTrue,
      );
    });

    test('every sample exists and is declared in pubspec.yaml', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();

      for (final entry in RhythmPlaybackService.metronomeSounds.entries) {
        for (final sample in [entry.value.accent, entry.value.click]) {
          // Pool paths are relative to assets/ (AssetSource prepends it).
          final path = 'assets/$sample';
          expect(File(path).existsSync(), isTrue,
              reason: '${entry.key}: $path non esiste');

          final dir = path.substring(0, path.lastIndexOf('/') + 1);
          expect(pubspec.contains(path) || pubspec.contains('- $dir'), isTrue,
              reason: '${entry.key}: $path non è dichiarato in pubspec.yaml');
        }
      }
    });
  });

  group('switching the metronome sound', () {
    late RhythmPlaybackService service;

    // Deliberately not disposed: audioplayers' `setSource` waits for a
    // "prepared" event that a stubbed platform never sends, and disposing
    // closes that stream, which surfaces a late "Bad state: No element" the
    // runner then blames on whatever test happens to be running. The players
    // are inert stubs and the process exits at the end of the file.
    setUp(() {
      stubAudioPlugins();
      service = RhythmPlaybackService();
    });

    test('starts on the classic click', () {
      expect(service.metronomeSound, RhythmPlaybackService.defaultMetronomeSound);
      expect(service.metronomeSound, 'classic');
    });

    test('updateSettings switches sound and notifies listeners', () {
      var notifications = 0;
      service.addListener(() => notifications++);

      service.updateSettings(metronomeSound: 'beatter');

      expect(service.metronomeSound, 'beatter');
      expect(notifications, 1);
    });

    test('an unknown id is ignored rather than silencing the metronome', () {
      service.updateSettings(metronomeSound: 'beatter');
      service.updateSettings(metronomeSound: 'not-a-sound');

      expect(service.metronomeSound, 'beatter');
    });

    test('leaves the other audio settings alone', () {
      service.updateSettings(bpm: 96, soundInstrument: 'snare');
      service.updateSettings(metronomeSound: 'beatter');

      expect(service.bpm, 96);
      expect(service.soundInstrument, 'snare');
      expect(service.isMetronomeEnabled, isTrue);
    });
  });

  group('volumes', () {
    late RhythmPlaybackService service;

    setUp(() {
      stubAudioPlugins();
      service = RhythmPlaybackService(); // see the note above on dispose
    });

    test('start at the maximum', () {
      expect(service.metronomeVolume, 1.0);
      expect(service.noteVolume, 1.0);
    });

    test('are set independently and notify listeners', () {
      var notifications = 0;
      service.addListener(() => notifications++);

      service.updateSettings(metronomeVolume: 0.4);

      expect(service.metronomeVolume, 0.4);
      expect(service.noteVolume, 1.0, reason: 'le figurazioni non cambiano');
      expect(notifications, 1);

      service.updateSettings(noteVolume: 0.25);
      expect(service.metronomeVolume, 0.4);
      expect(service.noteVolume, 0.25);
    });

    test('are clamped to 0..1', () {
      service.updateSettings(metronomeVolume: 3.0, noteVolume: -1.0);

      expect(service.metronomeVolume, 1.0);
      expect(service.noteVolume, 0.0);
    });
  });

  group('Flow Mode volume sliders', () {
    setUp(stubAudioPlugins);

    Finder sliderFor(String label) => find.descendant(
          of: find.ancestor(of: find.text(label), matching: find.byType(Column))
              .first,
          matching: find.byType(Slider),
        );

    testWidgets('start at 100% and follow the slider', (tester) async {
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

      await tester.tap(find.byTooltip('Impostazioni'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.scrollUntilVisible(find.text('Volume figurazioni'), 120,
          scrollable: find.byType(Scrollable).last);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('100%'), findsNWidgets(2));

      // onChanged is exactly what a drag ends up calling.
      tester.widget<Slider>(sliderFor('Volume metronomo')).onChanged!(0.5);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('50%'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget, reason: 'solo il metronomo');
    });
  });

  group('MetronomeSoundDropdown', () {
    testWidgets('offers both beeps and switches the engine', (tester) async {
      stubAudioPlugins();
      final service = RhythmPlaybackService(); // see the note above on dispose

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Center(
              child: MetronomeSoundDropdown(playbackService: service),
            ),
          ),
        ),
      );

      expect(find.text('🔔 Beep metronomo'), findsOneWidget);

      // Open the menu and pick the Beatter beep. The menu route repeats the
      // items, so the last match is the one on top.
      await tester.tap(find.byType(MetronomeSoundDropdown));
      await tester.pumpAndSettle();
      expect(find.text('✨ Beep Beatter'), findsWidgets);
      await tester.tap(find.text('✨ Beep Beatter').last);
      await tester.pumpAndSettle();

      expect(service.metronomeSound, 'beatter');
    });

    testWidgets('every engine sound has a label', (tester) async {
      for (final id in RhythmPlaybackService.metronomeSounds.keys) {
        expect(MetronomeSoundDropdown.labels[id], isNotNull,
            reason: '$id non ha etichetta nel menù');
      }
    });
  });
}
