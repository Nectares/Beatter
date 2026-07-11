import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

import '../../core/errors/app_failure.dart';

/// Maps raw Firebase/platform errors to the app's typed [AppFailure]s.
AppFailure mapFirebaseError(Object error) {
  if (error is AppFailure) return error;

  if (error is FirebaseAuthException) {
    final message = switch (error.code) {
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' =>
        'Credenziali non valide.',
      'email-already-in-use' => 'Esiste già un account con questa email.',
      'credential-already-in-use' =>
        'Questo account è già collegato a un altro utente.',
      'weak-password' => 'Password troppo debole (minimo 6 caratteri).',
      'requires-recent-login' => 'Per sicurezza, accedi di nuovo e riprova.',
      'network-request-failed' => 'Connessione non disponibile.',
      'too-many-requests' => 'Troppi tentativi. Riprova tra qualche minuto.',
      _ => error.message ?? 'Errore di autenticazione.',
    };
    if (error.code == 'network-request-failed') {
      return NetworkFailure(cause: error);
    }
    return AuthFailure(error.code, message, cause: error);
  }

  if (error is FirebaseException) {
    return switch (error.code) {
      'permission-denied' => PermissionFailure(cause: error),
      'unauthenticated' => const NotAuthenticatedFailure(),
      'unavailable' || 'deadline-exceeded' => NetworkFailure(cause: error),
      'not-found' || 'object-not-found' => const NotFoundFailure(),
      'already-exists' => const ConflictFailure(),
      _ => UnknownFailure(
          message: error.message ?? 'Errore imprevisto.', cause: error),
    };
  }

  if (error is TimeoutException) return NetworkFailure(cause: error);
  if (error is FormatException || error is TypeError) {
    return DataFormatFailure(cause: error);
  }
  return UnknownFailure(cause: error);
}

/// Runs [action], converting any thrown error into an [AppFailure].
Future<T> guard<T>(Future<T> Function() action) async {
  try {
    return await action();
  } catch (e) {
    throw mapFirebaseError(e);
  }
}
