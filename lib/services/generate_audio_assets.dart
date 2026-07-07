// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'wav_utils.dart';

void main() async {
  print('Inizio generazione asset audio...');
  
  final outputDir = Directory('assets/audio');
  if (!await outputDir.exists()) {
    await outputDir.create(recursive: true);
    print('Directory assets/audio creata.');
  }

  // 1. Metronome Accent (1000 Hz, 0.1s decay)
  await generateTone(
    filePath: 'assets/audio/metronome_accent.wav',
    frequency: 1000.0,
    duration: 0.1,
    amplitude: 30000.0,
    decayRate: 15.0,
  );

  // 2. Metronome Click (800 Hz, 0.07s decay)
  await generateTone(
    filePath: 'assets/audio/metronome_click.wav',
    frequency: 800.0,
    duration: 0.08,
    amplitude: 25000.0,
    decayRate: 25.0,
  );

  // 3. Stick Click (1400 Hz, very fast 0.04s decay)
  await generateTone(
    filePath: 'assets/audio/stick.wav',
    frequency: 1400.0,
    duration: 0.04,
    amplitude: 28000.0,
    decayRate: 60.0,
  );

  // 4. Snare Drum (180 Hz resonance + white noise burst, 0.2s decay)
  await generateSnare(
    filePath: 'assets/audio/snare.wav',
    duration: 0.2,
  );

  print('Generazione completata con successo!');
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
