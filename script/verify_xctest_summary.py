#!/usr/bin/env python3
"""Require the full declared XCTest suite to execute successfully in CI."""

import json
import pathlib
import re
import sys


summary = json.loads(pathlib.Path(sys.argv[1]).read_text())
source_directory = pathlib.Path(sys.argv[2])
expected = sum(
    len(re.findall(r"^\s*func\s+test\w+\s*\(", source.read_text(), re.MULTILINE))
    for source in source_directory.glob("*.swift")
)
actual = {key: summary.get(key) for key in ("totalTestCount", "passedTests", "failedTests", "skippedTests")}
if expected == 0 or actual != {
    "totalTestCount": expected, "passedTests": expected, "failedTests": 0, "skippedTests": 0
}:
    raise SystemExit(f"The complete XCTest suite must pass without skips: expected {expected}, received {actual}")
print(json.dumps({"declaredTestCount": expected, "actual": actual, "fullSuiteVerified": True}, indent=2))
