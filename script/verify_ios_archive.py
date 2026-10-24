#!/usr/bin/env python3
"""Validate a device archive without launching it or claiming signing readiness."""

import hashlib
import json
import os
import pathlib
import plistlib
import re
import subprocess
import sys


def verify_archive(archive, output):
    app = archive / "Products/Applications/MDJournal.app"
    with (app / "Info.plist").open("rb") as handle:
        info = plistlib.load(handle)
    with (app / "PrivacyInfo.xcprivacy").open("rb") as handle:
        privacy = plistlib.load(handle)
    executable = app / info["CFBundleExecutable"]
    architectures = subprocess.check_output(
        ["xcrun", "lipo", "-archs", str(executable)], text=True
    ).split()
    load_commands = subprocess.check_output(
        ["xcrun", "otool", "-l", str(executable)], text=True
    )
    build = re.search(r"cmd LC_BUILD_VERSION\b(.*?)(?=\nLoad command|\Z)", load_commands, re.S)
    if build is None:
        raise ValueError("Device binary is missing LC_BUILD_VERSION")
    platform = re.search(r"\bplatform\s+(\S+)", build[1])
    sdk = re.search(r"\bsdk\s+(\S+)", build[1])
    if platform is None or platform[1] not in {"2", "IOS", "iOS"}:
        raise ValueError("Archive executable is not an iPhoneOS device binary")
    if sdk is None or int(sdk[1].split(".")[0]) < 26:
        raise ValueError("Device binary must be built with iOS 26 or later SDK")
    if architectures != ["arm64"]:
        raise ValueError(f"Unexpected iOS device architectures: {architectures}")
    sdk_name = re.fullmatch(r"iphoneos(\d+)(?:\.\d+)*", info.get("DTSDKName", ""))
    if int(info.get("DTXcode", "0")) < 2600 or sdk_name is None or int(sdk_name[1]) < 26:
        raise ValueError("Archive Info.plist does not identify an Xcode 26 / iOS 26 SDK build")
    if info.get("MinimumOSVersion") != "16.0":
        raise ValueError("The iOS deployment target changed unexpectedly")
    if not info.get("NSFaceIDUsageDescription"):
        raise ValueError("Face ID authentication requires a usage description")
    if info.get("ITSAppUsesNonExemptEncryption") is not False:
        raise ValueError("System-only encryption export declaration is missing")
    if info.get("UIFileSharingEnabled", False):
        raise ValueError("The private journal directory must not be exposed by file sharing")
    if privacy.get("NSPrivacyTracking") is not False or privacy.get("NSPrivacyCollectedDataTypes") != []:
        raise ValueError("Privacy manifest must describe the actual no-tracking, no-collection behavior")
    reasons = privacy.get("NSPrivacyAccessedAPITypes", [])
    if not any(
        item.get("NSPrivacyAccessedAPIType") == "NSPrivacyAccessedAPICategoryUserDefaults"
        and "CA92.1" in item.get("NSPrivacyAccessedAPITypeReasons", [])
        for item in reasons
    ):
        raise ValueError("App-owned UserDefaults access needs the CA92.1 required reason")
    icons = info.get("CFBundleIcons", {}).get("CFBundlePrimaryIcon", {})
    if not icons.get("CFBundleIconName"):
        raise ValueError("Archive is missing its primary app icon")
    if not (app / "Assets.car").is_file():
        raise ValueError("Archive is missing its compiled assets")
    files = []
    for path in sorted(archive.rglob("*")):
        if path.is_file() and not path.is_symlink():
            with path.open("rb") as handle:
                digest = hashlib.file_digest(handle, "sha256").hexdigest()
            files.append({"path": str(path.relative_to(archive)), "bytes": path.stat().st_size, "sha256": digest})
    report = {
        "version": "v0.95",
        "branch": os.environ.get("GITHUB_REF_NAME"),
        "commitSha": os.environ.get("GITHUB_SHA"),
        "runId": os.environ.get("GITHUB_RUN_ID"),
        "runAttempt": os.environ.get("GITHUB_RUN_ATTEMPT"),
        "verificationOutcome": "success",
        "signingStatus": "unsigned-requires-developer-team-and-distribution-signing",
        "appStoreUploadPerformed": False,
        "bundleIdentifier": info["CFBundleIdentifier"],
        "marketingVersion": info["CFBundleShortVersionString"],
        "buildNumber": info["CFBundleVersion"],
        "minimumOSVersion": info["MinimumOSVersion"],
        "xcodeBuild": info["DTXcodeBuild"],
        "sdkName": info["DTSDKName"],
        "binarySDKVersion": sdk[1],
        "architectures": architectures,
        "privacyManifest": privacy,
        "faceIDUsageDescription": info["NSFaceIDUsageDescription"],
        "files": files,
    }
    output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    print(f"Verified iOS {sdk[1]} device archive, {len(files)} files; distribution signing is still required.")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit("Usage: verify_ios_archive.py ARCHIVE OUTPUT_JSON")
    verify_archive(pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2]))
