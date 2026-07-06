enum RhythmElementType {
  whole,         // Semibreve (4.0 beats)
  half,          // Minima (2.0 beats)
  quarter,       // Semiminima (1.0 beat)
  eighth,        // Croma (0.5 beat)
  sixteenth,     // Semicroma (0.25 beat)
  quarterRest,   // Pausa di semiminima (1.0 beat)
  eighthRest,    // Pausa di croma (0.5 beat)
  sixteenthRest, // Pausa di semicroma (0.25 beat)
  triplet,       // Terzina di crome (1.0 beat total, 3 note da 0.333 ciascuna)
}

class RhythmElement {
  final RhythmElementType type;
  final double duration; // Durata in battiti (es. 1.0, 0.5, 0.25)
  final String noteName; // Pitch per il rendering sul pentagramma (es. 'C4', 'E4', 'G4', 'B4', etc.)
  final List<String> tripletNotes; // Pitch per le tre note se si tratta di una terzina

  RhythmElement({
    required this.type,
    required this.duration,
    this.noteName = 'B4',
    this.tripletNotes = const ['B4', 'B4', 'B4'],
  });

  bool get isRest =>
      type == RhythmElementType.quarterRest ||
      type == RhythmElementType.eighthRest ||
      type == RhythmElementType.sixteenthRest;

  String get displayName {
    switch (type) {
      case RhythmElementType.whole:
        return 'Semibreve (1/1)';
      case RhythmElementType.half:
        return 'Minima (1/2)';
      case RhythmElementType.quarter:
        return 'Semiminima (1/4)';
      case RhythmElementType.eighth:
        return 'Croma (1/8)';
      case RhythmElementType.sixteenth:
        return 'Semicroma (1/16)';
      case RhythmElementType.quarterRest:
        return 'Pausa Semiminima (1/4)';
      case RhythmElementType.eighthRest:
        return 'Pausa Croma (1/8)';
      case RhythmElementType.sixteenthRest:
        return 'Pausa Semicroma (1/16)';
      case RhythmElementType.triplet:
        return 'Terzina';
    }
  }
}

class RhythmMeasure {
  final List<RhythmElement> elements;
  final String timeSignature; // '4/4', '3/4', '6/8'

  RhythmMeasure({
    required this.elements,
    required this.timeSignature,
  });

  double get totalDuration => elements.fold(0.0, (sum, el) => sum + el.duration);
}

class RhythmSlot {
  final String assetPath;
  final List<double> noteDurations; // sub-durations within the 1.0 beat
  final List<bool> isRestList;       // whether each sub-beat is a rest

  RhythmSlot({
    required this.assetPath,
    required this.noteDurations,
    required this.isRestList,
  });

