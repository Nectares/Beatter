import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/utils/json_codecs.dart';
import '../../domain/entities/user_statistics.dart';
import '../../domain/entities/workout_session.dart';
import '../../domain/logic/point_rules.dart';
import '../../domain/repositories/gamification_repositories.dart';
import '../../domain/repositories/workout_repository.dart';
import '../../domain/services/crash_reporter.dart';
import 'firebase_failure_mapper.dart';
import 'firestore_paths.dart';

class FirestoreWorkoutRepository implements WorkoutRepository {
  final FirebaseFirestore _db;
  final StatisticsRepository _statistics;
  final CrashReporter _crashReporter;

  FirestoreWorkoutRepository({
    required StatisticsRepository statistics,
    required CrashReporter crashReporter,
    FirebaseFirestore? firestore,
  })  : _statistics = statistics,
        _crashReporter = crashReporter,
        _db = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection(FirestorePaths.workouts(uid));

  @override
  Future<WorkoutSession> recordSession(String uid, WorkoutSession draft) async {
    // Optimistic points: estimate with the cached stats snapshot. Cached is
    // fine (and works offline) — the Cloud Function recomputes canonically
    // and flips pointsStatus to `confirmed`.
    UserStatistics stats;
    try {
      stats = await _statistics.fetchStatistics(uid);
    } catch (_) {
      stats = UserStatistics.empty();
    }
    final streak = PointRules.nextStreakDays(stats, draft.startedAt);
    final doc = _col(uid).doc();
    final session = draft.copyWith(
      id: doc.id,
      pointsEarned: PointRules.totalFor(draft, streakDaysIncludingToday: streak),
      pointsStatus: PointsStatus.provisional,
    );
    // Optimistic write: with offline persistence the set() future only
    // completes once the server acknowledges, which can be much later (or
    // never, offline). Local snapshot listeners see the write immediately,
    // so we return right away and surface sync errors through the stream's
    // error mapping instead of blocking the UI here.
    doc.set(session.toJson()).catchError((Object e, StackTrace s) {
      // A rejected workout write means a client bug or rules mismatch —
      // never user error — so report it rather than surfacing a dialog.
      _crashReporter.recordError(mapFirebaseError(e), s);
    });
    return session;
  }

  @override
  Stream<List<WorkoutSession>> watchRecent(String uid, {int limit = 50}) =>
      _col(uid)
          .orderBy('startedAt', descending: true)
          .limit(limit)
          .snapshots(includeMetadataChanges: true)
          .map((snap) => snap.docs
              .map((d) => WorkoutSession.fromJson(d.data()))
              .toList(growable: false))
          .handleError((Object e) => throw mapFirebaseError(e));

  @override
  Future<List<WorkoutSession>> fetchPage(
    String uid, {
    DateTime? startAfter,
    int limit = 30,
    WorkoutType? type,
  }) =>
      guard(() async {
        Query<Map<String, dynamic>> query =
            _col(uid).orderBy('startedAt', descending: true);
        if (type != null) {
          // Served by the (type ASC, startedAt DESC) composite index.
          query = _col(uid)
              .where('type', isEqualTo: type.name)
              .orderBy('startedAt', descending: true);
        }
        if (startAfter != null) {
          query = query.startAfter([dateToJson(startAfter)]);
        }
        final snap = await query.limit(limit).get();
        return snap.docs
            .map((d) => WorkoutSession.fromJson(d.data()))
            .toList(growable: false);
      });
}
