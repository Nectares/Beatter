import 'package:beatter/domain/entities/user_statistics.dart';
import 'package:beatter/domain/entities/workout_session.dart';
import 'package:beatter/domain/logic/achievement_rules.dart';
import 'package:beatter/domain/logic/point_rules.dart';
import 'package:flutter_test/flutter_test.dart';

// These scenarios are duplicated in functions/src/test/logic.test.ts against
// the TypeScript source of truth; a change that breaks parity fails there
// or here.
void main() {
  WorkoutSession session({
    int durationSeconds = 600,
    int difficultyLevel = 1,
    double? accuracy,
  }) =>
      WorkoutSession(
        id: 'w1',
        type: WorkoutType.sheetReading,
        startedAt: DateTime.utc(2026, 7, 10, 10),
        durationSeconds: durationSeconds,
        bpm: 100,
        difficultyLevel: difficultyLevel,
        accuracy: accuracy,
        createdAt: DateTime.utc(2026, 7, 10, 10, 30),
      );

  group('PointRules', () {
    test('10 minutes at level 1, no accuracy, streak 1 → 105', () {
      expect(
        PointRules.totalFor(session(), streakDaysIncludingToday: 1),
        100 + 5,
      );
    });

    test('30 minutes at level 3, 80% accuracy, streak 5 → 655', () {
      // base 300, difficulty ×1.5 = 450, accuracy 450*80~/200 = 180, streak 25.
      expect(
        PointRules.totalFor(
          session(durationSeconds: 1800, difficultyLevel: 3, accuracy: 0.8),
          streakDaysIncludingToday: 5,
        ),
        450 + 180 + 25,
      );
    });

    test('points cap at 1500', () {
      expect(
        PointRules.totalFor(
          session(durationSeconds: 999999, difficultyLevel: 5, accuracy: 1.0),
          streakDaysIncludingToday: 30,
        ),
        1500,
      );
    });

    test('streak: same day keeps, next day extends, gap resets', () {
      final stats = UserStatistics.empty().copyWith(
        currentStreakDays: 3,
        lastWorkoutAt: DateTime.utc(2026, 7, 10, 8),
      );
      expect(PointRules.nextStreakDays(stats, DateTime.utc(2026, 7, 10, 22)), 3);
      expect(PointRules.nextStreakDays(stats, DateTime.utc(2026, 7, 11, 1)), 4);
      expect(PointRules.nextStreakDays(stats, DateTime.utc(2026, 7, 13)), 1);
      expect(
        PointRules.nextStreakDays(UserStatistics.empty(), DateTime.utc(2026, 7, 10)),
        1,
      );
    });
  });

  group('AchievementRules', () {
    test('unlocks respect thresholds and never repeat', () {
      final stats = UserStatistics.empty().copyWith(
        totalWorkouts: 10,
        totalPoints: 1200,
        currentStreakDays: 7,
      );
      final first = AchievementRules.newlyUnlocked(stats, alreadyUnlockedIds: {});
      expect(
        first.map((d) => d.id).toList()..sort(),
        ['first_workout', 'points_1000', 'streak_7', 'workouts_10'],
      );

      final again = AchievementRules.newlyUnlocked(
        stats,
        alreadyUnlockedIds: first.map((d) => d.id).toSet(),
      );
      expect(again, isEmpty);
    });

    test('composition achievements use the compositions counter', () {
      final unlocks = AchievementRules.newlyUnlocked(
        UserStatistics.empty(),
        compositionsSaved: 10,
        alreadyUnlockedIds: {},
      );
      expect(
        unlocks.map((d) => d.id).toList()..sort(),
        ['compositions_1', 'compositions_10'],
      );
    });

    test('catalog ids are unique (they are Firestore document ids)', () {
      final ids = AchievementRules.catalog.map((d) => d.id).toSet();
      expect(ids.length, AchievementRules.catalog.length);
    });
  });
}
