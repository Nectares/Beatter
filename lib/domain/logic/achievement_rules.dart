import '../entities/achievement.dart';
import '../entities/user_statistics.dart';

/// Achievement catalog + evaluation.
///
/// ⚠️ Mirrored in `functions/src/logic/achievements.ts` (the server performs
/// the authoritative unlock + reward ledgering). Ids are stable forever —
/// they are Firestore document ids in `users/{uid}/achievements`.
abstract final class AchievementRules {
  static const List<AchievementDefinition> catalog = [
    AchievementDefinition(
      id: 'first_workout',
      title: 'Primo allenamento',
      description: 'Completa il tuo primo allenamento.',
      criterion: AchievementCriterion.totalWorkouts,
      threshold: 1,
      rewardPoints: 50,
    ),
    AchievementDefinition(
      id: 'workouts_10',
      title: 'In cammino',
      description: 'Completa 10 allenamenti.',
      criterion: AchievementCriterion.totalWorkouts,
      threshold: 10,
      rewardPoints: 100,
    ),
    AchievementDefinition(
      id: 'workouts_50',
      title: 'Costanza',
      description: 'Completa 50 allenamenti.',
      criterion: AchievementCriterion.totalWorkouts,
      threshold: 50,
      rewardPoints: 250,
    ),
    AchievementDefinition(
      id: 'workouts_100',
      title: 'Centurione del ritmo',
      description: 'Completa 100 allenamenti.',
      criterion: AchievementCriterion.totalWorkouts,
      threshold: 100,
      rewardPoints: 500,
    ),
    AchievementDefinition(
      id: 'points_1000',
      title: 'Mille!',
      description: 'Raggiungi 1.000 punti.',
      criterion: AchievementCriterion.totalPoints,
      threshold: 1000,
      rewardPoints: 100,
    ),
    AchievementDefinition(
      id: 'points_10000',
      title: 'Diecimila!',
      description: 'Raggiungi 10.000 punti.',
      criterion: AchievementCriterion.totalPoints,
      threshold: 10000,
      rewardPoints: 500,
    ),
    AchievementDefinition(
      id: 'streak_7',
      title: 'Una settimana di fila',
      description: 'Allenati per 7 giorni consecutivi.',
      criterion: AchievementCriterion.streakDays,
      threshold: 7,
      rewardPoints: 150,
    ),
    AchievementDefinition(
      id: 'streak_30',
      title: 'Un mese di fila',
      description: 'Allenati per 30 giorni consecutivi.',
      criterion: AchievementCriterion.streakDays,
      threshold: 30,
      rewardPoints: 750,
    ),
    AchievementDefinition(
      id: 'compositions_1',
      title: 'Compositore esordiente',
      description: 'Salva la tua prima composizione.',
      criterion: AchievementCriterion.compositionsSaved,
      threshold: 1,
      rewardPoints: 50,
    ),
    AchievementDefinition(
      id: 'compositions_10',
      title: 'Compositore prolifico',
      description: 'Salva 10 composizioni.',
      criterion: AchievementCriterion.compositionsSaved,
      threshold: 10,
      rewardPoints: 200,
    ),
  ];

  static AchievementDefinition? byId(String id) {
    for (final def in catalog) {
      if (def.id == id) return def;
    }
    return null;
  }

  /// Definitions newly satisfied by [stats] (+ [compositionsSaved]) that are
  /// not in [alreadyUnlockedIds].
  static List<AchievementDefinition> newlyUnlocked(
    UserStatistics stats, {
    int compositionsSaved = 0,
    required Set<String> alreadyUnlockedIds,
  }) {
    final result = <AchievementDefinition>[];
    for (final def in catalog) {
      if (alreadyUnlockedIds.contains(def.id)) continue;
      final value = switch (def.criterion) {
        AchievementCriterion.totalWorkouts => stats.totalWorkouts,
        AchievementCriterion.totalPoints => stats.totalPoints,
        AchievementCriterion.streakDays => stats.currentStreakDays,
        AchievementCriterion.compositionsSaved => compositionsSaved,
      };
      if (value >= def.threshold) result.add(def);
    }
    return result;
  }
}
