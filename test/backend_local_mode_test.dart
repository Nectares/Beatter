import 'package:beatter/core/di/service_locator.dart';
import 'package:beatter/domain/entities/workout_session.dart';
import 'package:beatter/domain/repositories/auth_repository.dart';
import 'package:beatter/domain/repositories/gamification_repositories.dart';
import 'package:beatter/domain/repositories/workout_repository.dart';
import 'package:beatter/services/auth_service.dart';
import 'package:beatter/services/workout_tracker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// End-to-end test of the backend in local mode: DI wiring, the preserved
/// AuthService contract, and the gamification pipeline (the local engine
/// applies the same rules the Cloud Function applies in production).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    ServiceLocator.configureLocal();
  });

  test('locator resolves every repository interface', () {
    expect(ServiceLocator.get<AuthRepository>(), isNotNull);
    expect(ServiceLocator.get<WorkoutRepository>(), isNotNull);
    expect(ServiceLocator.get<StatisticsRepository>(), isNotNull);
    expect(ServiceLocator.get<PointsRepository>(), isNotNull);
    expect(ServiceLocator.get<AchievementsRepository>(), isNotNull);
    expect(ServiceLocator.get<LeaderboardRepository>(), isNotNull);
    expect(ServiceLocator.get<DocumentStoreFactory>(), isNotNull);
    expect(ServiceLocator.mode, BackendMode.local);
  });

  test('AuthService.login preserves the historical mock contract', () async {
    final bad = await AuthService.login(
      email: 'user@beatter.com',
      password: 'nope',
      expectedRole: UserRole.user,
    );
    expect(bad, isNull);

    final user = await AuthService.login(
      email: 'user@beatter.com',
      password: 'password123',
      expectedRole: UserRole.user,
    );
    expect(user, isNotNull);
    expect(user!.role, UserRole.user);

    final admin = await AuthService.login(
      email: 'admin@beatter.com',
      password: 'admin123',
      expectedRole: UserRole.admin,
    );
    expect(admin, isNotNull);
    expect(admin!.role, UserRole.admin);
  });

  test('recording a workout updates points, stats and achievements', () async {
    final session = await WorkoutTracker.recordCompleted(
      type: WorkoutType.sheetReading,
      startedAt: DateTime.now().toUtc(),
      durationSeconds: 600,
      bpm: 100,
      difficultyLevel: 1,
    );

    expect(session, isNotNull);
    // 10 min → 100 base + 5 streak-day-1 bonus; local mode confirms directly.
    expect(session!.pointsEarned, 105);
    expect(session.pointsStatus, PointsStatus.confirmed);

    // Local-mode repositories are single-user; the uid argument is ignored.
    final stats =
        await ServiceLocator.get<StatisticsRepository>().fetchStatistics('any');
    // 105 workout points + 50 'first_workout' achievement reward.
    expect(stats.totalPoints, 155);
    expect(stats.totalWorkouts, 1);
    expect(stats.currentStreakDays, 1);

    final unlocked = await ServiceLocator.get<AchievementsRepository>()
        .watchUnlocked('any')
        .first;
    expect(unlocked.map((a) => a.definitionId), contains('first_workout'));

    final ledger =
        await ServiceLocator.get<PointsRepository>().watchHistory('any').first;
    expect(ledger, hasLength(2)); // workout + achievement entries
    expect(ledger.fold<int>(0, (sum, e) => sum + e.points), 155);
  });

  test('leaderboard reflects the local user total', () async {
    final board = await ServiceLocator.get<LeaderboardRepository>()
        .watchTop('global')
        .first;
    expect(board.single.points, 155);
  });
}
