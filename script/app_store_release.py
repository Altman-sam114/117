#!/usr/bin/env python3
"""Fail-closed checks for manual cloud distribution; never opens an app or simulator."""

import argparse
import base64
import hashlib
import importlib.util
import io
import json
import os
import pathlib
import plistlib
import re
import shlex
import shutil
import stat
import struct
import subprocess
import sys
import tempfile
import uuid
import xml.etree.ElementTree as ET
import zipfile
import zlib
from datetime import datetime, timezone

PNG_SPEC = importlib.util.spec_from_file_location("release_png_contract", pathlib.Path(__file__).with_name("package_store_screenshots.py"))
PNG_CONTRACT = importlib.util.module_from_spec(PNG_SPEC)
PNG_SPEC.loader.exec_module(PNG_CONTRACT)


class ReleaseError(ValueError):
    pass


def require(condition, message):
    if not condition:
        raise ReleaseError(message)


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def write_json(path, value):
    path = pathlib.Path(path)
    with tempfile.NamedTemporaryFile(mode="w", dir=path.parent, delete=False) as handle:
        handle.write(json.dumps(value, indent=2) + "\n")
        pending = handle.name
    os.replace(pending, path)


def inputs(environment):
    values = {key: environment.get(key, "") for key in (
        "SOURCE_SHA", "VALIDATION_RUN_ID", "VALIDATION_ATTEMPT", "TEAM_ID", "DELIVERY_OPERATION"
    )}
    require(environment.get("GITHUB_REF") == "refs/heads/main", "Release dispatch must use main")
    require(re.fullmatch(r"[0-9a-f]{40}", values["SOURCE_SHA"]), "An exact source SHA is required")
    for key in ("VALIDATION_RUN_ID", "VALIDATION_ATTEMPT"):
        require(re.fullmatch(r"[1-9][0-9]*", values[key]), "Invalid " + key)
    require(re.fullmatch(r"[A-Z0-9]{10}", values["TEAM_ID"]), "A real 10-character Team ID is required")
    require(values["DELIVERY_OPERATION"] in {"export", "testflight"}, "Unknown delivery operation")
    require(environment.get("ALLOW_TEMP_CLEANUP") == "true", "Confirm cleanup of this run's temporary signing material")
    return values


def validate_run(run, jobs, comparison, protected_environment, values):
    require(run.get("head_sha") == values["SOURCE_SHA"] and run.get("head_branch") == "main", "Validation source mismatch")
    require(str(run.get("run_attempt")) == values["VALIDATION_ATTEMPT"], "Use the latest validation attempt")
    require(str(run.get("id")) == values["VALIDATION_RUN_ID"], "Validation run mismatch")
    require(run.get("status") == "completed" and run.get("conclusion") == "success", "Full validation is not successful")
    require(run.get("event") == "workflow_dispatch" and run.get("path") == ".github/workflows/ci-results.yml", "Wrong validation workflow")
    require(comparison.get("status") in {"ahead", "identical"}, "Source is not an ancestor of current main")
    expected = {"Validate Requested Scope", "iOS 26 Release Archive"}
    require({job.get("name") for job in jobs} == expected and len(jobs) == 2, "Both validation jobs are required")
    require(all(job.get("conclusion") == "success" and job.get("steps") for job in jobs), "A validation job did not execute successfully")
    require(all(job.get("head_sha") == values["SOURCE_SHA"] and str(job.get("run_attempt")) == values["VALIDATION_ATTEMPT"] for job in jobs), "Validation job identity mismatch")
    reviewers = [rule for rule in protected_environment.get("protection_rules", []) if rule.get("type") == "required_reviewers"]
    require(protected_environment.get("name") == "app-store" and any(rule.get("reviewers") for rule in reviewers), "Configure app-store environment required reviewers before release")
    require(protected_environment.get("can_admins_bypass") is False, "Disable administrator bypass for app-store approvals")
    require(protected_environment.get("deployment_branch_policy") == {"protected_branches": False, "custom_branch_policies": True}, "Use explicit app-store deployment branch policies")


def safe_zip(source):
    archive = zipfile.ZipFile(source)
    seen = set()
    size = 0
    try:
        for entry in archive.infolist():
            path = pathlib.PurePosixPath(entry.filename)
            require(not entry.flag_bits & 1, "Encrypted ZIP entry")
            require(not path.is_absolute() and ".." not in path.parts and "\\" not in entry.filename and ":" not in entry.filename, "Unsafe ZIP path")
            require(entry.filename not in seen, "Duplicate ZIP path")
            require(stat.S_IFMT(entry.external_attr >> 16) != stat.S_IFLNK, "ZIP symlinks are not allowed")
            seen.add(entry.filename)
            size += entry.file_size
        require(len(seen) <= 20000 and size <= 2 * 1024**3, "ZIP exceeds release limits")
        require(archive.testzip() is None, "ZIP CRC failure")
    except (zipfile.BadZipFile, RuntimeError, zlib.error):
        archive.close()
        raise ReleaseError("Corrupt or unreadable ZIP") from None
    except Exception:
        archive.close()
        raise
    return archive


