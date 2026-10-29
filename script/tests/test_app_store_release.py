"""Pure release-gate fixtures; never import real keys, sign, build, launch or upload."""

import copy
import hashlib
import importlib.util
import io
import json
import os
import pathlib
import plistlib
import re
import stat
import struct
import subprocess
import sys
import tempfile
import unittest
import zipfile
from datetime import datetime, timedelta, timezone
from unittest.mock import patch


ROOT = pathlib.Path(__file__).parents[2]
SPEC = importlib.util.spec_from_file_location("app_store_release", ROOT / "script/app_store_release.py")
RELEASE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(RELEASE)
PNG_SPEC = importlib.util.spec_from_file_location("fixture_png", pathlib.Path(__file__).with_name("test_store_screenshots.py"))
PNG = importlib.util.module_from_spec(PNG_SPEC)
PNG_SPEC.loader.exec_module(PNG)
SHA = "a" * 40
IDENTITY = {"branch": "main", "commitSha": SHA, "runId": "123", "runAttempt": "2"}
TEAM = "ABCDE12345"
ENV = {"GITHUB_REF": "refs/heads/main", "SOURCE_SHA": SHA, "VALIDATION_RUN_ID": "123",
       "VALIDATION_ATTEMPT": "2", "TEAM_ID": TEAM, "DELIVERY_OPERATION": "export", "ALLOW_TEMP_CLEANUP": "true"}


def zip_bytes(files):
    output = io.BytesIO()
    with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED) as archive:
        for name, data in files.items():
            entry = zipfile.ZipInfo(name)
            entry.create_system = 3
            entry.external_attr = (stat.S_IFREG | (0o755 if name.endswith("/MDJournal") else 0o644)) << 16
            archive.writestr(entry, data, compress_type=zipfile.ZIP_DEFLATED)
    return output.getvalue()


def macho(platform=2, sdk=0x1A0200, code=b"CODE"):
    segment_size = 72 + 80
    commands_size = 24 + segment_size
    code_offset = 32 + commands_size
    header = struct.pack("<IiiIIIII", 0xFEEDFACF, 0x100000C, 0, 2, 2, commands_size, 0, 0)
    build = struct.pack("<IIIIII", 0x32, 24, platform, 0x100000, sdk, 0)
    segment = struct.pack("<II16sQQQQiiII", 0x19, segment_size, b"__TEXT", 0, code_offset + len(code), 0, code_offset + len(code), 7, 5, 1, 0)
    section = struct.pack("<16s16sQQIIIIIIII", b"__text", b"__TEXT", 0, len(code), code_offset, 0, 0, 0, 0, 0, 0, 0)
    return header + build + segment + section + code


def summary(count):
    return {"result": "Passed", "testFailures": [], "expectedFailures": 0,
            "totalTestCount": count, "passedTests": count, "failedTests": 0, "skippedTests": 0}


def junit(names):
    return ('<testsuite tests="' + str(len(names)) + '" failures="0" errors="0" skipped="0">'
            + ''.join('<testcase name="' + name + '" />' for name in names) + '</testsuite>').encode()


def profile_fixture():
    certificate = b"synthetic-certificate-not-an-actual-identity"
    fingerprint = hashlib.sha1(certificate).hexdigest().upper()
    identities = '  1) ' + fingerprint + ' "Apple Distribution: Fixture Team (' + TEAM + ')"\n'
    profile = {"UUID": "11111111-2222-3333-4444-555555555555", "ExpirationDate": datetime.now(timezone.utc) + timedelta(days=30),
               "TeamIdentifier": [TEAM], "ApplicationIdentifierPrefix": [TEAM], "Platform": ["iOS"],
               "DeveloperCertificates": [certificate], "Entitlements": {"get-task-allow": False,
                   "com.apple.developer.team-identifier": TEAM, "application-identifier": TEAM + ".test.journal"}}
    return profile, certificate, identities


class ReleaseEvidenceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.store_images = {}
        for name, spec in RELEASE.PNG_CONTRACT.EXPECTED_IMAGES.items():
            cls.store_images[name] = PNG.png(*spec["size"])

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="mdjournal-release-fixture-")
        self.addCleanup(self.temporary.cleanup)
        self.root = pathlib.Path(self.temporary.name)
        (self.root / "MDJournalTests").mkdir()
        (self.root / "MDJournalTests/Example.swift").write_text(
            "final class Example: XCTestCase {\n func testFirst() {}\n func testSecond() {}\n}\n")
        self.identity = dict(IDENTITY)

    def functional_files(self):
        stages = ["static-checks", "xcodebuild", "maccatalyst-build", "xctest", "interface-review", "mac-release"]
        manifest = {**IDENTITY, "validationProfile": "full", "validationPassed": True, "fullReleaseGateRequested": True,
                    "requiredStages": stages, "notSelectedStages": [],
                    "validationScope": {"onlyTesting": [], "pythonTestPattern": "test_*.py", "buildPlatform": "both", "releaseArchives": True}}
        for key in ("staticChecksOutcome", "buildOutcome", "macCatalystBuildOutcome", "testOutcome", "interfaceReviewExportOutcome", "macReleaseOutcome", "scopeOutcome"):
            manifest[key] = "success"
        files = {"ci-artifact-manifest.json": json.dumps(manifest).encode(), "junit.xml": junit(stages),
                 "xctest-summary.json": json.dumps(summary(2)).encode(),
                 "storekit-preflight-summary.json": json.dumps(summary(3)).encode(),
                 "navigation-preflight-summary.json": json.dumps(summary(4)).encode(),
                 "xctest-verification.json": json.dumps({"fullSuiteVerified": True, "declaredTestCount": 2,
                    "selectedTestIdentifiers": sorted(RELEASE.test_inventory(self.root))}).encode(),
                 "xctest.log": b"Executed 2 tests, with 0 failures (0 unexpected)\n** TEST EXECUTE SUCCEEDED **\n",
                 "body-derivation-benchmark.json": b'{"resultsEquivalent":true,"iterations":3}'}
        review = []
        for index in range(28):
            path = "interface-review/image-" + str(index) + ".png"
            files[path] = b"synthetic-review-attachment"
            review.append({"path": path})
        files["interface-review/index.json"] = json.dumps({"matrixVerified": True, "expectedImageCount": 28, "images": review}).encode()
        screenshots = []
        for name, data in self.store_images.items():
            path = name + ".png"
            files["app-store-screenshots/" + path] = data
            screenshots.append({"name": name, "path": path, "hasAlpha": False, "bytes": len(data), "sha256": RELEASE.sha256(data)})
        files["app-store-screenshots/index.json"] = json.dumps({**IDENTITY, "verificationOutcome": "success", "imageCount": 3, "images": screenshots}).encode()
        return files

    def functional(self, files):
        with RELEASE.safe_zip(io.BytesIO(zip_bytes(files))) as archive:
            return RELEASE.validate_functional(archive, IDENTITY, self.root)

    def test_complete_evidence_matches_source_inventory(self):
        self.assertEqual(self.functional(self.functional_files()), 2)

    def test_targeted_or_partial_scope_cannot_release(self):
        for change in [{"validationProfile": "targeted"}, {"notSelectedStages": ["mac-release"]},
                       {"requiredStages": ["xctest"]}, {"validationPassed": False}, {"testOutcome": "failure"},
                       {"validationScope": {"onlyTesting": ["MDJournalTests/Example"]}}]:
            files = self.functional_files()
            manifest = json.loads(files["ci-artifact-manifest.json"])
            manifest.update(change)
            files["ci-artifact-manifest.json"] = json.dumps(manifest).encode()
            with self.subTest(change=change), self.assertRaises(RELEASE.ReleaseError):
                self.functional(files)

    def test_zero_missing_failed_skipped_or_expected_failure_tests_reject(self):
        for change in [{"totalTestCount": 0, "passedTests": 0}, {"totalTestCount": 1},
                       {"failedTests": 1}, {"skippedTests": 1}, {"expectedFailures": 1}, {"result": "Failed"}]:
            files = self.functional_files()
            value = summary(2); value.update(change)
            files["xctest-summary.json"] = json.dumps(value).encode()
            with self.subTest(change=change), self.assertRaises(RELEASE.ReleaseError):
                self.functional(files)

    def test_incorrect_junit_or_missing_actual_log_rejects(self):
        for name, data in [("junit.xml", b'<testsuite tests="6" failures="1" errors="0" skipped="0"/>'),
                           ("xctest.log", b"tests declared but not executed")]:
            files = self.functional_files(); files[name] = data
            with self.subTest(name=name), self.assertRaises(RELEASE.ReleaseError):
                self.functional(files)

    def test_source_changes_cannot_reuse_an_old_test_inventory(self):
        files = self.functional_files()
        (self.root / "MDJournalTests/Added.swift").write_text("class Added: XCTestCase {\nfunc testNew() {}\n}\n")
        with self.assertRaises(RELEASE.ReleaseError):
            self.functional(files)

    def test_duplicate_source_classes_fail_closed(self):
        (self.root / "MDJournalTests/Duplicate.swift").write_text("class Example: XCTestCase {\nfunc testOther() {}\n}\n")
        with self.assertRaises(RELEASE.ReleaseError):
            RELEASE.test_inventory(self.root)

    def test_images_or_performance_evidence_cannot_be_omitted(self):
        for name in ("interface-review/index.json", "app-store-screenshots/index.json", "body-derivation-benchmark.json"):
            files = self.functional_files(); files[name] = b"{}"
            with self.subTest(name=name), self.assertRaises(RELEASE.ReleaseError):
                self.functional(files)

    def test_store_image_payload_is_validated_not_just_a_manifest_claim(self):
        files = self.functional_files()
        index = json.loads(files["app-store-screenshots/index.json"])
        image = index["images"][0]
        fake = b"not-an-image"
        files["app-store-screenshots/" + image["path"]] = fake
        image.update(bytes=len(fake), sha256=RELEASE.sha256(fake))
        files["app-store-screenshots/index.json"] = json.dumps(index).encode()
        with self.assertRaises(ValueError):
            self.functional(files)

    def device_files(self, binary=None):
        info = {"CFBundleIdentifier": "test.journal", "CFBundleExecutable": "MDJournal", "MinimumOSVersion": "16.0",
                "CFBundleVersion": "226.2", "CFBundleShortVersionString": "1.0", "NSFaceIDUsageDescription": "Fixture only",
                "ITSAppUsesNonExemptEncryption": False}
        privacy = {"NSPrivacyTracking": False, "NSPrivacyCollectedDataTypes": []}
        app = "Products/Applications/MDJournal.app/"
        files = {app + "Info.plist": plistlib.dumps(info), app + "PrivacyInfo.xcprivacy": plistlib.dumps(privacy),
                 app + "MDJournal": binary or macho(), app + "Assets.car": b"synthetic-assets"}
        nested = zip_bytes({"MDJournal.xcarchive/" + name: data for name, data in files.items()})
        report = {**IDENTITY, "appStoreUploadPerformed": False, "verificationOutcome": "success",
                  "archiveZip": "archive.zip", "archiveZipBytes": len(nested), "archiveZipSHA256": RELEASE.sha256(nested),
                  "files": [{"path": name, "bytes": len(data), "sha256": RELEASE.sha256(data)} for name, data in files.items()],
                  "bundleIdentifier": "test.journal", "buildNumber": "226.2", "marketingVersion": "1.0", "privacyManifest": privacy}
        return {"ci-artifact-manifest.json": json.dumps({**IDENTITY, "appStoreUploadPerformed": False, "archiveOutcome": "success", "validationProfile": "full"}).encode(),
                "ios-release-manifest.json": json.dumps(report).encode(), "junit.xml": junit(["ios-device-release-archive"]), "archive.zip": nested}

    def device(self, files):
        with RELEASE.safe_zip(io.BytesIO(zip_bytes(files))) as archive:
            return RELEASE.validate_device(archive, IDENTITY)

    def test_device_archive_actual_code_and_resources_are_bound(self):
        data, details = self.device(self.device_files())
        self.assertEqual(RELEASE.sha256(data), details["archiveSHA256"])
        self.assertEqual(details["codeSectionsSHA256"], {"__TEXT/__text": RELEASE.sha256(b"CODE")})
        self.assertEqual(details["resourcesSHA256"], {"Assets.car": RELEASE.sha256(b"synthetic-assets")})

    def test_simulator_old_sdk_or_truncated_macho_rejects(self):
        for binary in [macho(platform=7), macho(sdk=0x120500), b"truncated"]:
            with self.subTest(binary=binary[:20]), self.assertRaises(RELEASE.ReleaseError):
                self.device(self.device_files(binary=binary))

    def test_device_nested_digest_and_file_inventory_are_checked(self):
        files = self.device_files()
        report = json.loads(files["ios-release-manifest.json"])
        for field, value in [("archiveZipSHA256", "0" * 64), ("files", [])]:
            changed = copy.deepcopy(report); changed[field] = value
            files["ios-release-manifest.json"] = json.dumps(changed).encode()
            with self.subTest(field=field), self.assertRaises(RELEASE.ReleaseError):
                self.device(files)

    def test_artifact_digest_origin_and_size_are_checked(self):
        path = self.root / "artifact.zip"; path.write_bytes(zip_bytes({"proof.json": b"{}"}))
        metadata = {"name": "expected", "expired": False, "size_in_bytes": path.stat().st_size,
                    "digest": "sha256:" + RELEASE.sha256(path.read_bytes()),
                    "workflow_run": {"id": 123, "head_sha": SHA, "head_branch": "main"}}
        with RELEASE.checked_artifact(path, metadata, "expected", IDENTITY) as archive:
            self.assertEqual(archive.read("proof.json"), b"{}")
        for change in [{"name": "other"}, {"expired": True}, {"digest": "sha256:" + "0" * 64}, {"size_in_bytes": 1},
                       {"workflow_run": {"id": 456, "head_sha": SHA, "head_branch": "main"}}]:
            bad = copy.deepcopy(metadata); bad.update(change)
            with self.subTest(change=change), self.assertRaises(RELEASE.ReleaseError):
                RELEASE.checked_artifact(path, bad, "expected", IDENTITY)

    def test_unsafe_zip_paths_duplicate_names_and_symlinks_reject(self):
        for name in ["../escape", "/absolute", "folder\\escape", "C:/drive"]:
            with self.subTest(name=name), self.assertRaises(RELEASE.ReleaseError):
                RELEASE.safe_zip(io.BytesIO(zip_bytes({name: b"fixture"})))
        buffer = io.BytesIO()
        with zipfile.ZipFile(buffer, "w") as archive:
            entry = zipfile.ZipInfo("symlink"); entry.create_system = 3
            entry.external_attr = (stat.S_IFLNK | 0o777) << 16
            archive.writestr(entry, "../escape")
        with self.assertRaises(RELEASE.ReleaseError):
            RELEASE.safe_zip(io.BytesIO(buffer.getvalue()))
        with self.assertWarns(UserWarning):
            buffer = io.BytesIO()
            with zipfile.ZipFile(buffer, "w") as archive:
                archive.writestr("duplicate", b"one"); archive.writestr("duplicate", b"two")
        with self.assertRaises(RELEASE.ReleaseError):
            RELEASE.safe_zip(io.BytesIO(buffer.getvalue()))

    def test_encrypted_or_corrupted_zip_is_rejected(self):
        original = zip_bytes({"fixture": b"complete-synthetic-content"})
        encrypted = bytearray(original)
        central = encrypted.index(b"PK\x01\x02")
        struct.pack_into("<H", encrypted, central + 8, 1)
        with self.assertRaises(RELEASE.ReleaseError):
            RELEASE.safe_zip(io.BytesIO(encrypted))
        corrupt = bytearray(original)
        offset = 30 + len("fixture")
        corrupt[offset + 2] ^= 0xFF
        with self.assertRaises(RELEASE.ReleaseError):
            RELEASE.safe_zip(io.BytesIO(corrupt))

    def test_reusable_prepared_input_is_bound_to_the_current_delivery_job(self):
        directory = self.root / "input"; directory.mkdir()
        data, details = self.device(self.device_files())
        report = {**IDENTITY, **details, "teamID": TEAM, "operation": "export", "fullValidationVerified": True,
                  "preparedByRunId": "789", "preparedByRunAttempt": "1"}
        (directory / "release-input.json").write_text(json.dumps(report))
        (directory / "MDJournal-iOS-unsigned.xcarchive.zip").write_bytes(data)
        environment = {**ENV, "GITHUB_RUN_ID": "789", "GITHUB_RUN_ATTEMPT": "1"}
        with patch.dict(os.environ, environment, clear=True):
            RELEASE.unpack(directory, self.root / "unpacked")
        environment["GITHUB_RUN_ID"] = "790"
        with patch.dict(os.environ, environment, clear=True), self.assertRaises(RELEASE.ReleaseError):
            RELEASE.unpack(directory, self.root / "other")


