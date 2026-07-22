import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:get_it/get_it.dart';

import '../../data/firebase/crashlytics_reporter.dart';
import '../../data/firebase/firebase_analytics_tracker.dart';
import '../../data/firebase/firebase_auth_repository.dart';
import '../../data/firebase/firebase_media_storage_repository.dart';
import '../../data/firebase/functions_account_deletion_service.dart';
import '../../data/firebase/firestore_document_store.dart';
import '../../data/firebase/firestore_gamification_repositories.dart';
import '../../data/firebase/firestore_paths.dart';
import '../../data/firebase/firestore_profile_repository.dart';
import '../../data/firebase/firestore_settings_repository.dart';
import '../../data/firebase/firestore_workout_repository.dart';
import '../../data/local/local_auth_repository.dart';
import '../../data/local/local_document_store.dart';
import '../../data/local/local_gamification.dart';
import '../../data/local/noop_services.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/document_store.dart';
import '../../domain/repositories/gamification_repositories.dart';
import '../../domain/repositories/media_storage_repository.dart';
import '../../domain/repositories/profile_repository.dart';
import '../../domain/repositories/settings_repository.dart';
import '../../domain/repositories/workout_repository.dart';
import '../../domain/services/account_deletion_service.dart';
import '../../domain/services/analytics_tracker.dart';
import '../../domain/services/crash_reporter.dart';
import '../../models/composition.dart';
import '../../models/reading_score.dart';
import '../../models/rhythm_exercise.dart';

/// Which backend the app is running against.
enum BackendMode {
  /// Firebase project configured and initialized.
  firebase,

  /// Firebase unavailable (not configured / init failed): everything runs on
  /// device-local storage, preserving pre-backend behavior.
  local,
}

/// Composition root. `configure` is called once from main(); tests call
/// `configureLocal()` (or register their own fakes) after `reset()`.
///
/// Widgets never touch this directly for data access — they keep using the
/// existing facade services (`AuthService`, `CompositionRepository`, ...),
/// which resolve their dependencies from here.
abstract final class ServiceLocator {
  static final GetIt _getIt = GetIt.instance;

  static BackendMode _mode = BackendMode.local;

  static BackendMode get mode => _mode;
  static bool get isFirebase => _mode == BackendMode.firebase;

  static T get<T extends Object>() => _getIt.get<T>();

  static Future<void> reset() => _getIt.reset();

  static void configure(BackendMode mode) {
    _mode = mode;
    switch (mode) {
      case BackendMode.firebase:
        _configureFirebase();
      case BackendMode.local:
        configureLocal();
    }
  }

  static void _configureFirebase() {
    _getIt.registerLazySingleton<AnalyticsTracker>(() => FirebaseAnalyticsTracker());
    _getIt.registerLazySingleton<CrashReporter>(
        () => kIsWeb ? const NoopCrashReporter() : CrashlyticsReporter());
    _getIt.registerLazySingleton<AuthRepository>(() => FirebaseAuthRepository());
    _getIt.registerLazySingleton<ProfileRepository>(() => FirestoreProfileRepository());
    _getIt.registerLazySingleton<SettingsRepository>(
        () => FirestoreSettingsRepository());
    _getIt.registerLazySingleton<StatisticsRepository>(
        () => FirestoreStatisticsRepository());
    _getIt.registerLazySingleton<PointsRepository>(() => FirestorePointsRepository());
    _getIt.registerLazySingleton<AchievementsRepository>(
        () => FirestoreAchievementsRepository());
    _getIt.registerLazySingleton<LeaderboardRepository>(
        () => FirestoreLeaderboardRepository());
    _getIt.registerLazySingleton<MediaStorageRepository>(
        () => FirebaseMediaStorageRepository());
    _getIt.registerLazySingleton<AccountDeletionService>(
        () => FunctionsAccountDeletionService());
    _getIt.registerLazySingleton<WorkoutRepository>(() => FirestoreWorkoutRepository(
          statistics: get<StatisticsRepository>(),
          crashReporter: get<CrashReporter>(),
        ));
    _getIt.registerLazySingleton<DocumentStoreFactory>(
        () => const _FirebaseDocumentStoreFactory());
  }