def checked_artifact(path, metadata, expected_name, identity):
    require(metadata.get("name") == expected_name and metadata.get("expired") is False, "Wrong or expired artifact")
    origin = metadata.get("workflow_run", {})
    require(str(origin.get("id")) == identity["runId"] and origin.get("head_sha") == identity["commitSha"] and origin.get("head_branch") == "main", "Artifact origin mismatch")
    require(0 < metadata.get("size_in_bytes", 0) <= 1024**3, "Invalid artifact size")
    require(path.stat().st_size == metadata["size_in_bytes"], "Artifact size mismatch")
    with path.open("rb") as handle:
        digest = hashlib.file_digest(handle, "sha256").hexdigest()
    require(metadata.get("digest") == "sha256:" + digest, "Artifact digest mismatch")
    return safe_zip(path)


def read_json(archive, name):
    require(archive.getinfo(name).file_size <= 4 * 1024**2, "Oversized JSON evidence")
    return json.loads(archive.read(name))


def check_identity(record, identity):
    require(all(record.get(key) == value for key, value in identity.items()), "Evidence identity mismatch")


def check_junit(data, names):
    suite = ET.fromstring(data)
    expected = {"tests": str(len(names)), "failures": "0", "errors": "0", "skipped": "0"}
    require(all(suite.get(key) == value for key, value in expected.items()), "JUnit contains failed or skipped stages")
    require(len(suite.findall("testcase")) == len(names) and {case.get("name") for case in suite.findall("testcase")} == set(names), "Missing JUnit stages")
    require(not suite.findall(".//failure") and not suite.findall(".//error") and not suite.findall(".//skipped"), "JUnit stage did not pass")


def test_inventory(source):
    selected = set()
    class_names = set()
    for path in sorted((source / "MDJournalTests").glob("*.swift")):
        text = path.read_text()
        methods = re.findall(r"^\s*func\s+(test\w+)\s*\(", text, re.M)
        if not methods:
            continue
        classes = re.findall(r"^\s*(?:final\s+)?class\s+(\w+)\s*:\s*XCTestCase\b", text, re.M)
        require(len(classes) == 1 and len(set(methods)) == len(methods), "Ambiguous source test inventory")
        require(classes[0] not in class_names, "Duplicate XCTest class")
        class_names.add(classes[0])
        for method in methods:
            identifier = "MDJournalTests/" + classes[0] + "/" + method
            require(identifier not in selected, "Duplicate source test")
            selected.add(identifier)
    require(selected, "Source declares no XCTest methods")
    return selected


def validate_functional(archive, identity, source):
    manifest = read_json(archive, "ci-artifact-manifest.json")
    check_identity(manifest, identity)
    stages = {"static-checks", "xcodebuild", "maccatalyst-build", "xctest", "interface-review", "mac-release"}
    require(manifest.get("validationProfile") == "full" and manifest.get("validationPassed") is True and manifest.get("fullReleaseGateRequested") is True, "Only full validation can release")
    require(set(manifest.get("requiredStages", [])) == stages and manifest.get("notSelectedStages") == [], "Incomplete full validation scope")
    for key in ("staticChecksOutcome", "buildOutcome", "macCatalystBuildOutcome", "testOutcome", "interfaceReviewExportOutcome", "macReleaseOutcome", "scopeOutcome"):
        require(manifest.get(key) == "success", "Unsuccessful stage: " + key)
    require(manifest.get("validationScope") == {"onlyTesting": [], "pythonTestPattern": "test_*.py", "buildPlatform": "both", "releaseArchives": True}, "Filtered validation cannot release")
    check_junit(archive.read("junit.xml"), stages)
    inventory = test_inventory(source)
    verification = read_json(archive, "xctest-verification.json")
    require(verification.get("fullSuiteVerified") is True and verification.get("declaredTestCount") == len(inventory) and len(verification.get("selectedTestIdentifiers", [])) == len(inventory) and set(verification["selectedTestIdentifiers"]) == inventory, "Source inventory differs from executed test scope")
    for name, count in (("xctest-summary.json", len(inventory)), ("storekit-preflight-summary.json", 3), ("navigation-preflight-summary.json", 4)):
        summary = read_json(archive, name)
        require(summary.get("result") == "Passed" and summary.get("testFailures") == [], "Test result is not passed")
        require(all(summary.get(key) == value for key, value in {"totalTestCount": count, "passedTests": count, "failedTests": 0, "skippedTests": 0}.items()), "Tests missing, failed or skipped")
        require(summary.get("expectedFailures") == 0, "Expected test failures are not a release pass")
    log = archive.read("xctest.log").decode("utf-8")
    require(re.search(r"Executed " + str(len(inventory)) + r" tests, with 0 failures \(0 unexpected\)", log) and "** TEST EXECUTE SUCCEEDED **" in log, "Missing actual successful test log")
    review = read_json(archive, "interface-review/index.json")
    require(review.get("matrixVerified") is True and review.get("expectedImageCount", 0) == len(review.get("images", [])) >= 28, "Incomplete interface review matrix")
    for image in review["images"]:
        require(archive.getinfo(image["path"]).file_size > 0, "Missing review image")
    screenshots = read_json(archive, "app-store-screenshots/index.json")
    check_identity(screenshots, identity)
    require(screenshots.get("verificationOutcome") == "success" and screenshots.get("imageCount") == len(screenshots.get("images", [])) == 3, "Missing store screenshots")
    require({image.get("name") for image in screenshots["images"]} == set(PNG_CONTRACT.EXPECTED_IMAGES), "Wrong store screenshot set")
    for image in screenshots["images"]:
        data = archive.read("app-store-screenshots/" + image["path"])
        require(len(data) == image["bytes"] and sha256(data) == image["sha256"] and image.get("hasAlpha") is False, "Screenshot checksum or opacity mismatch")
        PNG_CONTRACT.validate_png(data, PNG_CONTRACT.EXPECTED_IMAGES[image["name"]]["size"])
    benchmark = read_json(archive, "body-derivation-benchmark.json")
    require(benchmark.get("resultsEquivalent") is True and benchmark.get("iterations") == 3, "Missing equivalent performance evidence")
    return len(inventory)


