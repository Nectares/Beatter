// What the audio engine actually allocates, and when.
//
// Every mode's page stays mounted in the shell's IndexedStack, so pools
// built in a constructor are native players kept alive for modes the user
// may never open — the thing that hurts on low-end devices. The engine
// therefore allocates on demand, at `prepare`/`updateSettings` time (never
// on the note attack, which is what the pools exist to avoid). These
// numbers are the contract: pool sizes are metronome 2+3, stick 3, snare 4,
// accent twins 2, one pitch 2.
import 'package:flutter_test/flutter_test.dart';
import 'package:beatter/models/rhythm_element.dart';
import 'package:beatter/services/polyrhythm/polyrhythm_audio_scheduler.dart';
import 'package:beatter/services/rhythm_playback_service.dart';

import 'support/audio_plugin_stubs.dart';

const int _metronomePlayers = 5; // accent 2 + click 3

RhythmSlot _slot({bool accented = false}) => RhythmSlot(
      assetPath: 'assets/icon/whatever.png',
      noteDurations: const [1.0],
      isRestList: const [false],
      isAccented: accented,
    );

RhythmMeasure _measure(List<String> pitches) => RhythmMeasure(
      timeSignature: '4/4',
      elements: [
        for (final pitch in pitches)
          RhythmElement(
            type: RhythmElementType.quarter,
            duration: 1.0,
            noteName: pitch,
          ),
      ],
    );

/// Players allocated while running [body]. Services are left undisposed on
/// purpose (see the note in metronome_sound_test.dart), so the count is
/// read as a delta rather than an absolute.
int allocatedBy(void Function() body) {
  final int before = AudioPlayerPool.livePlayers;
  body();
  return AudioPlayerPool.livePlayers - before;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(stubAudioPlugins);

  group('RhythmPlaybackService', () {
    test('a fresh service allocates no players at all', () {
      expect(allocatedBy(() => RhythmPlaybackService()), 0);
      expect(
        allocatedBy(() => RhythmPlaybackService(enableMelodicPlayback: true)),
        0,
        reason: 'nemmeno le 22 altezze del Composer',
      );
    });

    test('a silent Flow Mode loop allocates only the metronome', () {
      final service = RhythmPlaybackService();

      expect(
        allocatedBy(() => service.prepareSlotPlayback([_slot(), _slot()])),
        _metronomePlayers,
      );
    });

    test('the instrument is allocated when it is chosen, once', () {
      final service = RhythmPlaybackService()
        ..prepareSlotPlayback([_slot(), _slot()]);

      expect(
        allocatedBy(() => service.updateSettings(soundInstrument: 'snare')),
        4,
      );
      expect(
        allocatedBy(() => service.updateSettings(soundInstrument: 'snare')),
        0,
        reason: 'i pool si riusano',
      );
      expect(
        allocatedBy(() => service.updateSettings(soundInstrument: 'stick')),
        3,
      );
    });

    test('the accent twin arrives only with an accented pattern', () {
      final service = RhythmPlaybackService()
        ..prepareSlotPlayback([_slot(), _slot()])
        ..updateSettings(soundInstrument: 'stick');

      expect(
        allocatedBy(() => service.prepareSlotPlayback([_slot(), _slot()])),
        0,
      );
      expect(
        allocatedBy(() =>
            service.prepareSlotPlayback([_slot(accented: true), _slot()])),
        2,
      );
    });

    test('melodic playback allocates only the pitches in the piece', () {
      final service = RhythmPlaybackService(enableMelodicPlayback: true)
        ..updateSettings(soundInstrument: 'melodic');

      expect(
        allocatedBy(() => service.preparePlayback([
              _measure(['C4', 'E4', 'C4', 'E4']),
            ])),
        _metronomePlayers + 2 * 2,
        reason: 'due altezze distinte, non tutte e 22',
      );

      expect(
        allocatedBy(() => service.preparePlayback([
              _measure(['C4', 'G4', 'C4', 'C4']),
            ])),
        2,
        reason: 'solo la nuova altezza',
      );
    });

    test('Reading Mode gets its tap pool with the echo windows', () {
      final service = RhythmPlaybackService();

      expect(
        allocatedBy(() => service.preparePlayback(
              [_measure(['B4'])],
              echoEveryMeasures: 1,
            )),
        _metronomePlayers + 3,
        reason: 'metronomo più la bacchetta del pad TAP',
      );
    });
  });

  group('Polyrhythm AudioScheduler', () {
    test('starts empty and allocates the primed voices once', () {
      late AudioScheduler scheduler;

      expect(allocatedBy(() => scheduler = AudioScheduler()), 0);
      expect(allocatedBy(() => scheduler.prime(['tom', 'click'])), 6);
      expect(allocatedBy(() => scheduler.prime(['tom'])), 0);
      expect(allocatedBy(() => scheduler.prime(['nope'])), 0);
    });

    test('an unprimed voice still gets a pool rather than staying mute', () {
      final scheduler = AudioScheduler();

      expect(allocatedBy(() => scheduler.trigger('shaker')), 3);
      expect(allocatedBy(() => scheduler.trigger('shaker')), 0);
    });
  });
}
