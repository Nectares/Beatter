import '../../core/utils/json_codecs.dart';

/// Aggregated practice statistics (`users/{uid}/stats/summary`).
///
/// Written exclusively by Cloud Functions (security rules block client
/// writes) so totals and streaks can't drift or be forged. The client keeps
/// an optimistic local copy while a workout's points are still provisional.
class UserStatistics {
  static const int currentSchemaVersion = 1;

  final int totalPoints;
  final int weeklyPoints;
  final int totalWorkouts;
  final int totalDurationSeconds;

  /// Workout counts keyed by [WorkoutType.name].
  final Map<String, int> workoutsByType;

  final int currentStreakDays;
  final int longestStreakDays;
  final DateTime? lastWorkoutAt;
  final DateTime updatedAt;
  final int schemaVersion;

  const UserStatistics({
    this.totalPoints = 0,
    this.weeklyPoints = 0,
    this.totalWorkouts = 0,
    this.totalDurationSeconds = 0,
    this.workoutsByType = const {},
    this.currentStreakDays = 0,
    this.longestStreakDays = 0,
    this.lastWorkoutAt,
    required this.updatedAt,
    this.schemaVersion = currentSchemaVersion,
  });

  factory UserStatistics.empty() => UserStatistics(updatedAt: DateTime.now().toUtc());

  UserStatistics copyWith({
    int? totalPoints,
    int? weeklyPoints,
    int? totalWorkouts,
    int? totalDurationSeconds,
    Map<String, int>? workoutsByType,
    int? currentStreakDays,
    int? longestStreakDays,
    DateTime? lastWorkoutAt,
    DateTime? updatedAt,
  }) {
    return UserStatistics(
      totalPoints: totalPoints ?? this.totalPoints,
      weeklyPoints: weeklyPoints ?? this.weeklyPoints,
      totalWorkouts: totalWorkouts ?? this.totalWorkouts,
      totalDurationSeconds: totalDurationSeconds ?? this.totalDurationSeconds,
      workoutsByType: workoutsByType ?? this.workoutsByType,
      currentStreakDays: currentStreakDays ?? this.currentStreakDays,
      longestStreakDays: longestStreakDays ?? this.longestStreakDays,
      lastWorkoutAt: lastWorkoutAt ?? this.lastWorkoutAt,
      updatedAt: updatedAt ?? this.updatedAt,
      schemaVersion: schemaVersion,
    );
  }

  Map<String, dynamic> toJson() => {
        'totalPoints': totalPoints,
        'weeklyPoints': weeklyPoints,
        'totalWorkouts': totalWorkouts,
        'totalDurationSeconds': totalDurationSeconds,
        'workoutsByType': workoutsByType,
        'currentStreakDays': currentStreakDays,
        'longestStreakDays': longestStreakDays,
        'lastWorkoutAt': lastWorkoutAt == null ? null : dateToJson(lastWorkoutAt!),
        'updatedAt': dateToJson(updatedAt),
        'schemaVersion': schemaVersion,
      };

  factory UserStatistics.fromJson(Map<String, dynamic> json) => UserStatistics(
        totalPoints: intFromJson(json, 'totalPoints'),
        weeklyPoints: intFromJson(json, 'weeklyPoints'),
        totalWorkouts: intFromJson(json, 'totalWorkouts'),
        totalDurationSeconds: intFromJson(json, 'totalDurationSeconds'),
        workoutsByType: intMapFromJson(json['workoutsByType']),
        currentStreakDays: intFromJson(json, 'currentStreakDays'),
        longestStreakDays: intFromJson(json, 'longestStreakDays'),
        lastWorkoutAt: dateFromJson(json['lastWorkoutAt']),
        updatedAt: dateFromJson(json['updatedAt']) ?? DateTime.now().toUtc(),
        schemaVersion: intFromJson(json, 'schemaVersion', fallback: 1),
      );
}
