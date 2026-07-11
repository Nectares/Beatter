/**
 * Beatter Cloud Functions.
 *
 * Server-authoritative gamification pipeline:
 *  - onWorkoutCreated: canonical point calculation, stats aggregation,
 *    achievement unlocks, point ledger, leaderboard sync (global + weekly).
 *  - onCompositionCreated: composition-count achievements.
 *  - onProfileWritten: propagates displayName/photoUrl to leaderboard rows.
 *  - resetWeeklyPoints: Monday 00:00 UTC weekly counter reset.
 *
 * All writes are transactional and idempotent (deterministic ledger doc ids
 * guard against Cloud Functions' at-least-once delivery).
 */
import { initializeApp } from "firebase-admin/app";
import { FieldValue, getFirestore, Transaction } from "firebase-admin/firestore";
import { setGlobalOptions } from "firebase-functions/v2";
import { onDocumentCreated, onDocumentWritten } from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import * as logger from "firebase-functions/logger";

import { newlyUnlocked } from "./logic/achievements";
import { nextStreakDays, totalFor } from "./logic/points";
import { GLOBAL_BOARD, paths, weeklyBoardId } from "./paths";

initializeApp();
// europe-west4 is required for Firestore triggers: the (default) database
// lives in the eur3 multi-region, whose Eventarc location is europe-west4.
setGlobalOptions({ region: "europe-west4", maxInstances: 10 });

const db = () => getFirestore();

interface ProfileLite {
  displayName: string;
  photoUrl: string | null;
}

function readProfileLite(data: FirebaseFirestore.DocumentData | undefined): ProfileLite {
  return {
    displayName: (data?.displayName as string) ?? "Musicista",
    photoUrl: (data?.photoUrl as string) ?? null,
  };
}

/** Upserts the user's row on the global and current weekly boards. */
function syncLeaderboards(
  tx: Transaction,
  uid: string,
  profile: ProfileLite,
  totalPoints: number,
  weeklyPoints: number,
  now: number,
) {
  const entry = {
    uid,
    displayName: profile.displayName,
    photoUrl: profile.photoUrl,
    updatedAt: now,
    schemaVersion: 1,
  };
  tx.set(
    db().collection(paths.leaderboardEntries(GLOBAL_BOARD)).doc(uid),
    { ...entry, points: totalPoints },
    { merge: true },
  );
  tx.set(
    db().collection(paths.leaderboardEntries(weeklyBoardId(new Date(now)))).doc(uid),
    { ...entry, points: weeklyPoints },
    { merge: true },
  );
}

export const onWorkoutCreated = onDocumentCreated(
  "users/{uid}/workouts/{workoutId}",
  async (event) => {
    const { uid, workoutId } = event.params;
    const workout = event.data?.data();
    if (!workout) return;

    await db().runTransaction(async (tx) => {
      const ledgerRef = db().collection(paths.pointHistory(uid)).doc(`w-${workoutId}`);
      if ((await tx.get(ledgerRef)).exists) {
        logger.info("workout already processed, skipping", { uid, workoutId });
        return; // retry of an already-applied event
      }

      const statsRef = db().doc(paths.statsSummary(uid));
      const profileRef = db().doc(paths.user(uid));
      const achievementsRef = db().collection(paths.achievements(uid));
      const [statsSnap, profileSnap, achievementsSnap] = await Promise.all([
        tx.get(statsRef),
        tx.get(profileRef),
        tx.get(achievementsRef),
      ]);

      const stats = statsSnap.data() ?? {};
      const now = Date.now();
      const startedAt = (workout.startedAt as number) ?? now;
      const streak = nextStreakDays(
        {
          currentStreakDays: (stats.currentStreakDays as number) ?? 0,
          lastWorkoutAt: (stats.lastWorkoutAt as number) ?? null,
        },
        startedAt,
      );
      const points = totalFor(
        {
          durationSeconds: (workout.durationSeconds as number) ?? 0,
          difficultyLevel: (workout.difficultyLevel as number) ?? 1,
          accuracy: (workout.accuracy as number | null) ?? null,
          startedAt,
        },
        streak,
      );

      // 1. Confirm canonical points on the workout document.
      tx.update(event.data!.ref, { pointsEarned: points, pointsStatus: "confirmed" });

      // 2. Ledger the workout points (idempotency anchor).
      const workoutType = (workout.type as string) ?? "sheetReading";
      tx.set(ledgerRef, {
        id: ledgerRef.id,
        source: "workout",
        points,
        referenceId: workoutId,
        description: `Allenamento ${workoutType}`,
        createdAt: now,
        schemaVersion: 1,
      });

      // 3. Aggregate statistics.
      let totalPoints = ((stats.totalPoints as number) ?? 0) + points;
      let weeklyPoints = ((stats.weeklyPoints as number) ?? 0) + points;
      const totalWorkouts = ((stats.totalWorkouts as number) ?? 0) + 1;
      const longest = Math.max((stats.longestStreakDays as number) ?? 0, streak);
      const byType = { ...((stats.workoutsByType as Record<string, number>) ?? {}) };
      byType[workoutType] = (byType[workoutType] ?? 0) + 1;

      // 4. Achievement unlocks (+ their reward points, ledgered separately).
      const unlocked = new Set(achievementsSnap.docs.map((d) => d.id));
      const newUnlocks = newlyUnlocked(
        {
          totalWorkouts,
          totalPoints,
          currentStreakDays: streak,
          compositionsSaved: Number.MIN_SAFE_INTEGER, // not evaluated here
        },
        unlocked,
      );
      for (const def of newUnlocks) {
        tx.set(achievementsRef.doc(def.id), {
          definitionId: def.id,
          unlockedAt: now,
          rewardPoints: def.rewardPoints,
          schemaVersion: 1,
        });
        tx.set(db().collection(paths.pointHistory(uid)).doc(`a-${def.id}`), {
          id: `a-${def.id}`,
          source: "achievement",
          points: def.rewardPoints,
          referenceId: def.id,
          description: def.title,
          createdAt: now,
          schemaVersion: 1,
        });
        totalPoints += def.rewardPoints;
        weeklyPoints += def.rewardPoints;
      }

      tx.set(
        statsRef,
        {
          totalPoints,
          weeklyPoints,
          totalWorkouts,
          totalDurationSeconds: FieldValue.increment(
            (workout.durationSeconds as number) ?? 0,
          ),
          workoutsByType: byType,
          currentStreakDays: streak,
          longestStreakDays: longest,
          lastWorkoutAt: startedAt,
          updatedAt: now,
          schemaVersion: 1,
        },
        { merge: true },
      );

      // 5. Leaderboards.
      syncLeaderboards(tx, uid, readProfileLite(profileSnap.data()), totalPoints, weeklyPoints, now);
    });
  },
);

