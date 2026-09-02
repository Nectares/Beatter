// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'wav_utils.dart';

/// Generatore degli asset audio "di sistema" (metronomo, bacchetta,
/// rullante, beep). Non fa parte del runtime dell'app.
///
/// `dart run lib/services/generate_audio_assets.dart` rigenera tutto;
/// passando uno o più nomi ne rigenera solo una parte, utile per aggiungere
/// un suono nuovo senza riscrivere (e quindi far cambiare byte a) quelli
/// già in repo — il rullante in particolare parte da rumore casuale e non è
/// riproducibile bit per bit.
///
/// Esempio: `dart run lib/services/generate_audio_assets.dart beatter_beep_accent beatter_beep_click`
void main(List<String> args) async {
  final outputDir = Directory('assets/audio');
  if (!await outputDir.exists()) {
    await outputDir.create(recursive: true);
    print('Directory assets/audio creata.');
  }

  final generators = <String, Future<void> Function()>{
    // Metronomo "classico": seno puro, accento più grave e lungo del click.
    'metronome_accent': () => generateTone(
          filePath: 'assets/audio/metronome_accent.wav',
          frequency: 1000.0,
          duration: 0.1,
          amplitude: 30000.0,
          decayRate: 15.0,
        ),
    'metronome_click': () => generateTone(
          filePath: 'assets/audio/metronome_click.wav',
          frequency: 800.0,
          duration: 0.08,
          amplitude: 25000.0,
          decayRate: 25.0,
        ),

    // Beep "Beatter": stessa funzione del metronomo (accento + click) ma
    // timbro digitale invece che seno puro — armoniche dispari smorzate e
    // una breve caduta di intonazione, così i due metronomi restano
    // distinguibili anche a colpo d'orecchio. Do6 / Sol5, quarta giusta.
    'beatter_beep_accent': () => generateBeep(
          filePath: 'assets/audio/beatter_beep_accent.wav',
          frequency: 1046.5,
          duration: 0.1,
          amplitude: 29000.0,
          decayRate: 26.0,
          pitchDrop: 0.06,
        ),
    'beatter_beep_click': () => generateBeep(
          filePath: 'assets/audio/beatter_beep_click.wav',
          frequency: 784.0,
          duration: 0.075,
          amplitude: 24000.0,
          decayRate: 34.0,
          pitchDrop: 0.04,
        ),

    'stick': () => generateTone(
          filePath: 'assets/audio/stick.wav',
          frequency: 1400.0,
          duration: 0.04,
          amplitude: 28000.0,
          decayRate: 60.0,
        ),
    'snare': () => generateSnare(
          filePath: 'assets/audio/snare.wav',
          duration: 0.2,
        ),
  };

  final selected = args.isEmpty ? generators.keys.toList() : args;
  final unknown = selected.where((name) => !generators.containsKey(name));
  if (unknown.isNotEmpty) {
    print('Asset sconosciuti: ${unknown.join(', ')}');
    print('Disponibili: ${generators.keys.join(', ')}');
    exitCode = 64; // EX_USAGE
    return;
  }

  print('Inizio generazione asset audio (${selected.join(', ')})...');
  for (final name in selected) {
    await generators[name]!();
  }
  print('Generazione completata con successo!');
}

