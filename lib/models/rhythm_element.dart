enum RhythmElementType {
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
