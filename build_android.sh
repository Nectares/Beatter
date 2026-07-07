#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

MODE="release"
TARGET="apk"
CLEAN=false

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options:
  --debug      Build a debug artifact
  --profile    Build a profile artifact
  --release    Build a release artifact (default)
  --apk        Build an APK (default)
  --aab        Build an Android App Bundle (.aab), for Play Store upload
  --both       Build both APK and AAB
  --clean      Run "flutter clean" before building
  -h, --help   Show this help message
EOF
}

for arg in "$@"; do
  case "$arg" in
    --debug) MODE="debug" ;;
    --profile) MODE="profile" ;;
    --release) MODE="release" ;;
    --apk) TARGET="apk" ;;
    --aab) TARGET="aab" ;;
    --both) TARGET="both" ;;
    --clean) CLEAN=true ;;
    -h|--help) usage; exit 0 ;;
    *)
      echo "Unknown option: $arg" >&2
      usage
      exit 1
      ;;
  esac
done

if [ "$CLEAN" = true ]; then
  flutter clean
fi

flutter pub get

if [ "$TARGET" = "apk" ] || [ "$TARGET" = "both" ]; then
  flutter build apk --"$MODE"
  echo "APK ready: build/app/outputs/flutter-apk/app-$MODE.apk"
fi

if [ "$TARGET" = "aab" ] || [ "$TARGET" = "both" ]; then
  flutter build appbundle --"$MODE"
  echo "AAB ready: build/app/outputs/bundle/$MODE/app-$MODE.aab"
fi
