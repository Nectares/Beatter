// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'wav_utils.dart';

/// Standalone script (not part of the app runtime) that pre-bakes pitched
/// WAV samples for Composer Mode playback, run once via:
///   dart run lib/services/generate_note_assets.dart
///
/// Only natural notes are generated — the staff's pitch math (see
/// `staff_geometry.dart`) is letter-only and never produces accidentals, so
/// a chromatic set would be pure waste. Range C3–C6 covers the treble staff
/// plus a couple of ledger lines each direction.
const List<String> _letters = ['C', 'D', 'E', 'F', 'G', 'A', 'B'];
const Map<String, int> _semitonesFromC = {
  'C': 0,
  'D': 2,
  'E': 4,
  'F': 5,
  'G': 7,
  'A': 9,
  'B': 11,
};

void main() async {
  print('Inizio generazione asset note...');

  final outputDir = Directory('assets/audio/notes');
  if (!await outputDir.exists()) {
    await outputDir.create(recursive: true);
    print('Directory assets/audio/notes creata.');
  }

  for (int octave = 3; octave <= 6; octave++) {
    for (final letter in _letters) {
      if (octave == 6 && letter != 'C') continue; // stop at C6 inclusive
      final noteName = '$letter$octave';
      final frequency = _frequencyFor(letter, octave);
      await generateNoteTone(
        filePath: 'assets/audio/notes/$noteName.wav',
        frequency: frequency,
      );
    }
  }

  print('Generazione completata con successo!');
}

/// Equal-temperament frequency for a natural note (A4 = 440 Hz reference).
double _frequencyFor(String letter, int octave) {
  final int semitone = _semitonesFromC[letter]!;
  final int midiNote = (octave + 1) * 12 + semitone;
  return 440.0 * math.pow(2.0, (midiNote - 69) / 12.0);
}

/// A gentler, more sustained envelope than the percussion clicks in
/// `generate_audio_assets.dart` — long enough to sound like a held note
/// rather than a transient hit.
Future<void> generateNoteTone({
  required String filePath,
  required double frequency,
}) async {
  const int sampleRate = 44100;
  const double duration = 0.35;
  const double decayRate = 4.0;
  const double amplitude = 22000.0;

  final int numSamples = (sampleRate * duration).round();
  final header = getWavHeader(numSamples, sampleRate);

  final pcmData = Int16List(numSamples);
  for (int i = 0; i < numSamples; i++) {
    final double t = i / sampleRate;
    final double envelope = amplitude * math.exp(-decayRate * t);
    // Fundamental + a couple of gentle harmonics for a less clinical, more
    // note-like timbre than a pure sine.
    final double sampleVal = envelope *
        (math.sin(2.0 * math.pi * frequency * t) +
            0.3 * math.sin(2.0 * math.pi * frequency * 2 * t) +
            0.15 * math.sin(2.0 * math.pi * frequency * 3 * t));
    pcmData[i] = sampleVal.clamp(-32768.0, 32767.0).round();
  }

  final File file = File(filePath);
  final buffer = BytesBuilder();
  buffer.add(header);
  buffer.add(pcmData.buffer.asUint8List());
  await file.writeAsBytes(buffer.toBytes());
  print('Scritto file: $filePath');
}
