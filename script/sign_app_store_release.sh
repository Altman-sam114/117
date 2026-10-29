#!/bin/bash
set -euo pipefail
umask 077

tool="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/app_store_release.py"
if [[ "${1:-}" == cleanup ]]; then
  exec python3 "$tool" cleanup
fi
input_dir="${1:?Usage: sign_app_store_release.sh VERIFIED_INPUT OUTPUT}"
output_dir="${2:?An output directory is required}"
python3 "$tool" inputs
[[ "${GITHUB_ACTIONS:-}" == true && "${RUNNER_OS:-}" == macOS ]]
[[ "${DEVELOPER_DIR:-}" == /Applications/Xcode_26.2.app/Contents/Developer ]]

cleanup() {
  status=$?
  trap - EXIT
  if [[ "$status" -ne 0 && -n "${private_dir:-}" && -d "$output_dir" ]]; then
    python3 "$tool" failure-report "$private_dir" "$output_dir/failure-summary.json" || true
  fi
  python3 "$tool" cleanup || status=1
  exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
export RELEASE_STAGE=materials
private_dir=$(python3 "$tool" begin-signing)
mkdir -p "$output_dir"
bundle_id=$(python3 "$tool" unpack "$input_dir" "$private_dir")
keychain="$private_dir/signing.keychain-db"
python3 "$tool" save-keychain-search "$private_dir"
password=$(openssl rand -base64 32)
security create-keychain -p "$password" "$keychain"
security set-keychain-settings -lut 1800 "$keychain"
security unlock-keychain -p "$password" "$keychain"
security import "$private_dir/distribution.p12" -k "$keychain" \
  -P "$IOS_DISTRIBUTION_P12_PASSWORD" -T /usr/bin/codesign -T /usr/bin/security >/dev/null
unset IOS_DISTRIBUTION_P12_BASE64 IOS_DISTRIBUTION_P12_PASSWORD IOS_APP_STORE_PROFILE_BASE64 ASC_PRIVATE_KEY_P8_BASE64
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$password" "$keychain" >/dev/null
unset password
security find-identity -v -p codesigning "$keychain" > "$private_dir/identities.txt"
security cms -D -i "$private_dir/distribution.mobileprovision" > "$private_dir/profile.plist"
export RELEASE_STAGE=profile
python3 "$tool" profile "$private_dir/profile.plist" "$private_dir/identities.txt" \
  "$input_dir/release-input.json" "$private_dir/signing-config.json"
python3 "$tool" install-material "$private_dir" "$private_dir/signing-config.json"
python3 "$tool" select-keychain "$private_dir"
python3 "$tool" export-options "$private_dir/signing-config.json" "$private_dir/ExportOptions.plist"

# Export re-signs the verified cloud archive; it never rebuilds different application sources.
# Do not allow automatic profile generation or changing a validated version/build number.
export RELEASE_STAGE=export
xcrun xcodebuild -exportArchive -archivePath "$private_dir/MDJournal.xcarchive" \
  -exportOptionsPlist "$private_dir/ExportOptions.plist" -exportPath "$private_dir/export" \
  > "$output_dir/export.log" 2>&1
ipas=("$private_dir/export/"*.ipa)
[[ ${#ipas[@]} -eq 1 && -f "${ipas[0]}" ]]
cp "${ipas[0]}" "$output_dir/MDJournal.ipa"
export RELEASE_STAGE=verify-ipa
python3 "$tool" verify-ipa "$output_dir/MDJournal.ipa" "$private_dir/ipa/Payload/MDJournal.app" \
  "$input_dir" "$private_dir/signing-config.json" "$private_dir/entitlements.plist" \
  "$private_dir/signer" "$output_dir/app-store-release.json"

if [[ "$DELIVERY_OPERATION" == testflight ]]; then
  key="$private_dir/AuthKey_${ASC_KEY_ID}.p8"
  openssl pkey -in "$key" -check -noout >/dev/null 2>&1
  export RELEASE_STAGE=apple-validation
  xcrun altool --validate-app --type ios --file "$output_dir/MDJournal.ipa" \
    --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID" --output-format json \
    > "$private_dir/apple-validation.json" 2> "$private_dir/apple-validation.stderr"
  export RELEASE_STAGE=apple-upload
  xcrun altool --upload-app --type ios --file "$output_dir/MDJournal.ipa" \
    --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID" --output-format json \
    > "$private_dir/apple-upload.json" 2> "$private_dir/apple-upload.stderr"
  python3 "$tool" record-upload "$output_dir/app-store-release.json" "$private_dir/apple-upload.json"
fi
printf '%s\n' "Signed IPA verified for $bundle_id. See app-store-release.json for the actual delivery state."
