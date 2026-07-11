import 'package:firebase_crashlytics/firebase_crashlytics.dart';

import '../../domain/services/crash_reporter.dart';

/// Crashlytics adapter. Only registered on Android/iOS — Crashlytics has no
/// web SDK, so web (and local mode) get [NoopCrashReporter] instead.
class CrashlyticsReporter implements CrashReporter {
  final FirebaseCrashlytics _crashlytics;

  CrashlyticsReporter({FirebaseCrashlytics? crashlytics})
      : _crashlytics = crashlytics ?? FirebaseCrashlytics.instance;

  @override
  Future<void> recordError(Object error, StackTrace? stack, {bool fatal = false}) =>
      _crashlytics.recordError(error, stack, fatal: fatal);

  @override
  Future<void> setUserId(String? uid) => _crashlytics.setUserIdentifier(uid ?? '');

  @override
  Future<void> log(String message) => _crashlytics.log(message);
}
