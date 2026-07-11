/**
 * Achievement catalog + evaluation.
 *
 * ⚠️ Mirrored by lib/domain/logic/achievement_rules.dart. Ids are stable
 * forever — they are document ids in users/{uid}/achievements.
 */
export type Criterion = "totalWorkouts" | "totalPoints" | "streakDays" | "compositionsSaved";

export interface AchievementDefinition {
  id: string;
  title: string;
  criterion: Criterion;
  threshold: number;
  rewardPoints: number;
}

export const CATALOG: readonly AchievementDefinition[] = [
  { id: "first_workout", title: "Primo allenamento", criterion: "totalWorkouts", threshold: 1, rewardPoints: 50 },
  { id: "workouts_10", title: "In cammino", criterion: "totalWorkouts", threshold: 10, rewardPoints: 100 },
  { id: "workouts_50", title: "Costanza", criterion: "totalWorkouts", threshold: 50, rewardPoints: 250 },
  { id: "workouts_100", title: "Centurione del ritmo", criterion: "totalWorkouts", threshold: 100, rewardPoints: 500 },
  { id: "points_1000", title: "Mille!", criterion: "totalPoints", threshold: 1000, rewardPoints: 100 },
  { id: "points_10000", title: "Diecimila!", criterion: "totalPoints", threshold: 10000, rewardPoints: 500 },
  { id: "streak_7", title: "Una settimana di fila", criterion: "streakDays", threshold: 7, rewardPoints: 150 },
  { id: "streak_30", title: "Un mese di fila", criterion: "streakDays", threshold: 30, rewardPoints: 750 },
  { id: "compositions_1", title: "Compositore esordiente", criterion: "compositionsSaved", threshold: 1, rewardPoints: 50 },
  { id: "compositions_10", title: "Compositore prolifico", criterion: "compositionsSaved", threshold: 10, rewardPoints: 200 },
];

export interface ProgressSnapshot {
  totalWorkouts: number;
  totalPoints: number;
  currentStreakDays: number;
  compositionsSaved: number;
}

export function newlyUnlocked(
  progress: ProgressSnapshot,
  alreadyUnlockedIds: ReadonlySet<string>,
): AchievementDefinition[] {
  return CATALOG.filter((def) => {
    if (alreadyUnlockedIds.has(def.id)) return false;
    const value =
      def.criterion === "totalWorkouts" ? progress.totalWorkouts :
      def.criterion === "totalPoints" ? progress.totalPoints :
      def.criterion === "streakDays" ? progress.currentStreakDays :
      progress.compositionsSaved;
    return value >= def.threshold;
  });
}
