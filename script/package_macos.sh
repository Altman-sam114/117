#!/usr/bin/env bash
set -euo pipefail

journal_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
result_dir="${1:?Usage: package_macos.sh absolute-result-directory}"
derived_dir="${RUNNER_TEMP:?This packaging entry point runs on the CI runner}/mdjournal-release-derived-data"
build_number="${GITHUB_RUN_NUMBER:?}.${GITHUB_RUN_ATTEMPT:?}"
app_path="$derived_dir/Build/Products/Release-maccatalyst/MDJournal.app"
archive_path="$result_dir/MDJournal-${VERSION:?}-mac-universal-${GITHUB_SHA:0:7}.zip"
mkdir -p "$result_dir"

build_args=(
  -project "$journal_root/MDJournal.xcodeproj" -scheme MDJournal -configuration Release
  -destination 'generic/platform=macOS,variant=Mac Catalyst'
  -derivedDataPath "$derived_dir"
  CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=NO 'ARCHS=arm64 x86_64'
  SWIFT_OPTIMIZATION_LEVEL=-O -enableCodeCoverage NO
  "CURRENT_PROJECT_VERSION=$build_number"
)
xcrun xcodebuild "${build_args[@]}" \
  -showBuildSettings -json > "$result_dir/mac-release-build-settings.json"
xcrun xcodebuild "${build_args[@]}" \
  -resultBundlePath "$result_dir/MDJournalMacRelease.xcresult" build

# Ad-hoc signing uses no certificate or private key and is not Developer ID distribution.
codesign --force --sign - --timestamp=none "$app_path"
codesign --verify --deep --strict --verbose=2 "$app_path"
ditto -c -k --sequesterRsrc --keepParent "$app_path" "$archive_path"
python3 "$journal_root/script/verify_macos_package.py" \
  --app "$app_path" --archive "$archive_path" --output "$result_dir" --build-number "$build_number"
