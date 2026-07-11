import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/repositories/document_store.dart';
import 'firebase_failure_mapper.dart';

/// Firestore-backed [DocumentStore] for user-owned JSON documents
/// (compositions at `users/{uid}/compositions`, exercises at
/// `users/{uid}/exercises`).
///
/// Offline persistence gives local-first reads and queued writes; snapshot
/// listeners fire from the local cache immediately after a write, which is
/// what makes the UI-facing repositories' updates optimistic for free.
class FirestoreDocumentStore<T> implements DocumentStore<T> {
  final CollectionReference<Map<String, dynamic>> _collection;
  final T Function(Map<String, dynamic> json) _fromJson;
  final Map<String, dynamic> Function(T value) _toJson;
  final String Function(T value) _idOf;
  final String _orderByField;
  final bool _descending;

  FirestoreDocumentStore({
    required FirebaseFirestore firestore,
    required String collectionPath,
    required T Function(Map<String, dynamic> json) fromJson,
    required Map<String, dynamic> Function(T value) toJson,
    required String Function(T value) idOf,
    String orderByField = 'modifiedAt',
    bool descending = true,
  })  : _collection = firestore.collection(collectionPath),
        _fromJson = fromJson,
        _toJson = toJson,
        _idOf = idOf,
        _orderByField = orderByField,
        _descending = descending;

  Query<Map<String, dynamic>> get _query =>
      _collection.orderBy(_orderByField, descending: _descending);

  List<T> _decode(QuerySnapshot<Map<String, dynamic>> snap) {
    final result = <T>[];
    for (final doc in snap.docs) {
      try {
        result.add(_fromJson(doc.data()));
      } catch (_) {
        // One corrupt/newer-schema document must not take down the whole
        // library view; skip it (same policy the local repos already had).
      }
    }
    return result;
  }

  @override
  Stream<List<T>> watchAll() => _query
      .snapshots(includeMetadataChanges: true)
      .map(_decode)
      .handleError((Object e) => throw mapFirebaseError(e));

  @override
  Future<List<T>> loadAll() => guard(() async => _decode(await _query.get()));

  @override
  Future<void> upsert(T document) {
    final id = _idOf(document);
    // Fire-and-forget against the local cache: completion tracks the server
    // ack, but listeners (and therefore the UI) update synchronously.
    _collection.doc(id).set(_toJson(document)).catchError((Object _) {});
    return Future.value();
  }

  @override
  Future<void> delete(String id) {
    _collection.doc(id).delete().catchError((Object _) {});
    return Future.value();
  }

  @override
  Future<void> dispose() async {}
}
