enum RhythmElementType {
  whole,         // Semibreve (4.0 beats)
  half,          // Minima (2.0 beats)
  quarter,       // Semiminima (1.0 beat)
  eighth,        // Croma (0.5 beat)
  sixteenth,     // Semicroma (0.25 beat)
  dottedEighth,  // Croma puntata (0.75 beat)
  quarterRest,   // Pausa di semiminima (1.0 beat)
  eighthRest,    // Pausa di croma (0.5 beat)
  sixteenthRest, // Pausa di semicroma (0.25 beat)
  dottedEighthRest, // Pausa di croma puntata (0.75 beat)
  triplet,       // Terzina di crome (1.0 beat total, 3 note da 0.333 ciascuna)
  beatGroup,     // Gruppo da 1 battito (terzine variate, quintine, sestine, biscrome…)
}

class RhythmElement {
  final RhythmElementType type;
  final double duration; // Durata in battiti (es. 1.0, 0.5, 0.25)
  final String noteName; // Pitch per il rendering sul pentagramma (es. 'C4', 'E4', 'G4', 'B4', etc.)
  final List<String> tripletNotes; // Pitch per le tre note se si tratta di una terzina

  // Solo per type == beatGroup: durata (in battiti) e natura di ciascun
  // membro del gruppo, più l'eventuale numero del gruppo irregolare
  // (3 = terzina, 5 = quintina, 6 = sestina; null = nessuna staffa, come
  // per le otto biscrome che riempiono il battito esattamente).
  final List<double> groupDurations;
  final List<bool> groupRests;
  final int? tupletLabel;

  /// Id della figurazione da 1/4 di provenienza (= nome del PNG in
  /// assets/audio/figurazioni_quarti_png): il pentagramma disegna il blocco
  /// come immagine intera del glifo invece di ricomporlo nota per nota.
  final String? figurationId;

  RhythmElement({
    required this.type,
    required this.duration,
    this.noteName = 'B4',
    this.tripletNotes = const ['B4', 'B4', 'B4'],
    this.groupDurations = const [],
    this.groupRests = const [],
    this.tupletLabel,
    this.figurationId,
  });

  bool get isRest =>
      type == RhythmElementType.quarterRest ||
      type == RhythmElementType.eighthRest ||
      type == RhythmElementType.sixteenthRest ||
      type == RhythmElementType.dottedEighthRest;

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
      case RhythmElementType.dottedEighth:
        return 'Croma puntata (3/16)';
      case RhythmElementType.dottedEighthRest:
        return 'Pausa Croma puntata (3/16)';
      case RhythmElementType.triplet:
        return 'Terzina';
      case RhythmElementType.beatGroup:
        return 'Gruppo ritmico (1/4)';
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
