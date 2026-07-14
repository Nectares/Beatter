# Building for Android

Use `build_android.sh` at the project root to produce an installable APK or a
Play Store–ready App Bundle.

## Prerequisites

- Flutter SDK on `PATH` (`flutter --version` should work)
- Android SDK / build tools installed (normally set up alongside Flutter or Android Studio)

## Usage

```bash
./build_android.sh [options]
```

| Option      | Description                                                |
|-------------|--------------------------------------------------------------|
| `--debug`   | Build a debug artifact                                       |
| `--profile` | Build a profile artifact                                     |
| `--release` | Build a release artifact (default)                           |
| `--apk`     | Build an APK (default)                                       |
| `--aab`     | Build an Android App Bundle (`.aab`), for Play Store upload  |
| `--both`    | Build both APK and AAB                                       |
| `--clean`   | Run `flutter clean` before building                          |
| `-h`, `--help` | Show usage                                                 |

The script always runs `flutter pub get` before building.

## Examples

Build a release APK (default):

```bash
./build_android.sh
```

Build a release App Bundle for Play Store upload:

```bash
./build_android.sh --aab
```

Build both, from a clean state:

```bash
./build_android.sh --both --clean
```

Build a debug APK:

```bash
./build_android.sh --debug
```

## Output locations

- APK: `build/app/outputs/flutter-apk/app-<mode>.apk`
- AAB: `build/app/outputs/bundle/<mode>/app-<mode>.aab`

## Signing

The app currently ships with **no release signing configuration** —
`android/app/build.gradle.kts` signs release builds with the debug key, so
`--release` builds install and run but are **not suitable for a Play Store
upload as-is**. To publish, configure a real signing key:

1. Generate a keystore: `keytool -genkey -v -keystore ~/beatter-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias beatter`
2. Add a `key.properties` file (keystore path/passwords) and wire up a
   `signingConfigs.release` block in `android/app/build.gradle.kts` per the
   [official Flutter Android deployment guide](https://docs.flutter.dev/deployment/android).

## Release signing

Release builds are signed with the upload keystore when
`android/key.properties` exists (git-ignored; keystore lives in
`~/keystores/beatter-upload.jks`). Without that file the build falls back to
**debug signing** — fine for local testing, rejected by Google Play.

Verify what signed an artifact:

```bash
keytool -printcert -jarfile build/app/outputs/bundle/release/app-release.aab
# CN=Beatter → upload key; CN=Android Debug → fallback
```

Full setup, backup, and Play Console workflow: [DEPLOYMENT.md](../DEPLOYMENT.md).
