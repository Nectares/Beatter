import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/di/service_locator.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/repositories/document_store.dart';
import '../domain/services/crash_reporter.dart';
import '../models/rhythm_exercise.dart';

/// UI-facing saved-exercise library for Sheet Mode. Same facade pattern as
/// [CompositionRepository]: unchanged ChangeNotifier API, backend-provided
/// storage (device-local when signed out, `users/{uid}/exercises` with
/// offline persistence when signed in).
class ExerciseRepository extends ChangeNotifier {
  static final ExerciseRepository _instance = ExerciseRepository._internal();
  factory ExerciseRepository() => _instance;
  ExerciseRepository._internal();

  final List<RhythmExercise> _exercises = [];
  bool _initialized = false;

  DocumentStore<RhythmExercise>? _store;
  StreamSubscription<List<RhythmExercise>>? _storeSub;
  StreamSubscription<Object?>? _authSub;
  String? _attachedUid;

  /// Saved exercises, newest first.
  List<RhythmExercise> get exercises => List.unmodifiable(_exercises);
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

    final store = ServiceLocator.get<DocumentStoreFactory>().exercises(uid);
    _store = store;
    _storeSub = store.watchAll().listen(
      (items) {
        _exercises
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

  Future<void> _migrateLocalLibraryOnce(
      String uid, DocumentStore<RhythmExercise> cloudStore) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final flagKey = 'backend.migrated.exercises.$uid';
      if (prefs.getBool(flagKey) ?? false) return;

      final localItems =
          await ServiceLocator.get<DocumentStoreFactory>().exercises(null).loadAll();
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

  void _upsertLocal(RhythmExercise exercise, {required bool prepend}) {
    final index = _exercises.indexWhere((e) => e.id == exercise.id);
    if (index == -1) {
      prepend ? _exercises.insert(0, exercise) : _exercises.add(exercise);
    } else {
      _exercises[index] = exercise;
    }
    notifyListeners();
  }

  /// Saves [exercise]. If it has no id yet, assigns one and prepends it
  /// (first save); otherwise overwrites the existing entry with the same id.
  Future<RhythmExercise> save(RhythmExercise exercise) async {
    final toSave = exercise.id.isEmpty
        ? exercise.copyWith(id: _generateId())
        : exercise;
    _upsertLocal(toSave, prepend: true);
    await _store?.upsert(toSave);
    return toSave;
  }

  Future<void> rename(String id, String newTitle) async {
    final index = _exercises.indexWhere((e) => e.id == id);
    if (index == -1) return;
    final renamed = _exercises[index].copyWith(title: newTitle);
    _upsertLocal(renamed, prepend: false);
    await _store?.upsert(renamed);
  }

  Future<RhythmExercise> duplicate(String id) async {
    final source = _exercises.firstWhere((e) => e.id == id);
    final copy = source.copyWith(
      id: _generateId(),
      title: '${source.title} (copia)',
      createdAt: DateTime.now(),
    );
    _upsertLocal(copy, prepend: true);
    await _store?.upsert(copy);
    return copy;
  }

  Future<void> delete(String id) async {
    _exercises.removeWhere((e) => e.id == id);
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
