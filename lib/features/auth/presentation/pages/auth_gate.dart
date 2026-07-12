import 'package:flutter/material.dart';

import '../../../../services/auth_service.dart';
import '../../../../theme/app_theme.dart';
import '../../../admin/presentation/pages/admin_dashboard.dart';
import '../../../music/presentation/navigation/main_navigation_shell.dart';
import 'login_page.dart';

/// The app's entry screen: resumes the persisted Firebase Auth session and
/// routes straight to the right home (user shell or admin dashboard),
/// falling back to [LoginPage] when nobody is signed in.
///
/// One-shot on purpose: after this first routing decision the app navigates
/// imperatively (login pushes the shell, logout pushes the login page), so a
/// stream-based gate would fight those transitions.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Future<UserSession?> _restore = AuthService.restoreSession();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserSession?>(
      future: _restore,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            body: Container(
              decoration: AppTheme.backgroundGradient,
              alignment: Alignment.center,
              child: const CircularProgressIndicator(),
            ),
          );
        }
        final session = snapshot.data;
        if (session == null) return const LoginPage();
        return session.role == UserRole.admin
            ? const AdminDashboard()
            : const MainNavigationShell();
      },
    );
  }
}
