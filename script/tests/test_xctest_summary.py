import importlib.util
import json
import os
import pathlib
import re
import subprocess
import sys
import tempfile
import textwrap
import unittest


SCRIPT = pathlib.Path(__file__).resolve().parents[1] / "verify_xctest_summary.py"
SPEC = importlib.util.spec_from_file_location("verify_xctest_summary", SCRIPT)
VERIFIER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(VERIFIER)


class XCTestSummaryTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.directory = pathlib.Path(self.temporary.name)
        (self.directory / "Alpha.swift").write_text(
            "final class Alpha: XCTestCase {\n"
            "    func testOne() {}\n    func testTwo() async throws {}\n}\n"
        )
        (self.directory / "Beta.swift").write_text(
            "class Beta: XCTestCase {\n    func testThree() {}\n}\n"
        )

    def selected(self, *selectors):
        return VERIFIER.selected_tests(self.directory, list(selectors))

    def run_verifier(self, passed=1, failed=0, skipped=0, selectors=(), selection_only=False):
        summary = self.directory / "summary.json"
        summary.write_text(json.dumps({
            "totalTestCount": passed + failed + skipped,
            "passedTests": passed, "failedTests": failed, "skippedTests": skipped,
        }))
        command = [sys.executable, str(SCRIPT), str(summary), str(self.directory)]
        for selector in selectors:
            command += ["--only-testing", selector]
        if selection_only:
            command.append("--selection-only")
        return subprocess.run(command, capture_output=True, text=True, check=False)

    def test_full_suite_keeps_existing_count_gate(self):
        self.assertEqual(len(self.selected()), 3)
        result = self.run_verifier(passed=3)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(json.loads(result.stdout)["fullSuiteVerified"])

    def test_selects_class_or_exact_method(self):
        self.assertEqual(len(self.selected("MDJournalTests/Alpha")), 2)
        self.assertEqual(self.selected("MDJournalTests/Beta/testThree"), ["MDJournalTests/Beta/testThree"])

    def test_overlapping_selections_count_once(self):
        self.assertEqual(len(self.selected("MDJournalTests/Alpha", "MDJournalTests/Alpha/testOne")), 2)

    def test_rejects_unknown_or_broad_selectors(self):
        for selector in ("", "MDJournalTests", "MDJournalTests/*", "MDJournalTests/Other",
                         "MDJournalTests/Alpha/testMissing", "-skip-testing:MDJournalTests/Alpha",
                         "MDJournalTests/Alpha;exit", "OtherTests/Alpha", "../Alpha"):
            with self.subTest(selector=selector), self.assertRaises(ValueError):
                self.selected(selector)

    def test_empty_source_cannot_pass(self):
        with tempfile.TemporaryDirectory() as empty, self.assertRaises(ValueError):
            VERIFIER.selected_tests(pathlib.Path(empty), [])

    def test_ambiguous_source_cannot_silently_change_scope(self):
        (self.directory / "Alpha.swift").write_text(
            "class Alpha: XCTestCase {\n    func testOne() {}\n}\nclass Extra: XCTestCase {}\n"
        )
        with self.assertRaises(ValueError):
            self.selected("MDJournalTests/Alpha")

    def test_targeted_success_is_not_full_suite_evidence(self):
        result = self.run_verifier(selectors=["MDJournalTests/Alpha/testOne"])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(json.loads(result.stdout)["fullSuiteVerified"])

    def test_rejects_zero_extra_failed_or_skipped_execution(self):
        for counts in ((0, 0, 0), (2, 0, 0), (0, 1, 0), (0, 0, 1)):
            with self.subTest(counts=counts):
                result = self.run_verifier(*counts, selectors=["MDJournalTests/Alpha/testOne"])
                self.assertNotEqual(result.returncode, 0)

    def test_selection_only_does_not_claim_execution(self):
        result = self.run_verifier(selectors=["MDJournalTests/Alpha"], selection_only=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        report = json.loads(result.stdout)
        self.assertEqual(report["declaredTestCount"], 2)
        self.assertNotIn("actual", report)
        self.assertNotIn("fullSuiteVerified", report)


class ValidationWorkflowScopeTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.directory = pathlib.Path(self.temporary.name)
        self.root = SCRIPT.parent.parent
        self.workflow = (self.root / ".github/workflows/ci-results.yml").read_text()
        self.env = dict(os.environ, RESULT_DIR=str(self.directory),
                        GITHUB_OUTPUT=str(self.directory / "output"), VALIDATION_PROFILE="targeted",
                        ONLY_TESTING="", PYTHON_TEST_PATTERN="", BUILD_PLATFORM="none")

    def run_block(self, name):
        match = re.search(rf"^      - name: {re.escape(name)}\n(.*?)(?=^      - name: |\Z)",
                          self.workflow, re.MULTILINE | re.DOTALL)
        self.assertIsNotNone(match, name)
        return textwrap.dedent(match.group(1).split("        run: |\n", 1)[1])

    def resolve_scope(self, **changes):
        return subprocess.run(["bash", "-c", self.run_block("Resolve validation scope")],
                              env=dict(self.env, **changes), cwd=self.root,
                              capture_output=True, text=True, check=False)

    def write_summary(self, **changes):
        env = dict(self.env, STATIC_OUTCOME="success", BUILD_OUTCOME="skipped",
                   MACCATALYST_BUILD_OUTCOME="skipped", TEST_OUTCOME="skipped",
                   INTERFACE_REVIEW_OUTCOME="skipped", MAC_RELEASE_OUTCOME="skipped",
                   SCOPE_OUTCOME="success", VERSION="fixture", GITHUB_REF_NAME="main",
                   GITHUB_SHA="a" * 40, GITHUB_RUN_ID="123", GITHUB_RUN_ATTEMPT="2",
                   GITHUB_WORKFLOW="scope-fixture", SHORT_SHA="aaaaaaa", PROJECT_NAME="MD Journal",
                   SCHEME="MDJournalCI", BUILD_DESTINATION="generic/platform=iOS",
                   MACCATALYST_BUILD_DESTINATION="generic/platform=macOS,variant=Mac Catalyst",
                   DEVELOPER_DIR="/not-used", TEST_RUNTIME="not-used", SIMULATOR_PREPARATION_OUTCOME="skipped")
        program = self.run_block("Write manifest and summaries").split("<<'PY'\n", 1)[1].rsplit("\nPY", 1)[0]
        result = subprocess.run([sys.executable, "-c", program], env=dict(env, **changes),
                                capture_output=True, text=True, check=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        return json.loads((self.directory / "ci-artifact-manifest.json").read_text())

    def test_no_push_trigger_or_default_full_run(self):
        self.assertNotRegex(self.workflow, r"(?m)^  (push|pull_request):")
        self.assertRegex(self.workflow, r"(?m)^  workflow_dispatch:")
        self.assertNotEqual(self.resolve_scope().returncode, 0)

    def test_python_only_scope_does_not_prepare_xctest(self):
        result = self.resolve_scope(PYTHON_TEST_PATTERN="test_xctest_summary.py")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        outputs = (self.directory / "output").read_text()
        self.assertIn("full=false\n", outputs)
        self.assertIn("has_tests=false\n", outputs)
        self.assertFalse((self.directory / "test-selection.json").exists())

    def test_exact_test_selection_is_resolved_before_build(self):
        result = self.resolve_scope(ONLY_TESTING="MDJournalTests/MarkdownSnippetTests/testAllSnippetsHaveVisibleMetadataAndMarkdown")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        selection = json.loads((self.directory / "test-selection.json").read_text())
        self.assertEqual(selection["declaredTestCount"], 1)
        self.assertIn("has_tests=true\n", (self.directory / "output").read_text())

    def test_invalid_filters_are_rejected(self):
        for changes in ({"ONLY_TESTING": "MDJournalTests/Unknown"},
                        {"ONLY_TESTING": " \n\t "},
                        {"PYTHON_TEST_PATTERN": "test_*.py"},
                        {"PYTHON_TEST_PATTERN": "../test_ci_simulator.py"},
                        {"PYTHON_TEST_PATTERN": "test_missing.py"},
                        {"BUILD_PLATFORM": "unknown"}):
            with self.subTest(changes=changes):
                self.assertNotEqual(self.resolve_scope(**changes).returncode, 0)

    def test_full_is_explicit_and_does_not_accept_filters(self):
        result = self.resolve_scope(VALIDATION_PROFILE="full")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("full=true\n", (self.directory / "output").read_text())
        self.assertNotEqual(self.resolve_scope(VALIDATION_PROFILE="full", ONLY_TESTING="MDJournalTests/Alpha").returncode, 0)

    def test_unselected_stages_are_not_counted_as_passes(self):
        report = self.write_summary(PYTHON_TEST_PATTERN="test_xctest_summary.py")
        self.assertTrue(report["validationPassed"])
        self.assertEqual(report["requiredStages"], ["static-checks"])
        self.assertEqual(len(report["notSelectedStages"]), 5)
        self.assertFalse(report["fullReleaseGateRequested"])
        self.assertEqual(report["testOutcome"], "skipped")

    def test_selected_test_or_build_failure_cannot_pass(self):
        for changes in ({"ONLY_TESTING": "MDJournalTests/Alpha", "TEST_OUTCOME": "skipped"},
                        {"ONLY_TESTING": "MDJournalTests/Alpha", "TEST_OUTCOME": "failure"},
                        {"BUILD_PLATFORM": "catalyst", "MACCATALYST_BUILD_OUTCOME": "skipped"},
                        {"BUILD_PLATFORM": "ios", "BUILD_OUTCOME": "failure"},
                        {"SCOPE_OUTCOME": "failure"}):
            with self.subTest(changes=changes):
                self.assertFalse(self.write_summary(**changes)["validationPassed"])

    def test_build_only_scope_and_full_gate_remain_distinct(self):
        report = self.write_summary(BUILD_PLATFORM="catalyst", MACCATALYST_BUILD_OUTCOME="success")
        self.assertTrue(report["validationPassed"])
        self.assertEqual(report["requiredStages"], ["static-checks", "maccatalyst-build"])
        self.assertFalse(self.write_summary(VALIDATION_PROFILE="full")["validationPassed"])
        report = self.write_summary(VALIDATION_PROFILE="full", BUILD_OUTCOME="success",
                                    MACCATALYST_BUILD_OUTCOME="success", TEST_OUTCOME="success",
                                    INTERFACE_REVIEW_OUTCOME="success", MAC_RELEASE_OUTCOME="success")
        self.assertTrue(report["validationPassed"])
        self.assertEqual(len(report["requiredStages"]), 6)
        self.assertEqual(report["notSelectedStages"], [])


if __name__ == "__main__":
    unittest.main()
