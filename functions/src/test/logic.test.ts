/**
 * Pure-logic tests (run with `npm test`). The same scenarios are asserted in
 * the Flutter test suite against the Dart mirror (test/point_rules_test.dart)
 * so drift between the two implementations shows up as a failing pair.
 */
import assert from "node:assert/strict";
import { test } from "node:test";

import { newlyUnlocked } from "../logic/achievements";
import { nextStreakDays, totalFor } from "../logic/points";

test("10 minutes at level 1, no accuracy, streak 1 → 105", () => {
  const points = totalFor(
    { durationSeconds: 600, difficultyLevel: 1, accuracy: null, startedAt: 0 },
    1,
  );
  assert.equal(points, 100 + 5);
});

test("30 minutes at level 3, 80% accuracy, streak 5 → 655", () => {
  // base 300, difficulty ×1.5 = 450, accuracy 450*80/200 = 180, streak 25.
  const points = totalFor(
    { durationSeconds: 1800, difficultyLevel: 3, accuracy: 0.8, startedAt: 0 },
    5,
  );
  assert.equal(points, 450 + 180 + 25);
});

test("points cap at 1500", () => {
  const points = totalFor(
    { durationSeconds: 999999, difficultyLevel: 5, accuracy: 1, startedAt: 0 },
    30,
  );
  assert.equal(points, 1500);
});

test("streak: same day keeps, next day extends, gap resets", () => {
  const day = 86_400_000;
  const stats = { currentStreakDays: 3, lastWorkoutAt: 10 * day };
  assert.equal(nextStreakDays(stats, 10 * day + 3600_000), 3);
  assert.equal(nextStreakDays(stats, 11 * day), 4);
  assert.equal(nextStreakDays(stats, 13 * day), 1);
  assert.equal(nextStreakDays({ currentStreakDays: 0, lastWorkoutAt: null }, 0), 1);
});

test("achievements unlock once and respect thresholds", () => {
  const progress = {
    totalWorkouts: 10,
    totalPoints: 1200,
    currentStreakDays: 7,
    compositionsSaved: 0,
  };
  const first = newlyUnlocked(progress, new Set());
  assert.deepEqual(
    first.map((d) => d.id).sort(),
    ["first_workout", "points_1000", "streak_7", "workouts_10"],
  );
  const again = newlyUnlocked(progress, new Set(first.map((d) => d.id)));
  assert.equal(again.length, 0);
});
