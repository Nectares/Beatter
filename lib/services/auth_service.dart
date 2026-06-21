import 'dart:async';

enum UserRole { admin, user }

class UserSession {
  final String email;
  final UserRole role;

  UserSession({required this.email, required this.role});
}

class AuthService {
  // Mock login function
  static Future<UserSession?> login({
    required String email,
    required String password,
    required UserRole expectedRole,
  }) async {
    // Simulate network latency
    await Future.delayed(const Duration(milliseconds: 1200));

    final normalizedEmail = email.trim().toLowerCase();

    if (expectedRole == UserRole.admin) {
      // Admin authentication rule: must match admin credentials
      if (normalizedEmail == 'admin@beatter.com' && password == 'admin123') {
        return UserSession(email: 'admin@beatter.com', role: UserRole.admin);
      }
    } else {
      // User authentication rule: accept user@beatter.com/password123, or any valid email/password (for demonstration)
      if (normalizedEmail == 'user@beatter.com' && password == 'password123') {
        return UserSession(email: 'user@beatter.com', role: UserRole.user);
      } else if (normalizedEmail.contains('@') && password.length >= 6) {
        // Allow fallback user login if it looks like a valid email/password
        return UserSession(email: normalizedEmail, role: UserRole.user);
      }
    }
    return null;
  }
}
