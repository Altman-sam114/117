#!/usr/bin/env python3
"""Package original XCTest screenshot attachments without changing their pixels."""

import argparse
import hashlib
import json
import os
import pathlib
import re
import struct
import zlib


PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
EXPECTED_IMAGES = {
    "appstore-iphone-library-1179x2556": {
        "size": (1179, 2556), "pointSize": (393, 852), "renderScale": 3,
        "surface": "ContentView / compact library",
        "renderBoundary": "Production UI captured from the CI iPhone host's native window at 3x.",
        "iPadDeviceCapture": False,
    },
    "appstore-iphone-detail-1179x2556": {
        "size": (1179, 2556), "pointSize": (393, 852), "renderScale": 3,
        "surface": "ContentView / editor opened through the production NavigationLink",
        "renderBoundary": "Production UI captured from the CI iPhone host's native window at 3x.",
        "iPadDeviceCapture": False,
    },
    "appstore-ipad-library-2732x2048": {
        "size": (2732, 2048), "pointSize": (1366, 1024), "renderScale": 2,
        "surface": "ContentView / complete regular-width library and editor",
        "renderBoundary": (
            "Production UI rendered on a 1366x1024-point canvas at 2x in the iPhone test host; "
            "this is not an iPad device capture or iPad device validation."
        ),
        "iPadDeviceCapture": False,
    },
}


