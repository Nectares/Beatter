#!/usr/bin/env bash
#
# Build the Beatter iOS app.
#
# Usage:
#   ./build_ios.sh                 # signed .ipa for TestFlight/App Store (default)
#   ./build_ios.sh --ipa           # same as default
#   ./build_ios.sh --no-codesign   # unsigned release .app (CI / smoke checks)
#   ./build_ios.sh --simulator     # debug build for the iOS Simulator
#   ./build_ios.sh --clean         # flutter clean before building
#
# Signing is MANUAL: the Runner target uses the "Apple Distribution" certificate
# and the "provisioning-profile-beatter-1" profile (team SQKY73537G).
# The .ipa export reads ios/ExportOptions.plist — update that file if the
# profile or team ever changes. See DEPLOYMENT.md Part 2.

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

if [[ "$(uname)" != "Darwin" ]]; then
  echo "iOS builds require macOS with Xcode installed." >&2
  exit 1
fi

TARGET="ipa"
CLEAN=false

for arg in "$@"; do
  case "$arg" in
    --ipa) TARGET="ipa" ;;
    --no-codesign) TARGET="no-codesign" ;;
    --simulator|--sim) TARGET="simulator" ;;
    --clean) CLEAN=true ;;
    -h|--help)
      grep '^#' "$0" | sed 's/^#//'
      exit 0
      ;;
    *)
      echo "Unknown option: $arg" >&2
      echo "Run with --help for usage." >&2
      exit 1
      ;;
  esac
done

if ! command -v flutter >/dev/null 2>&1; then
  echo "Error: flutter not found on PATH. Install it first: https://docs.flutter.dev/get-started/install" >&2
  exit 1
fi

if [ "$CLEAN" = true ]; then
  flutter clean
fi

echo "==> flutter pub get"
flutter pub get

case "$TARGET" in
  ipa)
    echo "==> flutter build ipa --release (manual signing, ios/ExportOptions.plist)"
    flutter build ipa --release --export-options-plist=ios/ExportOptions.plist
    OUT_DIR="build/ios/ipa"
    ;;
  no-codesign)
    echo "==> flutter build ios --release --no-codesign"
    flutter build ios --release --no-codesign
    OUT_DIR="build/ios/iphoneos"
    ;;
  simulator)
    echo "==> flutter build ios --debug --simulator"
    flutter build ios --debug --simulator
    OUT_DIR="build/ios/iphonesimulator"
    ;;
esac

echo
echo "Build complete. Output in: $OUT_DIR"
ls -la "$OUT_DIR" 2>/dev/null || true
