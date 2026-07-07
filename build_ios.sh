#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

if [[ "$(uname)" != "Darwin" ]]; then
  echo "iOS builds require macOS with Xcode installed." >&2
  exit 1
fi

MODE="release"
SIMULATOR=false
IPA=false
CLEAN=false

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options:
  --debug        Build a debug artifact
  --profile      Build a profile artifact
  --release      Build a release artifact (default)
  --simulator    Build for the iOS Simulator (no code signing needed)
  --ipa          Build a signed .ipa for distribution. Requires a signing
                 team configured in Xcode (open ios/Runner.xcworkspace to set one)
  --clean        Run "flutter clean" before building
  -h, --help     Show this help message

With no --simulator/--ipa flag, builds an unsigned device app bundle
(useful for verifying the build compiles without needing signing set up).
EOF
}

for arg in "$@"; do
  case "$arg" in
    --debug) MODE="debug" ;;
    --profile) MODE="profile" ;;
    --release) MODE="release" ;;
    --simulator) SIMULATOR=true ;;
    --ipa) IPA=true ;;
    --clean) CLEAN=true ;;
    -h|--help) usage; exit 0 ;;
    *)
      echo "Unknown option: $arg" >&2
      usage
      exit 1
      ;;
  esac
done

if [ "$SIMULATOR" = true ] && [ "$IPA" = true ]; then
  echo "--simulator and --ipa are mutually exclusive." >&2
  exit 1
fi

if [ "$CLEAN" = true ]; then
  flutter clean
fi

flutter pub get

if [ "$IPA" = true ]; then
  flutter build ipa --"$MODE"
  echo "IPA ready: build/ios/ipa/"
elif [ "$SIMULATOR" = true ]; then
  flutter build ios --"$MODE" --simulator
  echo "Simulator app bundle ready: build/ios/iphonesimulator/Runner.app"
else
  flutter build ios --"$MODE" --no-codesign
  echo "Unsigned device app bundle ready: build/ios/iphoneos/Runner.app"
  echo "To install on a device or produce a signed .ipa, open ios/Runner.xcworkspace in Xcode, set a signing team, and re-run with --ipa."
fi
