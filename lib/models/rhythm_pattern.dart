import 'rhythm_element.dart';

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

  /// Converts this 16-step sequencer pattern into 4/4 [RhythmMeasure]s of
  /// sixteenth notes/rests, so it can be rendered by [MusicStaffView] the
  /// same way any other rhythm content is.
  List<RhythmMeasure> toRhythmMeasures() {
    final measures = <RhythmMeasure>[];
    for (int start = 0; start < beats.length; start += 16) {
      final end = (start + 16).clamp(0, beats.length);
      final elements = <RhythmElement>[];
      for (int i = start; i < end; i++) {
        elements.add(RhythmElement(
          type: beats[i] ? RhythmElementType.sixteenth : RhythmElementType.sixteenthRest,
          duration: 0.25,
          noteName: notes[i],
        ));
      }
      measures.add(RhythmMeasure(elements: elements, timeSignature: '4/4'));
    }
    return measures;
  }
}