  /// Local mode wiring — also the default wiring for widget tests.
  static void configureLocal() {
    _mode = BackendMode.local;
    final engine = LocalGamificationEngine();
    final auth = LocalAuthRepository();
    _getIt.registerLazySingleton<AnalyticsTracker>(() => const NoopAnalyticsTracker());
    _getIt.registerLazySingleton<CrashReporter>(() => const NoopCrashReporter());
    _getIt.registerSingleton<AuthRepository>(auth);
    _getIt.registerLazySingleton<ProfileRepository>(() => LocalProfileRepository());
    _getIt.registerLazySingleton<SettingsRepository>(() => LocalSettingsRepository());
    _getIt.registerSingleton<LocalGamificationEngine>(engine);
    _getIt.registerLazySingleton<StatisticsRepository>(
        () => LocalStatisticsRepository(engine));
    _getIt.registerLazySingleton<PointsRepository>(() => LocalPointsRepository(engine));
    _getIt.registerLazySingleton<AchievementsRepository>(
        () => LocalAchievementsRepository(engine));
    _getIt.registerLazySingleton<LeaderboardRepository>(
        () => LocalLeaderboardRepository(engine, () => auth.currentUser));
    _getIt.registerLazySingleton<MediaStorageRepository>(
        () => const UnavailableMediaStorageRepository());
    _getIt.registerLazySingleton<AccountDeletionService>(
        () => const LocalAccountDeletionService());
    _getIt.registerLazySingleton<WorkoutRepository>(
        () => LocalWorkoutRepository(engine));
    _getIt.registerLazySingleton<DocumentStoreFactory>(
        () => const _LocalDocumentStoreFactory());
  }
}

/// Creates uid-scoped document stores for the facade repositories.
/// `uid == null` (signed out) always yields the device-local store, so the
/// app remains usable before login and in local mode.
abstract interface class DocumentStoreFactory {
  DocumentStore<Composition> compositions(String? uid);

  DocumentStore<RhythmExercise> exercises(String? uid);

  DocumentStore<ReadingScore> readingScores(String? uid);
}

/// Storage keys predate the backend: keep them so existing on-device
/// libraries survive the migration.
const String kLocalCompositionsKey = 'composer.compositions.v1';
const String kLocalExercisesKey = 'sheet_mode.exercises.v1';
const String kLocalReadingScoresKey = 'reading_mode.records.v1';

class _LocalDocumentStoreFactory implements DocumentStoreFactory {
  const _LocalDocumentStoreFactory();

  @override
  DocumentStore<Composition> compositions(String? uid) => LocalDocumentStore(
        storageKey: kLocalCompositionsKey,
        fromJson: Composition.fromJson,
        toJson: (c) => c.toJson(),
        idOf: (c) => c.id,
      );

  @override
  DocumentStore<RhythmExercise> exercises(String? uid) => LocalDocumentStore(
        storageKey: kLocalExercisesKey,
        fromJson: RhythmExercise.fromJson,
        toJson: (e) => e.toJson(),
        idOf: (e) => e.id,
        sort: (a, b) => b.createdAt.compareTo(a.createdAt), // newest first
      );

  @override
  DocumentStore<ReadingScore> readingScores(String? uid) => LocalDocumentStore(
        storageKey: kLocalReadingScoresKey,
        fromJson: ReadingScore.fromJson,
        toJson: (s) => s.toJson(),
        idOf: (s) => s.id,
      );
}

class _FirebaseDocumentStoreFactory implements DocumentStoreFactory {
  const _FirebaseDocumentStoreFactory();

  @override
  DocumentStore<Composition> compositions(String? uid) {
    if (uid == null) return const _LocalDocumentStoreFactory().compositions(null);
    return FirestoreDocumentStore(
      firestore: FirebaseFirestore.instance,
      collectionPath: FirestorePaths.compositions(uid),
      fromJson: Composition.fromJson,
      toJson: (c) => c.toJson(),
      idOf: (c) => c.id,
      orderByField: 'modifiedAt',
    );
  }

  @override
  DocumentStore<RhythmExercise> exercises(String? uid) {
    if (uid == null) return const _LocalDocumentStoreFactory().exercises(null);
    return FirestoreDocumentStore(
      firestore: FirebaseFirestore.instance,
      collectionPath: FirestorePaths.exercises(uid),
      fromJson: RhythmExercise.fromJson,
      toJson: (e) => e.toJson(),
      idOf: (e) => e.id,
      orderByField: 'createdAt',
    );
  }

  @override
  DocumentStore<ReadingScore> readingScores(String? uid) {
    if (uid == null) {
      return const _LocalDocumentStoreFactory().readingScores(null);
    }
    return FirestoreDocumentStore(
      firestore: FirebaseFirestore.instance,
      collectionPath: FirestorePaths.readingScores(uid),
      fromJson: ReadingScore.fromJson,
      toJson: (s) => s.toJson(),
      idOf: (s) => s.id,
      orderByField: 'updatedAt',
    );
  }
}
