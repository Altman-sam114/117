#!/usr/bin/env python3
"""Require the explicitly selected XCTest scope to pass without skips."""

import argparse
import json
import pathlib
import re


def selected_tests(source_directory, selectors):
    inventory = {}
    for source in sorted(source_directory.glob("*.swift")):
        text = source.read_text()
        methods = re.findall(r"^\s*func\s+(test\w+)\s*\(", text, re.MULTILINE)
        if not methods:
            continue
        classes = re.findall(r"^\s*(?:final\s+)?class\s+(\w+)\s*:\s*XCTestCase\b", text, re.MULTILINE)
        # The project keeps one XCTestCase per source; fail closed if that changes.
        if len(classes) != 1 or classes[0] in inventory or len(methods) != len(set(methods)):
            raise ValueError(f"Cannot resolve unique XCTest declarations in {source}")
        inventory[classes[0]] = set(methods)
    if not inventory:
        raise ValueError("No XCTest declarations found")

    available = {
        f"MDJournalTests/{name}/{method}"
        for name, methods in inventory.items() for method in methods
    }
    if not selectors:
        return sorted(available)
    selected = set()
    for selector in selectors:
        if not re.fullmatch(r"MDJournalTests/[A-Za-z_]\w*(?:/test\w*)?", selector, re.ASCII):
            raise ValueError(f"Invalid XCTest selector: {selector!r}")
        parts = selector.split("/")
        if parts[1] not in inventory:
            raise ValueError(f"Unknown XCTest class: {selector}")
        if len(parts) == 2:
            selected.update(f"{selector}/{method}" for method in inventory[parts[1]])
        elif selector in available:
            selected.add(selector)
        else:
            raise ValueError(f"Unknown XCTest method: {selector}")
    return sorted(selected)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("summary", type=pathlib.Path)
    parser.add_argument("source_directory", type=pathlib.Path)
    parser.add_argument("--only-testing", action="append", default=[])
    parser.add_argument("--selection-only", action="store_true")
    args = parser.parse_args()
    try:
        selected = selected_tests(args.source_directory, args.only_testing)
    except ValueError as error:
        parser.error(str(error))
    report = {
        "declaredTestCount": len(selected),
        "onlyTesting": args.only_testing,
        "selectedTestIdentifiers": selected,
        "fullSuiteRequested": not args.only_testing,
    }
    if not args.selection_only:
        summary = json.loads(args.summary.read_text())
        actual = {key: summary.get(key) for key in ("totalTestCount", "passedTests", "failedTests", "skippedTests")}
        if actual != {
            "totalTestCount": len(selected), "passedTests": len(selected), "failedTests": 0, "skippedTests": 0
        }:
            raise SystemExit(f"The selected XCTest scope must pass without skips: expected {len(selected)}, received {actual}")
        report.update(actual=actual, fullSuiteVerified=not args.only_testing)
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
