# Beatter — Deployment & Release Signing Runbook

Complete guide for producing, signing, and publishing production builds of Beatter
on Google Play and the Apple App Store. Written against the actual state of this
repo (14 July 2026). Follows the same infrastructure philosophy as Nicosia in
Vetrina (`NicosiaInVetrina/docs/RELEASE_SIGNING.md`).

**Project facts this guide is based on:**

| Fact | Value |
|---|---|
| Application ID / Bundle ID | `com.nectares.beatter` |
| Firebase project | `beatterapp` (`242679736794`) |
| App version | `1.0.0+6` (from `pubspec.yaml`) |
| Auth methods in use | Anonymous + email/password + **Google Sign-In** |
| App Check | **active in code** (`lib/core/firebase/firebase_bootstrap.dart`): Play Integrity (Android release), DeviceCheck (iOS release), debug providers in debug builds |
| Crashlytics | **active**: Gradle plugin installed, handlers installed in bootstrap |
| Cloud Functions | **used** (`functions/`, Node 20) |
| Push notifications | not used (no `firebase_messaging`) |
| Apple Team ID | `SQKY73537G` — **manual** signing: profile `provisioning-profile-beatter-1` (expires 2027-04-12) + "Apple Distribution: GIANVITO MARZO" |
| iOS deployment target | 15.0 (raised from 13.0 on 2026-07-14: Firebase iOS SDK 12+ requires it) |
| Android signing | upload keystore `~/keystores/beatter-upload.jks` (alias `upload`) + Play App Signing |

---

## Part 0 — Folder structure & where every secret lives

```
~/keystores/                          OUTSIDE the repo, chmod 700
├── beatter-upload.jks                Android upload keystore   (chmod 600)
├── beatter-key.properties            backup copy of key.properties (chmod 600)
├── nicosiainvetrina-upload.jks       (other project)
└── nicosiainvetrina-key.properties   (other project)

Beatter/                              the repo
├── android/key.properties            SECRET, git-ignored, chmod 600
├── android/app/build.gradle.kts      committed — reads key.properties, no secrets
├── ios/ExportOptions.plist           committed — profile/team names, no secrets
├── build_android.sh                  committed build script
├── build_ios.sh                      committed build script
└── DEPLOYMENT.md                     this file
```

**Why the keystore lives outside the repo instead of an ignored `/secrets`
folder:** an ignored in-repo folder is one `git add -f` (or one overeager tool)
away from being committed, and gets swept up by anything that archives the
project directory. A directory outside the working tree cannot be committed at
all. `.gitignore` still ignores `**/key.properties`, `*.jks`, `*.keystore`,
`*.p12`, `*.mobileprovision` and `/secrets/` as defense in depth.