export const onCompositionCreated = onDocumentCreated(
  "users/{uid}/compositions/{compositionId}",
  async (event) => {
    const { uid } = event.params;

    const count = (
      await db().collection(paths.compositions(uid)).count().get()
    ).data().count;

    await db().runTransaction(async (tx) => {
      const statsRef = db().doc(paths.statsSummary(uid));
      const profileRef = db().doc(paths.user(uid));
      const achievementsRef = db().collection(paths.achievements(uid));
      const [statsSnap, profileSnap, achievementsSnap] = await Promise.all([
        tx.get(statsRef),
        tx.get(profileRef),
        tx.get(achievementsRef),
      ]);

      const stats = statsSnap.data() ?? {};
      const unlocked = new Set(achievementsSnap.docs.map((d) => d.id));
      const newUnlocks = newlyUnlocked(
        {
          totalWorkouts: Number.MIN_SAFE_INTEGER,
          totalPoints: Number.MIN_SAFE_INTEGER,
          currentStreakDays: Number.MIN_SAFE_INTEGER,
          compositionsSaved: count,
        },
        unlocked,
      );
      if (newUnlocks.length === 0) return;

      const now = Date.now();
      let totalPoints = (stats.totalPoints as number) ?? 0;
      let weeklyPoints = (stats.weeklyPoints as number) ?? 0;
      for (const def of newUnlocks) {
        tx.set(achievementsRef.doc(def.id), {
          definitionId: def.id,
          unlockedAt: now,
          rewardPoints: def.rewardPoints,
          schemaVersion: 1,
        });
        tx.set(db().collection(paths.pointHistory(uid)).doc(`a-${def.id}`), {
          id: `a-${def.id}`,
          source: "achievement",
          points: def.rewardPoints,
          referenceId: def.id,
          description: def.title,
          createdAt: now,
          schemaVersion: 1,
        });
        totalPoints += def.rewardPoints;
        weeklyPoints += def.rewardPoints;
      }

      tx.set(
        statsRef,
        { totalPoints, weeklyPoints, updatedAt: now, schemaVersion: 1 },
        { merge: true },
      );
      syncLeaderboards(tx, uid, readProfileLite(profileSnap.data()), totalPoints, weeklyPoints, now);
    });
  },
);

/** Keeps denormalized leaderboard identity in sync with profile edits. */
export const onProfileWritten = onDocumentWritten("users/{uid}", async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!after) return; // profile deleted — entries are cleaned up elsewhere
  if (
    before &&
    before.displayName === after.displayName &&
    before.photoUrl === after.photoUrl
  ) {
    return;
  }

  const uid = event.params.uid;
  const identity = {
    displayName: (after.displayName as string) ?? "Musicista",
    photoUrl: (after.photoUrl as string) ?? null,
  };
  const batch = db().batch();
  for (const boardId of [GLOBAL_BOARD, weeklyBoardId(new Date())]) {
    const ref = db().collection(paths.leaderboardEntries(boardId)).doc(uid);
    const snap = await ref.get();
    if (snap.exists) batch.update(ref, identity);
  }
  await batch.commit();
});

/** Weekly counters reset every Monday 00:00 UTC (boards rotate by id). */
export const resetWeeklyPoints = onSchedule(
  { schedule: "0 0 * * 1", timeZone: "Etc/UTC" },
  async () => {
    const summaries = await db()
      .collectionGroup("stats")
      .where("weeklyPoints", ">", 0)
      .get();
    let batch = db().batch();
    let pending = 0;
    for (const doc of summaries.docs) {
      batch.update(doc.ref, { weeklyPoints: 0, updatedAt: Date.now() });
      if (++pending === 400) {
        await batch.commit();
        batch = db().batch();
        pending = 0;
      }
    }
    if (pending > 0) await batch.commit();
    logger.info(`weekly points reset for ${summaries.size} users`);
  },
);
