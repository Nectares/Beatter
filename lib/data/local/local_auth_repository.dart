import 'dart:async';

import '../../core/errors/app_failure.dart';
import '../../core/utils/value_stream.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';

/// Offline/dev [AuthRepository]: accepts any plausible email/password so the
/// app stays usable without Firebase. Real credential checks (and the admin
/// role, which lives on the Firestore profile) only exist in Firebase mode.
class LocalAuthRepository implements AuthRepository {
  final _controller = StreamController<AuthUser?>.broadcast();
  AuthUser? _current;

  void _set(AuthUser? user) {
    _current = user;
    _controller.add(user);
  }

  @override
  Stream<AuthUser?> authStateChanges() => valueThenUpdates(
        snapshot: () => _current,
        updates: _controller.stream,
      );

  @override
  AuthUser? get currentUser => _current;

  AuthUser _fromEmail(String email) {
    final normalized = email.trim().toLowerCase();
    return AuthUser(
      uid: 'local-${normalized.hashCode.toRadixString(16)}',
      email: normalized,
      displayName: normalized.split('@').first,
      providerIds: const ['password'],
    );
  }

  @override
  Future<AuthUser> signInAnonymously() async {
    final user = AuthUser(
      uid: 'local-anon-${DateTime.now().microsecondsSinceEpoch}',
      isAnonymous: true,
    );
    _set(user);
    return user;
  }

  @override
  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final normalized = email.trim().toLowerCase();
    if (!normalized.contains('@') || password.length < 6) {
      throw const AuthFailure('invalid-credential', 'Credenziali non valide.');
    }
    final user = _fromEmail(normalized);
    _set(user);
    return user;
  }

  @override
  Future<AuthUser> registerWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    if (password.length < 6) {
      throw const AuthFailure('weak-password', 'Password troppo debole.');
    }
    final user = _fromEmail(email).copyWith(displayName: displayName);
    _set(user);
    return user;
  }

  Never _unsupported() => throw const AuthFailure(
      'unavailable-offline', 'Accesso social non disponibile in modalità offline.');

  @override
  Future<AuthUser> signInWithGoogle() async => _unsupported();

  @override
  Future<AuthUser> signInWithApple() async => _unsupported();

  @override
  Future<AuthUser> linkAnonymousToGoogle() async => _unsupported();

  @override
  Future<AuthUser> linkAnonymousToApple() async => _unsupported();

  @override
  Future<AuthUser> linkAnonymousToEmail({
    required String email,
    required String password,
  }) async {
    final current = _current;
    if (current == null) throw const NotAuthenticatedFailure();
    final upgraded = _fromEmail(email);
    final user = AuthUser(
      uid: current.uid, // keep the uid, like a real anonymous link
      email: upgraded.email,
      displayName: upgraded.displayName,
      providerIds: const ['password'],
    );
    _set(user);
    return user;
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<void> signOut() async => _set(null);

  @override
  Future<void> deleteAccount() async => _set(null);
}