**Git-ignore verification** (run any time you're unsure):

```bash
git check-ignore -v android/key.properties   # must print a match
git status --short                           # must NOT list key.properties or any .jks
```

---

## Part 1 — Android

### 1.1 The signing model: upload key vs app signing key

- **Upload key** (yours, `~/keystores/beatter-upload.jks`): signs what you
  *upload* to Play. It only authenticates you to Google.
- **App signing key** (Google's, created automatically at first upload under
  **Play App Signing**, mandatory for new apps): signs the APKs users actually
  install. Google keeps it in their HSMs; you never touch it.
- **If the upload key is lost or compromised:** Play Console → Test and release
  → Setup → App integrity → App signing → **Request upload key reset**. You
  generate a new keystore, upload its certificate, Google switches in ~2 days.
  Users are never affected — this is exactly why Play App Signing exists.
- **What you must keep safe:** the upload keystore + its password (§1.3).
  **What Firebase needs:** SHA fingerprints of *both* keys (§1.5).

### 1.2 Generate the upload keystore — ⚠️ RUN THIS YOURSELF

Interactive on purpose: the password is typed at the prompt and never appears
in shell history or any file except `key.properties`.

```bash
mkdir -p ~/keystores && chmod 700 ~/keystores

keytool -genkeypair -v \
  -keystore ~/keystores/beatter-upload.jks \
  -alias upload \
  -keyalg RSA -keysize 4096 -sigalg SHA256withRSA \
  -storetype PKCS12 \
  -validity 10950 \
  -dname "CN=Beatter, OU=Mobile, O=Nectares, L=Torino, ST=TO, C=IT"

chmod 600 ~/keystores/beatter-upload.jks
```

Parameter rationale:

- **RSA 4096 + SHA256withRSA** — current best practice; keytool's RSA-2048
  default is acceptable but 4096 costs nothing for an upload key.
- **PKCS12** — the modern keystore format (JKS is deprecated); one password for
  both store and key.
- **10950 days ≈ 30 years** — Google requires validity beyond 2033-10-22.
- **alias `upload`** — self-documents its role under Play App Signing.
- **Password**: 25+ characters from your password manager. Never reuse it.

### 1.3 Create `android/key.properties` — ⚠️ CREATE THIS YOURSELF

```bash
cat > android/key.properties <<'EOF'
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEYSTORE_PASSWORD
keyAlias=upload
storeFile=/Users/cr4ft/keystores/beatter-upload.jks
EOF
chmod 600 android/key.properties
# edit it and put the real password in (same value for both fields with PKCS12)

# backup copy next to the keystore (restoring on a new machine = copy it back):
cp android/key.properties ~/keystores/beatter-key.properties
chmod 600 ~/keystores/beatter-key.properties
```

`android/app/build.gradle.kts` (already committed) reads this file and signs
release builds with the upload key. **When the file is absent, release builds
fall back to debug signing** so `flutter run --release` still works on machines
without the keystore — Play rejects debug-signed AABs, so an accidental
fallback cannot reach production.

Verify the config picked the key up:

```bash
cd android && ./gradlew signingReport | grep -A8 "Variant: release"
# Store must be /Users/cr4ft/keystores/beatter-upload.jks, alias upload
```

### 1.4 Backup strategy (do all three)

1. **Password manager** — store the passphrase as a login item AND attach the
   `.jks` file itself (1Password/Bitwarden support attachments). This alone is
   a complete offsite backup.
2. **Encrypted external drive** — copy `beatter-upload.jks` +
   `beatter-key.properties` to an encrypted volume (APFS encrypted), together
   with a note of alias and creation date.
3. Optional second offsite location as an encrypted archive:
   ```bash
   gpg --symmetric --cipher-algo AES256 ~/keystores/beatter-upload.jks
   ```

**Never** email the keystore, put it in an unencrypted shared drive, or paste
the password into a chat or terminal command line.

### 1.5 SHA fingerprints → Firebase

Google Sign-In on Android **will not work** unless the signing certificate's
SHA-1 is registered in Firebase; App Check / Play Integrity needs SHA-256.
Three certificates matter:

| Certificate | When to register |
|---|---|
| Debug key | already registered if local dev Google Sign-In works |
| **Upload key** | now, after generating it |
| **App signing key** | after the first Play upload (Google creates it then) |

```bash
# Upload key (prompts for the keystore password):
keytool -list -v -keystore ~/keystores/beatter-upload.jks -alias upload | grep -E "SHA1|SHA256"

# Debug key:
keytool -list -v -keystore ~/.android/debug.keystore \
  -alias androiddebugkey -storepass android -keypass android | grep -E "SHA1|SHA256"
```

Register at: Firebase Console → ⚙️ Project settings → General → Android app
(`com.nectares.beatter`) → **Add fingerprint**. Add SHA-1 + SHA-256 for the
upload key now, and for the **app signing key** right after the first upload
(Play Console → Test and release → Setup → App integrity → App signing).

Because this app **uses Google Sign-In**, after adding fingerprints
**re-download `google-services.json`** (it gains the OAuth client entries) and
replace `android/app/google-services.json`.

### 1.6 Play Console — first upload

1. **All apps → Create app** — "Beatter", default language, App / Free.
2. Play App Signing is enrolled automatically at first upload; keep the default
   "Let Google generate the app signing key".
3. **Test and release → Testing → Internal testing → Create release** — upload
   the `.aab` here first, never straight to production.
4. Copy the **app signing key** SHA-1/SHA-256 into Firebase (§1.5).
5. Complete **App content** (privacy policy URL, data safety form — remember
   the app collects Analytics + Crashlytics data —, ads declaration, target
   audience) and **Main store listing**.
6. **Production → Create release** only after the internal-testing checklist
   (§3.2) passes, with a staged rollout (start 10–20%).

### 1.7 Android build commands

```bash
# The Play Store artifact (.aab — Play generates per-device APKs from it):
./build_android.sh --aab          # = flutter build appbundle --release
#   → build/app/outputs/bundle/release/app-release.aab

# Direct-install APK (sideload testing, non-Play distribution only):
./build_android.sh                # = flutter build apk --release
#   → build/app/outputs/flutter-apk/app-release.apk

# Verify what actually signed the artifact:
keytool -printcert -jarfile build/app/outputs/bundle/release/app-release.aab
#   CN must be "Beatter" (upload key), NOT "Android Debug"
```

**When to use which:** `.aab` is the only thing you upload to Play. `.apk` is
for installing directly on a device (`adb install`) or sharing outside Play.
Debug/profile builds are for development only and are signed with the debug key.

Optional hardening (Crashlytics is active, so symbols matter):

```bash
flutter build appbundle --release --obfuscate --split-debug-info=build/symbols
# keep build/symbols with the release tag; upload native symbols with:
# firebase crashlytics:symbols:upload --app 1:242679736794:android:f1bf90daecd68085b338e3 build/symbols
```

---

## Part 2 — iOS

### 2.1 Concepts

- **Apple Distribution certificate** — proves *who* builds. Lives in this Mac's
  keychain ("Apple Distribution: GIANVITO MARZO (SQKY73537G)"). Used for
  TestFlight/App Store builds; "Apple Development" certs are for running on
  your own devices.
- **Provisioning profile** — binds certificate + App ID + entitlements.
  This project uses **manual signing** with the App Store distribution profile
  `provisioning-profile-beatter-1` (expires **2027-04-12**), created in the
  developer portal and imported into Xcode.
- **ExportOptions.plist** — with manual signing, `xcodebuild -exportArchive`
  can't guess which profile to use; `ios/ExportOptions.plist` (committed, no
  secrets) maps `com.nectares.beatter` → `provisioning-profile-beatter-1`,
  team `SQKY73537G`, certificate "Apple Distribution".
  **If the profile is ever renewed/renamed, update both Xcode and this file.**
