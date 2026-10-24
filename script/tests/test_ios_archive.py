"""Pure archive-contract fixtures; no simulator, compiler, or application is used."""

import importlib.util
import json
import pathlib
import plistlib
import tempfile
import unittest
from unittest.mock import patch


spec = importlib.util.spec_from_file_location(
    "verify_ios_archive", pathlib.Path(__file__).parents[1] / "verify_ios_archive.py"
)
verifier = importlib.util.module_from_spec(spec)
spec.loader.exec_module(verifier)


class IOSArchiveTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="mdjournal-archive-fixture-")
        self.addCleanup(self.temporary.cleanup)
        self.root = pathlib.Path(self.temporary.name)
        self.archive = self.root / "MDJournal.xcarchive"
        self.app = self.archive / "Products/Applications/MDJournal.app"
        self.app.mkdir(parents=True)
        self.output = self.root / "verification.json"
        self.info = {
            "CFBundleExecutable": "MDJournal", "CFBundleIdentifier": "test.journal",
            "CFBundleShortVersionString": "1.0", "CFBundleVersion": "1.1",
            "MinimumOSVersion": "16.0", "DTXcode": "2620", "DTSDKName": "iphoneos26.2",
            "DTXcodeBuild": "17C52", "NSFaceIDUsageDescription": "Unlock local journals",
            "ITSAppUsesNonExemptEncryption": False,
            "CFBundleIcons": {"CFBundlePrimaryIcon": {"CFBundleIconName": "AppIcon"}},
        }
        self.privacy = {
            "NSPrivacyTracking": False, "NSPrivacyCollectedDataTypes": [],
            "NSPrivacyAccessedAPITypes": [{
                "NSPrivacyAccessedAPIType": "NSPrivacyAccessedAPICategoryUserDefaults",
                "NSPrivacyAccessedAPITypeReasons": ["CA92.1"],
            }],
        }
        (self.app / "MDJournal").write_bytes(b"fixture-not-a-device-binary")
        (self.app / "Assets.car").write_bytes(b"fixture-assets")

    def verify(self, platform="2", sdk="26.2"):
        (self.app / "Info.plist").write_bytes(plistlib.dumps(self.info))
        (self.app / "PrivacyInfo.xcprivacy").write_bytes(plistlib.dumps(self.privacy))
        responses = ["arm64\n", f"Load command 1\n      cmd LC_BUILD_VERSION\n platform {platform}\n      sdk {sdk}\nLoad command 2\n"]
        with patch.object(verifier.subprocess, "check_output", side_effect=responses):
            verifier.verify_archive(self.archive, self.output)

    def test_reports_unsigned_device_contract_and_hashes(self):
        self.verify()
        report = json.loads(self.output.read_text())
        self.assertFalse(report["appStoreUploadPerformed"])
        self.assertIn("unsigned", report["signingStatus"])
        self.assertEqual(report["architectures"], ["arm64"])
        self.assertEqual(len(report["files"]), 4)
        self.assertTrue(all(len(item["sha256"]) == 64 for item in report["files"]))

    def test_rejects_simulator_binary_even_if_info_claims_device(self):
        with self.assertRaisesRegex(ValueError, "not an iPhoneOS device"):
            self.verify(platform="7")

    def test_rejects_old_sdk_binary(self):
        with self.assertRaisesRegex(ValueError, "iOS 26 or later SDK"):
            self.verify(sdk="18.5")

    def test_rejects_missing_privacy_reason(self):
        self.privacy["NSPrivacyAccessedAPITypes"] = []
        with self.assertRaisesRegex(ValueError, "CA92.1"):
            self.verify()

    def test_rejects_exposed_journal_directory(self):
        self.info["UIFileSharingEnabled"] = True
        with self.assertRaisesRegex(ValueError, "file sharing"):
            self.verify()


if __name__ == "__main__":
    unittest.main()
