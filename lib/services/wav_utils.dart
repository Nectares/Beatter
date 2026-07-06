import 'dart:typed_data';

/// Writes a standard 44-byte PCM WAV header (16-bit mono) for [numSamples]
/// at [sampleRate]. Shared by the standalone audio-asset generator scripts
/// (`generate_audio_assets.dart`, `generate_note_assets.dart`) — neither is
/// part of the app runtime, this just avoids duplicating the header bytes.
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