def code_sections(binary):
    require(len(binary) >= 32, "Truncated Mach-O")
    magic, cpu, _, filetype, count, command_bytes, _, _ = struct.unpack_from("<IiiIIIII", binary)
    require(magic == 0xFEEDFACF and cpu == 0x100000C and filetype == 2, "Expected an arm64 device executable")
    position = 32
    builds = []
    sections = {}
    for _ in range(count):
        command, size = struct.unpack_from("<II", binary, position)
        require(size >= 8 and position + size <= min(len(binary), 32 + command_bytes), "Invalid Mach-O load command")
        if command == 0x32:
            platform, minimum, sdk, _ = struct.unpack_from("<IIII", binary, position + 8)
            require(platform == 2 and sdk >> 16 >= 26, "Expected iPhoneOS 26+ binary, not simulator")
            builds.append((platform, minimum, sdk))
        if command == 0x19:
            require(size >= 72, "Truncated segment")
            section_count = struct.unpack_from("<I", binary, position + 64)[0]
            require(72 + section_count * 80 <= size, "Truncated sections")
            for index in range(section_count):
                start = position + 72 + index * 80
                name = binary[start:start + 16].split(b"\0")[0].decode("ascii")
                segment = binary[start + 16:start + 32].split(b"\0")[0].decode("ascii")
                length, offset = struct.unpack_from("<QI", binary, start + 40)
                flags = struct.unpack_from("<I", binary, start + 64)[0]
                if (flags & 0xFF) in {1, 0xC, 0x12} or not length:
                    continue
                require(offset > 0 and offset + length <= len(binary), "Invalid file-backed section")
                key = segment + "/" + name
                require(key not in sections, "Duplicate Mach-O section")
                sections[key] = sha256(binary[offset:offset + length])
        position += size
    require(builds and "__TEXT/__text" in sections, "Missing executable code sections")
    return sections


