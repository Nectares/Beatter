import 'package:firebase_analytics/firebase_analytics.dart';

import '../../domain/services/analytics_tracker.dart';

class FirebaseAnalyticsTracker implements AnalyticsTracker {
  final FirebaseAnalytics _analytics;

  FirebaseAnalyticsTracker({FirebaseAnalytics? analytics})
      : _analytics = analytics ?? FirebaseAnalytics.instance;

  @override
  Future<void> setUserId(String? uid) => _analytics.setUserId(id: uid);

  @override
  Future<void> logLogin(String method) => _analytics.logLogin(loginMethod: method);

  @override
  Future<void> logSignUp(String method) => _analytics.logSignUp(signUpMethod: method);

  @override
  Future<void> logWorkoutCompleted({
    required String type,
    required int durationSeconds,
    required int provisionalPoints,
  }) =>
      _analytics.logEvent(name: 'workout_completed', parameters: {
        'workout_type': type,
        'duration_seconds': durationSeconds,
        'provisional_points': provisionalPoints,
      });

  @override
  Future<void> logCompositionSaved({required int noteCount}) =>
      _analytics.logEvent(name: 'composition_saved', parameters: {
        'note_count': noteCount,
      });

  @override
  Future<void> logAchievementUnlocked(String achievementId) =>
      _analytics.logUnlockAchievement(id: achievementId);

  @override
  Future<void> logScreenView(String screenName) =>
      _analytics.logScreenView(screenName: screenName);
}
