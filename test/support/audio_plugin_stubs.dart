import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Silences the audio plugins for tests that build a
/// `RhythmPlaybackService`: it creates its audioplayers pools eagerly in the
/// constructor, and `AssetSource` also reaches for path_provider to stage
/// the WAV in a temp file. Without stubs those platform calls throw
/// MissingPluginException and fail the test for reasons unrelated to it.
void stubAudioPlugins() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  for (final channel in const [
    MethodChannel('xyz.luan/audioplayers'),
    MethodChannel('xyz.luan/audioplayers.global'),
  ]) {
    messenger.setMockMethodCallHandler(channel, (call) async => null);
  }
  messenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (call) async => Directory.systemTemp.path,
  );
}
