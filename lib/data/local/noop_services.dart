import 'package:flutter/foundation.dart';

import '../../core/errors/app_failure.dart';
import '../../domain/repositories/media_storage_repository.dart';
import '../../domain/services/analytics_tracker.dart';
import '../../domain/services/crash_reporter.dart';

/// No-op analytics for local mode and tests.
class NoopAnalyticsTracker implements AnalyticsTracker {
  const NoopAnalyticsTracker();

  @override
  Future<void> setUserId(String? uid) async {}

  @override
  Future<void> logLogin(String method) async {}

  @override
  Future<void> logSignUp(String method) async {}

  @override
  Future<void> logWorkoutCompleted({
    required String type,
    required int durationSeconds,
    required int provisionalPoints,
  }) async {}

  @override
  Future<void> logCompositionSaved({required int noteCount}) async {}

  @override
  Future<void> logAchievementUnlocked(String achievementId) async {}

  @override
  Future<void> logScreenView(String screenName) async {}
}

/// Debug-console crash reporter for local mode, web, and tests.
class NoopCrashReporter implements CrashReporter {
  const NoopCrashReporter();

  @override
  Future<void> recordError(Object error, StackTrace? stack, {bool fatal = false}) async {
    debugPrint('[crash-reporter] $error');
  }

  @override
  Future<void> setUserId(String? uid) async {}

  @override
  Future<void> log(String message) async {}
}

/// Local mode has no blob storage; uploads fail with a clear, typed error.
class UnavailableMediaStorageRepository implements MediaStorageRepository {
  const UnavailableMediaStorageRepository();

  Never _unavailable() => throw const NetworkFailure(
      message: 'Archiviazione file non disponibile in modalità offline.');

  @override
  Future<String> uploadAvatar(String uid, Uint8List bytes,
          {String contentType = 'image/jpeg'}) async =>
      _unavailable();

  @override
  Future<void> deleteAvatar(String uid) async => _unavailable();

  @override
  Future<String> uploadPdfExport(String uid, String fileName, Uint8List bytes) async =>
      _unavailable();
}
