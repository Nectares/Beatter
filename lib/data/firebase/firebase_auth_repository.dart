import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/errors/app_failure.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';
import 'firebase_failure_mapper.dart';

/// Production [AuthRepository] backed by Firebase Authentication.
///
/// Platform notes (per the google_sign_in 7.x migration):
///  - Mobile Google sign-in uses `GoogleSignIn.instance.authenticate()`
///    (initialized lazily, never on web).
///  - Web uses `signInWithPopup`, so the GoogleSignIn plugin is never
///    initialized there (avoids the DWDS hang when no meta client id is set).
///  - Apple uses firebase_auth's native `AppleAuthProvider` flow on iOS/macOS
///    and a popup on web — no extra plugin needed.
class FirebaseAuthRepository implements AuthRepository {
  final fb.FirebaseAuth _auth;
  bool _googleInitialized = false;

  FirebaseAuthRepository({fb.FirebaseAuth? auth})
      : _auth = auth ?? fb.FirebaseAuth.instance;

  AuthUser _toAuthUser(fb.User user) => AuthUser(
        uid: user.uid,
        email: user.email,
        displayName: user.displayName,
        photoUrl: user.photoURL,
        isAnonymous: user.isAnonymous,
        providerIds:
            user.providerData.map((p) => p.providerId).toList(growable: false),
      );

  @override
  Stream<AuthUser?> authStateChanges() =>
      _auth.authStateChanges().map((u) => u == null ? null : _toAuthUser(u));

  @override
  AuthUser? get currentUser {
    final u = _auth.currentUser;
    return u == null ? null : _toAuthUser(u);
  }

  fb.User _requireUser() {
    final u = _auth.currentUser;
    if (u == null) throw const NotAuthenticatedFailure();
    return u;
  }

  @override
  Future<AuthUser> signInAnonymously() => guard(() async {
        final cred = await _auth.signInAnonymously();
        return _toAuthUser(cred.user!);
      });

  @override
  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
  }) =>
      guard(() async {
        final cred = await _auth.signInWithEmailAndPassword(
            email: email.trim(), password: password);
        return _toAuthUser(cred.user!);
      });

  @override
  Future<AuthUser> registerWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) =>
      guard(() async {
        final cred = await _auth.createUserWithEmailAndPassword(
            email: email.trim(), password: password);
        if (displayName != null && displayName.isNotEmpty) {
          await cred.user!.updateDisplayName(displayName);
          await cred.user!.reload();
        }
        return _toAuthUser(_auth.currentUser!);
      });

  Future<fb.AuthCredential> _googleCredential() async {
    if (!_googleInitialized) {
      await GoogleSignIn.instance.initialize();
      _googleInitialized = true;
    }
    try {
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw const AuthFailure('missing-id-token', 'Accesso Google non riuscito.');
      }
      return fb.GoogleAuthProvider.credential(idToken: idToken);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        throw AuthFailure('cancelled', 'Accesso annullato.', cause: e);
      }
      throw AuthFailure('google-sign-in-failed',
          e.description ?? 'Accesso Google non riuscito.',
          cause: e);
    }
  }

  @override
  Future<AuthUser> signInWithGoogle() => guard(() async {
        final fb.UserCredential cred;
        if (kIsWeb) {
          cred = await _auth.signInWithPopup(fb.GoogleAuthProvider());
        } else {
          cred = await _auth.signInWithCredential(await _googleCredential());
        }
        return _toAuthUser(cred.user!);
      });

  @override
  Future<AuthUser> signInWithApple() => guard(() async {
        final provider = fb.AppleAuthProvider()
          ..addScope('email')
          ..addScope('name');
        final cred = kIsWeb
            ? await _auth.signInWithPopup(provider)
            : await _auth.signInWithProvider(provider);
        return _toAuthUser(cred.user!);
      });

  @override
  Future<AuthUser> linkAnonymousToGoogle() => guard(() async {
        final user = _requireUser();
        final fb.UserCredential cred;
        if (kIsWeb) {
          cred = await user.linkWithPopup(fb.GoogleAuthProvider());
        } else {
          cred = await user.linkWithCredential(await _googleCredential());
        }
        return _toAuthUser(cred.user!);
      });

  @override
  Future<AuthUser> linkAnonymousToApple() => guard(() async {
        final user = _requireUser();
        final provider = fb.AppleAuthProvider()
          ..addScope('email')
          ..addScope('name');
        final cred = kIsWeb
            ? await user.linkWithPopup(provider)
            : await user.linkWithProvider(provider);
        return _toAuthUser(cred.user!);
      });

  @override
  Future<AuthUser> linkAnonymousToEmail({
    required String email,
    required String password,
  }) =>
      guard(() async {
        final user = _requireUser();
        final credential = fb.EmailAuthProvider.credential(
            email: email.trim(), password: password);
        final cred = await user.linkWithCredential(credential);
        return _toAuthUser(cred.user!);
      });

  @override
  Future<void> sendPasswordResetEmail(String email) =>
      guard(() => _auth.sendPasswordResetEmail(email: email.trim()));

  @override
  Future<void> signOut() => guard(() async {
        // The GoogleSignIn plugin is only initialized on mobile; calling it
        // uninitialized on web crashes (see firebase-auth-basics skill).
        if (!kIsWeb && _googleInitialized) {
          await GoogleSignIn.instance.signOut();
        }
        await _auth.signOut();
      });

  @override
  Future<void> deleteAccount() => guard(() async {
        await _requireUser().delete();
      });
}
