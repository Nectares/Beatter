class RhythmPattern {
  final String name;
  final int bpm;
  final double baseFrequency;
  final List<bool> beats; // 16 steps
  final List<String> notes; // 16 musical notes corresponding to steps

  RhythmPattern({
    required this.name,
    required this.bpm,
    required this.baseFrequency,
    required this.beats,
    required this.notes,
  });

  RhythmPattern copyWith({
    String? name,
    int? bpm,
    double? baseFrequency,
    List<bool>? beats,
    List<String>? notes,
  }) {
    return RhythmPattern(
      name: name ?? this.name,
      bpm: bpm ?? this.bpm,
      baseFrequency: baseFrequency ?? this.baseFrequency,
      beats: beats ?? List<bool>.from(this.beats),
      notes: notes ?? List<String>.from(this.notes),
    );
  }
}