/// Beep digitale: fondamentale + armoniche dispari smorzate, attacco con
/// rampa di 1.5 ms (senza, il salto da zero fa un "tac" udibile) e una
/// leggera caduta di intonazione di [pitchDrop] (frazione della frequenza)
/// lungo il decadimento. [amplitude] è il picco finale, non l'ampiezza
/// prima della somma delle armoniche.
Future<void> generateBeep({
  required String filePath,
  required double frequency,
  required double duration,
  required double amplitude,
  required double decayRate,
  required double pitchDrop,
}) async {
  const int sampleRate = 44100;
  const double attack = 0.0015;
  final int numSamples = (sampleRate * duration).round();
  final header = getWavHeader(numSamples, sampleRate);

  final samples = Float64List(numSamples);
  // Fase integrata a mano: la frequenza cambia nel tempo, quindi
  // sin(2*pi*f*t) darebbe discontinuità.
  double phase = 0.0;
  for (int i = 0; i < numSamples; i++) {
    final double t = i / sampleRate;
    final double f = frequency * (1.0 - pitchDrop * (t / duration));
    phase += 2.0 * math.pi * f / sampleRate;

    final double attackGain = t < attack ? t / attack : 1.0;
    final double envelope =
        attackGain * math.exp(-decayRate * t) * (1.0 - t / duration);
    final double timbre = math.sin(phase) +
        0.32 * math.sin(3.0 * phase) +
        0.12 * math.sin(5.0 * phase);
    samples[i] = envelope * timbre;
  }

  // Normalizzazione sul picco: le armoniche non sommano in fase, quindi il
  // picco effettivo non è prevedibile a priori. Scalarlo su [amplitude]
  // tiene il beep alla stessa "distanza" dal fondo scala del click
  // classico, invece di lasciarlo 6 dB più piano.
  double peak = 0.0;
  for (final value in samples) {
    if (value.abs() > peak) peak = value.abs();
  }
  final double gain = peak == 0.0 ? 0.0 : amplitude / peak;

  final pcmData = Int16List(numSamples);
  for (int i = 0; i < numSamples; i++) {
    pcmData[i] = (samples[i] * gain).clamp(-32768.0, 32767.0).round();
  }

  final File file = File(filePath);
  final buffer = BytesBuilder();
  buffer.add(header);
  buffer.add(pcmData.buffer.asUint8List());
  await file.writeAsBytes(buffer.toBytes());
  print('Scritto file: $filePath');
}

Future<void> generateTone({
  required String filePath,
  required double frequency,
  required double duration,
  required double amplitude,
  required double decayRate,
}) async {
  const int sampleRate = 44100;
  final int numSamples = (sampleRate * duration).round();
  final header = getWavHeader(numSamples, sampleRate);
  
  final pcmData = Int16List(numSamples);
  for (int i = 0; i < numSamples; i++) {
    final double t = i / sampleRate;
    final double envelope = amplitude * math.exp(-decayRate * t) * (1.0 - t / duration);
    final double sampleVal = envelope * math.sin(2.0 * math.pi * frequency * t);
    pcmData[i] = sampleVal.clamp(-32768.0, 32767.0).round();
  }

  final File file = File(filePath);
  final buffer = BytesBuilder();
  buffer.add(header);
  buffer.add(pcmData.buffer.asUint8List());
  await file.writeAsBytes(buffer.toBytes());
  print('Scritto file: $filePath');
}

Future<void> generateSnare({
  required String filePath,
  required double duration,
}) async {
  const int sampleRate = 44100;
  final int numSamples = (sampleRate * duration).round();
  final header = getWavHeader(numSamples, sampleRate);
  
  final pcmData = Int16List(numSamples);
  final rand = math.Random();
  
  const double baseFreq = 180.0;
  
  for (int i = 0; i < numSamples; i++) {
    final double t = i / sampleRate;
    
    // Sine component for snare drum body (low/mid punch)
    final double sineEnvelope = 16000.0 * math.exp(-30.0 * t);
    final double sineSample = sineEnvelope * math.sin(2.0 * math.pi * baseFreq * t);
    
    // Noise component for snare wires/sizzle
    final double noiseEnvelope = 14000.0 * math.exp(-18.0 * t) * (1.0 - t / duration);
    final double noiseSample = noiseEnvelope * (rand.nextDouble() * 2.0 - 1.0);
    
    // Sum and clamp
    final double combined = sineSample + noiseSample;
    pcmData[i] = combined.clamp(-32768.0, 32767.0).round();
  }

  final File file = File(filePath);
  final buffer = BytesBuilder();
  buffer.add(header);
  buffer.add(pcmData.buffer.asUint8List());
  await file.writeAsBytes(buffer.toBytes());
  print('Scritto file: $filePath');
}
