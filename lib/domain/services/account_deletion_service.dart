/// Server-authoritative account deletion boundary.
///
/// Implementations: [FunctionsAccountDeletionService] (production — invokes
/// the `deleteAccount` Cloud Function, which erases Firestore data, Storage
/// files and the Auth user in that order) and a local no-op used in
/// offline/dev mode where there is no backend account to erase.
///
/// The client never deletes user data directly: it only asks the server to,
/// then tears down its own local session and caches once the server confirms.
abstract interface class AccountDeletionService {
  /// Requests permanent deletion of the currently authenticated account.
  ///
  /// Throws an [AppFailure] subtype on failure (e.g. [NotAuthenticatedFailure]
  /// when signed out, [NetworkFailure] when offline). Returns normally only
  /// when the server has confirmed the deletion.
  Future<void> deleteAccount();
}
