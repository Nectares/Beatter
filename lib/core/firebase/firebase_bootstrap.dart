import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';
import '../di/service_locator.dart';

/// Optional reCAPTCHA v3 site key for App Check on web, injected at build
/// time: `flutter build web --dart-define=APP_CHECK_RECAPTCHA_SITE_KEY=...`.
const String _recaptchaSiteKey = String.fromEnvironment('APP_CHECK_RECAPTCHA_SITE_KEY');

/// Initializes the Firebase backend and returns the [BackendMode] the app
/// should run in. Never throws: if anything fails (missing platform config,
/// no Play Services, ...) the app falls back to fully-local mode instead of
/// refusing to start.
Future<BackendMode> initializeFirebaseBackend() async {
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

    await _activateAppCheck();
    _configureFirestorePersistence();
    _installCrashlyticsHandlers();

    return BackendMode.firebase;
  } catch (e, s) {
    debugPrint('Firebase init failed, falling back to local mode: $e\n$s');
    return BackendMode.local;
  }
}

Future<void> _activateAppCheck() async {
  try {
    await FirebaseAppCheck.instance.activate(
      // Debug providers print a token to the console on first run; register
      // it under App Check > Apps > Manage debug tokens in the console.
      providerAndroid:
          kDebugMode ? const AndroidDebugProvider() : const AndroidPlayIntegrityProvider(),
      providerApple:
          kDebugMode ? const AppleDebugProvider() : const AppleDeviceCheckProvider(),
      providerWeb: _recaptchaSiteKey.isEmpty
          ? null
          : ReCaptchaV3Provider(_recaptchaSiteKey),
    );
  } catch (e) {
    // App Check being unavailable must never block the app; enforcement is
    // opt-in per service in the console anyway.
    debugPrint('App Check activation skipped: $e');
  }
}

void _configureFirestorePersistence() {
  try {
    // Local cache makes every repository read/watch offline-first and gives
    // writes latency compensation (our optimistic updates).
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  } catch (e) {
    debugPrint('Firestore persistence unavailable: $e');
  }
}

void _installCrashlyticsHandlers() {
  if (kIsWeb) return; // Crashlytics has no web SDK
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
}
