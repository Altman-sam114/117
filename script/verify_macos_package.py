#!/usr/bin/env python3
"""Verify the actual CI product and a fresh ZIP extraction without launching it."""

import argparse
import hashlib
import json
import os
import pathlib
import plistlib
import re
import stat
import subprocess
import zipfile


def command(*args):
    return subprocess.run(args, check=True, text=True, stdout=subprocess.PIPE,
                          stderr=subprocess.STDOUT).stdout


def inventory(app):
    records = []
    for path in sorted(app.rglob("*")):
        mode = stat.S_IMODE(path.lstat().st_mode)
        record = {"path": str(path.relative_to(app)), "mode": oct(mode)}
        if path.is_symlink():
            assert path.resolve().is_relative_to(app.resolve()), "Link escapes app bundle"
            record.update(type="symlink", target=os.readlink(path))
        elif path.is_file():
            data = path.read_bytes()
            record.update(type="file", size=len(data), sha256=hashlib.sha256(data).hexdigest())
        else:
            record.update(type="directory")
        records.append(record)
    return records


def main():
    parser = argparse.ArgumentParser()
    for name in ["app", "archive", "output", "build-number"]:
        parser.add_argument("--" + name, required=True)
    args = parser.parse_args()
    app, archive, output = map(pathlib.Path, [args.app, args.archive, args.output])
    with (app / "Contents/Info.plist").open("rb") as handle:
        info = plistlib.load(handle)
    assert info["CFBundleIdentifier"] == "com.codex.mdjournal.mac"
    assert info["CFBundleVersion"] == args.build_number
    assert info["CFBundlePackageType"] == "APPL"
    assert info["LSApplicationCategoryType"] == "public.app-category.productivity"
    assert info["CFBundleShortVersionString"]
    minimum = [int(part) for part in info["LSMinimumSystemVersion"].split(".")]
    assert minimum[:2] == [13, 0] and all(part == 0 for part in minimum[2:])
    executable = app / "Contents/MacOS" / info["CFBundleExecutable"]
    assert executable.is_file() and os.access(executable, os.X_OK)
    icons = sorted(str(p.relative_to(app)) for p in app.rglob("*.icns"))
    assert icons, "Missing compiled Mac application icon"

    settings = json.loads((output / "mac-release-build-settings.json").read_text())
    target = next(item["buildSettings"] for item in settings if item["target"] == "MDJournal")
    assert target["CONFIGURATION"] == "Release"
    assert target["SWIFT_OPTIMIZATION_LEVEL"] in ["-O", "-Osize"]
    assert target["CURRENT_PROJECT_VERSION"] == args.build_number
    assert target["ASSETCATALOG_COMPILER_APPICON_NAME"] == "AppIcon"

    magic = {b"\xfe\xed\xfa\xce", b"\xce\xfa\xed\xfe", b"\xfe\xed\xfa\xcf", b"\xcf\xfa\xed\xfe",
             b"\xca\xfe\xba\xbe", b"\xbe\xba\xfe\xca", b"\xca\xfe\xba\xbf", b"\xbf\xba\xfe\xca"}
    binaries = []
    for path in sorted(app.rglob("*")):
        if not path.is_file() or path.is_symlink():
            continue
        with path.open("rb") as handle:
            if handle.read(4) not in magic:
                continue
        architectures = command("lipo", "-archs", str(path)).strip().split()
        assert set(architectures) == {"arm64", "x86_64"}, (str(path), architectures)
        loads = command("otool", "-l", str(path))
        platforms = re.findall(r"\bplatform\s+(\S+)", loads)
        allowed_platforms = {"6", "MACCATALYST"} if path == executable else {"1", "MACOS", "6", "MACCATALYST"}
        assert len(platforms) == 2 and all(p in allowed_platforms for p in platforms), platforms
        dependencies = [line for line in command("otool", "-L", str(path)).splitlines() if line[:1].isspace()]
        assert not any("/Users/runner/" in line or "/private/tmp/" in line for line in dependencies)
        binaries.append({"path": str(path.relative_to(app)), "architectures": architectures,
                         "platforms": platforms})
    assert any(item["path"] == str(executable.relative_to(app)) for item in binaries)
    command("codesign", "--verify", "--deep", "--strict", str(app))
    signature = command("codesign", "-dvv", str(app))
    assert "Signature=adhoc" in signature

    with zipfile.ZipFile(archive) as package:
        assert package.testzip() is None
        assert all(not (i.flag_bits & 1) for i in package.infolist())
        for entry in package.infolist():
            name = pathlib.PurePosixPath(entry.filename)
            assert not name.is_absolute() and ".." not in name.parts
            assert name.parts[0] in [app.name, "__MACOSX"]
    fresh = pathlib.Path(os.environ["RUNNER_TEMP"]) / "mdjournal-mac-package-verification"
    assert not fresh.exists(), "Verification directory must be fresh"
    fresh.mkdir()
    command("ditto", "-x", "-k", str(archive), str(fresh))
    extracted = fresh / app.name
    files = inventory(app)
    assert inventory(extracted) == files, "Extracted content or permissions differ"
    command("codesign", "--verify", "--deep", "--strict", str(extracted))
    assert set(command("lipo", "-archs", str(extracted / executable.relative_to(app))).split()) == {"arm64", "x86_64"}
    report = {
        "version": os.environ["VERSION"], "branch": os.environ["GITHUB_REF_NAME"],
        "commitSha": os.environ["GITHUB_SHA"], "runId": os.environ["GITHUB_RUN_ID"],
        "runAttempt": os.environ["GITHUB_RUN_ATTEMPT"], "configuration": "Release",
        "bundleIdentifier": info["CFBundleIdentifier"], "marketingVersion": info["CFBundleShortVersionString"],
        "buildNumber": args.build_number, "minimumSystemVersion": info["LSMinimumSystemVersion"],
        "archive": archive.name, "archiveBytes": archive.stat().st_size,
        "archiveSHA256": hashlib.sha256(archive.read_bytes()).hexdigest(), "binaries": binaries,
        "icons": icons, "signatureType": "ad-hoc", "notarized": False, "developerIdSigned": False,
        "freshExtractMatches": True, "filesReport": "mac-release-files.json",
        "verificationBoundary": "Internal review package; no app launch, Developer ID signing or notarization."
    }
    (output / "mac-release-files.json").write_text(json.dumps(files, indent=2) + "\n")
    (output / "mac-release-manifest.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
