/**
 * Firestore paths — mirrors lib/data/firebase/firestore_paths.dart and
 * firestore.rules. Keep the three in sync when evolving the schema.
 */
export const paths = {
  user: (uid: string) => `users/${uid}`,
  statsSummary: (uid: string) => `users/${uid}/stats/summary`,
  workouts: (uid: string) => `users/${uid}/workouts`,
  compositions: (uid: string) => `users/${uid}/compositions`,
  achievements: (uid: string) => `users/${uid}/achievements`,
  pointHistory: (uid: string) => `users/${uid}/pointHistory`,
  leaderboardEntries: (boardId: string) => `leaderboards/${boardId}/entries`,
  usernames: () => `usernames`,
} as const;

/**
 * Firestore collection group that contains a user's per-board leaderboard
 * rows. Every entry document stores its owner's `uid`, so a collection-group
 * query by that field reaches the global board and every weekly board at once
 * without having to enumerate board ids.
 */
export const LEADERBOARD_ENTRIES_GROUP = "entries";

/** `weekly-2026-28` style board id for the ISO week containing `when`. */
export function weeklyBoardId(when: Date): string {
  const utc = new Date(Date.UTC(when.getUTCFullYear(), when.getUTCMonth(), when.getUTCDate()));
  const weekday = utc.getUTCDay() === 0 ? 7 : utc.getUTCDay();
  // ISO-8601: Thursday of the current week decides the year.
  const thursday = new Date(utc);
  thursday.setUTCDate(utc.getUTCDate() + 4 - weekday);
  const firstDayOfYear = Date.UTC(thursday.getUTCFullYear(), 0, 1);
  const week = 1 + Math.floor((thursday.getTime() - firstDayOfYear) / (7 * 24 * 3600 * 1000));
  return `weekly-${thursday.getUTCFullYear()}-${String(week).padStart(2, "0")}`;
}

export const GLOBAL_BOARD = "global";
