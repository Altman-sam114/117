#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="MDJournal"
BUNDLE_ID="com.codex.mdjournal.mac"
PROJECT_NAME="MDJournal.xcodeproj"
SCHEME="MDJournal"
CONFIGURATION="Debug"
DESTINATION="generic/platform=macOS,variant=Mac Catalyst"
DERIVED_DATA_PATH="/private/tmp/mdjournal-build-and-run"
XCODEBUILD="/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$DERIVED_DATA_PATH/Build/Products/Debug-maccatalyst/$APP_NAME.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/$APP_NAME"

usage() {
  echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
}

build_app() {
  pkill -x "$APP_NAME" >/dev/null 2>&1 || true

  "$XCODEBUILD" \
    -project "$ROOT_DIR/$PROJECT_NAME" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination "$DESTINATION" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    CODE_SIGNING_ALLOWED=NO \
    build

  if [[ ! -d "$APP_BUNDLE" ]]; then
    echo "error: expected app bundle was not created: $APP_BUNDLE" >&2
    exit 1
  fi

  if [[ ! -x "$APP_BINARY" ]]; then
    echo "error: expected app binary is not executable: $APP_BINARY" >&2
    exit 1
  fi
}

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

if [[ $# -gt 1 ]]; then
  usage
  exit 2
fi

build_app

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 2
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *)
    usage
    exit 2
    ;;
esac
