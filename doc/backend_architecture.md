# Beatter — Firebase Backend Architecture

Firebase project: **BeatterApp** (`beatterapp`, project number 242679736794).
Registered apps: Android (`com.nectares.beatter`), iOS/Apple (`com.nectares.beatter`), Web.

## Layers (clean architecture)

```
UI (widgets, pages)
  │  never sees Firebase — only the facades below
  ▼
Facades (lib/services/)              AuthService, CompositionRepository,
                                     ExerciseRepository, WorkoutTracker
  ▼
Domain (lib/domain/)                 entities + repository interfaces +
                                     PointRules / AchievementRules
  ▼
Data (lib/data/)                     firebase/ (production) and local/
                                     (offline fallback + test fakes)
  ▼
Composition root (lib/core/di/)      ServiceLocator (get_it), BackendMode
```

- `main.dart` calls `initializeFirebaseBackend()` (lib/core/firebase/): if
  Firebase init fails for any reason the app falls back to **local mode**
  (shared_preferences, mock auth) instead of refusing to start. The UI is
  identical in both modes.
- All data-layer errors are mapped to typed `AppFailure`s
  (lib/core/errors/app_failure.dart); widgets never see `FirebaseException`.
- Offline: Firestore persistence is enabled with unlimited cache. Writes are
  optimistic — snapshot listeners fire from the local cache immediately,
  queued writes sync when connectivity returns.

## Firestore schema

```
users/{uid}                          profile (displayName, photoUrl, username?, role, …)
users/{uid}/settings/main            private preferences
users/{uid}/workouts/{id}            append-only workout history (client-created)
users/{uid}/compositions/{id}        Composer Mode library
users/{uid}/exercises/{id}           Sheet Mode saved exercises
users/{uid}/stats/summary            aggregates — Cloud Functions only
users/{uid}/achievements/{defId}     unlocks — Cloud Functions only
users/{uid}/pointHistory/{id}        point ledger — Cloud Functions only
leaderboards/{boardId}/entries/{uid} boardId: global | weekly-YYYY-WW
usernames/{handle}                   handle uniqueness reservations (future social)
```

Design notes for scale/social:

- Everything user-owned lives under `users/{uid}` → single-document security
  rules, cheap per-user pagination, natural shard-by-user distribution.
- Leaderboard rows denormalize `displayName`/`photoUrl` so rendering a board
  is one query; `onProfileWritten` keeps them in sync.
- `stats/summary` equals the sum of the `pointHistory` ledger, so balances
  are auditable and recomputable.
- Dates are stored as UTC epoch millis (ints): locale-free, sortable, and
  identical semantics in Dart and TypeScript.
- Profiles are private today; flipping them public for social features is a
  rules-only change.

## Point pipeline (optimistic + authoritative)

1. A page calls `WorkoutTracker.recordCompleted(...)` → the workout doc is
   written with a **provisional** point estimate computed by the Dart
   `PointRules` (instant UI update, works offline).
2. The `onWorkoutCreated` Cloud Function recomputes canonically (same
   formula, TypeScript mirror), flips `pointsStatus` to `confirmed`, writes
   the ledger entry, updates `stats/summary`, unlocks achievements, and
   upserts the global + weekly leaderboard rows — all in one transaction,
   idempotent via deterministic ledger ids.
3. Security rules make workout docs append-only and all aggregates
   client-read-only, so points cannot be forged.

Formula (keep the two mirrors in sync — `lib/domain/logic/point_rules.dart`
and `functions/src/logic/points.ts`; parity is asserted by
`test/point_rules_test.dart` + `functions/src/test/logic.test.ts`):

```
base       = min(duration, 1h) ⌊/60⌋ × 10
difficulty = base × (100 + 25·(level−1)) ⌊/100⌋      level ∈ 1..5
accuracy   = difficulty × round(acc·100) ⌊/200⌋       up to +50%
streak     = 5 × min(streakDays, 10)
total      = clamp(difficulty + accuracy + streak, 0, 1500)
```

## Auth

Providers enabled on the project: **email/password, Google, anonymous**
(deployed via the `auth` block in firebase.json → `firebase deploy --only auth`).

- Email/password backs the existing login page (plus a new register toggle).
- Google: native `google_sign_in` 7.x flow on Android/iOS, `signInWithPopup`
  on web (the GoogleSignIn plugin is intentionally never initialized on web).
- Apple: `AppleAuthProvider` via firebase_auth (no extra plugin). Enable the
  provider in Firebase console + the "Sign in with Apple" capability in Xcode
  before shipping the iOS build.
- Anonymous → permanent upgrades keep the uid via `linkAnonymousTo*` methods.
- The admin role comes from `users/{uid}.role`, which clients can never set
  to `admin` (enforced by rules); grant it manually in the console.

## Operational checklist

Done (2026-07-11): apps registered, auth providers deployed, Firestore rules +
indexes deployed, all four Cloud Functions live in **europe-west4** (required:
the default database is in `eur3`).

Still manual:

1. **Cloud Storage**: click "Get started" at
   https://console.firebase.google.com/project/beatterapp/storage then
   `firebase deploy --only storage`.
2. **Android release Google Sign-In**: add your SHA-1/SHA-256 fingerprints in
   Project settings → Android app, then re-run `flutterfire configure`.
3. **Apple Sign-In**: enable the provider in console + Xcode capability.
4. **App Check**: debug builds print a debug token on first run — register it
   under App Check → Apps. For web, pass
   `--dart-define=APP_CHECK_RECAPTCHA_SITE_KEY=<key>`. Turn on enforcement
   (Firestore/Storage/Functions) only after all clients attest.
5. **Crashlytics**: dSYM upload for iOS release builds is configured by the
   flutterfire crashlytics integration (`uploadDebugSymbols: true`).

## Emulators & tests

- `firebase emulators:start` (auth 9099, firestore 8080, functions 5001,
  storage 9199, UI 4000).
- Flutter: `flutter test` (67 tests — models, rules mirrors, local backend,
  facades, UI).
- Functions: `cd functions && npm test` (pure-logic tests, Node test runner).
