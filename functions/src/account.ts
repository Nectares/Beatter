/**
 * Account deletion — GDPR / Play Store / App Store "delete your account".
 *
 * A single authenticated callable that erases everything belonging to the
 * caller, in a fixed, auditable order:
 *
 *   1. Firestore  — the user document and every subcollection under it
 *                   (profile, settings, workouts, compositions, exercises,
 *                   readingScores, stats, achievements, pointHistory), plus
 *                   the denormalized rows that live outside that tree: the
 *                   username reservation and every leaderboard entry.
 *   2. Storage    — every object under `users/{uid}/` (avatars, PDF exports).
 *   3. Auth       — the Firebase Authentication user itself.
 *
 * Why this order: Auth is the recovery anchor. Deleting it last means that if
 * step 1 or 2 throws we abort *before* the account becomes unreachable, so the
 * user can retry (or support can intervene) with the account still intact.
 * Once Auth is gone the operation is irreversible by design.
 *
 * Security: the uid is taken exclusively from the verified `request.auth`
 * context — never from client-supplied data — so a caller can only ever
 * delete their own account.
 */
import { getFirestore } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import { getAuth } from "firebase-admin/auth";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";

import { LEADERBOARD_ENTRIES_GROUP, paths } from "./paths";

// Reuse the project's European region (the (default) Firestore database lives
// in the eur3 multi-region, served from europe-west4). Set explicitly here so
// the region is correct regardless of module evaluation order relative to the
// global options configured in index.ts.
const REGION = "europe-west4";

/** Storage prefix owned by a user (see storage.rules). */
const userStoragePrefix = (uid: string) => `users/${uid}/`;

/**
 * Deletes the user document and all of its subcollections. `recursiveDelete`
 * streams the deletes in batches, so it scales past the 500-writes limit of a
 * single batch and needs no explicit pagination.
 */
async function deleteFirestoreTree(uid: string): Promise<void> {
  const db = getFirestore();
  await db.recursiveDelete(db.doc(paths.user(uid)));
}

/** Removes the user's username reservation(s), if any. */
async function deleteUsernameReservations(uid: string): Promise<void> {
  const db = getFirestore();
  const snap = await db.collection(paths.usernames()).where("uid", "==", uid).get();
  if (snap.empty) return;
  const batch = db.batch();
  snap.docs.forEach((doc) => batch.delete(doc.ref));
  await batch.commit();
}

/** Removes the user's row from the global and every weekly leaderboard. */
async function deleteLeaderboardEntries(uid: string): Promise<void> {
  const db = getFirestore();
  const snap = await db
    .collectionGroup(LEADERBOARD_ENTRIES_GROUP)
    .where("uid", "==", uid)
    .get();
  if (snap.empty) return;
  let batch = db.batch();
  let pending = 0;
  for (const doc of snap.docs) {
    batch.delete(doc.ref);
    if (++pending === 400) {
      await batch.commit();
      batch = db.batch();
      pending = 0;
    }
  }
  if (pending > 0) await batch.commit();
}

/** Deletes every Storage object under the user's folder. No-op if empty. */
async function deleteStorageFiles(uid: string): Promise<void> {
  await getStorage()
    .bucket()
    .deleteFiles({ prefix: userStoragePrefix(uid), force: true });
}

export const deleteAccount = onCall({ region: REGION }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    // Not signed in (or a forged/expired token App Check couldn't validate).
    throw new HttpsError("unauthenticated", "Autenticazione richiesta.");
  }

  logger.info("account deletion requested", { uid });

  // 1. Firestore — owned tree + denormalized rows outside it.
  try {
    await deleteFirestoreTree(uid);
    await deleteUsernameReservations(uid);
    await deleteLeaderboardEntries(uid);
    logger.info("account deletion: Firestore data removed", { uid });
  } catch (err) {
    logger.error("account deletion: Firestore step failed", { uid, err });
    // Auth is still intact here — the user can safely retry.
    throw new HttpsError(
      "internal",
      "Eliminazione dei dati non riuscita. Riprova più tardi.",
    );
  }

  // 2. Storage — user-owned files.
  try {
    await deleteStorageFiles(uid);
    logger.info("account deletion: Storage files removed", { uid });
  } catch (err) {
    logger.error("account deletion: Storage step failed", { uid, err });
    throw new HttpsError(
      "internal",
      "Eliminazione dei file non riuscita. Riprova più tardi.",
    );
  }

  // 3. Auth — irreversible from here on.
  try {
    await getAuth().deleteUser(uid);
    logger.info("account deletion: Auth user removed", { uid });
  } catch (err) {
    // Firestore/Storage are already gone; if the record no longer exists the
    // account is effectively deleted, so treat "not found" as success and
    // keep the operation idempotent under Cloud Functions' retries.
    if (
      typeof err === "object" &&
      err !== null &&
      (err as { code?: string }).code === "auth/user-not-found"
    ) {
      logger.warn("account deletion: Auth user already absent", { uid });
    } else {
      logger.error("account deletion: Auth step failed", { uid, err });
      throw new HttpsError(
        "internal",
        "Eliminazione dell'account non riuscita. Contatta il supporto.",
      );
    }
  }

  logger.info("account deletion completed", { uid });
  return { success: true };
});
