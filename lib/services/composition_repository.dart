import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/di/service_locator.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/repositories/document_store.dart';
import '../domain/services/analytics_tracker.dart';
import '../domain/services/crash_reporter.dart';
import '../models/composition.dart';

/// UI-facing composition library. Public API is unchanged from the
/// shared_preferences era — widgets keep listening to this ChangeNotifier —
/// but storage now goes through the backend's [DocumentStore]:
///
///  - signed out / local mode → device-local store (same storage key as
///    before, so existing libraries survive);
///  - signed in with Firebase → `users/{uid}/compositions` with offline
///    persistence and multi-device sync.
///
/// Mutations update the in-memory list immediately (optimistic) and let the
/// store's stream reconcile with the backend.
class CompositionRepository extends ChangeNotifier {
  static final CompositionRepository _instance = CompositionRepository._internal();
  factory CompositionRepository() => _instance;
  CompositionRepository._internal();

  final List<Composition> _compositions = [];
  bool _initialized = false;

  DocumentStore<Composition>? _store;
  StreamSubscription<List<Composition>>? _storeSub;
  StreamSubscription<Object?>? _authSub;
  String? _attachedUid;

  List<Composition> get compositions => List.unmodifiable(_compositions);
  bool get isInitialized => _initialized;

  /// Binds to the backend. Safe to call more than once (e.g. from multiple
  /// screens' initState) — later calls are no-ops.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    final auth = ServiceLocator.get<AuthRepository>();
    await _attachStore(auth.currentUser?.uid);
    _authSub = auth.authStateChanges().listen((user) {
      _attachStore(user?.uid);
    });
  }

  Future<void> _attachStore(String? uid) async {
    if (_store != null && uid == _attachedUid) return;
    _attachedUid = uid;

    await _storeSub?.cancel();
    await _store?.dispose();

    final store = ServiceLocator.get<DocumentStoreFactory>().compositions(uid);
    _store = store;
    _storeSub = store.watchAll().listen(
      (items) {
        _compositions
          ..clear()
          ..addAll(items);
        notifyListeners();
      },
      onError: (Object e, StackTrace s) =>
          ServiceLocator.get<CrashReporter>().recordError(e, s),
    );

    if (uid != null && ServiceLocator.isFirebase) {
      unawaited(_migrateLocalLibraryOnce(uid, store));
    }
  }

  /// One-time upload of the pre-backend on-device library into the user's
  /// cloud collection, so nothing is lost the first time they sign in.
  Future<void> _migrateLocalLibraryOnce(
      String uid, DocumentStore<Composition> cloudStore) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final flagKey = 'backend.migrated.compositions.$uid';
      if (prefs.getBool(flagKey) ?? false) return;

      final localItems = await ServiceLocator.get<DocumentStoreFactory>()
          .compositions(null)
          .loadAll();
      for (final item in localItems) {
        await cloudStore.upsert(item);
      }
      await prefs.setBool(flagKey, true);
    } catch (e, s) {
      ServiceLocator.get<CrashReporter>().recordError(e, s);
    }
  }

  String _generateId() {
    final random = Random();
    return '${DateTime.now().microsecondsSinceEpoch}-${random.nextInt(1 << 31)}';
  }

  void _upsertLocal(Composition composition) {
    final index = _compositions.indexWhere((c) => c.id == composition.id);
    if (index == -1) {
      _compositions.add(composition);
    } else {
      _compositions[index] = composition;
    }
    notifyListeners();
  }

  /// Saves [composition]. If it has no id yet, assigns one and appends it
  /// (first save); otherwise overwrites the existing entry with the same id.
  Future<Composition> save(Composition composition) async {
    final now = DateTime.now();
    final isNew = composition.id.isEmpty ||
        !_compositions.any((c) => c.id == composition.id);
    final toSave = composition.copyWith(
      id: composition.id.isEmpty ? _generateId() : composition.id,
      modifiedAt: now,
    );

    _upsertLocal(toSave);
    await _store?.upsert(toSave);
    if (isNew) {
      unawaited(ServiceLocator.get<AnalyticsTracker>()
          .logCompositionSaved(noteCount: toSave.notes.length));
    }
    return toSave;
  }

  Future<void> rename(String id, String newTitle) async {
    final index = _compositions.indexWhere((c) => c.id == id);
    if (index == -1) return;
    final renamed = _compositions[index].copyWith(
      title: newTitle,
      modifiedAt: DateTime.now(),
    );
    _upsertLocal(renamed);
    await _store?.upsert(renamed);
  }

  Future<Composition> duplicate(String id) async {
    final source = _compositions.firstWhere((c) => c.id == id);
    final now = DateTime.now();
    final copy = source.copyWith(
      id: _generateId(),
      title: '${source.title} (copia)',
      createdAt: now,
      modifiedAt: now,
    );
    _upsertLocal(copy);
    await _store?.upsert(copy);
    return copy;
  }

  Future<void> delete(String id) async {
    _compositions.removeWhere((c) => c.id == id);
    notifyListeners();
    await _store?.delete(id);
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _storeSub?.cancel();
    _store?.dispose();
    super.dispose();
  }
}
