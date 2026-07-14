# Building for iOS

Use `build_ios.sh` at the project root. Requires **macOS with Xcode
installed** — the script refuses to run on any other OS.

For the full release/signing runbook (certificates, profiles, TestFlight,
App Store submission) see [DEPLOYMENT.md](../DEPLOYMENT.md).

## Prerequisites

- Flutter SDK on `PATH` (`flutter --version` should work)
- Xcode installed, with the iOS platform/simulators available
- For the default `.ipa` build: the "Apple Distribution" certificate in the
  keychain and the `provisioning-profile-beatter-1` profile installed
  (team `SQKY73537G`) — see DEPLOYMENT.md Part 2/Part 4

## Usage

```bash
./build_ios.sh [options]
```

| Option          | Description                                                       |
|-----------------|-------------------------------------------------------------------|
| *(none)* / `--ipa` | Signed `.ipa` for TestFlight/App Store (default)               |
| `--no-codesign` | Unsigned release `.app` — verify compilation without signing      |
| `--simulator`   | Debug build for the iOS Simulator (no signing needed)             |
| `--clean`       | Run `flutter clean` before building                               |
| `-h`, `--help`  | Show usage                                                        |

The script always runs `flutter pub get` before building.

Signing is **manual**: the `.ipa` export reads
[`ios/ExportOptions.plist`](../ios/ExportOptions.plist), which maps the bundle
ID to the provisioning profile. If the profile or team ever changes, update
that file *and* the Xcode project.

## Examples

Store-ready `.ipa` (output in `build/ios/ipa/`):

```bash
./build_ios.sh
```

Smoke-check that the app compiles, no signing required:

```bash
./build_ios.sh --no-codesign
```

Run on the Simulator during development:

```bash
./build_ios.sh --simulator
```