def validate_device(artifact, identity):
    ci = read_json(artifact, "ci-artifact-manifest.json")
    report = read_json(artifact, "ios-release-manifest.json")
    for record in (ci, report):
        check_identity(record, identity)
        require(record.get("appStoreUploadPerformed") is False, "Unexpected archive upload state")
    require(ci.get("validationProfile") == "full" and ci.get("archiveOutcome") == "success" and report.get("verificationOutcome") == "success", "Device archive did not pass")
    check_junit(artifact.read("junit.xml"), {"ios-device-release-archive"})
    data = artifact.read(report["archiveZip"])
    require(len(data) == report["archiveZipBytes"] and sha256(data) == report["archiveZipSHA256"], "Nested device archive checksum mismatch")
    prefix = "MDJournal.xcarchive/"
    with safe_zip(io.BytesIO(data)) as archive:
        files = report["files"]
        expected = {item["path"] for item in files}
        actual = {name[len(prefix):] for name in archive.namelist() if name.startswith(prefix) and not name.endswith("/")}
        require(len(expected) == len(files) and expected == actual, "Device file inventory mismatch")
        for item in files:
            content = archive.read(prefix + item["path"])
            require(len(content) == item["bytes"] and sha256(content) == item["sha256"], "Device file checksum mismatch")
        app = prefix + "Products/Applications/MDJournal.app/"
        info = plistlib.loads(archive.read(app + "Info.plist"))
        privacy = plistlib.loads(archive.read(app + "PrivacyInfo.xcprivacy"))
        require(info.get("CFBundleIdentifier") == report["bundleIdentifier"] and info.get("MinimumOSVersion") == "16.0", "Unexpected application identity or deployment target")
        require(info.get("CFBundleVersion") == report["buildNumber"] and info.get("CFBundleShortVersionString") == report["marketingVersion"], "Application version mismatch")
        require(privacy == report["privacyManifest"] and privacy.get("NSPrivacyTracking") is False and privacy.get("NSPrivacyCollectedDataTypes") == [], "Privacy declaration mismatch")
        require(not info.get("UIFileSharingEnabled", False) and info.get("NSFaceIDUsageDescription") and info.get("ITSAppUsesNonExemptEncryption") is False, "Missing application privacy settings")
        require(not any(name.lower().endswith(".storekit") for name in archive.namelist()), "Test StoreKit configuration in distribution archive")
        sections = code_sections(archive.read(app + info["CFBundleExecutable"]))
        resources = {name[len(app):]: sha256(archive.read(name)) for name in archive.namelist()
                     if name.startswith(app) and not name.endswith("/")
                     and name[len(app):] not in {info["CFBundleExecutable"], "Info.plist", "PrivacyInfo.xcprivacy"}}
    return data, {"appInfo": info, "privacy": privacy, "archiveSHA256": sha256(data), "codeSectionsSHA256": sections, "resourcesSHA256": resources}


def validate_profile(profile, team_id, bundle_id, identities, now=None):
    now = now or datetime.now(timezone.utc)
    expiry = profile.get("ExpirationDate")
    require(isinstance(expiry, datetime) and expiry.replace(tzinfo=timezone.utc) > now, "Provisioning profile expired")
    require(profile.get("TeamIdentifier") == [team_id] and profile.get("Platform") == ["iOS"], "Profile team or platform mismatch")
    require("ProvisionedDevices" not in profile and not profile.get("ProvisionsAllDevices", False), "App Store profile required, not development/ad-hoc/enterprise")
    entitlements = profile.get("Entitlements", {})
    require(entitlements.get("get-task-allow") is False and entitlements.get("com.apple.developer.team-identifier") == team_id, "Profile must disable debugging and match team")
    prefixes = profile.get("ApplicationIdentifierPrefix", [])
    app_identifier = entitlements.get("application-identifier")
    require(any(app_identifier == prefix + "." + bundle_id for prefix in prefixes), "An exact explicit App ID profile is required")
    profile_uuid = profile.get("UUID", "")
    require(str(uuid.UUID(profile_uuid)).upper() == profile_uuid.upper(), "Invalid profile UUID")
    certificates = {hashlib.sha1(data).hexdigest().upper() for data in profile.get("DeveloperCertificates", [])}
    available = re.findall(r'\b([0-9A-F]{40})\s+"Apple Distribution:[^"]+"', identities)
    matching = set(available) & certificates
    require(len(matching) == 1, "Import one valid Apple Distribution private-key identity matching this profile")
    return {"teamID": team_id, "bundleID": bundle_id, "profileUUID": profile_uuid, "applicationIdentifier": app_identifier, "certificateSHA1": matching.pop()}


def github_json(repository, path):
    result = subprocess.run(["gh", "api", "repos/" + repository + "/" + path], capture_output=True, timeout=60)
    require(result.returncode == 0, "GitHub metadata request failed: " + path.split("?")[0])
    return json.loads(result.stdout)


