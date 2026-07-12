import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/di/service_locator.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/repositories/document_store.dart';
import '../domain/services/crash_reporter.dart';
import '../models/reading_score.dart';

export '../models/reading_score.dart';

/// Persistenza dei record di Reading Mode, per id di esercizio salvato.
/// Same facade pattern as [ExerciseRepository]: i widget parlano con questo
/// ChangeNotifier; lo storage arriva dal backend — Firestore
/// (`users/{uid}/readingScores`, con persistenza offline e sync
/// multi-dispositivo) da loggati, device-local da sloggati/modalità locale.
/// I record sono monotoni: [submit] alza solo i valori battuti e riferisce
/// se c'è stato un nuovo record.
class ReadingScoreRepository extends ChangeNotifier {
  static final ReadingScoreRepository _instance =
      ReadingScoreRepository._internal();
  factory ReadingScoreRepository() => _instance;
  ReadingScoreRepository._internal();

  final Map<String, ReadingScore> _scores = {};
  bool _initialized = false;

  DocumentStore<ReadingScore>? _store;
  StreamSubscription<List<ReadingScore>>? _storeSub;
  StreamSubscription<Object?>? _authSub;
  String? _attachedUid;

  /// Binds to the backend. Safe to call more than once — later calls are
  /// no-ops.
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

    final store = ServiceLocator.get<DocumentStoreFactory>().readingScores(uid);
    _store = store;

    // Semina la cache prima di sottoscrivere: submit() confronta col
    // record corrente e non deve mai decidere su una cache fredda.
    try {
      _applyAll(await store.loadAll());
    } catch (e, s) {
      ServiceLocator.get<CrashReporter>().recordError(e, s);
    }

    _storeSub = store.watchAll().listen(
      _applyAll,
      onError: (Object e, StackTrace s) =>
          ServiceLocator.get<CrashReporter>().recordError(e, s),
    );

    if (uid != null && ServiceLocator.isFirebase) {
      unawaited(_mergeLocalRecordsOnce(uid, store));
    }
  }

  void _applyAll(List<ReadingScore> items) {
    _scores
      ..clear()
      ..addEntries(items.map((s) => MapEntry(s.id, s)));
    notifyListeners();
  }

  /// Primo login su questo device: fonde i record giocati da sloggato nel
  /// cloud, tenendo per ciascun esercizio il massimo tra locale e remoto
  /// (i record sono monotoni, quindi il merge non può mai peggiorarli).
  Future<void> _mergeLocalRecordsOnce(
      String uid, DocumentStore<ReadingScore> cloudStore) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final flagKey = 'backend.migrated.readingScores.$uid';
      if (prefs.getBool(flagKey) ?? false) return;

      final localItems = await ServiceLocator.get<DocumentStoreFactory>()
          .readingScores(null)
          .loadAll();
      for (final local in localItems) {
        final cloud = _scores[local.id];
        if (cloud == null ||
            local.good > cloud.good ||
            local.strike > cloud.strike) {
          final merged = ReadingScore(
            id: local.id,
            good: local.good > (cloud?.good ?? 0) ? local.good : cloud!.good,
            strike: local.strike > (cloud?.strike ?? 0)
                ? local.strike
                : cloud!.strike,
            updatedAt: DateTime.now(),
          );
          _scores[local.id] = merged;
          await cloudStore.upsert(merged);
        }
      }
      await prefs.setBool(flagKey, true);
      notifyListeners();
    } catch (e, s) {
      ServiceLocator.get<CrashReporter>().recordError(e, s);
    }
  }

  /// Il record per [exerciseId], o null se non è mai stato giocato.
  ReadingScore? recordFor(String exerciseId) => _scores[exerciseId];

  /// Registra l'esito di una sessione; ritorna true se good e/o strike
  /// hanno battuto il record precedente (che viene aggiornato e salvato
  /// sul backend).
  Future<bool> submit(
    String exerciseId, {
    required int good,
    required int strike,
  }) async {
    final current = _scores[exerciseId];
    final bool improved =
        good > (current?.good ?? 0) || strike > (current?.strike ?? 0);
    if (!improved) return false;

    final record = ReadingScore(
      id: exerciseId,
      good: good > (current?.good ?? 0) ? good : current!.good,
      strike: strike > (current?.strike ?? 0) ? strike : current!.strike,
      updatedAt: DateTime.now(),
    );
    _scores[exerciseId] = record;
    notifyListeners();
    await _store?.upsert(record);
    return true;
  }

  /// Sgancia store e auth e svuota la cache — solo per i test, che devono
  /// poter ripartire da zero nonostante il singleton.
  @visibleForTesting
  Future<void> resetForTests() async {
    await _authSub?.cancel();
    await _storeSub?.cancel();
    await _store?.dispose();
    _authSub = null;
    _storeSub = null;
    _store = null;
    _attachedUid = null;
    _initialized = false;
    _scores.clear();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _storeSub?.cancel();
    _store?.dispose();
    super.dispose();
  }
}
