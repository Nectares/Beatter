// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'wav_utils.dart';

/// One-off generator for Polyrhythm Lab's default instrument set. Mirrors
/// `generate_audio_assets.dart` (same WAV header helper, same "run once,
/// commit the output" workflow) — not part of the app runtime.
void main() async {
  print('Inizio generazione asset audio Polyrhythm Lab...');

  final outputDir = Directory('assets/audio/polyrhythm');
  if (!await outputDir.exists()) {
    await outputDir.create(recursive: true);
    print('Directory assets/audio/polyrhythm creata.');
  }

  // Triangle (3) -> Rimshot: dual detuned square burst + a noise transient,
  // mimics the "crack" of a rim click.
  await _write('assets/audio/polyrhythm/rimshot.wav', _rimshot(duration: 0.09));

  // Square (4) -> Closed HiHat: shaped, very-fast-decay high-frequency noise.
  await _write('assets/audio/polyrhythm/closed_hihat.wav', _closedHiHat(duration: 0.06));

  // Pentagon (5) -> Woodblock: short triangle-wave "knock" with a light
  // downward pitch envelope.
  await _write('assets/audio/polyrhythm/woodblock.wav', _woodblock(duration: 0.07));

  // Hexagon (6) -> Cowbell: classic two-square-wave synthesis (540Hz/800Hz).
  await _write('assets/audio/polyrhythm/cowbell.wav', _cowbell(duration: 0.18));

  // Heptagon (7) -> Click: short, very high sine burst.
  await _write('assets/audio/polyrhythm/click.wav', _click(duration: 0.03));

  // Octagon (8) -> Shaker: noise shaped with a two-hump "shake" envelope.
  await _write('assets/audio/polyrhythm/shaker.wav', _shaker(duration: 0.16));

  // Extra: subdivision 2 -> Tom, a low sine thump (not in the spec's 3-8
  // table, but every supported subdivision needs a default sound).
  await _write('assets/audio/polyrhythm/tom.wav', _tom(duration: 0.16));

  print('Generazione completata con successo!');
}

const int _sampleRate = 44100;

Future<void> _write(String filePath, Int16List pcmData) async {
  final header = getWavHeader(pcmData.length, _sampleRate);
  final file = File(filePath);
  final buffer = BytesBuilder();
  buffer.add(header);
  buffer.add(pcmData.buffer.asUint8List());
  await file.writeAsBytes(buffer.toBytes());
  print('Scritto file: $filePath');
}

int _clampSample(double v) => v.clamp(-32768.0, 32767.0).round();

/// Simple one-pole high-pass filter — turns raw white noise into a brighter,
/// "metallic" texture (used for hi-hat/shaker/rimshot) without needing a
/// real FFT-based filter design.
Float64List _highPass(List<double> input, double cutoffAlpha) {
  final out = Float64List(input.length);
  double prevIn = 0.0;
  double prevOut = 0.0;
  for (int i = 0; i < input.length; i++) {
    final double x = input[i];
    final double y = cutoffAlpha * (prevOut + x - prevIn);
    out[i] = y;
    prevIn = x;
    prevOut = y;
  }
  return out;
}

Int16List _rimshot({required double duration}) {
  final int n = (_sampleRate * duration).round();
  final pcm = Int16List(n);
  final rand = math.Random(1);

  final noise = List<double>.generate(n, (_) => rand.nextDouble() * 2.0 - 1.0);
  final bright = _highPass(noise, 0.85);

  for (int i = 0; i < n; i++) {
    final double t = i / _sampleRate;
    final double toneEnv = 9000.0 * math.exp(-70.0 * t);
    final double tone = toneEnv *
        (math.sin(2.0 * math.pi * 900.0 * t) + 0.6 * math.sin(2.0 * math.pi * 1500.0 * t));
    final double noiseEnv = 12000.0 * math.exp(-140.0 * t);
    pcm[i] = _clampSample(tone + bright[i] * noiseEnv);
  }
  return pcm;
}