- **App Store Connect workflow** — you upload a signed build (via Transporter
  or Xcode Organizer); it appears under TestFlight after processing; you test
  it there; then you attach it to a version and submit for review.

### 2.2 One-time setup checklist

1. **Xcode** (`open ios/Runner.xcworkspace`) → Runner target → **Signing &
   Capabilities → Release** — verify: Automatically manage signing **OFF**,
   Team `SQKY73537G`, Provisioning Profile `provisioning-profile-beatter-1`,
   Signing Certificate "Apple Distribution", Bundle Identifier
   `com.nectares.beatter`. Capabilities: none required today (no push, no
   associated domains; DeviceCheck for App Check needs no capability).
2. **App Store Connect → Apps → + → New App** — platform iOS, bundle ID
   `com.nectares.beatter` (register at developer.apple.com → Identifiers first
   if missing), SKU e.g. `beatter-001`.
3. **App Store Connect → Business** — the free-apps agreement must be Active.
4. `ios/Runner/Info.plist` already contains (added 2026-07-14):
   - `ITSAppUsesNonExemptEncryption = false` — the app only uses standard
     HTTPS/TLS (exempt); avoids the export-compliance questionnaire per build.
   - `CFBundleURLTypes` with the Google Sign-In reversed client ID
     (`com.googleusercontent.apps.242679736794-…`) — **required** for the
     Google Sign-In redirect to return to the app. If
     `GoogleService-Info.plist` is ever regenerated, keep this in sync with
     its `REVERSED_CLIENT_ID`.
5. **Privacy manifest**: Flutter and the Firebase/Google SDKs ship their own
   `PrivacyInfo.xcprivacy` bundles; the app's own code uses no
   required-reason APIs, so no app-level manifest is needed today. Revisit if
   App Store Connect emails an ITMS-91053 warning after upload.

### 2.3 iOS build commands

```bash
./build_ios.sh                 # flutter build ipa --release --export-options-plist=ios/ExportOptions.plist
#   → build/ios/ipa/*.ipa  and  build/ios/archive/Runner.xcarchive

./build_ios.sh --simulator     # debug build for the Simulator (no signing)
./build_ios.sh --no-codesign   # unsigned release .app (CI / smoke checks)
```

**When to use which:** the `.ipa` is the only artifact you upload to App Store
Connect. Simulator builds are for development; `--no-codesign` verifies
compilation without touching signing.

**Upload** (pick one):