def gate(source, output):
    values = inputs(os.environ)
    repository = os.environ.get("GITHUB_REPOSITORY", "")
    require(re.fullmatch(r"[\w.-]+/[\w.-]+", repository), "Invalid repository")
    head = subprocess.check_output(["git", "-C", str(source), "rev-parse", "HEAD"], text=True).strip()
    require(head == values["SOURCE_SHA"], "Checkout does not match requested SHA")
    run_id, attempt = values["VALIDATION_RUN_ID"], values["VALIDATION_ATTEMPT"]
    run = github_json(repository, "actions/runs/" + run_id)
    jobs = github_json(repository, "actions/runs/" + run_id + "/attempts/" + attempt + "/jobs?per_page=100")
    require(jobs.get("total_count") == len(jobs.get("jobs", [])), "Truncated job inventory")
    comparison = github_json(repository, "compare/" + values["SOURCE_SHA"] + "...main")
    protected = github_json(repository, "environments/app-store")
    validate_run(run, jobs["jobs"], comparison, protected, values)
    listing = github_json(repository, "actions/runs/" + run_id + "/artifacts?per_page=100")
    require(listing.get("total_count") == len(listing.get("artifacts", [])), "Truncated artifact inventory")
    identity = {"branch": "main", "commitSha": head, "runId": run_id, "runAttempt": attempt}
    names = ["mdjournal-ci-v0.95-full-main-" + head[:7] + "-run" + run_id + "-attempt" + attempt,
             "mdjournal-ios-release-v0.95-main-" + head + "-run" + run_id + "-attempt" + attempt]
    output.mkdir(parents=True, exist_ok=False)
    artifacts = []
    for name in names:
        matches = [item for item in listing["artifacts"] if item.get("name") == name]
        require(len(matches) == 1, "Exactly one matching artifact is required: " + name)
        metadata = matches[0]
        require(isinstance(metadata.get("id"), int) and 0 < metadata.get("size_in_bytes", 0) <= 1024**3, "Invalid artifact metadata")
        path = output / (str(metadata["id"]) + ".zip")
        with path.open("wb") as handle:
            result = subprocess.run(["gh", "api", "repos/" + repository + "/actions/artifacts/" + str(metadata["id"]) + "/zip"], stdout=handle, stderr=subprocess.PIPE, timeout=300)
        require(result.returncode == 0, "Artifact download failed")
        artifacts.append((path, metadata, name))
    with checked_artifact(*artifacts[0], identity) as functional:
        count = validate_functional(functional, identity, source)
    with checked_artifact(*artifacts[1], identity) as device:
        data, details = validate_device(device, identity)
    (output / "MDJournal-iOS-unsigned.xcarchive.zip").write_bytes(data)
    report = {**identity, **details, "teamID": values["TEAM_ID"], "operation": values["DELIVERY_OPERATION"],
              "preparedByRunId": os.environ["GITHUB_RUN_ID"], "preparedByRunAttempt": os.environ["GITHUB_RUN_ATTEMPT"],
              "executedTests": count, "fullValidationVerified": True, "signed": False, "uploaded": False,
              "artifactIDs": [item[1]["id"] for item in artifacts]}
    write_json(output / "release-input.json", report)
    print("Verified exact full validation and unsigned device archive; signing and upload have not run.")


def unpack(directory, output):
    report = json.loads((directory / "release-input.json").read_text())
    values = inputs(os.environ)
    require(report.get("commitSha") == values["SOURCE_SHA"] and report.get("runId") == values["VALIDATION_RUN_ID"] and report.get("runAttempt") == values["VALIDATION_ATTEMPT"], "Prepared source mismatch")
    require(report.get("preparedByRunId") == os.environ["GITHUB_RUN_ID"] and report.get("preparedByRunAttempt") == os.environ["GITHUB_RUN_ATTEMPT"], "Prepared input belongs to another release job")
    require(report.get("teamID") == values["TEAM_ID"] and report.get("operation") == values["DELIVERY_OPERATION"] and report.get("fullValidationVerified") is True, "Prepared approval mismatch")
    data = (directory / "MDJournal-iOS-unsigned.xcarchive.zip").read_bytes()
    require(sha256(data) == report["archiveSHA256"], "Prepared archive was changed")
    with safe_zip(io.BytesIO(data)) as archive:
        for item in archive.infolist():
            if not item.filename.startswith("MDJournal.xcarchive/"):
                require(item.filename.startswith("__MACOSX/"), "Unexpected archive root")
                continue
            archive.extract(item, output)
            if not item.is_dir():
                (output / item.filename).chmod((item.external_attr >> 16) & 0o777 or 0o644)
    return report


