import 'dart:async';

import '../core/di/service_locator.dart';
import '../core/errors/app_failure.dart';
import '../domain/entities/auth_user.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/repositories/profile_repository.dart';
import '../domain/services/analytics_tracker.dart';
import '../domain/services/crash_reporter.dart';

enum UserRole { admin, user }

class UserSession {
  final String uid;
  final String email;
  final UserRole role;

  UserSession({this.uid = '', required this.email, required this.role});
}

/// UI-facing authentication facade.
///
/// Keeps the original static API the login page consumes (`login` returning
/// a nullable [UserSession]), but delegates to the backend's
/// [AuthRepository]: Firebase Auth in production, the historical mock rules
/// in local mode. Role now comes from the user's Firestore profile
/// (`role: 'admin'`), never from the client.
class AuthService {
  static AuthRepository get _auth => ServiceLocator.get<AuthRepository>();
  static ProfileRepository get _profiles => ServiceLocator.get<ProfileRepository>();

  /// Session side effects shared by every sign-in path.
  static Future<UserSession> _openSession(AuthUser user, String method) async {
    final profile = await _profiles.ensureProfile(user);
    final analytics = ServiceLocator.get<AnalyticsTracker>();
    final crash = ServiceLocator.get<CrashReporter>();
    unawaited(analytics.setUserId(user.uid));
    unawaited(analytics.logLogin(method));
    unawaited(crash.setUserId(user.uid));
    return UserSession(
      uid: user.uid,
      email: user.email ?? '',
      role: profile.isAdmin ? UserRole.admin : UserRole.user,
    );
  }

  /// Rebuilds the [UserSession] for a user Firebase Auth kept signed in
  /// across app restarts (persistence is on disk; [currentUser] is already
  /// set when the app launches). Returns null when nobody is signed in or
  /// the profile can't be loaded — the caller falls back to the login page.
  ///
  /// Unlike [_openSession] this doesn't log a `login` analytics event:
  /// reopening the app is not a login.
  static Future<UserSession?> restoreSession() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    try {
      final profile =
          await _profiles.fetchProfile(user.uid) ?? await _profiles.ensureProfile(user);
      unawaited(ServiceLocator.get<AnalyticsTracker>().setUserId(user.uid));
      unawaited(ServiceLocator.get<CrashReporter>().setUserId(user.uid));
      return UserSession(
        uid: user.uid,
        email: user.email ?? '',
        role: profile.isAdmin ? UserRole.admin : UserRole.user,
      );
    } on AppFailure {
      return null;
    }
  }

  /// Email/password login preserving the historical contract: returns null
  /// on bad credentials or when [expectedRole] doesn't match the account.
  static Future<UserSession?> login({
    required String email,
    required String password,
    required UserRole expectedRole,
  }) async {
    try {
      final user = await _auth.signInWithEmail(email: email, password: password);
      final session = await _openSession(user, 'password');
      if (expectedRole == UserRole.admin && session.role != UserRole.admin) {
        await _auth.signOut();
        return null;
      }
      return session;
    } on AppFailure {
      return null;
    }
  }

  /// Nickname policy shared by the registration form and [register].
  static final RegExp nicknameFormat = RegExp(r'^[a-zA-Z0-9_]{3,24}$');

  /// First-time email/password registration with a unique app nickname.
  ///
  /// Unlike [login] (which keeps its historical null-on-failure contract),
  /// this throws [AppFailure] so the form can tell apart "email già in uso",
  /// "nickname già in uso" and network errors.
  static Future<UserSession> register({
    required String email,
    required String password,
    required String nickname,
  }) async {
    final handle = nickname.trim().toLowerCase();
    if (!nicknameFormat.hasMatch(handle)) {
      throw const DataFormatFailure(
          message: 'Il nickname deve avere 3-24 caratteri (lettere, numeri, _).');
    }
    if (await _profiles.isUsernameTaken(handle)) {
      throw const ConflictFailure(message: 'Nickname già in uso. Scegline un altro.');
    }

    final user = await _auth.registerWithEmail(
        email: email, password: password, displayName: nickname.trim());
    unawaited(ServiceLocator.get<AnalyticsTracker>().logSignUp('password'));
    final session = await _openSession(user, 'password');

    try {
      // Authoritative, race-free reservation. Losing the (tiny) race window
      // after the pre-check leaves the account without a handle rather than
      // failing the whole registration; the user can pick another later.
      await _profiles.claimUsername(uid: user.uid, username: handle);
    } on ConflictFailure catch (e, s) {
      unawaited(ServiceLocator.get<CrashReporter>().recordError(e, s));
    }
    return session;
  }

  /// Google sign-in. Throws [AuthFailure] (check `isCancelled`) so the UI
  /// can distinguish a dismissed sheet from a real error.
  static Future<UserSession> loginWithGoogle() async {
    final user = await _auth.signInWithGoogle();
    return _openSession(user, 'google.com');
  }

  /// Apple sign-in (iOS/macOS/web).
  static Future<UserSession> loginWithApple() async {
    final user = await _auth.signInWithApple();
    return _openSession(user, 'apple.com');
  }

  /// Guest session that can later be upgraded via [upgradeGuestToGoogle] &co.
  static Future<UserSession> loginAsGuest() async {
    final user = await _auth.signInAnonymously();
    return _openSession(user, 'anonymous');
  }

  /// Upgrades the current anonymous user in place, keeping uid and data.
  static Future<UserSession> upgradeGuestToGoogle() async {
    final user = await _auth.linkAnonymousToGoogle();
    return _openSession(user, 'google.com');
  }

  static Future<UserSession> upgradeGuestToApple() async {
    final user = await _auth.linkAnonymousToApple();
    return _openSession(user, 'apple.com');
  }

  static Future<UserSession> upgradeGuestToEmail({
    required String email,
    required String password,
  }) async {
    final user = await _auth.linkAnonymousToEmail(email: email, password: password);
    return _openSession(user, 'password');
  }

  static Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email);

  static Future<void> logout() async {
    final analytics = ServiceLocator.get<AnalyticsTracker>();
    final crash = ServiceLocator.get<CrashReporter>();
    unawaited(analytics.setUserId(null));
    unawaited(crash.setUserId(null));
    await _auth.signOut();
  }

  static AuthUser? get currentUser => _auth.currentUser;

  static Stream<AuthUser?> authStateChanges() => _auth.authStateChanges();
}
