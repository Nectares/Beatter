# Building for iOS

Use `build_ios.sh` at the project root to produce an iOS app bundle. Requires
**macOS with Xcode installed** — the script refuses to run on any other OS.

## Prerequisites

- Flutter SDK on `PATH` (`flutter --version` should work)
- Xcode installed, with the iOS platform/simulators available
- CocoaPods installed (`pod --version`)

## Usage

```bash
./build_ios.sh [options]
```

| Option        | Description                                                      |
|---------------|--------------------------------------------------------------------|
| `--debug`     | Build a debug artifact                                             |
| `--profile`   | Build a profile artifact                                           |
| `--release`   | Build a release artifact (default)                                 |
| `--simulator` | Build for the iOS Simulator (no code signing needed)                |
| `--ipa`       | Build a signed `.ipa` for distribution (needs a signing team, see below) |
| `--clean`     | Run `flutter clean` before building                                 |
| `-h`, `--help` | Show usage                                                         |

`--simulator` and `--ipa` are mutually exclusive. The script always runs
`flutter pub get` before building.

With no `--simulator`/`--ipa` flag, it builds an **unsigned** device app
bundle — useful to verify the app compiles without needing signing set up.

## Examples

Verify the app builds (unsigned, release):

```bash
./build_ios.sh
```

Build for the Simulator:

```bash
./build_ios.sh --simulator --debug
```

Build a signed `.ipa` for TestFlight/App Store submission:

```bash
./build_ios.sh --ipa
```

## Output locations

- Unsigned device build: `build/ios/iphoneos/Runner.app`
- Simulator build: `build/ios/iphonesimulator/Runner.app`
- Signed distribution build: `build/ios/ipa/`

## Signing

The project has **no signing team configured** yet — there's no
`ios/ExportOptions.plist` and the default Xcode scheme doesn't specify a
team. Before `--ipa` will succeed:

1. Open `ios/Runner.xcworkspace` in Xcode.
2. Select the `Runner` target → **Signing & Capabilities**.
3. Choose your Apple Developer team and let Xcode manage signing (or
   configure manual provisioning profiles).

Once a team is set, `./build_ios.sh --ipa` will produce a distributable
`.ipa` in `build/ios/ipa/`.
