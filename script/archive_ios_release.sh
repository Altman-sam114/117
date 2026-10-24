#!/bin/bash
set -euo pipefail

# Generic-device archiving never starts or selects a simulator.
result_dir="${1:?Usage: archive_ios_release.sh RESULT_DIRECTORY}"
mkdir -p "$result_dir"
result_dir="$(cd "$result_dir" && pwd)"
archive_path="$result_dir/MDJournal.xcarchive"
build_number="${GITHUB_RUN_NUMBER:-1}.${GITHUB_RUN_ATTEMPT:-1}"
sdk_version="$(xcrun --sdk iphoneos --show-sdk-version)"
if [[ "${sdk_version%%.*}" -lt 26 ]]; then
  printf '%s\n' 'The App Store release archive requires an iOS 26 or later SDK.' >&2
  exit 1
fi

xcrun xcodebuild -version
printf 'iPhoneOS SDK: %s\n' "$sdk_version"
xcrun xcodebuild \
  -project MDJournal.xcodeproj -scheme MDJournal -configuration Release \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "${RUNNER_TEMP:-/private/tmp}/mdjournal-ios-release-derived" \
  -archivePath "$archive_path" \
  -resultBundlePath "$result_dir/MDJournalIOSRelease.xcresult" \
  CODE_SIGNING_ALLOWED=NO SKIP_INSTALL=NO \
  SWIFT_OPTIMIZATION_LEVEL=-O DEBUG_INFORMATION_FORMAT=dwarf-with-dsym \
  CURRENT_PROJECT_VERSION="$build_number" archive

python3 script/verify_ios_archive.py "$archive_path" "$result_dir/ios-release-manifest.json"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$archive_path" "$result_dir/MDJournal-iOS-unsigned.xcarchive.zip"
python3 - "$result_dir" <<'PY'
import hashlib
import json
import pathlib
import sys

directory = pathlib.Path(sys.argv[1])
package = directory / "MDJournal-iOS-unsigned.xcarchive.zip"
manifest_path = directory / "ios-release-manifest.json"
manifest = json.loads(manifest_path.read_text())
manifest["archiveZip"] = package.name
manifest["archiveZipBytes"] = package.stat().st_size
with package.open("rb") as handle:
    manifest["archiveZipSHA256"] = hashlib.file_digest(handle, "sha256").hexdigest()
manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
PY
