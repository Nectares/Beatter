import 'dart:math' as math;
import '../models/rhythm_element.dart';

class RhythmGeneratorService {
  static final List<String> _scale = ['E4', 'F4', 'G4', 'A4', 'B4', 'C5', 'D5', 'E5', 'F5'];
  static final math.Random _random = math.Random();

  /// Genera una sequenza di battute ritmiche casuali e matematicamente valide.
  static List<RhythmMeasure> generate({
    required String timeSignature, // '4/4', '3/4', '6/8'
    required int measuresCount,    // Da 1 a 16
    required Map<RhythmElementType, bool> enabledFigures,
  }) {
    // Se l'utente disabilita tutte le figure, forziamo la semiminima come fallback di sicurezza
    final activeFigures = Map<RhythmElementType, bool>.from(enabledFigures);
    if (!activeFigures.values.contains(true)) {
      activeFigures[RhythmElementType.quarter] = true;
    }

    final double targetDuration = _getTargetDuration(timeSignature);
    final List<RhythmMeasure> measures = [];

    for (int m = 0; m < measuresCount; m++) {
      List<RhythmElement>? measureElements;
      int retries = 0;
      
      // Prova a generare una battuta valida fino a 100 volte (backtracking retry)
      while (measureElements == null && retries < 100) {
        measureElements = _tryGenerateMeasure(targetDuration, activeFigures);
        retries++;
      }
      
      // Se dopo 100 tentativi fallisce (configurazione estrema), usiamo un fallback sicuro
      measureElements ??= _generateFallbackMeasure(targetDuration);
      
      measures.add(RhythmMeasure(
        elements: measureElements,
        timeSignature: timeSignature,
      ));
    }

    return measures;
  }

  /// Restituisce la durata totale della battuta espressa in battiti (quarti).
  static double _getTargetDuration(String timeSig) {
    if (timeSig == '4/4') return 4.0;
    if (timeSig == '3/4') return 3.0;
    if (timeSig == '6/8') {
      // In 6/8 ci sono 6 crome. Se 1 croma = 0.5 battiti, allora il totale è 3.0 battiti di crome.
      return 3.0; 
    }
    return 4.0;
  }

  /// Tenta di generare una battuta riempiendo esattamente lo spazio disponibile.
  static List<RhythmElement>? _tryGenerateMeasure(
    double targetDuration,
    Map<RhythmElementType, bool> enabledFigures,
  ) {
    final List<RhythmElement> elements = [];
    double remaining = targetDuration;

    // Margine di precisione float
    while (remaining > 0.001) {
      final candidates = <RhythmElementType>[];
      
      for (final type in RhythmElementType.values) {
        if (enabledFigures[type] == true) {
          final dur = _getDurationForType(type);
          if (dur <= remaining + 0.001) {
            candidates.add(type);
          }
        }
      }

      // Se non ci sono figure che entrano nello spazio rimanente, la battuta è bloccata matematicamente
      if (candidates.isEmpty) {
        return null; 
      }

      // Seleziona casualmente una figura dai candidati validi
      final chosenType = candidates[_random.nextInt(candidates.length)];
      final dur = _getDurationForType(chosenType);

      // Determina altezze casuali per le note per un rendering accattivante e realistico
      final String noteName = _scale[_random.nextInt(_scale.length)];
      final List<String> tripletNotes = [
        _scale[_random.nextInt(_scale.length)],
        _scale[_random.nextInt(_scale.length)],
        _scale[_random.nextInt(_scale.length)],
      ];

      elements.add(RhythmElement(
        type: chosenType,
        duration: dur,
        noteName: noteName,
        tripletNotes: tripletNotes,
      ));

      remaining -= dur;
    }

    return elements;
  }

  /// Restituisce la durata di ciascun tipo di elemento ritmico.
  static double _getDurationForType(RhythmElementType type) {
    switch (type) {
      case RhythmElementType.whole:
        return 4.0;
      case RhythmElementType.half:
        return 2.0;
      case RhythmElementType.quarter:
      case RhythmElementType.quarterRest:
        return 1.0;
      case RhythmElementType.eighth:
      case RhythmElementType.eighthRest:
        return 0.5;
      case RhythmElementType.sixteenth:
      case RhythmElementType.sixteenthRest:
        return 0.25;
      case RhythmElementType.triplet:
        return 1.0; // Una terzina (3 crome terzinate) occupa esattamente 1.0 movimento (quarto)
    }
  }

  /// Genera una battuta di fallback in caso di mancata convergenza dell'algoritmo casuale.
  static List<RhythmElement> _generateFallbackMeasure(double targetDuration) {
    final List<RhythmElement> elements = [];
    double remaining = targetDuration;
    
    while (remaining >= 1.0) {
      elements.add(RhythmElement(type: RhythmElementType.quarter, duration: 1.0, noteName: 'B4'));
      remaining -= 1.0;
    }
    while (remaining >= 0.5) {
      elements.add(RhythmElement(type: RhythmElementType.eighth, duration: 0.5, noteName: 'B4'));
      remaining -= 0.5;
    }
    while (remaining >= 0.25) {
      elements.add(RhythmElement(type: RhythmElementType.sixteenth, duration: 0.25, noteName: 'B4'));
      remaining -= 0.25;
    }
    
    return elements;
  }
}