Int16List _closedHiHat({required double duration}) {
  final int n = (_sampleRate * duration).round();
  final pcm = Int16List(n);
  final rand = math.Random(2);

  final noise = List<double>.generate(n, (_) => rand.nextDouble() * 2.0 - 1.0);
  final bright = _highPass(noise, 0.92);

  for (int i = 0; i < n; i++) {
    final double t = i / _sampleRate;
    final double env = 22000.0 * math.exp(-90.0 * t) * (1.0 - t / duration);
    pcm[i] = _clampSample(bright[i] * env);
  }
  return pcm;
}

Int16List _woodblock({required double duration}) {
  final int n = (_sampleRate * duration).round();
  final pcm = Int16List(n);

  for (int i = 0; i < n; i++) {
    final double t = i / _sampleRate;
    final double freq = 1300.0 - 300.0 * (t / duration); // slight downward glide
    final double env = 24000.0 * math.exp(-45.0 * t);
    // Triangle-ish wave via a fast-converging sine sum for a woodier tone.
    final double wave = math.sin(2.0 * math.pi * freq * t) +
        0.25 * math.sin(2.0 * math.pi * freq * 3 * t);
    pcm[i] = _clampSample(env * wave);
  }
  return pcm;
}

Int16List _cowbell({required double duration}) {
  final int n = (_sampleRate * duration).round();
  final pcm = Int16List(n);
  const double f1 = 540.0;
  const double f2 = 800.0;

  for (int i = 0; i < n; i++) {
    final double t = i / _sampleRate;
    final double env = 14000.0 * math.exp(-14.0 * t);
    double square1 = math.sin(2.0 * math.pi * f1 * t) >= 0 ? 1.0 : -1.0;
    double square2 = math.sin(2.0 * math.pi * f2 * t) >= 0 ? 1.0 : -1.0;
    pcm[i] = _clampSample(env * (0.5 * square1 + 0.5 * square2));
  }
  return pcm;
}

Int16List _click({required double duration}) {
  final int n = (_sampleRate * duration).round();
  final pcm = Int16List(n);

  for (int i = 0; i < n; i++) {
    final double t = i / _sampleRate;
    final double env = 26000.0 * math.exp(-140.0 * t);
    pcm[i] = _clampSample(env * math.sin(2.0 * math.pi * 2200.0 * t));
  }
  return pcm;
}

Int16List _shaker({required double duration}) {
  final int n = (_sampleRate * duration).round();
  final pcm = Int16List(n);
  final rand = math.Random(3);

  final noise = List<double>.generate(n, (_) => rand.nextDouble() * 2.0 - 1.0);
  final bright = _highPass(noise, 0.7);

  for (int i = 0; i < n; i++) {
    final double t = i / _sampleRate;
    // Two-hump envelope: a quick attack-decay, a short gap, then a softer
    // second hump — reads as a single "shake" motion rather than a hit.
    final double hump1 = math.exp(-40.0 * t);
    final double hump2 = 0.6 * math.exp(-40.0 * (t - duration * 0.45).abs()) * (t > duration * 0.35 ? 1.0 : 0.0);
    final double env = 9000.0 * (hump1 + hump2) * (1.0 - t / duration).clamp(0.0, 1.0);
    pcm[i] = _clampSample(bright[i] * env);
  }
  return pcm;
}

Int16List _tom({required double duration}) {
  final int n = (_sampleRate * duration).round();
  final pcm = Int16List(n);

  for (int i = 0; i < n; i++) {
    final double t = i / _sampleRate;
    final double freq = 160.0 - 60.0 * (t / duration); // pitch drop, classic tom
    final double env = 20000.0 * math.exp(-18.0 * t);
    pcm[i] = _clampSample(env * math.sin(2.0 * math.pi * freq * t));
  }
  return pcm;
}
