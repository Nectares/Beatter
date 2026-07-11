import 'package:beatter/core/di/service_locator.dart';
import 'package:beatter/core/errors/app_failure.dart';
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

  test('AuthService.login: local fallback signs in plausible credentials as user',
      () async {
    final bad = await AuthService.login(
      email: 'someone@example.com',
      password: 'nope', // too short
      expectedRole: UserRole.user,
    );
    expect(bad, isNull);

    final user = await AuthService.login(
      email: 'someone@example.com',
      password: 'password123',
      expectedRole: UserRole.user,
    );
    expect(user, isNotNull);
    expect(user!.role, UserRole.user);

    // The admin role only exists on Firebase profiles now — no local
    // credential pair grants it.
    final admin = await AuthService.login(
      email: 'admin@beatter.com',
      password: 'Admin123!',
      expectedRole: UserRole.admin,
    );
    expect(admin, isNull);
  });

  test('AuthService.register validates the nickname and creates the account',
      () async {
    await expectLater(
      AuthService.register(
        email: 'nuovo@example.com',
        password: 'Password1',
        nickname: 'x', // too short
      ),
      throwsA(isA<DataFormatFailure>()),
    );

    final session = await AuthService.register(
      email: 'nuovo@example.com',
      password: 'Password1',
      nickname: 'drummer_01',
    );
    expect(session.role, UserRole.user);
    expect(session.email, 'nuovo@example.com');
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
