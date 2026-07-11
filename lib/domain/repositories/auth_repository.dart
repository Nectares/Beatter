import '../entities/auth_user.dart';

/// Authentication boundary. Implementations: [FirebaseAuthRepository]
/// (production) and [LocalAuthRepository] (offline/dev fallback).
///
/// All methods throw [AppFailure] subtypes on error — most relevantly
/// [AuthFailure], whose [AuthFailure.code] is stable across backends.
abstract interface class AuthRepository {
  /// Emits the current user on every auth state change (null = signed out).
  Stream<AuthUser?> authStateChanges();

  AuthUser? get currentUser;

  /// Guest session; can later be upgraded losslessly via the `link*` methods.
  Future<AuthUser> signInAnonymously();

  Future<AuthUser> signInWithEmail({required String email, required String password});

  Future<AuthUser> registerWithEmail({
    required String email,
    required String password,
    String? displayName,
  });

  Future<AuthUser> signInWithGoogle();

  Future<AuthUser> signInWithApple();

  /// Upgrades the current anonymous account, preserving its uid and data.
  /// Throws [AuthFailure] `credential-already-in-use` if the Google account
  /// is already tied to another Beatter user.
  Future<AuthUser> linkAnonymousToGoogle();

  Future<AuthUser> linkAnonymousToApple();

  Future<AuthUser> linkAnonymousToEmail({
    required String email,
    required String password,
  });

  Future<void> sendPasswordResetEmail(String email);

  Future<void> signOut();

  /// Permanently deletes the auth account. May throw [AuthFailure]
  /// `requires-recent-login`, in which case the UI must reauthenticate first.
  Future<void> deleteAccount();
}