- **Xcode Organizer** (recommended first time): `open ios/Runner.xcworkspace`
  → Product → Archive → Distribute App → App Store Connect → Upload.
- **Transporter**: drag `build/ios/ipa/*.ipa` into the Transporter app → Deliver.

**Known quirk (fixed 2026-07-14):** the FlutterFire "upload-crashlytics-symbols"
script phase guesses the Firebase SDK path from Xcode's DerivedData layout,
which fails with `flutter build ipa` + a custom DerivedData location (this Mac
uses `/Volumes/CrucialX81T/XcodeData/DerivedData`). The script phase in
`project.pbxproj` now falls back to
`$SRCROOT/../build/ios/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/run`.
If `flutterfire configure` ever regenerates the project, re-apply that fallback.

**Expected warnings:** "Upload Symbols Failed" for FirebaseAnalytics,
GoogleAppMeasurement, grpc, absl, openssl_grpc, etc. — prebuilt binary
frameworks without public dSYMs; every Flutter+Firebase app gets these.
Safe to ignore.

After upload: App Store Connect → **TestFlight** → build appears after
processing (10–60 min) → add yourself as internal tester → install and run the
verification checklist (§3.2).

---

## Part 3 — Release checklist (every version)

### 3.1 Before building

- [ ] Bump `version:` in `pubspec.yaml` — at minimum the `+N` build number.
      Play requires a strictly increasing versionCode; App Store Connect
      requires a new CFBundleVersion per upload. Never edit versions anywhere
      else (`local.properties` values are derived).
- [ ] `flutter clean && flutter pub get && flutter test`
- [ ] Deploy any changed Firestore/Storage rules and Cloud Functions **before**
      shipping the build (`firebase deploy --only firestore:rules,storage,functions`).
- [ ] App icons present (`flutter_launcher_icons` config in `pubspec.yaml`;
      re-run `dart run flutter_launcher_icons` after logo changes).
- [ ] Splash/launch screen still correct (Android `LaunchTheme`, iOS
      `LaunchScreen.storyboard`).
- [ ] Permissions audit: AndroidManifest adds none beyond defaults; iOS purpose
      strings — none needed today (no camera/photos/mic/location APIs in use).
      **Re-check whenever a new plugin is added.**
- [ ] Release notes written (per store language).

### 3.2 Post-build verification (internal testing / TestFlight build)

Install the store-delivered build (not a local one) on a physical device:

- [ ] Cold start, no Firebase init errors (`adb logcat | grep -i firebase`)
- [ ] Anonymous auth → app reaches home
- [ ] Email/password sign-in
- [ ] **Google Sign-In** (certificate-bound! fails if SHA fingerprints or the
      iOS URL scheme are wrong)
- [ ] Firestore reads and writes
- [ ] Storage reads (and writes if applicable)
- [ ] Cloud Functions calls succeed
- [ ] **Account deletion** (Play/App Store requirement): Settings → Account →
      Elimina account → double-confirm; user is signed out and returned to the
      login screen, and Firestore/Storage no longer hold the uid's data. See
      [`ACCOUNT_DELETION.md`](ACCOUNT_DELETION.md).
- [ ] App Check: no `app-check` permission errors; Firebase Console → App Check
      shows verified requests (enforcement is opt-in per service — verify
      metrics before enforcing)
- [ ] Crashlytics: force a test crash in a debug menu or check that the console
      receives the session
- [ ] Signing verification: `keytool -printcert -jarfile app-release.aab`
      shows the upload key (Android); Organizer/ASC shows the Distribution
      cert (iOS)

### 3.3 Ship

- [ ] Android: Play Console → Internal testing → verify → Production with
      **staged rollout** (10–20% start)
- [ ] iOS: TestFlight → verify → App Store Connect → new version → submit for
      review
- [ ] Tag the release: `git tag v1.0.0+6 && git push --tags`; if built with
      `--obfuscate`, archive `build/symbols` with the tag

---

## Part 4 — Restoring on another computer (or onboarding a developer)

1. Clone the repo; install Flutter, Xcode, Android SDK, JDK 21
   (`brew install openjdk@21`).
2. **Android signing** (only needed for whoever uploads releases):
   - copy `beatter-upload.jks` + `beatter-key.properties` from the password
     manager attachment or encrypted drive into `~/keystores/` (chmod 700 dir,
     600 files);
   - `cp ~/keystores/beatter-key.properties android/key.properties`;
   - if the keystore path differs from `/Users/cr4ft/keystores/…`, fix
     `storeFile=` in `android/key.properties`.
   - Developers who don't publish skip all of this — the build falls back to
     debug signing automatically.