def verify_ipa(ipa, extracted_app, directory, material, entitlements, certificate, output):
    prepared = json.loads((directory / "release-input.json").read_text())
    config = json.loads(material.read_text())
    original = prepared["appInfo"]
    with safe_zip(ipa) as archive:
        apps = [name for name in archive.namelist() if re.fullmatch(r"Payload/[^/]+\.app/Info\.plist", name)]
        require(len(apps) == 1, "IPA must contain exactly one app")
        info = plistlib.loads(archive.read(apps[0]))
        require(all(info.get(key) == value for key, value in original.items()), "Export changed validated application metadata")
        prefix = apps[0][:-len("Info.plist")]
        require(set(info) - set(original) <= {"DTAppStoreToolsBuild"}, "Export added unreviewed application metadata")
        require(not info.get("UIFileSharingEnabled", False), "Export exposed the private journal directory")
        require((archive.getinfo(prefix + info["CFBundleExecutable"]).external_attr >> 16) & 0o111, "IPA executable permissions are missing")
        require(plistlib.loads(archive.read(prefix + "PrivacyInfo.xcprivacy")) == prepared["privacy"], "Export changed privacy declarations")
        require(code_sections(archive.read(prefix + info["CFBundleExecutable"])) == prepared["codeSectionsSHA256"], "Export changed validated executable code/data")
        for name, checksum in prepared["resourcesSHA256"].items():
            require(sha256(archive.read(prefix + name)) == checksum, "Export changed a validated application resource")
        for entry in archive.infolist():
            archive.extract(entry, extracted_app.parent.parent)
            if not entry.is_dir():
                (extracted_app.parent.parent / entry.filename).chmod((entry.external_attr >> 16) & 0o777 or 0o644)
    require(extracted_app == extracted_app.parent.parent / prefix.rstrip("/") and extracted_app.is_dir(), "Unexpected extracted app path")
    requirement = '=anchor apple generic and certificate leaf[subject.OU] = "' + config["teamID"] + '"'
    subprocess.run(["codesign", "--verify", "--deep", "--strict", "-R", requirement, str(extracted_app)], check=True)
    with entitlements.open("wb") as handle:
        subprocess.run(["codesign", "-d", "--entitlements", ":-", str(extracted_app)], stdout=handle, stderr=subprocess.PIPE, check=True)
    subprocess.run(["codesign", "-d", "--extract-certificates", str(certificate), str(extracted_app)], capture_output=True, check=True)
    actual = plistlib.loads(entitlements.read_bytes())
    require(actual.get("get-task-allow") is False and actual.get("com.apple.developer.team-identifier") == config["teamID"] and actual.get("application-identifier") == config["applicationIdentifier"], "IPA signing entitlements mismatch")
    signed_cert = pathlib.Path(str(certificate) + "0").read_bytes()
    require(hashlib.sha1(signed_cert).hexdigest().upper() == config["certificateSHA1"], "IPA certificate differs from approved distribution identity")
    decoded = subprocess.check_output(["security", "cms", "-D", "-i", str(extracted_app / "embedded.mobileprovision")], stderr=subprocess.PIPE)
    embedded = plistlib.loads(decoded)
    require(embedded.get("UUID") == config["profileUUID"] and embedded.get("TeamIdentifier") == [config["teamID"]], "IPA embedded profile mismatch")
    identities = subprocess.check_output(["security", "find-identity", "-v", "-p", "codesigning", str(material.parent / "signing.keychain-db")], text=True, stderr=subprocess.PIPE)
    require(validate_profile(embedded, config["teamID"], config["bundleID"], identities) == config, "Signing identity/profile expired or changed during export")
    report = {key: prepared[key] for key in ("branch", "commitSha", "runId", "runAttempt", "preparedByRunId", "preparedByRunAttempt", "executedTests", "artifactIDs")}
    report.update(bundleIdentifier=info["CFBundleIdentifier"], version=info["CFBundleShortVersionString"], build=info["CFBundleVersion"],
                  validationRunId=prepared["runId"], validationRunAttempt=prepared["runAttempt"],
                  releaseRunId=prepared["preparedByRunId"], releaseRunAttempt=prepared["preparedByRunAttempt"],
                  automationCommitSha=os.environ.get("GITHUB_SHA"),
                  teamID=config["teamID"], certificateSHA256=sha256(signed_cert), profileUUID=config["profileUUID"],
                  ipaBytes=ipa.stat().st_size, ipaSHA256=sha256(ipa.read_bytes()), signed=True,
                  deliveryStatus="exported-not-uploaded", uploaded=False, processingVerified=False, submittedForReview=False, published=False)
    write_json(output, report)


def private_directory():
    require(os.environ.get("GITHUB_ACTIONS") == "true" and os.environ.get("RUNNER_OS") == "macOS", "Signing material is cloud macOS only")
    inputs(os.environ)
    root = pathlib.Path(os.environ["RUNNER_TEMP"]).resolve()
    for name in ("GITHUB_RUN_ID", "GITHUB_RUN_ATTEMPT"):
        require(re.fullmatch(r"[1-9][0-9]*", os.environ.get(name, "")), "Invalid release job identity")
    return root / ("mdjournal-signing-" + os.environ["GITHUB_RUN_ID"] + "-" + os.environ["GITHUB_RUN_ATTEMPT"])


