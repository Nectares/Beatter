import '../models/rhythm_pattern.dart';

class PatternRepository {
  static final PatternRepository _instance = PatternRepository._internal();
  factory PatternRepository() => _instance;

  PatternRepository._internal() {
    // Populate defaults
    _patterns.addAll([
      RhythmPattern(
        name: 'Techno Pulse',
        bpm: 128,
        baseFrequency: 440.0,
        beats: [
          true, false, false, false,
          true, false, false, false,
          true, false, false, false,
          true, false, true, false
        ],
        notes: [
          'A4', 'C5', 'A4', 'G4',
          'A4', 'C5', 'D5', 'C5',
          'E5', 'D5', 'C5', 'A4',
          'G4', 'E4', 'G4', 'A4'
        ],
      ),
      RhythmPattern(
        name: 'Cyber Lofi',
        bpm: 85,
        baseFrequency: 293.66, // D4
        beats: [
          true, false, true, false,
          false, false, true, false,
          true, false, false, true,
          false, false, true, false
        ],
        notes: [
          'D4', 'F4', 'A4', 'C5',
          'D5', 'C5', 'A4', 'F4',
          'G4', 'A4', 'F4', 'D4',
          'C4', 'D4', 'F4', 'G4'
        ],
      ),
      RhythmPattern(
        name: 'Neon Arpeggio',
        bpm: 140,
        baseFrequency: 523.25, // C5
        beats: [
          true, true, false, true,
          true, true, false, true,
          true, true, false, true,
          true, true, false, true
        ],
        notes: [
          'C5', 'E5', 'G5', 'B5',
          'C6', 'B5', 'G5', 'E5',
          'D5', 'F#5', 'A5', 'C#6',
          'D6', 'C#6', 'A5', 'F#5'
        ],
      ),
    ]);
  }

  final List<RhythmPattern> _patterns = [];

  List<RhythmPattern> get patterns => List.unmodifiable(_patterns);

  void addPattern(RhythmPattern pattern) {
    // Avoid duplicates by name (overwrite if name matches)
    _patterns.removeWhere((p) => p.name.toLowerCase() == pattern.name.toLowerCase());
    _patterns.add(pattern);
  }
}