  // Helper to map an asset to its sub-beat notes
  static RhythmSlot fromAsset(String assetPath) {
    final filename = assetPath.split('/').last;

    // Default: single quarter note
    List<double> durations = [1.0];
    List<bool> rests = [false];

    if (filename.contains('15.39.51')) {
      // Single quarter note
      durations = [1.0];
      rests = [false];
    } else if (filename.contains('15.40.22')) {
      // Two eighth notes
      durations = [0.5, 0.5];
      rests = [false, false];
    } else if (filename.contains('15.40.59')) {
      // Four sixteenth notes
      durations = [0.25, 0.25, 0.25, 0.25];
      rests = [false, false, false, false];
    } else if (filename.contains('15.41.33')) {
      // Quarter rest
      durations = [1.0];
      rests = [true];
    } else if (filename.contains('15.43.32')) {
      // Eighth followed by two sixteenths
      durations = [0.5, 0.25, 0.25];
      rests = [false, false, false];
    } else if (filename.contains('15.43.59')) {
      // Two sixteenths followed by eighth
      durations = [0.25, 0.25, 0.5];
      rests = [false, false, false];
    } else if (filename.contains('15.44.26')) {
      // Eighth rest followed by eighth note
      durations = [0.5, 0.5];
      rests = [true, false];
    } else if (filename.contains('15.45.34')) {
      // Dotted eighth note followed by sixteenth
      durations = [0.75, 0.25];
      rests = [false, false];
    } else if (filename.contains('15.45.42')) {
      // Sixteenth note followed by dotted eighth
      durations = [0.25, 0.75];
      rests = [false, false];
    } else if (filename.contains('15.45.48')) {
      // Sixteenth rest followed by dotted eighth note
      durations = [0.25, 0.75];
      rests = [true, false];
    } else if (filename.contains('15.45.55')) {
      // Two sixteenth notes followed by eighth rest
      durations = [0.25, 0.25, 0.5];
      rests = [false, false, true];
    } else if (filename.contains('15.46.35')) {
      // Eighth rest followed by two sixteenth notes
      durations = [0.5, 0.25, 0.25];
      rests = [true, false, false];
    } else if (filename.contains('15.46.58')) {
      // Sixteenth, eighth, sixteenth
      durations = [0.25, 0.5, 0.25];
      rests = [false, false, false];
    } else if (filename.contains('15.47.06')) {
      // Sixteenth rest, sixteenth note, eighth note
      durations = [0.25, 0.25, 0.5];
      rests = [true, false, false];
    } else if (filename.contains('15.47.14')) {
      // Sixteenth rest, eighth note, sixteenth note
      durations = [0.25, 0.5, 0.25];
      rests = [true, false, false];
    } else if (filename.contains('15.47.35')) {
      // Sixteenth rest, two sixteenth notes, sixteenth rest
      durations = [0.25, 0.25, 0.25, 0.25];
      rests = [true, false, false, true];
    } else if (filename.contains('15.47.53')) {
      // Dotted eighth rest followed by sixteenth note
      durations = [0.75, 0.25];
      rests = [true, false];
    } else if (filename.contains('15.48.14')) {
      // Sixteenth rest, sixteenth note, sixteenth rest, sixteenth note
      durations = [0.25, 0.25, 0.25, 0.25];
      rests = [true, false, true, false];
    } else if (filename.contains('15.48.21')) {
      // Triplet of eighth notes
      durations = [1.0 / 3.0, 1.0 / 3.0, 1.0 / 3.0];
      rests = [false, false, false];
    } else if (filename.contains('15.48.27')) {
      // Triplet: croma, pausa croma, croma
      durations = [1.0 / 3.0, 1.0 / 3.0, 1.0 / 3.0];
      rests = [false, true, false];
    } else if (filename.contains('15.48.35')) {
      // Triplet: croma, croma, pausa croma
      durations = [1.0 / 3.0, 1.0 / 3.0, 1.0 / 3.0];
      rests = [false, false, true];
    } else if (filename.contains('15.48.40')) {
      // Triplet: pausa croma, croma, croma
      durations = [1.0 / 3.0, 1.0 / 3.0, 1.0 / 3.0];
      rests = [true, false, false];
    } else if (filename.contains('15.48.45')) {
      // Triplet: croma, pausa croma, pausa croma
      durations = [1.0 / 3.0, 1.0 / 3.0, 1.0 / 3.0];
      rests = [false, true, true];
    } else if (filename.contains('15.48.51')) {
      // Triplet: pausa croma, croma, pausa croma
      durations = [1.0 / 3.0, 1.0 / 3.0, 1.0 / 3.0];
      rests = [true, false, true];
    } else if (filename.contains('15.48.57')) {
      // Triplet: due pause croma, croma
      durations = [1.0 / 3.0, 1.0 / 3.0, 1.0 / 3.0];
      rests = [true, true, false];
    } else if (filename.contains('15.50.31')) {
      // Quintuplet
      durations = [0.2, 0.2, 0.2, 0.2, 0.2];
      rests = [false, false, false, false, false];
    } else if (filename.contains('15.50.38')) {
      // Sextuplet
      durations = [1.0 / 6.0, 1.0 / 6.0, 1.0 / 6.0, 1.0 / 6.0, 1.0 / 6.0, 1.0 / 6.0];
      rests = [false, false, false, false, false, false];
    } else if (filename.contains('15.50.48')) {
      // Septuplet
      durations = [1.0 / 7.0, 1.0 / 7.0, 1.0 / 7.0, 1.0 / 7.0, 1.0 / 7.0, 1.0 / 7.0, 1.0 / 7.0];
      rests = [false, false, false, false, false, false, false];
    } else if (filename.contains('15.51.02')) {
      // Octuplet
      durations = [0.125, 0.125, 0.125, 0.125, 0.125, 0.125, 0.125, 0.125];
      rests = [false, false, false, false, false, false, false, false];
    }

    return RhythmSlot(
      assetPath: assetPath,
      noteDurations: durations,
      isRestList: rests,
    );
  }
}
