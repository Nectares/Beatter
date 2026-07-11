import '../entities/workout_session.dart';

/// Workout history: append-only log of completed practice sessions.
abstract interface class WorkoutRepository {
  /// Records a completed session. The returned session carries the client's
  /// *provisional* point estimate ([PointsStatus.provisional]); the canonical
  /// value arrives asynchronously through [watchRecent] once the
  /// `onWorkoutCreated` Cloud Function confirms it. Works offline — the write
  /// queues and the function runs when connectivity returns.
  Future<WorkoutSession> recordSession(String uid, WorkoutSession draft);

  /// Most recent sessions, newest first, live-updating.
  Stream<List<WorkoutSession>> watchRecent(String uid, {int limit = 50});

  /// Paged history for the full log view. [startAfter] is the [WorkoutSession.startedAt]
  /// of the last item of the previous page.
  Future<List<WorkoutSession>> fetchPage(
    String uid, {
    DateTime? startAfter,
    int limit = 30,
    WorkoutType? type,
  });
}
