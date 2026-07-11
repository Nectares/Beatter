import 'dart:convert';

import 'package:beatter/domain/entities/achievement.dart';
import 'package:beatter/domain/entities/leaderboard_entry.dart';
import 'package:beatter/domain/entities/point_entry.dart';
import 'package:beatter/domain/entities/user_profile.dart';
import 'package:beatter/domain/entities/user_settings.dart';
import 'package:beatter/domain/entities/user_statistics.dart';
import 'package:beatter/domain/entities/workout_session.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every entity must survive a full JSON round-trip (including through a
/// string encode, as Firestore/API boundaries do) and must tolerate missing
/// fields from older schema versions.
void main() {
  Map<String, dynamic> roundTrip(Map<String, dynamic> json) =>
      jsonDecode(jsonEncode(json)) as Map<String, dynamic>;

  final when = DateTime.utc(2026, 7, 11, 9, 30);

  test('UserProfile round-trips', () {
    final profile = UserProfile(
      uid: 'u1',
      email: 'test@beatter.com',
      displayName: 'Test',
      photoUrl: 'https://example.com/p.jpg',
      username: 'tester',
      bio: 'drums',
      role: UserProfileRole.admin,
      createdAt: when,
      updatedAt: when,
    );
    final decoded = UserProfile.fromJson(roundTrip(profile.toJson()));
    expect(decoded.uid, 'u1');
    expect(decoded.role, UserProfileRole.admin);
    expect(decoded.username, 'tester');
    expect(decoded.createdAt, when);
  });

  test('UserProfile tolerates missing fields and unknown role', () {
    final decoded = UserProfile.fromJson({'uid': 'u2', 'role': 'superuser'});
    expect(decoded.displayName, 'Musicista');
    expect(decoded.role, UserProfileRole.user); // unknown roles never escalate
  });

  test('UserSettings round-trips and defaults', () {
    final settings = UserSettings.defaults().copyWith(defaultBpm: 132, locale: 'en');
    final decoded = UserSettings.fromJson(roundTrip(settings.toJson()));
    expect(decoded.defaultBpm, 132);
    expect(decoded.locale, 'en');
    expect(UserSettings.fromJson(const {}).defaultTimeSignature, '4/4');
  });

  test('WorkoutSession round-trips', () {
    final workout = WorkoutSession(
      id: 'w1',
      type: WorkoutType.polyrhythm,
      startedAt: when,
      durationSeconds: 900,
      bpm: 120,
      difficultyLevel: 3,
      accuracy: 0.85,
      sourceId: 'ex-1',
      pointsEarned: 250,
      pointsStatus: PointsStatus.confirmed,
      createdAt: when,
    );
    final decoded = WorkoutSession.fromJson(roundTrip(workout.toJson()));
    expect(decoded.type, WorkoutType.polyrhythm);
    expect(decoded.accuracy, 0.85);
    expect(decoded.pointsStatus, PointsStatus.confirmed);
    expect(decoded.startedAt, when);
  });

  test('WorkoutSession tolerates junk', () {
    final decoded = WorkoutSession.fromJson(const {'type': 'yoga', 'bpm': 'fast'});
    expect(decoded.type, WorkoutType.sheetReading);
    expect(decoded.bpm, 100);
    expect(decoded.pointsStatus, PointsStatus.provisional);
  });

  test('UserStatistics round-trips including type map', () {
    final stats = UserStatistics(
      totalPoints: 5000,
      weeklyPoints: 300,
      totalWorkouts: 42,
      totalDurationSeconds: 36000,
      workoutsByType: const {'sheetReading': 30, 'polyrhythm': 12},
      currentStreakDays: 6,
      longestStreakDays: 14,
      lastWorkoutAt: when,
      updatedAt: when,
    );
    final decoded = UserStatistics.fromJson(roundTrip(stats.toJson()));
    expect(decoded.workoutsByType['sheetReading'], 30);
    expect(decoded.lastWorkoutAt, when);
    expect(decoded.longestStreakDays, 14);
  });

  test('PointEntry / UnlockedAchievement / LeaderboardEntry round-trip', () {
    final entry = PointEntry(
      id: 'p1',
      source: PointSource.achievement,
      points: 150,
      referenceId: 'streak_7',
      description: 'Una settimana di fila',
      createdAt: when,
    );
    expect(PointEntry.fromJson(roundTrip(entry.toJson())).source,
        PointSource.achievement);

    final unlock = UnlockedAchievement(
        definitionId: 'streak_7', unlockedAt: when, rewardPoints: 150);
    expect(UnlockedAchievement.fromJson(roundTrip(unlock.toJson())).definitionId,
        'streak_7');

    final row = LeaderboardEntry(
        uid: 'u1', displayName: 'Test', points: 990, updatedAt: when);
    expect(LeaderboardEntry.fromJson(roundTrip(row.toJson())).points, 990);
  });

  test('legacy ISO-8601 date strings still parse', () {
    final decoded = WorkoutSession.fromJson({
      'id': 'w1',
      'type': 'flowMode',
      'startedAt': '2026-07-11T09:30:00.000Z',
      'durationSeconds': 60,
      'bpm': 90,
    });
    expect(decoded.startedAt, when);
  });

  test('weekly leaderboard ids follow ISO weeks', () {
    expect(LeaderboardIds.weekly(DateTime.utc(2026, 7, 11)), 'weekly-2026-28');
    // Year boundary: 2026-01-01 falls in ISO week 1 of 2026.
    expect(LeaderboardIds.weekly(DateTime.utc(2026, 1, 1)), 'weekly-2026-01');
    // 2027-01-01 is a Friday → ISO week 53 of 2026.
    expect(LeaderboardIds.weekly(DateTime.utc(2027, 1, 1)), 'weekly-2026-53');
  });
}
