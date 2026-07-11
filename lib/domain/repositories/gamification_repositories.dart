import '../entities/leaderboard_entry.dart';
import '../entities/point_entry.dart';
import '../entities/achievement.dart';
import '../entities/user_statistics.dart';

/// Read-only view of the server-maintained statistics summary.
abstract interface class StatisticsRepository {
  /// Emits [UserStatistics.empty] until the first workout is processed.
  Stream<UserStatistics> watchStatistics(String uid);

  Future<UserStatistics> fetchStatistics(String uid);
}

/// Read-only view of the server-maintained point ledger.
abstract interface class PointsRepository {
  Stream<List<PointEntry>> watchHistory(String uid, {int limit = 50});
}

/// Read-only view of per-user achievement unlocks (definitions ship in code,
/// see [AchievementRules.catalog]).
abstract interface class AchievementsRepository {
  Stream<List<UnlockedAchievement>> watchUnlocked(String uid);
}

/// Read-only leaderboards, synchronized by Cloud Functions.
abstract interface class LeaderboardRepository {
  Stream<List<LeaderboardEntry>> watchTop(String boardId, {int limit = 100});

  /// The signed-in user's own row (null until they score points on [boardId]).
  Stream<LeaderboardEntry?> watchEntry(String boardId, String uid);
}
