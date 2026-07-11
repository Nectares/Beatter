import 'dart:math' as math;

import '../entities/user_statistics.dart';
import '../entities/workout_session.dart';

/// Deterministic point formula for a completed workout.
///
/// ⚠️ This is intentionally a *mirror* of `functions/src/logic/points.ts` —
/// the Cloud Function is the source of truth and recomputes the value
/// server-side; this copy exists only so the client can show an optimistic
/// (provisional) total instantly, including offline. Keep the two in sync,
/// and keep everything integer/deterministic (no floats in intermediate
/// state that could round differently across languages).
///
/// Formula:
///   base       = min(durationSeconds, 3600) ~/ 60 * 10      (10 pts/min, 1h cap)
///   difficulty = base * (100 + 25*(level-1)) ~/ 100          (level 1..5)
///   accuracy   = difficulty * round(accuracy*100) ~/ 200     (up to +50%)
///   streak     = 5 * min(streakDays, 10)                     (server-settled)
///   total      = clamp(difficulty + accuracy + streak, 0, 1500)
abstract final class PointRules {
  static const int pointsPerMinute = 10;
  static const int maxCountedSeconds = 3600;
  static const int maxPointsPerWorkout = 1500;
  static const int streakBonusPerDay = 5;
  static const int maxStreakBonusDays = 10;

  static int basePoints(int durationSeconds) {
    final counted = durationSeconds.clamp(0, maxCountedSeconds);
    return (counted ~/ 60) * pointsPerMinute;
  }

  static int difficultyAdjusted(int base, int difficultyLevel) {
    final level = difficultyLevel.clamp(1, 5);
    return base * (100 + 25 * (level - 1)) ~/ 100;
  }

  static int accuracyBonus(int difficultyAdjusted, double? accuracy) {
    if (accuracy == null) return 0;
    final pct = (accuracy.clamp(0.0, 1.0) * 100).round();
    return difficultyAdjusted * pct ~/ 200;
  }

  static int streakBonus(int streakDays) {
    return streakBonusPerDay * math.min(math.max(streakDays, 0), maxStreakBonusDays);
  }

  /// Full calculation. [streakDaysIncludingToday] is the user's practice
  /// streak counting today's workout (the server derives it from
  /// [UserStatistics.lastWorkoutAt]; the client passes its cached value for
  /// the optimistic estimate).
  static int totalFor(WorkoutSession session, {required int streakDaysIncludingToday}) {
    final base = basePoints(session.durationSeconds);
    final adjusted = difficultyAdjusted(base, session.difficultyLevel);
    final bonus = accuracyBonus(adjusted, session.accuracy);
    final streak = streakBonus(streakDaysIncludingToday);
    return (adjusted + bonus + streak).clamp(0, maxPointsPerWorkout);
  }

  /// The streak the user reaches with a workout at [workoutDay], given stats
  /// from before the workout. Same-day workouts keep the streak; a workout on
  /// the day after `lastWorkoutAt` extends it; anything later resets to 1.
  static int nextStreakDays(UserStatistics stats, DateTime workoutDay) {
    final last = stats.lastWorkoutAt;
    if (last == null) return 1;
    final lastDay = DateTime.utc(last.year, last.month, last.day);
    final day = DateTime.utc(workoutDay.toUtc().year, workoutDay.toUtc().month,
        workoutDay.toUtc().day);
    final gap = day.difference(lastDay).inDays;
    if (gap <= 0) return math.max(stats.currentStreakDays, 1);
    if (gap == 1) return stats.currentStreakDays + 1;
    return 1;
  }
}