def _scanline_layout(width, height, bits_per_pixel, interlace):
    passes = [(0, 0, 1, 1)] if interlace == 0 else [
        (0, 0, 8, 8), (4, 0, 8, 8), (0, 4, 4, 8), (2, 0, 4, 4),
        (0, 2, 2, 4), (1, 0, 2, 2), (0, 1, 1, 2),
    ]
    result = []
    for x, y, dx, dy in passes:
        columns = max(0, (width - x + dx - 1) // dx)
        rows = max(0, (height - y + dy - 1) // dy)
        if columns and rows:
            result.append((rows, 1 + (columns * bits_per_pixel + 7) // 8))
    return result


def validate_png(data, expected_size):
    """Validate every chunk and the bounded image stream, including Adam7 PNGs."""
    if not data.startswith(PNG_SIGNATURE):
        raise ValueError("Invalid PNG signature")
    offset = len(PNG_SIGNATURE)
    header = None
    palette_seen = False
    idat_parts = []
    idat_ended = False
    ended = False
    while offset < len(data):
        if len(data) - offset < 12:
            raise ValueError("Truncated PNG chunk")
        length = struct.unpack_from(">I", data, offset)[0]
        kind = data[offset + 4:offset + 8]
        if not re.fullmatch(rb"[A-Za-z]{4}", kind) or kind[2] & 32:
            raise ValueError("Invalid PNG chunk type")
        end = offset + 12 + length
        if end > len(data):
            raise ValueError("Truncated PNG chunk data")
        payload = data[offset + 8:end - 4]
        checksum = struct.unpack_from(">I", data, end - 4)[0]
        if zlib.crc32(kind + payload) & 0xFFFFFFFF != checksum:
            raise ValueError(f"Invalid PNG CRC for {kind.decode('ascii')}")
        if header is None and kind != b"IHDR":
            raise ValueError("PNG must begin with IHDR")
        if kind == b"IHDR":
            if header is not None or length != 13:
                raise ValueError("PNG must have exactly one 13-byte IHDR")
            width, height, depth, color, compression, filtering, interlace = struct.unpack(">IIBBBBB", payload)
            if (width, height) != tuple(expected_size) or width < 1 or height < 1:
                raise ValueError(f"Wrong PNG dimensions: {width}x{height}, expected {expected_size}")
            if color not in (0, 2):
                raise ValueError("PNG must use grayscale or RGB without an alpha channel")
            if depth not in ({1, 2, 4, 8, 16} if color == 0 else {8, 16}):
                raise ValueError("Invalid PNG bit depth")
            if compression != 0 or filtering != 0 or interlace not in (0, 1):
                raise ValueError("Unsupported PNG compression, filtering, or interlace method")
            header = (width, height, depth, color, interlace)
        elif kind == b"tRNS":
            raise ValueError("PNG transparency (tRNS) is not allowed")
        elif kind == b"PLTE":
            if palette_seen or idat_parts or header[3] == 0 or not length or length % 3 or length > 768:
                raise ValueError("Invalid PNG palette")
            palette_seen = True
        elif kind == b"IDAT":
            if idat_ended:
                raise ValueError("PNG IDAT chunks must be consecutive")
            idat_parts.append(payload)
        elif kind == b"IEND":
            if length != 0 or not idat_parts:
                raise ValueError("PNG IEND requires image data and an empty payload")
            if end != len(data):
                raise ValueError("PNG has trailing bytes after IEND")
            ended = True
            break
        elif not kind[0] & 32:
            raise ValueError(f"Unknown critical PNG chunk: {kind.decode('ascii')}")
        if idat_parts and kind != b"IDAT":
            idat_ended = True
        offset = end
    if not ended:
        raise ValueError("PNG is missing IEND")

    width, height, depth, color, interlace = header
    layout = _scanline_layout(width, height, depth * (1 if color == 0 else 3), interlace)
    expected_bytes = sum(rows * row_bytes for rows, row_bytes in layout)
    decoder = zlib.decompressobj()
    try:
        raw = decoder.decompress(b"".join(idat_parts), expected_bytes + 1)
    except zlib.error as error:
        raise ValueError("Invalid PNG compressed image data") from error
    if len(raw) != expected_bytes or not decoder.eof or decoder.unused_data or decoder.unconsumed_tail:
        raise ValueError("PNG image data does not match its dimensions or has an incomplete zlib stream")
    row_offset = 0
    for rows, row_bytes in layout:
        for _ in range(rows):
            if raw[row_offset] > 4:
                raise ValueError("Invalid PNG scanline filter")
            row_offset += row_bytes
    return {"width": width, "height": height, "bitDepth": depth, "colorType": color, "hasAlpha": False}


def _source_file(root, filename):
    if not isinstance(filename, str) or not filename:
        raise ValueError("Missing exported attachment path")
    relative = pathlib.Path(filename)
    if relative.is_absolute() or ".." in relative.parts or "\\" in filename:
        raise ValueError(f"Attachment path escapes its export directory: {filename}")
    path = (root / relative).resolve(strict=True)
    if not path.is_relative_to(root) or not path.is_file():
        raise ValueError(f"Attachment path escapes its export directory or is not a file: {filename}")
    return path


def _github_identity(environment):
    variables = {
        "branch": "GITHUB_REF_NAME", "commitSha": "GITHUB_SHA",
        "runId": "GITHUB_RUN_ID", "runAttempt": "GITHUB_RUN_ATTEMPT",
    }
    identity = {}
    for field, variable in variables.items():
        value = environment.get(variable)
        if not isinstance(value, str) or not value or value.strip() != value:
            raise ValueError(f"Missing or invalid GitHub provenance: {variable}")
        identity[field] = value
    if re.fullmatch(r"[0-9a-fA-F]{40}", identity["commitSha"]) is None:
        raise ValueError("GITHUB_SHA must identify a full 40-character commit")
    for field in ("runId", "runAttempt"):
        if re.fullmatch(r"[1-9][0-9]*", identity[field]) is None:
            raise ValueError(f"Invalid positive GitHub {field}")
    return identity


def package_screenshots(attachments, output, environment=None):
    identity = _github_identity(os.environ if environment is None else environment)
    root = pathlib.Path(attachments).resolve(strict=True)
    destination = pathlib.Path(output).resolve()
    if root == destination:
        raise ValueError("Screenshot output must differ from the attachment directory")
    manifest_path = _source_file(root, "manifest.json")
    manifest_bytes = manifest_path.read_bytes()
    manifest = json.loads(manifest_bytes)
    if not isinstance(manifest, list):
        raise ValueError("The XCTest attachment manifest must be a list")
    selected = {}
    source_paths = set()
    for test in manifest:
        if not isinstance(test, dict) or not isinstance(test.get("attachments", []), list):
            raise ValueError("Invalid XCTest manifest test record")
        for attachment in test.get("attachments", []):
            if not isinstance(attachment, dict):
                raise ValueError("Invalid XCTest attachment record")
            suggested = attachment.get("suggestedHumanReadableName", "")
            name = suggested.split("_", 1)[0] if isinstance(suggested, str) else ""
            if name not in EXPECTED_IMAGES:
                continue
            if name in selected:
                raise ValueError(f"Duplicate required attachment: {name}")
            identifier = test.get("testIdentifier")
            if not isinstance(identifier, str) or not identifier.strip():
                raise ValueError(f"Missing source test identifier for {name}")
            image = _source_file(root, attachment.get("exportedFileName"))
            if image in source_paths:
                raise ValueError(f"Duplicate source image path for {name}")
            source_paths.add(image)
            data = image.read_bytes()
            spec = EXPECTED_IMAGES[name]
            png = validate_png(data, spec["size"])
            selected[name] = (data, {
                "name": name, "path": f"{name}.png", **png,
                "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest(),
                "pointSize": list(spec["pointSize"]), "renderScale": spec["renderScale"],
                "surface": spec["surface"], "renderBoundary": spec["renderBoundary"],
                "iPadDeviceCapture": spec["iPadDeviceCapture"],
                "sampleData": {
                    "kind": "fictional-demonstration-journals",
                    "source": "MDJournalTests/JournalInterfaceTests.swift / reviewEntries()",
                },
                "source": {
                    "testIdentifier": identifier,
                    "testIdentifierURL": test.get("testIdentifierURL"),
                    "attachment": dict(attachment),
                },
            })
    missing = sorted(set(EXPECTED_IMAGES) - set(selected))
    if missing:
        raise ValueError(f"Missing required screenshots: {', '.join(missing)}")

    report = {
        **identity, "verificationOutcome": "success", "uploaded": False,
        "verificationScope": "Attachment provenance, original PNG bytes, dimensions, chunks, CRCs, and image stream.",
        "visualReviewRequired": True,
        "sourceManifest": {
            "directoryName": root.name, "path": "manifest.json",
            "bytes": len(manifest_bytes), "sha256": hashlib.sha256(manifest_bytes).hexdigest(),
        },
        "imageCount": len(EXPECTED_IMAGES),
        "images": [selected[name][1] for name in EXPECTED_IMAGES],
    }
    destination.mkdir(parents=True, exist_ok=True)
    for filename in [*(f"{name}.png" for name in EXPECTED_IMAGES), "index.json"]:
        path = destination / filename
        if path.is_symlink() or (path.exists() and not path.is_file()):
            raise ValueError(f"Unsafe screenshot output path: {filename}")
    for name, (data, _) in selected.items():
        (destination / f"{name}.png").write_bytes(data)
    (destination / "index.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--attachments", type=pathlib.Path, required=True)
    parser.add_argument("--output", type=pathlib.Path, required=True)
    args = parser.parse_args()
    try:
        report = package_screenshots(args.attachments, args.output)
    except (OSError, ValueError) as error:
        parser.exit(1, f"Screenshot packaging failed: {error}\n")
    print(f"Verified and copied {report['imageCount']} original App Store screenshot PNGs; uploaded=false.")


if __name__ == "__main__":
    main()
