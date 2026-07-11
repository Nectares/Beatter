/// Crash/error reporting boundary (Crashlytics on Android/iOS, no-op on web —
/// Crashlytics has no web SDK — and in local mode/tests).
abstract interface class CrashReporter {
  Future<void> recordError(Object error, StackTrace? stack, {bool fatal = false});

  Future<void> setUserId(String? uid);

  Future<void> log(String message);
}
