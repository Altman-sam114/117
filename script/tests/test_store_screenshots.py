"""Small synthetic PNG fixtures only; these are never App Store screenshot assets."""

import copy
import hashlib
import importlib.util
import json
import pathlib
import struct
import tempfile
import unittest
import zlib
from unittest.mock import patch


spec = importlib.util.spec_from_file_location(
    "package_store_screenshots", pathlib.Path(__file__).parents[1] / "package_store_screenshots.py"
)
packager = importlib.util.module_from_spec(spec)
spec.loader.exec_module(packager)


def chunk(kind, payload=b""):
    return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", zlib.crc32(kind + payload) & 0xFFFFFFFF)


def png(width=3, height=2, color=2, depth=8, before_data=b"", interlace=0, seed=0, raw=None):
    channels = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}[color]
    if raw is None:
        layout = packager._scanline_layout(width, height, depth * channels, interlace)
        raw = b"".join((b"\x00" + bytes([seed]) * (row_bytes - 1)) * rows for rows, row_bytes in layout)
    header = struct.pack(">IIBBBBB", width, height, depth, color, 0, 0, interlace)
    return packager.PNG_SIGNATURE + chunk(b"IHDR", header) + before_data + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND")


class PNGValidationTests(unittest.TestCase):
    def test_accepts_complete_rgb_grayscale_and_adam7_images(self):
        for color, depth, interlace in [(2, 8, 0), (2, 16, 1), (0, 1, 0), (0, 8, 1), (0, 16, 0)]:
            with self.subTest(color=color, depth=depth, interlace=interlace):
                result = packager.validate_png(png(color=color, depth=depth, interlace=interlace), (3, 2))
                self.assertEqual((result["width"], result["height"]), (3, 2))
                self.assertEqual(result["colorType"], color)
                self.assertFalse(result["hasAlpha"])

    def test_rejects_alpha_palette_and_transparent_rgb_or_grayscale(self):
        for color in (3, 4, 6):
            with self.subTest(color=color), self.assertRaisesRegex(ValueError, "without an alpha"):
                packager.validate_png(png(color=color), (3, 2))
        for color in (0, 2):
            with self.subTest(color=color), self.assertRaisesRegex(ValueError, "tRNS"):
                packager.validate_png(png(color=color, before_data=chunk(b"tRNS", b"\x00\x00")), (3, 2))

    def test_rejects_wrong_dimensions(self):
        with self.assertRaisesRegex(ValueError, "dimensions"):
            packager.validate_png(png(), (2, 3))

    def test_rejects_bad_signature_truncation_missing_end_and_trailing_bytes(self):
        original = png()
        for value, message in [
            (b"not a PNG", "signature"),
            (original[:-1], "Truncated"),
            (original[:-12], "missing IEND"),
            (original + b"extra", "trailing bytes"),
            (packager.PNG_SIGNATURE + b"short", "Truncated"),
        ]:
            with self.subTest(message=message), self.assertRaisesRegex(ValueError, message):
                packager.validate_png(value, (3, 2))

    def test_rejects_corrupt_crc_in_every_chunk_including_ancillary_and_end(self):
        original = png(before_data=chunk(b"tEXt", b"fixture\x00example"))
        offset = len(packager.PNG_SIGNATURE)
        while offset < len(original):
            length = struct.unpack_from(">I", original, offset)[0]
            kind = original[offset + 4:offset + 8].decode("ascii")
            end = offset + 12 + length
            corrupt = bytearray(original)
            corrupt[end - 1] ^= 1
            with self.subTest(chunk=kind), self.assertRaisesRegex(ValueError, "CRC"):
                packager.validate_png(bytes(corrupt), (3, 2))
            offset = end

    def test_rejects_duplicate_header_missing_data_and_nonconsecutive_data(self):
        original = png()
        ihdr = original[8:33]
        idat = chunk(b"IDAT", zlib.compress(b"\x00" * 20))
        values = [
            (packager.PNG_SIGNATURE + ihdr + ihdr + original[33:], "exactly one"),
            (packager.PNG_SIGNATURE + ihdr + chunk(b"IEND"), "requires image data"),
            (original[:-12] + chunk(b"tEXt", b"key\x00value") + idat + chunk(b"IEND"), "consecutive"),
        ]
        for value, message in values:
            with self.subTest(message=message), self.assertRaisesRegex(ValueError, message):
                packager.validate_png(value, (3, 2))

    def test_rejects_bad_image_stream_and_invalid_scanline_filter(self):
        ihdr = png()[8:33]
        bad_stream = packager.PNG_SIGNATURE + ihdr + chunk(b"IDAT", b"invalid zlib") + chunk(b"IEND")
        with self.assertRaisesRegex(ValueError, "compressed image data"):
            packager.validate_png(bad_stream, (3, 2))
        with self.assertRaisesRegex(ValueError, "dimensions"):
            packager.validate_png(png(raw=b"short"), (3, 2))
        with self.assertRaisesRegex(ValueError, "scanline filter"):
            packager.validate_png(png(raw=b"\x05" + b"\x00" * 19), (3, 2))


class ScreenshotPackageTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="mdjournal-screenshot-fixture-")
        self.addCleanup(temporary.cleanup)
        self.root = pathlib.Path(temporary.name)
        self.attachments = self.root / "interface-review"
        self.attachments.mkdir()
        self.output = self.root / "app-store-screenshots"
        self.environment = {
            "GITHUB_REF_NAME": "main", "GITHUB_SHA": "a" * 40,
            "GITHUB_RUN_ID": "40000000001", "GITHUB_RUN_ATTEMPT": "2",
        }
        self.names = list(packager.EXPECTED_IMAGES)
        self.expected = copy.deepcopy(packager.EXPECTED_IMAGES)
        for image in self.expected.values():
            image.update(size=(3, 2), pointSize=(3, 2), renderScale=1)
        self.manifest = []
        self.originals = {}
        for number, name in enumerate(self.names):
            filename = f"fixture-{number}.png"
            data = png(seed=number)
            (self.attachments / filename).write_bytes(data)
            self.originals[name] = data
            self.manifest.append({
                "testIdentifier": f"JournalInterfaceTests/testFixture{number}()",
                "testIdentifierURL": f"test://fixture/testFixture{number}",
                "attachments": [{
                    "suggestedHumanReadableName": f"{name}_0_fixture-{number}.png",
                    "exportedFileName": filename,
                    "deviceName": "Synthetic unit fixture, not a device",
                    "deviceId": "fixture-only", "timestamp": 1234 + number,
                    "configurationName": "Unit fixture", "isAssociatedWithFailure": False,
                }],
            })

    def package(self):
        (self.attachments / "manifest.json").write_text(json.dumps(self.manifest), encoding="utf-8")
        # Tiny images exercise packaging; production dimensions remain fixed in the CLI.
        with patch.dict(packager.EXPECTED_IMAGES, self.expected, clear=True):
            return packager.package_screenshots(self.attachments, self.output, self.environment)

    def test_copies_original_bytes_and_preserves_test_attachment_and_github_provenance(self):
        report = self.package()
        self.assertFalse(report["uploaded"])
        self.assertTrue(report["visualReviewRequired"])
        self.assertEqual(report["commitSha"], self.environment["GITHUB_SHA"])
        self.assertEqual(report["runId"], self.environment["GITHUB_RUN_ID"])
        self.assertEqual(report["runAttempt"], "2")
        self.assertEqual(report["imageCount"], 3)
        self.assertEqual(json.loads((self.output / "index.json").read_text()), report)
        manifest_data = (self.attachments / "manifest.json").read_bytes()
        self.assertEqual(report["sourceManifest"]["sha256"], hashlib.sha256(manifest_data).hexdigest())
        for index, image in enumerate(report["images"]):
            original = self.originals[image["name"]]
            self.assertEqual((self.output / image["path"]).read_bytes(), original)
            self.assertEqual(image["sha256"], hashlib.sha256(original).hexdigest())
            self.assertEqual(image["bytes"], len(original))
            self.assertEqual(image["source"]["attachment"], self.manifest[index]["attachments"][0])
            self.assertEqual(image["source"]["testIdentifier"], self.manifest[index]["testIdentifier"])
            self.assertEqual(image["sampleData"]["kind"], "fictional-demonstration-journals")
        self.assertIn("not an iPad device capture", report["images"][2]["renderBoundary"])
        self.assertFalse(report["images"][2]["iPadDeviceCapture"])

    def test_ignores_unrelated_review_attachments(self):
        self.manifest.append({"testIdentifier": "Unrelated/test()", "attachments": [{
            "suggestedHumanReadableName": "review-existing_0_fixture.png", "exportedFileName": "unrelated.png",
        }]})
        self.assertEqual(self.package()["imageCount"], 3)

    def test_rejects_missing_and_inexact_attachment_names(self):
        for suggested in ("appstore-iphone-library-1179x2556-extra_0_fixture.png", "unrelated_0_fixture.png"):
            with self.subTest(suggested=suggested):
                self.manifest[0]["attachments"][0]["suggestedHumanReadableName"] = suggested
                with self.assertRaisesRegex(ValueError, "Missing required"):
                    self.package()
                self.assertFalse(self.output.exists())

    def test_rejects_duplicate_required_attachment_and_aliased_source(self):
        self.manifest.append(copy.deepcopy(self.manifest[0]))
        with self.assertRaisesRegex(ValueError, "Duplicate required"):
            self.package()
        self.manifest.pop()
        self.manifest[1]["attachments"][0]["exportedFileName"] = "fixture-0.png"
        with self.assertRaisesRegex(ValueError, "Duplicate source"):
            self.package()

    def test_rejects_absolute_parent_and_symlink_escape_paths(self):
        outside = self.root / "outside.png"
        outside.write_bytes(png())
        (self.attachments / "escape.png").symlink_to(outside)
        for filename in (str(outside), "../outside.png", "escape.png", "..\\outside.png"):
            with self.subTest(filename=filename):
                self.manifest[0]["attachments"][0]["exportedFileName"] = filename
                with self.assertRaisesRegex(ValueError, "escapes"):
                    self.package()

    def test_rejects_missing_source_test_and_malformed_manifest(self):
        self.manifest[0].pop("testIdentifier")
        with self.assertRaisesRegex(ValueError, "source test"):
            self.package()
        self.manifest = {"attachments": []}
        with self.assertRaisesRegex(ValueError, "must be a list"):
            self.package()

    def test_rejects_invalid_png_before_creating_any_deliverables(self):
        (self.attachments / "fixture-2.png").write_bytes(png(color=6))
        with self.assertRaisesRegex(ValueError, "alpha"):
            self.package()
        self.assertFalse(self.output.exists())

    def test_rejects_missing_or_invalid_github_provenance(self):
        for key in tuple(self.environment):
            original = self.environment.pop(key)
            with self.subTest(missing=key), self.assertRaisesRegex(ValueError, "provenance"):
                self.package()
            self.environment[key] = original
        for key, value in [("GITHUB_SHA", "short"), ("GITHUB_RUN_ID", "0"), ("GITHUB_RUN_ATTEMPT", "-1")]:
            original = self.environment[key]
            self.environment[key] = value
            with self.subTest(invalid=key), self.assertRaises(ValueError):
                self.package()
            self.environment[key] = original

    def test_rejects_output_alias_and_output_symlink_without_modifying_its_target(self):
        self.output = self.attachments
        with self.assertRaisesRegex(ValueError, "must differ"):
            self.package()
        self.output = self.root / "app-store-screenshots"
        self.output.mkdir()
        outside = self.root / "unrelated.png"
        outside.write_bytes(b"keep original")
        (self.output / f"{self.names[0]}.png").symlink_to(outside)
        with self.assertRaisesRegex(ValueError, "Unsafe screenshot output"):
            self.package()
        self.assertEqual(outside.read_bytes(), b"keep original")


if __name__ == "__main__":
    unittest.main()
