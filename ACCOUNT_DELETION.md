# Account Deletion

End-to-end, in-app account deletion for Beatter, built to satisfy the
[Google Play](https://support.google.com/googleplay/android-developer/answer/13327111)
and [Apple App Store](https://developer.apple.com/support/offering-account-deletion-in-your-app/)
"let users delete their account from within the app" requirements.

The user triggers deletion from **Impostazioni → Account → Elimina account**;
all destructive work runs **server-side** in a callable Cloud Function using the
Firebase Admin SDK. The client never deletes user data directly.

---

## 1. Architecture

```
┌────────────────────────── Flutter app ──────────────────────────┐
│                                                                  │
│  SettingsPage (Account section)                                  │
│    │  "Elimina account" (red)                                    │
│    │  → confirm #1 (irreversibile)                               │
│    │  → confirm #2 ("Elimina definitivamente")                   │
│    │  → busy loader                                              │
│    ▼                                                             │
│  AuthService.deleteAccount()            [lib/services]           │
│    │  1. AccountDeletionService.deleteAccount()                  │
│    │  2. logout()  (Auth signOut + analytics/crash reset)        │
│    │  3. clear SharedPreferences (local caches)                  │
│    ▼                                                             │
│  AccountDeletionService            [domain interface]            │
│    ├─ FunctionsAccountDeletionService  (Firebase mode)           │
│    │     → callable "deleteAccount" @ europe-west4               │
│    └─ LocalAccountDeletionService      (offline/dev mode: no-op) │
│                                                                  │
└──────────────────────────────────┬───────────────────────────────┘
                                    │ HTTPS callable (auth context)
                                    ▼
┌──────────────────── Cloud Function (europe-west4) ───────────────┐
│  deleteAccount  [functions/src/account.ts]  — Admin SDK          │
│    verify request.auth  →  uid                                   │
│    1. Firestore : recursiveDelete(users/{uid})                   │
│                   + usernames where uid==                        │
│                   + leaderboard entries (collectionGroup) where  │
│                     uid==                                        │
│    2. Storage   : bucket.deleteFiles(prefix users/{uid}/)        │
│    3. Auth      : deleteUser(uid)                                │
└──────────────────────────────────────────────────────────────────┘
```

The design follows the app's existing clean-architecture conventions: widgets
talk to the `AuthService` facade, which resolves the `AccountDeletionService`
domain interface from the `ServiceLocator` (get_it). Two implementations are
registered — the Firebase one in `_configureFirebase()`, the local no-op in
`configureLocal()` — so the flow works identically whether or not a Firebase
backend is configured.

### Key files

| Concern | File |
| --- | --- |
| Cloud Function | [`functions/src/account.ts`](functions/src/account.ts) |
| Function export | [`functions/src/index.ts`](functions/src/index.ts) |
| Firestore paths (server) | [`functions/src/paths.ts`](functions/src/paths.ts) |
| Domain interface | [`lib/domain/services/account_deletion_service.dart`](lib/domain/services/account_deletion_service.dart) |
| Firebase impl (callable) | [`lib/data/firebase/functions_account_deletion_service.dart`](lib/data/firebase/functions_account_deletion_service.dart) |
| Local no-op impl | [`lib/data/local/noop_services.dart`](lib/data/local/noop_services.dart) |
| DI registration | [`lib/core/di/service_locator.dart`](lib/core/di/service_locator.dart) |
| Client orchestration | [`lib/services/auth_service.dart`](lib/services/auth_service.dart) (`deleteAccount`) |
| Settings UI + confirm flow | [`lib/features/settings/presentation/pages/settings_page.dart`](lib/features/settings/presentation/pages/settings_page.dart) |
| Entry point (settings gear) | [`lib/features/music/presentation/pages/user_home_page.dart`](lib/features/music/presentation/pages/user_home_page.dart) |
| Public web page | [`../Beatter.it/how-to-delete-account/index.html`](../Beatter.it/how-to-delete-account/index.html) |

---

## 2. How the Cloud Function works

`deleteAccount` is an **authenticated callable** (`onCall`) pinned to
`europe-west4`. It:

1. **Verifies authentication.** It reads the uid exclusively from the verified
   `request.auth` context. If absent it throws `HttpsError('unauthenticated')`.
   Because the uid is never taken from client-supplied payload, a caller can
   only ever delete **their own** account.
2. **Deletes Firestore data** (step 1):
   - `recursiveDelete(users/{uid})` — the user document and every subcollection
     under it (profile, `settings`, `workouts`, `compositions`, `exercises`,
     `readingScores`, `stats`, `achievements`, `pointHistory`). `recursiveDelete`
     batches internally, so it scales past the 500-writes-per-batch limit.
   - The **username reservation**: `usernames` docs where `uid == <uid>`.
   - The **leaderboard rows**: a `collectionGroup('entries').where('uid','==',uid)`
     query reaches the global board and every weekly board at once (each entry
     stores its owner's `uid`), deleted in ≤400-op batches.
3. **Deletes Storage files** (step 2): `bucket().deleteFiles({ prefix: 'users/{uid}/' })`
   removes all objects the user owns (avatars, PDF exports — see `storage.rules`).
4. **Deletes the Auth user** (step 3): `getAuth().deleteUser(uid)`.

### Order & rollback

The fixed order is **Firestore → Storage → Auth**. Auth is the *recovery
anchor*: deleting it last means that if the Firestore or Storage step throws,
the function aborts **before** the account becomes unreachable, so the user can
retry (or support can intervene) with the account still intact. Each stage is
wrapped in its own `try/catch` with structured `logger` output; a failure in a
stage throws `HttpsError('internal', ...)` and stops the pipeline. Once Auth is
deleted the operation is irreversible by design.

The Auth step treats `auth/user-not-found` as success, keeping the function
**idempotent** under Cloud Functions' at-least-once retry semantics (a retried
invocation whose data is already gone still returns `{ success: true }`).

### Client-side follow-up

On a successful response, `AuthService.deleteAccount()`:
1. signs the user out (`logout()` — also resets the analytics/crash user id), then
2. clears **all** `SharedPreferences` (the single backing store for the on-device
   libraries, settings and gamification cache), so no personal data survives
   locally.

The Settings page then routes back to the login screen. Nothing local is cleared
unless the server-side deletion succeeded first.

---

## 3. Data deleted

Everything associated with the uid:

| Location | Data |
| --- | --- |
| `users/{uid}` | profile (display name, photo, preferences, role) |
| `users/{uid}/settings/*` | synced app settings |
| `users/{uid}/workouts/*` | workout history |
| `users/{uid}/compositions/*` | saved compositions |
| `users/{uid}/exercises/*` | saved Sheet Mode exercises |
| `users/{uid}/readingScores/*` | Reading Mode personal records |
| `users/{uid}/stats/*` | aggregated statistics |
| `users/{uid}/achievements/*` | unlocked achievements |
| `users/{uid}/pointHistory/*` | point ledger |
| `usernames/*` (uid==) | nickname reservation |
| `leaderboards/*/entries/{uid}` | global + weekly leaderboard rows |
| Storage `users/{uid}/**` | avatars, PDF exports, any user files |
| Firebase Authentication | the auth user record |
| Device `SharedPreferences` | all local caches/libraries/settings |

After the function returns, no orphan documents or files remain for the uid.

---

## 4. Data retained

By design, **no personal data is retained** after deletion. The only exceptions
are data that must be kept **strictly as required by law or legitimate
interest**, and only for the minimum necessary period, e.g.:

- security/abuse-prevention technical logs (Cloud Functions & Firebase logs,
  subject to the platform's own retention);
- records needed for accounting/tax/legal obligations;
- data needed to establish, exercise or defend a legal claim.

Note that **Cloud Logging** retains function-execution logs (which include the
uid in structured fields for audit/troubleshooting) according to the project's
log-retention policy; these are operational logs, not user content. This mirrors
the wording on the public page
([`Beatter.it/how-to-delete-account/`](../Beatter.it/how-to-delete-account/index.html))
and the [Privacy Policy](../Beatter.it/privacy/index.html).

---

## 5. Deploying the Cloud Function

The function lives in the existing `functions` codebase (Node 20, TypeScript)
and is deployed like any other Beatter function. From the project root:

### Exact deploy command

```bash
firebase deploy --only functions:deleteAccount
```

To deploy the whole functions codebase (e.g. as part of a release, alongside
rules — see `DEPLOYMENT.md`):

```bash
firebase deploy --only functions
# or, with rules:
firebase deploy --only firestore:rules,storage,functions
```

The `predeploy` hook in `firebase.json` runs `npm --prefix functions run build`
(`tsc`) automatically. To build/lint locally first:

```bash
cd functions
npm install      # first time only
npm run build    # tsc → lib/
```

### Region

The function is deployed to **`europe-west4`** — the European region the project
already uses (the `(default)` Firestore database is in the `eur3` multi-region,
whose Eventarc/Functions location is `europe-west4`; the existing Firestore-
trigger functions run there too). It is set **explicitly** on the callable
(`onCall({ region: "europe-west4" }, ...)`) so it is independent of the global
`setGlobalOptions` in `index.ts` and of module-evaluation order.

The Flutter client targets the same region:
`FirebaseFunctions.instanceFor(region: 'europe-west4')` in
`FunctionsAccountDeletionService`. **If the region ever changes, update both
places** or the SDK will call a non-existent endpoint.

### Configuration / environment variables

**None.** The function needs no secrets or env vars: it uses the default
Admin SDK credentials (Application Default Credentials in the Functions runtime)
and the project's default Storage bucket. No `.env`, no `functions:config`,
no service-account key to provision.

### Prerequisites (already in place for this project)

- Firestore, Storage and Authentication enabled on the `beatterapp` project.
- `firestore.rules` keeps `users/{uid}` client-deletion disabled
  (`allow delete: if false;`) precisely because deletion goes through this
  function (the Admin SDK bypasses rules).
- Firebase App Check may front the callable; the app already activates App Check
  at startup, so no extra work is required.

---

## 6. Manual verification

1. Sign in on a test account and create some data (an exercise, a composition).
2. Optionally upload a file so Storage has an object under `users/{uid}/`.
3. In the app: **Impostazioni → Account → Elimina account**, confirm twice.
4. Expect: loader → success toast → back to the login screen.
5. In the Firebase Console, confirm `users/{uid}` (and subcollections), the
   `usernames`/leaderboard rows, the Storage folder and the Auth user are gone.
6. Re-running the flow on an already-deleted uid (edge case) still succeeds
   (idempotent).
