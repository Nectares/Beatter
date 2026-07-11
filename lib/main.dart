import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'features/music/presentation/navigation/main_navigation_shell.dart'; // TEMP-VERIFY

void main() {
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
      home: const MainNavigationShell(
        initialTab: AppTab.polyrhythmLab,
      ), // TEMP-VERIFY: const LoginPage(),
    );
  }
}
