import 'dart:async';

import '../core/di/service_locator.dart';
import '../domain/entities/workout_session.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/repositories/workout_repository.dart';
import '../domain/services/analytics_tracker.dart';

/// UI-facing facade for recording completed practice sessions.
///
/// Pages call [recordCompleted] when a session ends (exercise player, flow
/// mode, polyrhythm lab); everything else — provisional points, canonical
/// server recalculation, stats/achievements/leaderboard updates — happens in
/// the backend layers. Returns null when nobody is signed in.
abstract final class WorkoutTracker {
  static Future<WorkoutSession?> recordCompleted({
    required WorkoutType type,
    required DateTime startedAt,
    required int durationSeconds,
    required int bpm,
    int difficultyLevel = 1,
    double? accuracy,
    String? sourceId,
  }) async {
    final user = ServiceLocator.get<AuthRepository>().currentUser;
    if (user == null) return null;

    final draft = WorkoutSession(
      id: '',
      type: type,
      startedAt: startedAt,
      durationSeconds: durationSeconds,
      bpm: bpm,
      difficultyLevel: difficultyLevel,
      accuracy: accuracy,
      sourceId: sourceId,
      createdAt: DateTime.now().toUtc(),
    );

    final session = await ServiceLocator.get<WorkoutRepository>()
        .recordSession(user.uid, draft);
    unawaited(ServiceLocator.get<AnalyticsTracker>().logWorkoutCompleted(
      type: type.name,
      durationSeconds: durationSeconds,
      provisionalPoints: session.pointsEarned,
    ));
    return session;
  }
}
