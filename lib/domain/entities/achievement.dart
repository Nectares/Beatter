import '../../core/utils/json_codecs.dart';

/// What an achievement's unlock criterion measures.
enum AchievementCriterion {
  totalWorkouts,
  totalPoints,
  streakDays,
  compositionsSaved,
}

/// Static catalog entry describing an achievement. Definitions live in code
/// (mirrored in the Cloud Functions package) so client and server always
/// agree; only *unlocks* are stored per-user in Firestore.
class AchievementDefinition {
  final String id;
  final String title;
  final String description;
  final AchievementCriterion criterion;
  final int threshold;

  /// Bonus points awarded on unlock (ledgered as a [PointSource.achievement]).
  final int rewardPoints;

  const AchievementDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.criterion,
    required this.threshold,
    required this.rewardPoints,
  });
}

/// A per-user unlock record (`users/{uid}/achievements/{definitionId}`).
/// Written only by Cloud Functions.
class UnlockedAchievement {
  static const int currentSchemaVersion = 1;

  final String definitionId;
  final DateTime unlockedAt;
  final int rewardPoints;
  final int schemaVersion;

  const UnlockedAchievement({
    required this.definitionId,
    required this.unlockedAt,
    required this.rewardPoints,
    this.schemaVersion = currentSchemaVersion,
  });

  Map<String, dynamic> toJson() => {
        'definitionId': definitionId,
        'unlockedAt': dateToJson(unlockedAt),
        'rewardPoints': rewardPoints,
        'schemaVersion': schemaVersion,
      };

  factory UnlockedAchievement.fromJson(Map<String, dynamic> json) =>
      UnlockedAchievement(
        definitionId: stringFromJson(json, 'definitionId'),
        unlockedAt: dateFromJson(json['unlockedAt']) ?? DateTime.now().toUtc(),
        rewardPoints: intFromJson(json, 'rewardPoints'),
        schemaVersion: intFromJson(json, 'schemaVersion', fallback: 1),
      );
}
