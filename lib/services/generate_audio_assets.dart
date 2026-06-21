import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

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

List<int> getWavHeader(int numSamples, int sampleRate) {
  final header = Uint8List(44);
  final byteData = ByteData.sublistView(header);

  // "RIFF"
  byteData.setUint8(0, 0x52);
  byteData.setUint8(1, 0x49);
  byteData.setUint8(2, 0x46);
  byteData.setUint8(3, 0x46);

  // ChunkSize (36 + SubChunk2Size)
  final subChunk2Size = numSamples * 2; // 16-bit mono = 2 bytes per sample
  byteData.setUint32(4, 36 + subChunk2Size, Endian.little);

  // "WAVE"
  byteData.setUint8(8, 0x57);
  byteData.setUint8(9, 0x41);
  byteData.setUint8(10, 0x56);
  byteData.setUint8(11, 0x45);

  // "fmt "
  byteData.setUint8(12, 0x66);
  byteData.setUint8(13, 0x6d);
  byteData.setUint8(14, 0x74);
  byteData.setUint8(15, 0x20);

  // SubChunk1Size (16 for PCM)
  byteData.setUint32(16, 16, Endian.little);

  // AudioFormat (1 for PCM)
  byteData.setUint16(20, 1, Endian.little);

  // NumChannels (1 for Mono)
  byteData.setUint16(22, 1, Endian.little);

  // SampleRate
  byteData.setUint32(24, sampleRate, Endian.little);

  // ByteRate (SampleRate * NumChannels * BitsPerSample/8)
  byteData.setUint32(28, sampleRate * 1 * 2, Endian.little);

  // BlockAlign (NumChannels * BitsPerSample/8)
  byteData.setUint16(32, 2, Endian.little);

  // BitsPerSample (16)
  byteData.setUint16(34, 16, Endian.little);

  // "data"
  byteData.setUint8(36, 0x64);
  byteData.setUint8(37, 0x61);
  byteData.setUint8(38, 0x74);
  byteData.setUint8(39, 0x61);

  // SubChunk2Size
  byteData.setUint32(40, subChunk2Size, Endian.little);

  return header;
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