3. **iOS signing** (only for whoever uploads):
   - Xcode → Settings → Accounts → sign in with the Apple ID on team
     `SQKY73537G`;
   - import the Apple Distribution certificate + private key (`.p12` exported
     from Keychain Access on the old Mac — the private key exists **only** in
     that keychain; export it now and attach it to the password manager entry);
   - download `provisioning-profile-beatter-1` from developer.apple.com →
     Profiles and double-click it (or let Xcode fetch it).
4. `flutter pub get`, then verify: `cd android && ./gradlew signingReport`
   and `./build_ios.sh --no-codesign`.
5. Machine-specific Gradle settings (JDK path) belong in
   `~/.gradle/gradle.properties`, not in the repo:
   ```properties
   org.gradle.java.home=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home
   ```

---

## Part 5 — Disaster recovery

| Failure | Recovery |
|---|---|
| Gradle signing change breaks the build | Delete `android/key.properties` → build falls back to debug signing, dev never blocked. Or `git revert` the build.gradle.kts commit. |
| Wrong password / corrupt keystore, **nothing uploaded yet** | Regenerate the keystore (§1.2). Play has no memory of unused keys. |
| Upload key lost/compromised **after** first upload | Play Console → App integrity → App signing → Request upload key reset (~2 days). Users unaffected. |
| Apple Distribution cert lost (Mac died, no .p12 backup) | Revoke it at developer.apple.com → Certificates, create a new one, regenerate the provisioning profile, update Xcode + `ios/ExportOptions.plist`. No user impact. |
| Provisioning profile expired (2027-04-12) | Renew at developer.apple.com → Profiles; if the name changes, update Xcode and `ios/ExportOptions.plist`. |
| Bad build in internal testing / TestFlight | No public users — upload a fixed build with a bumped build number (Play) or expire the TestFlight build. Always roll forward. |
| Bad build in production | Play: halt the staged rollout, roll forward. App Store: submit an expedited-review fix; there is no rollback. |
| Release-signed app won't install over a dev build | Expected (different certificate). `adb uninstall com.nectares.beatter` / delete the iOS app first. Anonymous-auth test users get a fresh UID on reinstall. |
| Google Sign-In fails only in release/store builds | Missing SHA fingerprint (§1.5) — register the app-signing-key SHAs and re-download `google-services.json`; on iOS check the `CFBundleURLTypes` scheme matches `REVERSED_CLIENT_ID`. |
| App Check blocks traffic | Console → App Check → check verified-request metrics; disable enforcement for the affected service while diagnosing (Play Integrity needs the app installed from Play; DeviceCheck needs a store/TestFlight build). |

---

## Part 6 — First-release master checklist (in order)

- [ ] 1. Generate upload keystore (§1.2) — **run keytool yourself**
- [ ] 2. Back it up: password manager (file + passphrase) + encrypted drive (§1.4)
- [ ] 3. Create `android/key.properties` + `~/keystores/beatter-key.properties` (§1.3)
- [ ] 4. `git status` / `git check-ignore` — confirm no secrets staged (Part 0)
- [ ] 5. `cd android && ./gradlew signingReport` — release variant shows the upload key
- [ ] 6. Export the Apple Distribution private key as `.p12` → password manager (Part 4.3)
- [ ] 7. Add upload-key SHA-1 + SHA-256 to Firebase; re-download `google-services.json` (§1.5)
- [ ] 8. `./build_android.sh --aab` + `keytool -printcert -jarfile …` (§1.7)
- [ ] 9. Play Console: create app → internal testing → upload the .aab (§1.6)
- [ ] 10. Register the **app signing key** SHAs in Firebase; re-download `google-services.json` again (§1.5)
- [ ] 11. Install the internal-testing build → §3.2 checklist (Google Sign-In especially)
- [ ] 12. Play declarations (privacy policy, data safety) → staged production rollout
- [ ] 13. App Store Connect app record + agreements (§2.2)
- [ ] 14. `./build_ios.sh` → upload via Transporter/Organizer (§2.3)
- [ ] 15. TestFlight → §3.2 checklist → submit for review
- [ ] 16. Verify App Check metrics from store builds before enabling enforcement