class ReleaseAccountBoundaryTests(unittest.TestCase):
    def test_valid_manual_inputs_and_export_default_contract(self):
        self.assertEqual(RELEASE.inputs(ENV)["DELIVERY_OPERATION"], "export")

    def test_branch_short_sha_shell_text_bad_team_and_cleanup_without_consent_reject(self):
        for change in [{"GITHUB_REF": "refs/heads/other"}, {"SOURCE_SHA": "aaaaaaa"},
                       {"VALIDATION_RUN_ID": "123;echo secret"}, {"VALIDATION_ATTEMPT": "0"},
                       {"TEAM_ID": "guess"}, {"DELIVERY_OPERATION": "publish"}, {"ALLOW_TEMP_CLEANUP": "false"}]:
            with self.subTest(change=change), self.assertRaises(RELEASE.ReleaseError):
                RELEASE.inputs({**ENV, **change})

    def run_records(self):
        run = {"head_sha": SHA, "head_branch": "main", "run_attempt": 2, "id": 123, "status": "completed",
               "conclusion": "success", "event": "workflow_dispatch", "path": ".github/workflows/ci-results.yml"}
        jobs = [{"name": name, "head_sha": SHA, "run_attempt": 2, "conclusion": "success", "steps": [{"name": "actually executed"}]} for name in ("Validate Requested Scope", "iOS 26 Release Archive")]
        protected = {"name": "app-store", "protection_rules": [{"type": "required_reviewers", "reviewers": [{"id": 1}]}],
                     "can_admins_bypass": False, "deployment_branch_policy": {"protected_branches": False, "custom_branch_policies": True}}
        return run, jobs, {"status": "ahead"}, protected

    def test_latest_successful_run_two_jobs_and_real_environment_reviewers_required(self):
        records = self.run_records()
        RELEASE.validate_run(*records, RELEASE.inputs(ENV))
        for index, change in [(0, {"conclusion": "failure"}), (0, {"run_attempt": 3}), (0, {"head_sha": "b" * 40}),
                              (0, {"path": ".github/workflows/other.yml"}), (2, {"status": "diverged"}), (3, {"protection_rules": []}),
                              (3, {"can_admins_bypass": True}), (3, {"deployment_branch_policy": None})]:
            bad = list(copy.deepcopy(records)); bad[index].update(change)
            with self.subTest(change=change), self.assertRaises(RELEASE.ReleaseError):
                RELEASE.validate_run(*bad, RELEASE.inputs(ENV))
        for jobs in [records[1][:1], [{**job, "steps": []} for job in records[1]], [{**job, "run_attempt": 1} for job in records[1]]]:
            with self.subTest(jobs=jobs), self.assertRaises(RELEASE.ReleaseError):
                RELEASE.validate_run(records[0], jobs, records[2], records[3], RELEASE.inputs(ENV))

    def profile(self):
        profile, self.certificate, self.identities = profile_fixture()
        self.fingerprint = hashlib.sha1(self.certificate).hexdigest().upper()
        return profile

    def test_profile_requires_exact_app_team_expiry_and_distribution_private_key(self):
        profile = self.profile()
        result = RELEASE.validate_profile(profile, TEAM, "test.journal", self.identities)
        self.assertEqual(result["certificateSHA1"], self.fingerprint)
        for change in [{"TeamIdentifier": ["OTHER12345"]}, {"Platform": ["OSX"]},
                       {"ExpirationDate": datetime.now(timezone.utc) - timedelta(seconds=1)},
                       {"ProvisionedDevices": []}, {"ProvisionsAllDevices": True}, {"DeveloperCertificates": []}]:
            with self.subTest(change=change), self.assertRaises(RELEASE.ReleaseError):
                RELEASE.validate_profile({**profile, **change}, TEAM, "test.journal", self.identities)
        for entitlements in [{"get-task-allow": True}, {"application-identifier": TEAM + ".*"}, {"com.apple.developer.team-identifier": "OTHER12345"}]:
            bad = copy.deepcopy(profile); bad["Entitlements"].update(entitlements)
            with self.subTest(entitlements=entitlements), self.assertRaises(RELEASE.ReleaseError):
                RELEASE.validate_profile(bad, TEAM, "test.journal", self.identities)
        with self.assertRaises(RELEASE.ReleaseError):
            RELEASE.validate_profile(profile, TEAM, "test.journal", self.identities.replace("Apple Distribution", "Apple Development"))

    def test_legacy_explicit_app_prefix_is_allowed_without_guessing_team(self):
        profile = self.profile()
        profile["ApplicationIdentifierPrefix"] = ["OLDID12345"]
        profile["Entitlements"]["application-identifier"] = "OLDID12345.test.journal"
        self.assertEqual(RELEASE.validate_profile(profile, TEAM, "test.journal", self.identities)["teamID"], TEAM)

    def test_keychain_and_secret_writes_are_refused_locally(self):
        with patch.dict(os.environ, ENV, clear=True), self.assertRaisesRegex(RELEASE.ReleaseError, "cloud macOS"):
            RELEASE.begin_signing()

    def test_github_failures_do_not_echo_authentication_or_response_bodies(self):
        with patch.object(RELEASE.subprocess, "run", return_value=subprocess.CompletedProcess([], 1, b"", b"private-response-marker")):
            with self.assertRaises(RELEASE.ReleaseError) as caught:
                RELEASE.github_json("owner/repo", "environments/app-store")
        self.assertNotIn("private-response-marker", str(caught.exception))

    def test_redacted_failure_does_not_publish_private_apple_messages(self):
        with tempfile.TemporaryDirectory() as temp:
            root = pathlib.Path(temp)
            (root / "apple-upload.json").write_text(json.dumps({"product-errors": [{"code": -1, "message": "private-user@example.com private-key-marker"}]}))
            output = root / "failure.json"
            with patch.dict(os.environ, {"RELEASE_STAGE": "apple-upload"}):
                RELEASE.failure_report(root, output)
            report = json.loads(output.read_text())
            self.assertTrue(report["uploadMayHaveBeenAccepted"])
            self.assertEqual(report["appleErrorCodes"], [{"code": -1}])
            self.assertNotIn("private-user", output.read_text())
            self.assertNotIn("private-key-marker", output.read_text())

    def test_workflow_is_manual_pinned_protected_and_never_submits_review(self):
        workflow = (ROOT / ".github/workflows/app-store-release.yml").read_text()
        self.assertIn("workflow_dispatch:", workflow)
        self.assertNotRegex(workflow, r"(?m)^  (push|pull_request|schedule):")
        self.assertIn("environment: app-store", workflow)
        self.assertIn("options: [export, testflight]", workflow)
        self.assertIn("default: export", workflow)
        self.assertIn("cancel-in-progress: false", workflow)
        self.assertNotIn("write-all", workflow)
        for action in re.findall(r"uses: (\S+)", workflow):
            self.assertRegex(action, r"^actions/[a-z-]+@[0-9a-f]{40}$")
        publish = workflow.split("Publish signed delivery evidence", 1)[1]
        self.assertNotIn("p12", publish)
        self.assertNotIn("p8", publish)
        self.assertNotIn("signing-", publish)
        script = (ROOT / "script/sign_app_store_release.sh").read_text()
        self.assertNotIn("simctl", script)
        self.assertNotIn("-allowProvisioningUpdates", script)
        self.assertIn('"$DELIVERY_OPERATION" == testflight', script)
        self.assertNotIn("set -x", script)
        self.assertNotIn("--submit", script)
        self.assertLess(script.index("save-keychain-search"), script.index("security create-keychain"))

    def test_shell_entry_and_workflow_run_blocks_parse_without_execution(self):
        result = subprocess.run(["bash", "-n", str(ROOT / "script/sign_app_store_release.sh")], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        ruby = 'w=YAML.load_file(ARGV[0]); puts w["jobs"].values.flat_map { |j| j["steps"].select { |s| s.key?("run") }.map { |s| s["run"] } }.to_json'
        result = subprocess.run(["ruby", "-ryaml", "-rjson", "-e", ruby, str(ROOT / ".github/workflows/app-store-release.yml")], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        blocks = json.loads(result.stdout)
        self.assertGreaterEqual(len(blocks), 4)
        for block in blocks:
            parsed = subprocess.run(["bash", "-n"], input=block, capture_output=True, text=True)
            self.assertEqual(parsed.returncode, 0, parsed.stderr)


class SignedPackageContractTests(unittest.TestCase):
    def setUp(self):
        self.fixture = ReleaseEvidenceTests()
        self.fixture.setUp()
        self.addCleanup(self.fixture.doCleanups)
        self.root = self.fixture.root
        self.directory = self.root / "input"; self.directory.mkdir()
        _, self.prepared = self.fixture.device(self.fixture.device_files())
        (self.directory / "release-input.json").write_text(json.dumps({**IDENTITY, **self.prepared,
            "preparedByRunId": "789", "preparedByRunAttempt": "1", "executedTests": 2, "artifactIDs": [1, 2]}))
        self.profile, self.certificate, self.identities = profile_fixture()
        self.config = RELEASE.validate_profile(self.profile, TEAM, "test.journal", self.identities)
        self.material = self.root / "signing-config.json"; self.material.write_text(json.dumps(self.config))
        self.entitlements = dict(self.profile["Entitlements"])
        self.output = self.root / "release.json"

    def ipa_files(self):
        return {"Payload/MDJournal.app/Info.plist": plistlib.dumps(self.prepared["appInfo"]),
                "Payload/MDJournal.app/PrivacyInfo.xcprivacy": plistlib.dumps(self.prepared["privacy"]),
                "Payload/MDJournal.app/MDJournal": macho(), "Payload/MDJournal.app/Assets.car": b"synthetic-assets",
                "Payload/MDJournal.app/embedded.mobileprovision": b"synthetic-cms-payload"}

    def verify(self, files=None, certificate=None, signing_error=False):
        path = self.root / "MDJournal.ipa"; path.write_bytes(zip_bytes(files or self.ipa_files()))

        def run(command, **kwargs):
            self.assertEqual(command[0], "codesign")
            if "--verify" in command:
                self.assertIn("--strict", command)
                self.assertIn("anchor apple generic", command[command.index("-R") + 1])
                if signing_error:
                    raise subprocess.CalledProcessError(1, command)
            if "--entitlements" in command:
                kwargs["stdout"].write(plistlib.dumps(self.entitlements))
            if "--extract-certificates" in command:
                pathlib.Path(command[3] + "0").write_bytes(self.certificate if certificate is None else certificate)
            return subprocess.CompletedProcess(command, 0)

        def check_output(command, **kwargs):
            self.assertEqual(command[0], "security")
            return plistlib.dumps(self.profile) if command[1] == "cms" else self.identities

        with patch.object(RELEASE.subprocess, "run", side_effect=run), patch.object(RELEASE.subprocess, "check_output", side_effect=check_output):
            RELEASE.verify_ipa(path, self.root / "extracted/Payload/MDJournal.app", self.directory, self.material,
                               self.root / "entitlements.plist", self.root / "certificate", self.output)

    def test_signed_package_verifier_binds_code_resources_entitlements_and_identity(self):
        self.verify()
        report = json.loads(self.output.read_text())
        self.assertTrue(report["signed"])
        self.assertEqual(report["deliveryStatus"], "exported-not-uploaded")
        self.assertEqual((report["validationRunId"], report["releaseRunId"]), ("123", "789"))
        for key in ["uploaded", "processingVerified", "submittedForReview", "published"]:
            self.assertFalse(report[key])

    def test_export_cannot_modify_executable_resources_privacy_or_version(self):
        for name, value in [("MDJournal", macho(code=b"EVIL")), ("Assets.car", b"changed"),
                            ("PrivacyInfo.xcprivacy", plistlib.dumps({"NSPrivacyTracking": True})),
                            ("Info.plist", plistlib.dumps({**self.prepared["appInfo"], "CFBundleVersion": "999"}))]:
            files = self.ipa_files(); files["Payload/MDJournal.app/" + name] = value
            with self.subTest(name=name), self.assertRaises(RELEASE.ReleaseError):
                self.verify(files)
            self.assertFalse(self.output.exists())

    def test_export_cannot_add_unreviewed_privacy_metadata(self):
        files = self.ipa_files()
        files["Payload/MDJournal.app/Info.plist"] = plistlib.dumps({**self.prepared["appInfo"], "UIFileSharingEnabled": True})
        with self.assertRaises(RELEASE.ReleaseError):
            self.verify(files)
        self.assertFalse(self.output.exists())

    def test_signature_verification_failure_does_not_produce_success_manifest(self):
        with self.assertRaises(subprocess.CalledProcessError):
            self.verify(signing_error=True)
        self.assertFalse(self.output.exists())

    def test_debug_entitlements_or_a_different_certificate_reject(self):
        self.entitlements["get-task-allow"] = True
        with self.assertRaises(RELEASE.ReleaseError):
            self.verify()
        self.entitlements["get-task-allow"] = False
        with self.assertRaises(RELEASE.ReleaseError):
            self.verify(certificate=b"different-fixture-certificate")
        self.assertFalse(self.output.exists())

    def test_profile_expiry_during_export_is_checked_again(self):
        self.profile["ExpirationDate"] = datetime.now(timezone.utc) - timedelta(seconds=1)
        with self.assertRaises(RELEASE.ReleaseError):
            self.verify()
        self.assertFalse(self.output.exists())

    def test_apple_upload_acknowledgement_does_not_claim_processing_or_publication(self):
        self.verify()
        response = self.root / "apple.json"; response.write_text(json.dumps({"success-message": "Synthetic acknowledgement, no real upload"}))
        result = subprocess.run([sys.executable, str(ROOT / "script/app_store_release.py"), "record-upload", str(self.output), str(response)], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        report = json.loads(self.output.read_text())
        self.assertTrue(report["uploaded"])
        self.assertEqual(report["deliveryStatus"], "upload-accepted-processing-unverified")
        self.assertFalse(report["processingVerified"])
        self.assertFalse(report["published"])

    def test_apple_error_or_empty_acknowledgement_cannot_mark_upload_success(self):
        self.verify()
        for payload in [[], {}, {"success-message": "Fixture", "product-errors": [{"code": -1}]}, {"success-message": "Fixture", "status": "failed"}]:
            response = self.root / "apple.json"; response.write_text(json.dumps(payload))
            result = subprocess.run([sys.executable, str(ROOT / "script/app_store_release.py"), "record-upload", str(self.output), str(response)], capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertFalse(json.loads(self.output.read_text())["uploaded"])


class SigningCleanupTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="mdjournal-signing-fixture-")
        self.addCleanup(self.temporary.cleanup)
        self.root = pathlib.Path(self.temporary.name)
        self.home = self.root / "home"; self.home.mkdir()
        self.environment = {**ENV, "GITHUB_ACTIONS": "true", "RUNNER_OS": "macOS", "RUNNER_TEMP": str(self.root),
                            "GITHUB_RUN_ID": "789", "GITHUB_RUN_ATTEMPT": "1"}
        self.env_patch = patch.dict(os.environ, self.environment, clear=True); self.env_patch.start(); self.addCleanup(self.env_patch.stop)
        self.home_patch = patch.object(pathlib.Path, "home", return_value=self.home); self.home_patch.start(); self.addCleanup(self.home_patch.stop)
        self.private = RELEASE.private_directory(); self.private.mkdir()
        RELEASE.write_json(self.private / "owner.json", {"run": "789", "attempt": "1"})
        (self.private / "distribution.mobileprovision").write_bytes(b"synthetic-profile-fixture")
        self.config = self.private / "config.json"
        RELEASE.write_json(self.config, {"profileUUID": "11111111-2222-3333-4444-555555555555"})

    def test_atomic_install_and_owned_material_cleanup_without_local_keychain_commands(self):
        RELEASE.install_material(self.private, self.config)
        tracked = json.loads((self.private / "installed-files.json").read_text())
        self.assertEqual(len(tracked), 2)
        for item in tracked:
            self.assertEqual(pathlib.Path(item["path"]).stat().st_ino, (self.private / "distribution.mobileprovision").stat().st_ino)
        with patch.object(RELEASE.subprocess, "run") as command:
            RELEASE.cleanup_signing()
            command.assert_not_called()
        self.assertFalse(self.private.exists())
        self.assertTrue(all(not pathlib.Path(item["path"]).exists() for item in tracked))

    def test_cleanup_preserves_another_writers_replacement_but_removes_our_private_keys(self):
        RELEASE.install_material(self.private, self.config)
        target = pathlib.Path(json.loads((self.private / "installed-files.json").read_text())[0]["path"])
        target.unlink(); target.write_bytes(b"replacement-owned-by-another-writer")
        with self.assertRaises(RELEASE.ReleaseError):
            RELEASE.cleanup_signing()
        self.assertEqual(target.read_bytes(), b"replacement-owned-by-another-writer")
        self.assertFalse(self.private.exists())

    def test_preexisting_profile_is_never_overwritten(self):
        target = self.home / "Library/Developer/Xcode/UserData/Provisioning Profiles/11111111-2222-3333-4444-555555555555.mobileprovision"
        target.parent.mkdir(parents=True); target.write_bytes(b"existing-fixture")
        with self.assertRaises(RELEASE.ReleaseError):
            RELEASE.install_material(self.private, self.config)
        RELEASE.cleanup_signing()
        self.assertEqual(target.read_bytes(), b"existing-fixture")

    def test_cleanup_requires_explicit_temporary_material_consent(self):
        os.environ["ALLOW_TEMP_CLEANUP"] = "false"
        with self.assertRaises(RELEASE.ReleaseError):
            RELEASE.cleanup_signing()
        self.assertTrue(self.private.exists())

    def test_keychain_command_failure_still_cleans_owned_secret_files(self):
        RELEASE.write_json(self.private / "keychain-search.json", [str(self.root / "login.keychain-db")])
        (self.private / "signing.keychain-db").write_bytes(b"synthetic-keychain")
        with patch.object(RELEASE.subprocess, "run", side_effect=subprocess.CalledProcessError(1, ["security"])) as command:
            with self.assertRaises(RELEASE.ReleaseError):
                RELEASE.cleanup_signing()
            self.assertEqual(command.call_count, 2)
        self.assertFalse(self.private.exists())


if __name__ == "__main__":
    unittest.main()
