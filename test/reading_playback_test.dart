import 'package:flutter_test/flutter_test.dart';
import 'package:beatter/models/rhythm_element.dart';
import 'package:beatter/services/exercise_generation/beat_figurations.dart';
import 'package:beatter/services/rhythm_playback_service.dart';

/// Timeline del Reading Mode: dopo ogni gruppo di N battute l'esecuzione
/// inserisce una finestra di eco della stessa durata con eventi-guida
/// silenziosi e metronomo.
void main() {
  RhythmMeasure measure(List<String> figurationIds) => RhythmMeasure(
        timeSignature: '4/4',
        elements: [
          for (final id in figurationIds)
            ...figurationById(id).toElements('C4'),
        ],
      );

  final measures = [
    measure(['A1', 'B1', 'C1', 'A1']),
    measure(['D1', 'A1', 'B2', 'C4']),
  ];

  test('senza eco la timeline resta identica a prima', () {
    final (events, totalBeats) =
        RhythmPlaybackService.buildTimeline(measures);

    expect(totalBeats, 8.0);
    expect(events.any((e) => e.isEcho), isFalse);
  });

  test('eco ogni battuta: durata doppia e finestre alternate', () {
    final (events, totalBeats) =
        RhythmPlaybackService.buildTimeline(measures, echoEveryMeasures: 1);

    expect(totalBeats, 16.0);

    // Struttura attesa: [play m0: 0-4][eco m0: 4-8][play m1: 8-12][eco m1: 12-16]
    for (final event in events.where((e) => !e.isMetronome)) {
      final bool inEchoWindow = (event.beatOffset >= 4 && event.beatOffset < 8) ||
          event.beatOffset >= 12;
      expect(event.isEcho, inEchoWindow,
          reason: 'evento a beat ${event.beatOffset} nella finestra sbagliata');
      // L'eco della battuta m evidenzia la battuta m stessa.
      expect(event.measureIndex, event.beatOffset < 8 ? 0 : 1);
    }

    // Gli eventi-guida rispecchiano esattamente gli eventi suonati,
    // spostati della durata della battuta.
    final played = events
        .where((e) => !e.isMetronome && !e.isEcho)
        .toList(growable: false);
    final guides =
        events.where((e) => !e.isMetronome && e.isEcho).toList(growable: false);
    expect(guides.length, played.length);
    for (int i = 0; i < played.length; i++) {
      expect(guides[i].beatOffset, closeTo(played[i].beatOffset + 4, 1e-9));
      expect(guides[i].elementIndex, played[i].elementIndex);
      expect(guides[i].tripletIndex, played[i].tripletIndex);
    }

    // Il metronomo continua anche nelle finestre di eco.
    expect(
      events.where((e) => e.isMetronome && e.beatOffset >= 4 && e.beatOffset < 8),
      hasLength(4),
    );
  });

  test('eco ogni 2 battute: gruppo intero poi ripetizione intera', () {
    final (events, totalBeats) =
        RhythmPlaybackService.buildTimeline(measures, echoEveryMeasures: 2);

    expect(totalBeats, 16.0);
    for (final event in events.where((e) => !e.isMetronome)) {
      expect(event.isEcho, event.beatOffset >= 8,
          reason: 'evento a beat ${event.beatOffset}');
    }
  });

  test('un gruppo parziale in coda genera comunque la sua finestra di eco',
      () {
    final three = [...measures, measure(['A1', 'A1', 'B1', 'C3'])];
    final (events, totalBeats) =
        RhythmPlaybackService.buildTimeline(three, echoEveryMeasures: 2);

    // [play m0+m1: 0-8][eco: 8-16][play m2: 16-20][eco m2: 20-24]
    expect(totalBeats, 24.0);
    final tail = events
        .where((e) => !e.isMetronome && e.beatOffset >= 20)
        .toList(growable: false);
    expect(tail, isNotEmpty);
    expect(tail.every((e) => e.isEcho && e.measureIndex == 2), isTrue);
  });

  test('valori di N non validi vengono trattati come 1', () {
    final (_, totalBeats) =
        RhythmPlaybackService.buildTimeline(measures, echoEveryMeasures: 0);
    expect(totalBeats, 16.0);
  });

  test('i bersagli del punteggio sono gli onset non-pausa delle finestre di eco',
      () {
    final withRests = [
      measure(['A1', 'B2', 'C7', 'A2']), // B2/C7 hanno pause interne, A2 è muta
    ];
    final (events, _) = RhythmPlaybackService.buildTimeline(withRests,
        echoEveryMeasures: 1);

    final targets = RhythmPlaybackService.echoTapTargets(events);
    final expected = events
        .where((e) => e.isEcho && !e.isMetronome && !e.isRest)
        .map((e) => e.beatOffset)
        .toList();

    expect(targets, expected);
    // A1 (1) + B2 (1 nota) + C7 (1 nota) + A2 (0) = 3 onset nell'eco.
    expect(targets, hasLength(3));
    // Tutti nella finestra di eco (secondi 4 beat del giro).
    expect(targets.every((t) => t >= 4.0), isTrue);
  });
}