def begin_signing():
    directory = private_directory()
    directory.mkdir(mode=0o700, exist_ok=False)
    write_json(directory / "owner.json", {"run": os.environ["GITHUB_RUN_ID"], "attempt": os.environ["GITHUB_RUN_ATTEMPT"]})
    require(os.environ.get("IOS_DISTRIBUTION_P12_PASSWORD"), "IOS_DISTRIBUTION_P12_PASSWORD is required")
    materials = [("IOS_DISTRIBUTION_P12_BASE64", "distribution.p12", 4 * 1024**2),
                 ("IOS_APP_STORE_PROFILE_BASE64", "distribution.mobileprovision", 2 * 1024**2)]
    if os.environ["DELIVERY_OPERATION"] == "testflight":
        require(re.fullmatch(r"[A-Z0-9]{10}", os.environ.get("ASC_KEY_ID", "")), "ASC_KEY_ID is required")
        require(str(uuid.UUID(os.environ.get("ASC_ISSUER_ID", ""))).lower() == os.environ["ASC_ISSUER_ID"].lower(), "ASC_ISSUER_ID is required")
        materials.append(("ASC_PRIVATE_KEY_P8_BASE64", "AuthKey_" + os.environ["ASC_KEY_ID"] + ".p8", 65536))
    for variable, filename, limit in materials:
        value = os.environ.get(variable, "")
        require(value and len(value) <= limit * 2, "Missing or oversized secret: " + variable)
        try:
            data = base64.b64decode("".join(value.split()), validate=True)
        except ValueError:
            raise ReleaseError("Invalid base64 secret: " + variable) from None
        require(0 < len(data) <= limit, "Invalid secret size: " + variable)
        path = directory / filename
        path.write_bytes(data)
        path.chmod(0o600)
    print(directory)


def install_material(directory, config_path):
    require(directory == private_directory(), "Unexpected private material directory")
    config = json.loads(config_path.read_text())
    require(str(uuid.UUID(config["profileUUID"])).upper() == config["profileUUID"].upper(), "Invalid installation profile UUID")
    installed = []
    tracked = directory / "installed-files.json"
    write_json(tracked, installed)
    targets = [pathlib.Path.home() / name / (config["profileUUID"] + ".mobileprovision") for name in (
        "Library/Developer/Xcode/UserData/Provisioning Profiles", "Library/MobileDevice/Provisioning Profiles"
    )]
    if os.environ["DELIVERY_OPERATION"] == "testflight":
        key = directory / ("AuthKey_" + os.environ["ASC_KEY_ID"] + ".p8")
        targets.append(pathlib.Path.home() / ".appstoreconnect/private_keys" / key.name)
    resolved_targets = set()
    for target in targets:
        resolved = target.resolve()
        require(resolved.is_relative_to(pathlib.Path.home().resolve()), "Signing installation escaped runner home")
        if resolved in resolved_targets:
            continue
        resolved_targets.add(resolved)
        require(not target.exists() and not target.is_symlink(), "Refusing to replace existing signing material")
        target.parent.mkdir(parents=True, exist_ok=True)
        source = key if target.suffix == ".p8" else directory / "distribution.mobileprovision"
        data = source.read_bytes()
        source_stat = source.stat()
        # Atomic hard links avoid partially written or untracked key/profile files on cancellation.
        installed.append({"path": str(target), "sha256": sha256(data), "device": source_stat.st_dev, "inode": source_stat.st_ino})
        write_json(tracked, installed)
        os.link(source, target)


def save_keychain_search(directory):
    require(directory == private_directory(), "Unexpected keychain directory")
    previous = shlex.split(subprocess.check_output(["security", "list-keychains", "-d", "user"], text=True))
    write_json(directory / "keychain-search.json", previous)


def select_keychain(directory):
    require(directory == private_directory(), "Unexpected keychain directory")
    previous = json.loads((directory / "keychain-search.json").read_text())
    subprocess.run(["security", "list-keychains", "-d", "user", "-s", str(directory / "signing.keychain-db"), *previous], check=True)


def cleanup_signing():
    directory = private_directory()
    if not directory.exists():
        return
    require(not directory.is_symlink(), "Refusing symlink material cleanup")
    owner = json.loads((directory / "owner.json").read_text())
    require(owner == {"run": os.environ["GITHUB_RUN_ID"], "attempt": os.environ["GITHUB_RUN_ATTEMPT"]}, "Unowned signing directory")
    failures = []
    search = directory / "keychain-search.json"
    if search.exists():
        try:
            subprocess.run(["security", "list-keychains", "-d", "user", "-s", *json.loads(search.read_text())], capture_output=True, check=True)
        except (ValueError, OSError, subprocess.SubprocessError):
            failures.append("keychain search restore")
    keychain = directory / "signing.keychain-db"
    if keychain.exists():
        try:
            subprocess.run(["security", "delete-keychain", str(keychain)], capture_output=True, check=True)
        except (OSError, subprocess.SubprocessError):
            failures.append("temporary keychain unregister")
    tracked = directory / "installed-files.json"
    try:
        installed = json.loads(tracked.read_text()) if tracked.exists() else []
        for item in installed:
            try:
                path = pathlib.Path(item["path"])
                permitted = [pathlib.Path.home() / name for name in (
                    "Library/Developer/Xcode/UserData/Provisioning Profiles", "Library/MobileDevice/Provisioning Profiles", ".appstoreconnect/private_keys"
                )]
                require(path.parent in permitted and path.suffix in {".mobileprovision", ".p8"} and not path.is_symlink(), "Unsafe signing cleanup target")
                if path.exists():
                    current = path.stat()
                    require(current.st_dev == item["device"] and current.st_ino == item["inode"] and sha256(path.read_bytes()) == item["sha256"], "Signing file changed; refusing to delete another writer's file")
                    path.unlink()
            except (ReleaseError, KeyError, OSError):
                failures.append("unowned/changed installed file retained")
    except (ValueError, OSError, TypeError):
        failures.append("installed file inventory unreadable")
    # Cleanup consent and ownership are checked first. Never retain our private keys just
    # because a separate installed file changed ownership or a keychain command failed.
    shutil.rmtree(directory)
    require(not failures, "Signing cleanup incomplete: " + ", ".join(failures))


