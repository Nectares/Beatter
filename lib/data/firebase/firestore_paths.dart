/// Single source of truth for Firestore document/collection paths.
///
/// Mirrored by `functions/src/paths.ts` and `firestore.rules`. Keep the three
/// in sync when evolving the schema.
abstract final class FirestorePaths {
  static String user(String uid) => 'users/$uid';
  static String settings(String uid) => 'users/$uid/settings/main';
  static String workouts(String uid) => 'users/$uid/workouts';
  static String compositions(String uid) => 'users/$uid/compositions';
  static String exercises(String uid) => 'users/$uid/exercises';
  static String readingScores(String uid) => 'users/$uid/readingScores';
  static String statsSummary(String uid) => 'users/$uid/stats/summary';
  static String achievements(String uid) => 'users/$uid/achievements';
  static String pointHistory(String uid) => 'users/$uid/pointHistory';
  static String leaderboardEntries(String boardId) => 'leaderboards/$boardId/entries';
  static String username(String handleLower) => 'usernames/$handleLower';

  /// Requisiti di versione dell'app: documento pubblico in lettura, scritto
  /// solo dalla console/Admin SDK.
  static const String appVersionConfig = 'config/appVersion';
}
