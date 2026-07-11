/// Generic persistence boundary for user-owned JSON documents (compositions,
/// saved exercises). The existing UI-facing repositories
/// ([CompositionRepository], [ExerciseRepository]) keep their ChangeNotifier
/// API and delegate storage here, so widgets never know whether documents
/// live in shared_preferences (signed-out/local mode) or Firestore
/// (signed-in, offline-persistent, multi-device).
abstract interface class DocumentStore<T> {
  /// Current documents, then every subsequent change (local or remote).
  Stream<List<T>> watchAll();

  Future<List<T>> loadAll();

  /// Insert-or-replace by id. Optimistic: local observers see the change
  /// before the backend acknowledges it.
  Future<void> upsert(T document);

  Future<void> delete(String id);

  /// Releases any listeners. The store is unusable afterwards.
  Future<void> dispose();
}
