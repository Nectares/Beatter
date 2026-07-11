/// Product analytics boundary (Firebase Analytics in production, no-op in
/// local mode and tests). Event names/params are centralized here so they
/// stay consistent across the app.
abstract interface class AnalyticsTracker {
  Future<void> setUserId(String? uid);

  Future<void> logLogin(String method);

  Future<void> logSignUp(String method);

  Future<void> logWorkoutCompleted({
    required String type,
    required int durationSeconds,
    required int provisionalPoints,
  });

  Future<void> logCompositionSaved({required int noteCount});

  Future<void> logAchievementUnlocked(String achievementId);

  Future<void> logScreenView(String screenName);
}
