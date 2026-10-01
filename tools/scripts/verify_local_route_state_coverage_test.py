"""Negative parser fixtures; these synthetic logs are never UI evidence."""
import copy
import contextlib
import importlib.util
import io
import json
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("coverage", Path(__file__).with_name("verify_local_route_state_coverage.py"))
coverage = importlib.util.module_from_spec(spec)
spec.loader.exec_module(coverage)


class LocalCoverageTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name).resolve()
        self.source = self.root / "fixture.dart"
        self.source.write_text("// parser unit fixture, not a rendered app\n")
        self.claim = {"localRouteAssertion": 1, "surface": "mobile", "route": "/recovery",
                      "kind": "system_state", "state": "dark", "club": "nkana",
                      "assertions": ["actual rendered state boundary", *sorted(coverage.GUIDELINES)]}
        self.events = [
            {"type": "testStart", "test": {"id": 1, "name": "unit fixture", "root_url": self.source.as_uri()}},
            {"type": "print", "testID": 1, "message": json.dumps(self.claim)},
            {"type": "testDone", "testID": 1, "result": "success", "skipped": False, "hidden": False},
            {"type": "done", "success": True},
        ]
        self.log = self.root / "unit-log.jsonl"
        self.receipt = self.root / "unit-receipt.json"
        self.inventory = self.root / "inventory.json"
        self.contracts = self.root / "contracts.json"
        route = {"surface": "mobile", "path": "/recovery", "kind": "system_state"}
        self.inventory.write_text(json.dumps({"route_count": 1, "duplicate_keys": [], "routes": [route]}))
        self.contracts.write_text(json.dumps({"route_count": 1, "state_catalog": list(coverage.STATES),
            "routes": [{**route, "states": {s: {"applicability": "applicable", "rationale": "actual unit contract"}
                                              for s in coverage.STATES}}]}))
        self.save()

    def save(self):
        self.log.write_text("\n".join(json.dumps(e) for e in self.events) + "\n")
        snapshot = [coverage.file_record(self.root, self.source)]
        self.record = {"schema_version": 1, "framework": "flutter-json", "command": ["unit-parser-fixture"],
                       "exit_code": 0, "sources_before": snapshot, "sources_after": copy.deepcopy(snapshot),
                       "log": coverage.file_record(self.root, self.log),
                       "artifacts": [coverage.file_record(self.root, self.inventory), coverage.file_record(self.root, self.contracts)]}
        self.receipt.write_text(json.dumps(self.record))

    def reject(self, fragment=None):
        with self.assertRaisesRegex(ValueError, fragment or ".*"):
            coverage.coverage_overlay(self.root, self.inventory, self.contracts, [self.receipt])

    def change_receipt(self, callback):
        callback(self.record)
        self.receipt.write_text(json.dumps(self.record))

    def test_actual_assertion_does_not_close_uncovered_clubs_or_states(self):
        result = coverage.coverage_overlay(self.root, self.inventory, self.contracts, [self.receipt])
        self.assertEqual(result["counts"]["automated_assertions_executed"], 1)
        self.assertEqual(result["counts"]["assertions_missing"], 79)
        self.assertFalse(result["local_assertion_closure_complete"])
        self.assertFalse(result["governed_review_admitted"])

    def test_generated_comparator_failures_excluded_while_goldens_remain_explicit(self):
        package = self.root / "packages" / "feature"
        generated = package / "test" / "failures" / "testImage.png"
        golden = package / "test" / "goldens" / "master.png"
        actual = package / "test" / "fixture_test.dart"
        real_failure_source = package / "lib" / "failures" / "policy.dart"
        for path in [generated, golden, actual, real_failure_source]:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b"explicit fixture bytes")
        records = coverage.source_snapshot(self.root, ["packages", "packages/feature/test/goldens"])
        selected = {row["path"] for row in records}
        self.assertNotIn(str(generated.relative_to(self.root)), selected)
        self.assertIn(str(golden.relative_to(self.root)), selected)
        self.assertIn(str(actual.relative_to(self.root)), selected)
        self.assertIn(str(real_failure_source.relative_to(self.root)), selected)

    def add_native_registration(self):
        scope = {club: {"registered": club != "costa_do_sol", "feature_key": "fan_clubs",
                       "profile": "declared_controlled_internal_admin", "allow_internal_mobile_admin": True,
                       "mobile_admin": True, "consumer_capabilities_preserved": True,
                       "rationale": "Actual compiled club feature flags exclude only Costa fan_clubs."}
                 for club in coverage.CLUBS}
        for path in (self.inventory, self.contracts):
            data = json.loads(path.read_text())
            data["routes"][0].update(native_feature_key="fan_clubs", native_registration=scope)
            path.write_text(json.dumps(data))
        self.save()

    def test_native_registration_preserves_all_enabled_club_obligations(self):
        self.add_native_registration()
        result = coverage.coverage_overlay(self.root, self.inventory, self.contracts, [self.receipt])
        costa = [row for row in result["cells"] if row["club"] == "costa_do_sol"]
        self.assertEqual(len(costa), 16)
        self.assertTrue(all(row["status"] == "contract_not_applicable" for row in costa))
        enabled = [row for row in result["cells"] if row["club"] != "costa_do_sol"]
        self.assertTrue(all(row["applicability"] == "applicable" for row in enabled))
        self.assertEqual(result["counts"]["assertions_missing"], 63)

    def test_native_registration_rejects_product_claim_for_unregistered_club(self):
        self.add_native_registration()
        self.claim["club"] = "costa_do_sol"
        self.events[1]["message"] = json.dumps(self.claim)
        self.save()
        self.reject("concrete N/A")

    def test_native_registration_cannot_hide_missing_club_or_feature_identity(self):
        self.add_native_registration()
        route = json.loads(self.contracts.read_text())["routes"][0]
        for mutation, reason in [(lambda r: r["native_registration"].pop("vitalo"), "every declared club"),
                                 (lambda r: r["native_registration"]["nkana"].update(feature_key="shop"), "identity drift"),
                                 (lambda r: r["native_registration"]["nkana"].update(registered="false"), "not boolean"),
                                 (lambda r: r["native_registration"]["nkana"].update(rationale=""), "concrete source rationale")]:
            altered = copy.deepcopy(route)
            mutation(altered)
            with self.subTest(reason=reason), self.assertRaisesRegex(ValueError, reason):
                coverage.effective_contract(altered, "dark", "nkana")

    def test_native_registration_cannot_waive_web_or_drift_from_inventory(self):
        self.add_native_registration()
        data = json.loads(self.contracts.read_text())
        data["routes"][0]["native_registration"]["nkana"]["registered"] = False
        self.contracts.write_text(json.dumps(data))
        self.save()
        self.reject("drifted from discovered")
        route = data["routes"][0]
        route["surface"] = "consumer_web"
        with self.assertRaisesRegex(ValueError, "non-native"):
            coverage.effective_contract(route, "dark", "nkana")

    def test_native_registration_requires_both_internal_admin_gates_and_consumer_preservation(self):
        self.add_native_registration()
        route = json.loads(self.contracts.read_text())["routes"][0]
        for flag in ["allow_internal_mobile_admin", "mobile_admin", "consumer_capabilities_preserved"]:
            altered = copy.deepcopy(route)
            altered["native_registration"]["nkana"][flag] = False
            with self.subTest(flag=flag), self.assertRaisesRegex(ValueError, "explicit controlled internal-admin profile"):
                coverage.effective_contract(altered, "dark", "nkana")

    def test_runner_executes_from_declared_workspace_directory_and_records_it(self):
        directory = self.root / "web"
        directory.mkdir()
        args = SimpleNamespace(root=str(self.root), cwd="web", source=["fixture.dart"],
            log="actual-run.jsonl", receipt="actual-run.receipt.json", artifact=[],
            framework="flutter-json", command=["unit-fixture"])
        def execute(command, **options):
            self.assertEqual(options["cwd"], directory)
            options["stdout"].write(("\n".join(json.dumps(e) for e in self.events) + "\n").encode())
            return SimpleNamespace(returncode=0)
        with patch.object(coverage.subprocess, "run", side_effect=execute), contextlib.redirect_stdout(io.StringIO()):
            coverage.run_execution(args)
        record = json.loads((self.root / args.receipt).read_text())
        self.assertEqual(record["working_directory"], "web")

    def test_runner_refuses_external_traversing_or_symlink_working_directory(self):
        (self.root / "web").mkdir()
        (self.root / "link").symlink_to(self.root / "web", target_is_directory=True)
        for cwd in ["/tmp", "web/../web", "link"]:
            args = SimpleNamespace(root=str(self.root), cwd=cwd)
            with self.subTest(cwd=cwd), patch.object(coverage.subprocess, "run") as execute:
                with self.assertRaises(ValueError):
                    coverage.run_execution(args)
                execute.assert_not_called()

    def test_filename_without_assertion_has_no_coverage(self):
        self.events = [r for r in self.events if r["type"] != "print"]
        self.save()
        result = coverage.coverage_overlay(self.root, self.inventory, self.contracts, [self.receipt])
        self.assertEqual(result["counts"]["assertions_missing"], 80)

    def test_assertions_without_guidelines_leave_accessibility_open(self):
        self.events[1]["message"] = json.dumps({**self.claim, "assertions": ["actual rendered state boundary"]})
        self.save()
        result = coverage.coverage_overlay(self.root, self.inventory, self.contracts, [self.receipt])
        self.assertEqual(result["counts"]["automated_assertions_executed"], 1)
        self.assertEqual(result["counts"]["automated_accessibility_executed"], 0)
        self.assertEqual(result["counts"]["automated_accessibility_missing"], 80)
        self.assertFalse(result["local_automated_accessibility_closure_complete"])
        self.assertFalse(result["local_route_state_and_accessibility_complete"])
        self.assertEqual(result["surface_counts"]["mobile"]["automated_accessibility_missing"], 80)

    def test_visual_source_changes_invalidate_execution(self):
        for name in ("fixture.css", "fixture.svg", "fixture.woff2"):
            (self.root / name).write_bytes(b"fixture input")
        snapshot = coverage.source_snapshot(self.root, ["."])
        self.assertTrue({"fixture.css", "fixture.svg", "fixture.woff2"}.issubset({row["path"] for row in snapshot}))
        for record in snapshot:
            if record["path"] == "fixture.css":
                (self.root / "fixture.css").write_text("changed styles")
                with self.assertRaisesRegex(ValueError, "stale or tampered"):
                    coverage.checked_record(self.root, record)

    def test_http_handlers_keep_response_obligations_without_ui_guidelines(self):
        for path in (self.inventory, self.contracts):
            value = json.loads(path.read_text())
            value["routes"][0]["kind"] = "api_route"
            path.write_text(json.dumps(value))
        self.events[1]["message"] = json.dumps({**self.claim, "kind": "api_route", "assertions": ["finite controlled HTTP response"]})
        self.save()
        result = coverage.coverage_overlay(self.root, self.inventory, self.contracts, [self.receipt])
        self.assertEqual(result["counts"]["assertions_missing"], 79)
        self.assertEqual(result["counts"]["accessibility_not_applicable"], 80)
        self.assertEqual(result["counts"]["automated_accessibility_executed"], 0)
        self.assertFalse(result["local_route_state_and_accessibility_complete"])

    def http_log(self):
        claim = {**self.claim, "surface": "web_api", "kind": "api_route",
                 "assertions": ["finite controlled HTTP response"]}
        return {"format": "africlub-vitest-route-assertions-v1", "reason": "passed",
                "modules": [{"source": str(self.source), "state": "passed"}],
                "unhandledErrors": [], "tests": [{"id": "case-1", "name": "actual handler result",
                    "source": str(self.source), "result": {"state": "passed"},
                    "diagnostic": {"retryCount": 0, "repeatCount": 0, "flaky": False},
                    "assertions": [claim]}]}

    def test_http_claim_is_linked_to_actual_successful_test_and_source(self):
        self.log.write_text("compiler notice\n" + json.dumps(self.http_log()) + "\n")
        claims, counts = coverage.parse_vitest(self.log, self.root)
        self.assertEqual(claims[0]["framework"], "vitest-json")
        self.assertEqual(claims[0]["test_id"], "case-1")
        self.assertEqual(claims[0]["test_source"], "fixture.dart")
        self.assertEqual(counts["passed"], 1)

    def test_consumer_http_callback_receipt_remains_a_response_assertion(self):
        report = self.http_log()
        report['tests'][0]['assertions'][0].update(
            surface='consumer_web', kind='http_route', route='/auth/callback')
        self.log.write_text(json.dumps(report) + '\n')
        claims, counts = coverage.parse_vitest(self.log, self.root)
        self.assertEqual(claims[0]['route'], '/auth/callback')
        self.assertEqual(claims[0]['assertions'], ['finite controlled HTTP response'])
        self.assertEqual(counts['passed'], 1)
        for surface, kind in [('consumer_web', 'next_page'), ('mobile', 'http_route'),
                              ('web_api', 'http_route'), ('consumer_web', 'api_route')]:
            report['tests'][0]['assertions'][0].update(surface=surface, kind=kind)
            self.log.write_text(json.dumps(report) + '\n')
            with self.assertRaisesRegex(ValueError, 'controlled HTTP assertion'):
                coverage.parse_vitest(self.log, self.root)

    def test_explicit_rendered_dimension_proofs_do_not_close_another_state(self):
        claim = {**self.claim, 'state': 'reduced_motion', 'assertions': [
            *self.claim['assertions'], 'actual rendered theme brightness',
            'actual rendered MediaQuery disables animations',
            'shared motion resolver returns zero duration']}
        self.events[1]['message'] = json.dumps(claim)
        self.save()
        result = coverage.coverage_overlay(self.root, self.inventory, self.contracts, [self.receipt])
        evidenced = [row for row in result['cells'] if row['status'] == 'automated_assertions_executed']
        self.assertEqual([(row['state'], row['club']) for row in evidenced], [('reduced_motion', 'nkana')])

    def test_navigation_receipt_never_closes_destination_accessibility(self):
        source_route = {'surface': 'mobile', 'path': '/alias', 'kind': 'redirect'}
        destination = {'surface': 'mobile', 'path': '/destination', 'kind': 'route'}
        self.inventory.write_text(json.dumps({'route_count': 2, 'duplicate_keys': [],
                                               'routes': [source_route, destination]}))
        self.contracts.write_text(json.dumps({'route_count': 2, 'state_catalog': list(coverage.STATES),
            'routes': [{**route, 'states': {state: {'applicability': 'applicable', 'rationale': 'unit contract'}
                                           for state in coverage.STATES}}
                       for route in [source_route, destination]]}))
        claim = {**self.claim, 'route': '/alias', 'kind': 'redirect',
                 'state': 'permission_denied', 'assertions': ['finite controlled navigation outcome']}
        self.events[1]['message'] = json.dumps(claim)
        self.save()
        result = coverage.coverage_overlay(self.root, self.inventory, self.contracts, [self.receipt])
        self.assertEqual(result['counts']['automated_assertions_executed'], 1)
        self.assertEqual(result['counts']['accessibility_not_applicable'], 80)
        self.assertEqual(result['counts']['automated_accessibility_missing'], 80)
        self.assertFalse(result['local_route_state_and_accessibility_complete'])

    def test_navigation_receipt_rejects_rendered_route_substitution(self):
        for kind, surface in [('route', 'mobile'), ('next_page', 'admin_pwa'),
                              ('api_route', 'web_api'), ('redirect', 'consumer_web')]:
            with self.subTest(kind=kind, surface=surface):
                claim = {**self.claim, 'kind': kind, 'surface': surface,
                         'assertions': ['finite controlled navigation outcome']}
                with self.assertRaisesRegex(ValueError, 'navigation-only alias'):
                    coverage.parse_claim(json.dumps(claim))

    def test_navigation_receipt_rejects_visual_or_accessibility_credit(self):
        for assertion in ['actual rendered state boundary', 'text contrast',
                          'axe wcag2a wcag2aa wcag22aa critical and serious',
                          'actual rendered theme brightness']:
            with self.subTest(assertion=assertion):
                claim = {**self.claim, 'kind': 'redirect', 'surface': 'mobile',
                         'assertions': ['finite controlled navigation outcome', assertion]}
                with self.assertRaisesRegex(ValueError, 'cannot claim rendered'):
                    coverage.parse_claim(json.dumps(claim))

    def test_http_runner_failure_or_duplicate_completion_cannot_admit_claims(self):
        for mutate in (
            lambda r: r.update(reason="interrupted"),
            lambda r: r.update(unhandledErrors=[{"message": "runner failure"}]),
            lambda r: r["modules"][0].update(state="failed"),
            lambda r: r["tests"][0]["result"].update(state="skipped"),
            lambda r: r["tests"][0]["result"].update(errors=[{"message": "failed"}]),
            lambda r: r["tests"][0]["diagnostic"].update(retryCount=1),
            lambda r: r["tests"][0]["diagnostic"].update(repeatCount=1),
            lambda r: r["tests"][0]["diagnostic"].update(flaky=True),
            lambda r: r["tests"].append(copy.deepcopy(r["tests"][0])),
            lambda r: r["tests"][0].update(source="/tmp/foreign.test.ts"),
            lambda r: r["tests"][0]["assertions"][0].update(assertions=["actual rendered state boundary"]),
        ):
            with self.subTest(mutate=mutate):
                report = self.http_log()
                mutate(report)
                self.log.write_text(json.dumps(report) + "\n")
                with self.assertRaises(ValueError):
                    coverage.parse_vitest(self.log, self.root)
        self.log.write_text((json.dumps(self.http_log()) + "\n") * 2)
        with self.assertRaisesRegex(ValueError, "repeated Vitest completion"):
            coverage.parse_vitest(self.log, self.root)

    def test_http_execution_rejects_claim_from_unfrozen_test_source(self):
        self.log.write_text(json.dumps(self.http_log()) + "\n")
        self.record["framework"] = "vitest-json"
        self.record["log"] = coverage.file_record(self.root, self.log)
        other = self.root / "other.ts"
        other.write_text("// unrelated parser fixture")
        self.record["sources_before"] = [coverage.file_record(self.root, other)]
        self.record["sources_after"] = copy.deepcopy(self.record["sources_before"])
        self.receipt.write_text(json.dumps(self.record))
        with self.assertRaisesRegex(ValueError, "not frozen"):
            coverage.validate_execution(self.root, self.receipt)

    def browser_log(self):
        directory = self.root / "apps/rayon_sports/web/e2e"
        directory.mkdir(parents=True)
        (directory / "fixture.spec.ts").write_text("// synthetic parser fixture only\n")
        result = {"status": "passed", "retry": 0, "stdout": [{"text": json.dumps(self.claim) + "\n"}]}
        return {"config": {"rootDir": str(directory)}, "stats": {"expected": 1, "unexpected": 0, "flaky": 0, "skipped": 0},
                "errors": [], "suites": [{"specs": [{"file": "fixture.spec.ts", "title": "parser fixture", "id": "case-1", "tests": [
                    {"status": "expected", "projectName": "nkana-desktop-chromium", "results": [result]},
                ]}]}]}

    def test_browser_sources_resolve_against_actual_report_root(self):
        self.log.write_text(json.dumps(self.browser_log()))
        claims, counts = coverage.parse_playwright(self.log, self.root)
        self.assertEqual(claims[0]["test_source"], "apps/rayon_sports/web/e2e/fixture.spec.ts")
        self.assertEqual(counts["passed"], 1)

    def test_browser_report_external_roots_are_rejected(self):
        document = self.browser_log()
        document["config"]["rootDir"] = "/tmp"
        self.log.write_text(json.dumps(document))
        with self.assertRaisesRegex(ValueError, "outside workspace"):
            coverage.parse_playwright(self.log, self.root)

    def test_retried_browser_case_cannot_manufacture_assertion(self):
        document = self.browser_log()
        document["suites"][0]["specs"][0]["tests"][0]["results"][0]["retry"] = 1
        self.log.write_text(json.dumps(document))
        with self.assertRaisesRegex(ValueError, "first attempt"):
            coverage.parse_playwright(self.log, self.root)

    def test_failed_browser_runner_cannot_manufacture_assertion(self):
        document = self.browser_log()
        document["errors"] = [{"message": "runner failure"}]
        self.log.write_text(json.dumps(document))
        with self.assertRaisesRegex(ValueError, "runner errors"):
            coverage.parse_playwright(self.log, self.root)

    def test_failed_suite_rejected(self):
        self.events[-1]["success"] = False
        self.save()
        self.reject("failed or unfinished")

    def test_unfinished_suite_rejected(self):
        self.events.pop()
        self.save()
        self.reject("failed or unfinished")

    def test_skipped_test_rejected(self):
        self.events[-2]["skipped"] = True
        self.save()
        self.reject("skipped")

    def test_failed_test_rejected_despite_spurious_success_end(self):
        self.events[-2]["result"] = "failure"
        self.save()
        self.reject("failed/skipped")

    def test_unassociated_print_rejected(self):
        self.events[1]["testID"] = 99
        self.save()
        self.reject("no actual successful test")

    def test_stale_source_rejected(self):
        self.source.write_text("// changed\n")
        self.reject("stale or tampered")

    def test_stale_log_rejected(self):
        self.log.write_text(self.log.read_text() + "changed\n")
        self.reject("stale or tampered")

    def test_source_change_during_execution_rejected(self):
        self.change_receipt(lambda r: r["sources_after"][0].update(sha256="0" * 64))
        self.reject("changed during")

    def test_source_not_frozen_rejected(self):
        other = self.root / "other.dart"
        other.write_text("// other\n")
        self.events[0]["test"]["root_url"] = other.as_uri()
        self.save()
        self.reject("not frozen")

    def test_unknown_club_and_state_rejected(self):
        for key, value in [("club", "sixth_club"), ("state", "default")]:
            with self.subTest(key=key):
                record = {**self.claim, key: value}
                with self.assertRaisesRegex(ValueError, "unknown state or club"):
                    coverage.parse_claim(json.dumps(record))

    def test_unknown_route_rejected(self):
        self.events[1]["message"] = json.dumps({**self.claim, "route": "/invented"})
        self.save()
        self.reject("not declared")

    def test_arbitrary_acceptance_fields_rejected(self):
        with self.assertRaisesRegex(ValueError, "invalid assertion receipt fields"):
            coverage.parse_claim(json.dumps({**self.claim, "human_accepted": True}))

    def test_empty_or_unknown_assertions_rejected(self):
        for assertions in [[], ["screenshot file exists"], ["text contrast", "text contrast"]]:
            with self.assertRaises(ValueError):
                coverage.parse_claim(json.dumps({**self.claim, "assertions": assertions}))

    def test_no_state_assertion_rejected(self):
        with self.assertRaisesRegex(ValueError, "no actual state assertion"):
            coverage.parse_claim(json.dumps({**self.claim, "assertions": ["text contrast"]}))

    def test_path_traversal_and_external_file_rejected(self):
        for path in ["../fixture.dart", str(self.root / ".." / "fixture.dart"), "/etc/hosts"]:
            with self.assertRaises(ValueError):
                coverage.local_file(self.root, path)

    def test_symlink_rejected(self):
        link = self.root / "linked.dart"
        link.symlink_to(self.source)
        with self.assertRaisesRegex(ValueError, "symlink"):
            coverage.local_file(self.root, str(link))

    def test_identical_repeated_cell_same_test_counts_once(self):
        self.events.insert(2, copy.deepcopy(self.events[1]))
        self.save()
        result = coverage.coverage_overlay(self.root, self.inventory, self.contracts, [self.receipt])
        self.assertEqual(result["counts"]["automated_assertions_executed"], 1)
        self.assertEqual(result["assertion_record_counts"],
                         {"raw": 2, "unique_cell_test_execution": 1, "identical_repeated": 1})
        cell = next(row for row in result["cells"] if row["state"] == "dark" and row["club"] == "nkana")
        self.assertEqual(len(cell["evidence"]), 1)
        repeat = result["identical_repeated_assertions"][0]
        self.assertEqual(repeat["execution_log"], self.record["log"])
        self.assertEqual(repeat["additional_identical_records"], 1)

    def test_differing_assertion_list_or_order_same_test_rejected(self):
        for assertions in [self.claim["assertions"][:-1], list(reversed(self.claim["assertions"]))]:
            with self.subTest(assertions=assertions):
                self.events.insert(2, {**self.events[1], "message": json.dumps({**self.claim, "assertions": assertions})})
                self.save()
                self.reject("conflicting duplicate assertion cell")
                self.events.pop(2)

    def test_differing_duplicate_metadata_or_provenance_rejected(self):
        claims, result = coverage.validate_execution(self.root, self.receipt)
        for key, value in [("test_name", "different actual case"),
                           ("test_source", "other.dart"), ("framework", "vitest-json"),
                           ("execution_log", {"path": "other-log.jsonl", "sha256": "0" * 64})]:
            with self.subTest(key=key), patch.object(coverage, "validate_execution",
                                                    return_value=([claims[0], {**claims[0], key: value}], result)):
                self.reject("conflicting duplicate assertion cell")

    def test_duplicate_execution_receipt_path_rejected(self):
        with self.assertRaisesRegex(ValueError, "duplicate execution receipt path"):
            coverage.coverage_overlay(self.root, self.inventory, self.contracts,
                                      [self.receipt, self.root / "." / self.receipt.name])

    def test_distinct_tests_for_same_cell_preserve_both_observations(self):
        self.events[-1:-1] = [
            {"type": "testStart", "test": {"id": 2, "name": "second actual fixture", "root_url": self.source.as_uri()}},
            {"type": "print", "testID": 2, "message": json.dumps(self.claim)},
            {"type": "testDone", "testID": 2, "result": "success", "skipped": False, "hidden": False},
        ]
        self.save()
        result = coverage.coverage_overlay(self.root, self.inventory, self.contracts, [self.receipt])
        self.assertEqual(result["assertion_record_counts"],
                         {"raw": 2, "unique_cell_test_execution": 2, "identical_repeated": 0})
        self.assertEqual(result["counts"]["automated_assertions_executed"], 1)
        cell = next(row for row in result["cells"] if row["state"] == "dark" and row["club"] == "nkana")
        self.assertEqual(len(cell["evidence"]), 2)

    def test_distinct_receipts_preserve_independent_observations(self):
        second = self.root / "second-receipt.json"
        second.write_bytes(self.receipt.read_bytes())
        result = coverage.coverage_overlay(self.root, self.inventory, self.contracts, [self.receipt, second])
        self.assertEqual(result["assertion_record_counts"],
                         {"raw": 2, "unique_cell_test_execution": 2, "identical_repeated": 0})
        self.assertEqual(result["counts"]["automated_assertions_executed"], 1)
        self.assertEqual(len(result["executions"]), 2)

    def test_na_contract_cannot_be_overridden(self):
        c = json.loads(self.contracts.read_text())
        c["routes"][0]["states"]["dark"]["applicability"] = "not_applicable"
        self.contracts.write_text(json.dumps(c))
        self.save()
        self.reject("N/A contract")

    def test_inventory_requires_actual_execution_binding(self):
        self.change_receipt(lambda r: r.update(artifacts=[]))
        self.reject("not produced and bound")

    def test_inventory_and_contract_route_drift_rejected(self):
        r = json.loads(self.inventory.read_text())
        r["routes"][0]["path"] = "/different"
        self.inventory.write_text(json.dumps(r))
        self.save()
        self.reject("identities drifted")

    def test_inventory_tampering_rejected(self):
        self.inventory.write_text(self.inventory.read_text() + "\n")
        self.reject("stale or tampered")


if __name__ == "__main__":
    unittest.main()
