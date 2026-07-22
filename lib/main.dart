import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'core/ads/ads_support.dart';
import 'core/di/service_locator.dart';
import 'core/firebase/firebase_bootstrap.dart';
import 'core/widgets/persistent_banner_ad.dart';
import 'features/auth/presentation/pages/auth_gate.dart';
import 'theme/app_theme.dart';

/// Build-time switch for screenshot/demo runs: skips Firebase entirely so the
/// app boots deterministically in local mode with no network dependency.
/// Usage: flutter run --dart-define=FORCE_LOCAL_BACKEND=true
const bool _forceLocalBackend = bool.fromEnvironment('FORCE_LOCAL_BACKEND');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Google Mobile Ads only ships an Android/iOS implementation. On web (and
  // any other platform) `MobileAds.initialize()` throws MissingPluginException;
  // before this guard that uncaught error ran *before* runApp and left the app
  // stuck on a blank screen. Keep ad init strictly best-effort so it can never
  // block or crash startup.
  if (adsSupported) {
    try {
      await MobileAds.instance.initialize();
    } catch (e, s) {
      debugPrint('MobileAds init skipped (continuing without ads): $e\n$s');
    }
  }

  // Firebase when configured, transparent local fallback otherwise — the UI
  // is identical in both modes and only talks to the repository facades.
  final mode =
      _forceLocalBackend ? BackendMode.local : await initializeFirebaseBackend();
  ServiceLocator.configure(mode);

  runApp(const BeatterApp());
}

class BeatterApp extends StatelessWidget {
  const BeatterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Beatter',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      // AuthGate resumes a persisted Firebase session (straight to the
      // shell/dashboard) and only shows the login page when signed out.
      home: const AuthGate(),
      builder: (context, child) {
        final keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
        return Material(
          child: Column(
            children: [
              Expanded(child: child ?? const SizedBox.shrink()),
              if (!keyboardVisible) const PersistentBannerAd(),
            ],
          ),
        );
      },
    );
  }
}