def failure_report(directory, output):
    stage = os.environ.get("RELEASE_STAGE", "unknown")
    require(stage in {"materials", "profile", "export", "verify-ipa", "apple-validation", "apple-upload", "cleanup", "unknown"}, "Unknown failure stage")
    errors = []
    for name in ("apple-validation.json", "apple-upload.json"):
        path = directory / name
        if not path.is_file():
            continue
        try:
            response = json.loads(path.read_text())
        except ValueError:
            continue
        if not isinstance(response, dict) or not isinstance(response.get("product-errors", []), list):
            continue
        for item in response.get("product-errors", []):
            if not isinstance(item, dict):
                continue
            code = item.get("code")
            if isinstance(code, int) or (isinstance(code, str) and re.fullmatch(r"-?[0-9]{1,10}", code)):
                errors.append({"code": int(code)})
    write_json(output, {"failedStage": stage, "appleErrorCodes": errors,
                        "uploadMayHaveBeenAccepted": stage == "apple-upload",
                        "processingVerified": False, "published": False,
                        "recovery": "Inspect App Store Connect before retrying an upload; no private response text is published."})


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["inputs", "gate", "unpack", "profile", "verify-ipa", "record-upload", "begin-signing", "install-material", "save-keychain-search", "select-keychain", "cleanup", "export-options", "failure-report"])
    parser.add_argument("paths", nargs="*", type=pathlib.Path)
    args = parser.parse_args()
    if args.command == "inputs":
        inputs(os.environ)
    elif args.command == "begin-signing":
        begin_signing()
    elif args.command == "cleanup":
        cleanup_signing()
    elif args.command == "install-material":
        install_material(*args.paths)
    elif args.command == "select-keychain":
        select_keychain(*args.paths)
    elif args.command == "save-keychain-search":
        save_keychain_search(*args.paths)
    elif args.command == "failure-report":
        failure_report(*args.paths)
    elif args.command == "export-options":
        config, output = args.paths
        material = json.loads(config.read_text())
        output.write_bytes(plistlib.dumps({
            "method": "app-store-connect", "destination": "export", "signingStyle": "manual",
            "teamID": material["teamID"], "signingCertificate": material["certificateSHA1"],
            "provisioningProfiles": {material["bundleID"]: material["profileUUID"]},
            "manageAppVersionAndBuildNumber": False, "stripSwiftSymbols": False, "uploadSymbols": False,
        }))
    elif args.command == "gate":
        gate(*args.paths)
    elif args.command == "unpack":
        report = unpack(*args.paths)
        print(report["appInfo"]["CFBundleIdentifier"])
    elif args.command == "profile":
        profile, identities, prepared, output = args.paths
        report = json.loads(prepared.read_text())
        config = validate_profile(plistlib.loads(profile.read_bytes()), report["teamID"], report["appInfo"]["CFBundleIdentifier"], identities.read_text())
        write_json(output, config)
    elif args.command == "verify-ipa":
        verify_ipa(*args.paths)
    elif args.command == "record-upload":
        manifest, response = args.paths
        acknowledgement = json.loads(response.read_text())
        require(isinstance(acknowledgement, dict), "Apple upload acknowledgement is not an object")
        require(not acknowledgement.get("product-errors") and acknowledgement.get("success-message") and acknowledgement.get("status", "success") in {"success", 0}, "Apple upload acknowledgement is missing or contains errors; inspect App Store Connect before retrying")
        report = json.loads(manifest.read_text())
        require(report.get("signed") is True and report.get("uploaded") is False, "Invalid delivery state")
        report.update(deliveryStatus="upload-accepted-processing-unverified", uploaded=True)
        write_json(manifest, report)


if __name__ == "__main__":
    try:
        main()
    except (ReleaseError, KeyError, ValueError, OSError, subprocess.SubprocessError, zipfile.BadZipFile) as error:
        # Never echo command arguments, signed download URLs, or secret payloads.
        print("Release stopped: " + (str(error) if isinstance(error, ReleaseError) else type(error).__name__), file=sys.stderr)
        raise SystemExit(1)
