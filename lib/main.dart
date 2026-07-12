import 'package:flutter/material.dart';

import 'core/di/service_locator.dart';
import 'core/firebase/firebase_bootstrap.dart';
import 'features/auth/presentation/pages/auth_gate.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase when configured, transparent local fallback otherwise — the UI
  // is identical in both modes and only talks to the repository facades.
  final mode = await initializeFirebaseBackend();
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
    );
  }
}
