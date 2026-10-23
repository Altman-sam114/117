#!/usr/bin/env python3
"""Select an existing device in the pinned CI runtime; never boot or create devices."""

import argparse
import json
import pathlib
import uuid


def select_device(payload, runtime):
    candidates = []
    for device in payload.get("devices", {}).get(runtime, []):
        if not device.get("isAvailable") or not device.get("name", "").startswith("iPhone"):
            continue
        try:
            uuid.UUID(device.get("udid", ""))
        except (ValueError, AttributeError, TypeError):
            continue
        candidates.append(device)
    if not candidates:
        raise ValueError(f"No available iPhone in required runtime {runtime}; no runtime fallback permitted.")
    selected = min(candidates, key=lambda device: (
        device.get("state") != "Booted",
        device["name"] != "iPhone 16",
        device["name"], device["udid"],
    ))
    return {"runtime": runtime, "name": selected["name"], "udid": selected["udid"],
            "initialState": selected.get("state"),
            "destination": f"platform=iOS Simulator,id={selected['udid']}"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--devices", type=pathlib.Path, required=True)
    parser.add_argument("--runtime", required=True)
    parser.add_argument("--report", type=pathlib.Path, required=True)
    args = parser.parse_args()
    try:
        selected = select_device(json.loads(args.devices.read_text()), args.runtime)
    except ValueError as error:
        parser.exit(1, f"{error}\n")
    args.report.write_text(json.dumps(selected, indent=2) + "\n")
    print(selected["destination"])


if __name__ == "__main__":
    main()
