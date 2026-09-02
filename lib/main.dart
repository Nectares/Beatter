import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'core/di/service_locator.dart';
import 'core/firebase/firebase_bootstrap.dart';
import 'core/widgets/persistent_banner_ad.dart';
import 'features/auth/presentation/pages/auth_gate.dart';
import 'features/update/presentation/version_gate.dart';
import 'theme/app_theme.dart';

/// Build-time switch for screenshot/demo runs: skips Firebase entirely so the
/// app boots deterministically in local mode with no network dependency.
/// Usage: flutter run --dart-define=FORCE_LOCAL_BACKEND=true
const bool _forceLocalBackend = bool.fromEnvironment('FORCE_LOCAL_BACKEND');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Google Mobile Ads SDK
  await MobileAds.instance.initialize();

  // Firebase when configured, transparent local fallback otherwise — the UI
  // is identical in both modes and only talks to the repository facades.
  final mode =
      _forceLocalBackend ? BackendMode.local : await initializeFirebaseBackend();
  ServiceLocator.configure(mode);

  runApp(const BeatterApp());
}

class BeatterApp extends StatelessWidget {
  const BeatterApp({super.key});

  /// Il [VersionGate] vive nel `builder`, sopra il Navigator: per aprire il
  /// dialog dell'aggiornamento gli serve un contesto che un Navigator ce
  /// l'abbia sopra.
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Beatter',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: AppTheme.lightTheme,
      // AuthGate resumes a persisted Firebase session (straight to the
      // shell/dashboard) and only shows the login page when signed out.
      home: const AuthGate(),
      builder: (context, child) {
        final keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
        return Material(
          // Sopra ogni schermata, login compreso: una build fuori supporto
          // vede solo la pagina di aggiornamento, anche a sessione aperta.
          child: VersionGate(
            navigatorKey: navigatorKey,
            child: Column(
              children: [
                Expanded(child: child ?? const SizedBox.shrink()),
                if (!keyboardVisible) const PersistentBannerAd(),
              ],
            ),
          ),
        );
      },
    );
  }
}
