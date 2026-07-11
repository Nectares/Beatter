/**
 * Canonical point formula.
 *
 * ⚠️ Mirrored by lib/domain/logic/point_rules.dart on the client (used there
 * only for the optimistic provisional estimate). Keep both in sync; keep all
 * arithmetic integer so results are identical across languages.
 */
export const POINTS_PER_MINUTE = 10;
export const MAX_COUNTED_SECONDS = 3600;
export const MAX_POINTS_PER_WORKOUT = 1500;
export const STREAK_BONUS_PER_DAY = 5;
export const MAX_STREAK_BONUS_DAYS = 10;

export interface WorkoutInput {
  durationSeconds: number;
  difficultyLevel: number;
  accuracy: number | null;
  /** UTC epoch millis. */
  startedAt: number;
}

export interface StatsSnapshot {
  currentStreakDays: number;
  /** UTC epoch millis, null when no workout yet. */
  lastWorkoutAt: number | null;
}

const clamp = (v: number, lo: number, hi: number) => Math.min(Math.max(v, lo), hi);

export function basePoints(durationSeconds: number): number {
  const counted = clamp(Math.trunc(durationSeconds), 0, MAX_COUNTED_SECONDS);
  return Math.trunc(counted / 60) * POINTS_PER_MINUTE;
}

export function difficultyAdjusted(base: number, difficultyLevel: number): number {
  const level = clamp(Math.trunc(difficultyLevel), 1, 5);
  return Math.trunc((base * (100 + 25 * (level - 1))) / 100);
}

export function accuracyBonus(adjusted: number, accuracy: number | null): number {
  if (accuracy === null || accuracy === undefined) return 0;
  const pct = Math.round(clamp(accuracy, 0, 1) * 100);
  return Math.trunc((adjusted * pct) / 200);
}

export function streakBonus(streakDays: number): number {
  return STREAK_BONUS_PER_DAY * clamp(Math.trunc(streakDays), 0, MAX_STREAK_BONUS_DAYS);
}

export function totalFor(workout: WorkoutInput, streakDaysIncludingToday: number): number {
  const base = basePoints(workout.durationSeconds);
  const adjusted = difficultyAdjusted(base, workout.difficultyLevel);
  const bonus = accuracyBonus(adjusted, workout.accuracy);
  const streak = streakBonus(streakDaysIncludingToday);
  return clamp(adjusted + bonus + streak, 0, MAX_POINTS_PER_WORKOUT);
}

const utcDayNumber = (millis: number) => Math.floor(millis / 86_400_000);

/**
 * Streak reached with a workout at `startedAt`, given the stats from before
 * it. Same-day keeps the streak, next-day extends it, later resets to 1.
 */
export function nextStreakDays(stats: StatsSnapshot, startedAt: number): number {
  if (stats.lastWorkoutAt === null) return 1;
  const gap = utcDayNumber(startedAt) - utcDayNumber(stats.lastWorkoutAt);
  if (gap <= 0) return Math.max(stats.currentStreakDays, 1);
  if (gap === 1) return stats.currentStreakDays + 1;
  return 1;
}
