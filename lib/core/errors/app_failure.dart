/// Typed failures thrown by the repository layer.
///
/// The UI and domain code never see raw `FirebaseException`s — the data layer
/// maps every platform error into one of these, so error handling is uniform
/// regardless of which backend implementation is active (Firebase or local).
sealed class AppFailure implements Exception {
  final String message;
  final Object? cause;

  const AppFailure(this.message, {this.cause});

  @override
  String toString() => '$runtimeType: $message';
}

/// Network unavailable or a call timed out. Safe to retry.
class NetworkFailure extends AppFailure {
  const NetworkFailure({String message = 'Connessione non disponibile.', Object? cause})
      : super(message, cause: cause);
}

/// The user is not signed in, or the session expired.
class NotAuthenticatedFailure extends AppFailure {
  const NotAuthenticatedFailure({String message = 'Accesso richiesto.'}) : super(message);
}

/// Signed in, but not allowed to perform the operation (security rules).
class PermissionFailure extends AppFailure {
  const PermissionFailure({String message = 'Operazione non consentita.', Object? cause})
      : super(message, cause: cause);
}

/// Authentication flow errors (wrong password, cancelled sign-in, ...).
class AuthFailure extends AppFailure {
  /// Stable machine-readable code, e.g. `wrong-password`, `cancelled`,
  /// `credential-already-in-use`, `requires-recent-login`.
  final String code;

  const AuthFailure(this.code, String message, {Object? cause})
      : super(message, cause: cause);

  bool get isCancelled => code == 'cancelled';
}

/// The requested document/resource does not exist.
class NotFoundFailure extends AppFailure {
  const NotFoundFailure({String message = 'Elemento non trovato.'}) : super(message);
}

/// A uniqueness or precondition conflict (e.g. username already taken).
class ConflictFailure extends AppFailure {
  const ConflictFailure({String message = 'Conflitto: risorsa già esistente.'})
      : super(message);
}

/// Stored data could not be parsed into a model (corrupt or future schema).
class DataFormatFailure extends AppFailure {
  const DataFormatFailure({String message = 'Dati non validi.', Object? cause})
      : super(message, cause: cause);
}

/// Anything unexpected — the original error is preserved in [cause] and is
/// reported to the crash reporter by the data layer before being rethrown.
class UnknownFailure extends AppFailure {
  const UnknownFailure({String message = 'Errore imprevisto.', Object? cause})
      : super(message, cause: cause);
}
