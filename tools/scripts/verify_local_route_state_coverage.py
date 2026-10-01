#!/usr/bin/env python3
"""Execute and verify current automated route assertions without review claims.

Discovery, an asserted local fixture, an automated accessibility check, a visual
comparison and governed human acceptance are separate evidence dimensions.
This overlay never modifies the governance evidence registry.
"""
from __future__ import annotations

import argparse
import collections
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
from urllib.parse import unquote, urlparse

CLUBS = ("as_vita", "costa_do_sol", "nkana", "rayon_sports", "vitalo")
STATES = ("loading", "empty", "error", "offline", "permission_denied", "disabled",
          "focused", "pressed", "selected", "large_text", "reduced_motion", "dark",
          "light", "syncing", "conflict", "security_timeout")
GUIDELINES = {"android tap targets", "ios tap targets", "tap target labels", "text contrast"}
WEB_GUIDELINES = {"axe wcag2a wcag2aa wcag22aa critical and serious"}
ASSERTIONS = GUIDELINES | WEB_GUIDELINES | {
    "state-specific visible title", "sanitized private destination",
    "selected semantics matches state", "no uncaught render exception",
    "motion disabled", "keyboard focus", "held press scale",
    "existing controlled state preparation and behavioral checks",
    "actual rendered state boundary", "club identity", "no horizontal overflow",
    "reduced motion preference", "200 percent text", "focused control",
    "held pointer active control", "finite controlled HTTP response",
    "actual rendered theme brightness",
    "actual rendered MediaQuery disables animations",
    "shared motion resolver returns zero duration",
    "finite controlled navigation outcome",
}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def local_file(root: Path, name: str) -> Path:
    require(isinstance(name, str) and name and "\0" not in name, "invalid path")
    candidate = Path(name)
    require(".." not in candidate.parts, "path traversal")
    if not candidate.is_absolute():
        require(".." not in candidate.parts, "path traversal")
        candidate = root / candidate
    require(candidate.is_relative_to(root), "path outside workspace")
    cursor = candidate
    while cursor != root:
        require(not cursor.is_symlink(), "symlink evidence path")
        cursor = cursor.parent
    require(candidate.is_file(), "missing regular evidence file")
    return candidate


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def file_record(root: Path, path: Path) -> dict:
    path = local_file(root, str(path))
    return {"path": str(path.relative_to(root)), "sha256": digest(path)}


def checked_record(root: Path, record: dict) -> Path:
    require(set(record) == {"path", "sha256"}, "invalid file record")
    path = local_file(root, record["path"])
    require(digest(path) == record["sha256"], "stale or tampered file: " + record["path"])
    return path


def source_snapshot(root: Path, prefixes: list[str]) -> list[dict]:
    sources = set()
    for prefix in prefixes:
        base = root / prefix
        require(base.exists() and base.is_relative_to(root), "invalid source scope")
        if base.is_file():
            sources.add(base)
        else:
            for path in base.rglob("*"):
                parts = path.relative_to(root).parts
                if any(parts[index:index + 2] == ("test", "failures")
                       for index in range(len(parts) - 1)):
                    continue  # generated Flutter comparator output, retained as artifacts
                if any(part in {"node_modules", ".dart_tool", "build", ".next", "goldens", "output"}
                       for part in path.relative_to(base).parts):
                    continue
                if path.is_file() and path.suffix in {
                    ".dart", ".yaml", ".json", ".tsx", ".ts", ".mjs", ".cjs", ".lock",
                    ".css", ".html", ".svg", ".png", ".webp", ".jpg", ".jpeg",
                    ".woff", ".woff2", ".ttf", ".otf",
                }:
                    sources.add(path)
    require(sources, "empty source scope")
    return [file_record(root, path) for path in sorted(sources)]


def parse_claim(message: str) -> dict | None:
    try:
        record = json.loads(message)
    except (json.JSONDecodeError, TypeError):
        return None
    if not isinstance(record, dict) or "localRouteAssertion" not in record:
        return None
    require(set(record) == {"localRouteAssertion", "surface", "route", "kind", "state", "club", "assertions"},
            "invalid assertion receipt fields")
    require(record["localRouteAssertion"] == 1, "unsupported assertion receipt")
    require(record["state"] in STATES and record["club"] in CLUBS, "unknown state or club")
    assertions = record["assertions"]
    require(isinstance(assertions, list) and assertions and len(set(assertions)) == len(assertions),
            "empty or repeated assertions")
    require(set(assertions).issubset(ASSERTIONS), "unknown assertion dimension")
    require("actual rendered state boundary" in assertions or "state-specific visible title" in assertions
            or "finite controlled HTTP response" in assertions
            or "finite controlled navigation outcome" in assertions, "no actual state assertion")
    if "finite controlled navigation outcome" in assertions:
        require(record["kind"] == "redirect" and record["surface"] in {
            "mobile", "mobile_internal_admin", "admin_pwa"},
            "navigation receipt must identify a declared navigation-only alias")
        require(assertions == ["finite controlled navigation outcome"],
                "navigation receipt cannot claim rendered or accessibility dimensions")
    return record


def parse_flutter(path: Path, root: Path) -> tuple[list[dict], dict]:
    tests, endings, claims, suite_end = {}, {}, [], []
    for line in path.read_text().splitlines():
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue  # compiler output is not an assertion receipt
        if event.get("type") == "testStart":
            test = event["test"]
            require(test["id"] not in tests, "repeated test start")
            tests[test["id"]] = test
        elif event.get("type") == "testDone":
            require(event["testID"] not in endings, "repeated test completion")
            endings[event["testID"]] = event
        elif event.get("type") == "done":
            suite_end.append(event)
        elif event.get("type") == "print":
            claim = parse_claim(event.get("message", ""))
            if claim:
                claims.append((event.get("testID"), claim))
    require(len(suite_end) == 1 and suite_end[0].get("success") is True, "failed or unfinished Flutter execution")
    visible = {i for i, t in tests.items() if not endings.get(i, {}).get("hidden")}
    require(visible, "execution has no actual test cases")
    for test_id in visible:
        end = endings.get(test_id, {})
        require(end.get("result") == "success" and end.get("skipped") is False,
                "failed/skipped/unfinished test cannot be evidence")
    result = []
    for test_id, claim in claims:
        require(test_id in visible, "assertion has no actual successful test")
        test = tests[test_id]
        url = urlparse(test.get("root_url") or test.get("url") or "")
        require(url.scheme == "file", "assertion test is not a local file")
        source = local_file(root, unquote(url.path))
        result.append({**claim, "test_name": test["name"], "test_id": test_id,
                       "test_source": str(source.relative_to(root)), "framework": "flutter-json"})
    return result, {"passed": len(visible), "failed": 0, "skipped": 0}


def parse_playwright(path: Path, root: Path) -> tuple[list[dict], dict]:
    document = json.loads(path.read_text())
    report_root = Path(document.get("config", {}).get("rootDir", root / "apps/rayon_sports/web"))
    require(report_root.is_absolute() and report_root.is_relative_to(root), "browser report root outside workspace")
    require(".." not in report_root.parts, "browser report root traversal")
    require(not document.get("errors"), "Playwright runner errors")
    stats = document.get("stats", {})
    require(stats.get("unexpected") == 0 and stats.get("flaky") == 0 and stats.get("skipped") == 0,
            "failed/flaky/skipped browser execution")
    require(stats.get("expected", 0) > 0, "empty browser execution")
    claims = []

    def visit(suites):
        for suite in suites:
            for spec in suite.get("specs", []):
                source = local_file(root, str(report_root / spec["file"]))
                for test in spec["tests"]:
                    results = test.get("results", [])
                    require(test.get("status") == "expected" and len(results) == 1,
                            "retries cannot manufacture browser acceptance")
                    result = results[0]
                    require(result["status"] == "passed" and result.get("retry", 0) == 0,
                            "browser test did not pass on first attempt")
                    for item in result.get("stdout", []):
                        for line in item.get("text", "").splitlines():
                            claim = parse_claim(line)
                            if claim:
                                claims.append({**claim, "test_name": spec["title"],
                                               "test_id": spec["id"], "test_source": str(source.relative_to(root)),
                                               "framework": "playwright-json", "project": test["projectName"]})
            visit(suite.get("suites", []))
    visit(document.get("suites", []))
    return claims, {"passed": stats["expected"], "failed": 0, "skipped": 0}


def parse_vitest(path: Path, root: Path) -> tuple[list[dict], dict]:
    reports = []
    for line in path.read_text().splitlines():
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(event, dict) and event.get("format") == "africlub-vitest-route-assertions-v1":
            reports.append(event)
    require(len(reports) == 1, "missing or repeated Vitest completion")
    report = reports[0]
    require(report.get("reason") == "passed" and report.get("unhandledErrors") == [],
            "failed or interrupted Vitest execution")
    modules = report.get("modules", [])
    tests = report.get("tests", [])
    require(isinstance(modules, list) and modules and isinstance(tests, list) and tests,
            "empty Vitest execution")
    module_sources = set()
    for module in modules:
        source = str(local_file(root, module["source"]).relative_to(root))
        require(source not in module_sources, "repeated Vitest module")
        require(module.get("state") == "passed", "failed/skipped Vitest module")
        module_sources.add(source)
    claims, ids, exercised = [], set(), set()
    for test in tests:
        require(isinstance(test.get("id"), str) and test["id"] not in ids,
                "missing or repeated Vitest test id")
        ids.add(test["id"])
        require(isinstance(test.get("name"), str) and test["name"], "missing Vitest test name")
        source = str(local_file(root, test["source"]).relative_to(root))
        require(source in module_sources, "Vitest test has no successful module")
        exercised.add(source)
        result = test.get("result", {})
        diagnostic = test.get("diagnostic", {})
        require(result.get("state") == "passed" and not result.get("errors"),
                "failed/skipped/unfinished Vitest test")
        require(diagnostic.get("retryCount") == 0 and diagnostic.get("repeatCount") == 0
                and diagnostic.get("flaky") is False, "retried/repeated/flaky Vitest test")
        assertions = test.get("assertions", [])
        require(isinstance(assertions, list), "invalid Vitest assertions")
        for assertion in assertions:
            claim = parse_claim(json.dumps(assertion))
            require(claim is not None and (claim["surface"], claim["kind"]) in {
                        ("web_api", "api_route"), ("consumer_web", "http_route")}
                    and claim["assertions"] == ["finite controlled HTTP response"],
                    "Vitest receipt is not a controlled HTTP assertion")
            claims.append({**claim, "test_name": test["name"], "test_id": test["id"],
                           "test_source": source, "framework": "vitest-json"})
    require(exercised == module_sources, "Vitest module contains no executed tests")
    return claims, {"passed": len(tests), "failed": 0, "skipped": 0}


def validate_execution(root: Path, receipt_path: Path) -> tuple[list[dict], dict]:
    receipt = json.loads(local_file(root, str(receipt_path)).read_text())
    require(receipt.get("schema_version") == 1 and receipt.get("exit_code") == 0, "unsuccessful execution receipt")
    require(receipt.get("sources_before") == receipt.get("sources_after"), "source changed during execution")
    require(receipt.get("sources_before"), "missing source binding")
    require(isinstance(receipt.get("command"), list) and receipt["command"], "missing actual command")
    for record in receipt["sources_before"]:
        checked_record(root, record)
    for record in receipt.get("artifacts", []):
        checked_record(root, record)
    log = checked_record(root, receipt["log"])
    parser = {"flutter-json": parse_flutter, "playwright-json": parse_playwright,
              "vitest-json": parse_vitest}.get(receipt.get("framework"))
    require(parser is not None, "unknown execution framework")
    claims, counts = parser(log, root)
    source_files = {row["path"] for row in receipt["sources_before"]}
    for claim in claims:
        require(claim["test_source"] in source_files, "assertion source was not frozen for execution")
        claim["execution_receipt"] = str(receipt_path.relative_to(root))
        claim["execution_log"] = receipt["log"]
    return claims, {**counts, "receipt": file_record(root, receipt_path), "assertion_count": len(claims)}


def effective_contract(route: dict, state: str, club: str) -> dict:
    contract = route["states"][state]
    registration = route.get("native_registration")
    if registration is None:
        return contract
    require(route["surface"] in {"mobile", "mobile_internal_admin"},
            "native registration cannot waive a non-native route")
    require(set(registration) == set(CLUBS), "native registration requires every declared club")
    feature = route.get("native_feature_key")
    require(isinstance(feature, str) and feature, "missing native feature identity")
    for scope in registration.values():
        require(scope.get("profile") == "declared_controlled_internal_admin" and
                scope.get("allow_internal_mobile_admin") is True and scope.get("mobile_admin") is True and
                scope.get("consumer_capabilities_preserved") is True,
                "native registration lacks the explicit controlled internal-admin profile")
        require(type(scope.get("registered")) is bool, "native registration is not boolean")
        require(scope.get("feature_key") == feature, "native registration feature identity drift")
        require(isinstance(scope.get("rationale"), str) and scope["rationale"].strip(),
                "native registration requires concrete source rationale")
    scope = registration[club]
    if scope["registered"]:
        return contract
    return {"applicability": "not_applicable", "rationale": scope["rationale"]}


def coverage_overlay(root: Path, inventory: Path, closure: Path, receipts: list[Path]) -> dict:
    receipt_paths = [str(local_file(root, str(receipt)).resolve()) for receipt in receipts]
    require(len(receipt_paths) == len(set(receipt_paths)), "duplicate execution receipt path")
    catalog = json.loads(local_file(root, str(inventory)).read_text())
    contracts = json.loads(local_file(root, str(closure)).read_text())
    require(contracts["state_catalog"] == list(STATES), "state catalog drift")
    require(catalog["duplicate_keys"] == [], "duplicate declared routes")
    routes = {(r["surface"], r["path"], r["kind"]): r for r in contracts["routes"]}
    require(len(routes) == catalog["route_count"] == contracts["route_count"], "route inventory mismatch")
    require(set(routes) == {(r["surface"], r["path"], r["kind"]) for r in catalog["routes"]},
            "contract route identities drifted from discovered inventory")
    for discovered in catalog["routes"]:
        route = routes[(discovered["surface"], discovered["path"], discovered["kind"])]
        require(discovered.get("native_registration") == route.get("native_registration") and
                discovered.get("native_feature_key") == route.get("native_feature_key"),
                "native registration drifted from discovered inventory")
    claims, execution = [], []
    for receipt in receipts:
        rows, result = validate_execution(root, receipt)
        claims.extend(rows)
        execution.append(result)
    frozen_artifacts = {r["path"]: r["sha256"] for p in receipts
                        for r in json.loads(p.read_text()).get("artifacts", [])}
    for path in (inventory, closure):
        relative = str(path.relative_to(root))
        require(frozen_artifacts.get(relative) == digest(path), "inventory was not produced and bound by a current execution")
    indexed = collections.defaultdict(list)
    repeated = {}
    for claim in claims:
        key = (claim["surface"], claim["route"], claim["kind"])
        require(key in routes, "assertion route is not declared: " + str(key))
        state = effective_contract(routes[key], claim["state"], claim["club"])
        require(state["applicability"] == "applicable", "assertion overrides a concrete N/A contract")
        cell = (*key, claim["state"], claim["club"])
        prior = next((x for x in indexed[cell] if x["test_id"] == claim["test_id"] and
                      x["execution_receipt"] == claim["execution_receipt"]), None)
        if prior is not None:
            # A successful interaction test can check the same rendered theme
            # at focus and press. Keep the raw records, but that repeated exact
            # observation supplies one cell/test, never additional coverage.
            require(prior == claim, "conflicting duplicate assertion cell for one test")
            identity = (*cell, claim["test_id"], claim["execution_receipt"])
            if identity not in repeated:
                repeated[identity] = {"cell": list(cell), "test_id": claim["test_id"],
                                      "execution_receipt": claim["execution_receipt"],
                                      "execution_log": claim["execution_log"],
                                      "claim_sha256": hashlib.sha256(json.dumps(claim, sort_keys=True).encode()).hexdigest(),
                                      "additional_identical_records": 0}
            repeated[identity]["additional_identical_records"] += 1
            continue
        indexed[cell].append(claim)
    rows, counts = [], collections.Counter()
    surfaces = collections.defaultdict(collections.Counter)
    for key, route in sorted(routes.items()):
        for state in route["states"]:
            for club in CLUBS:
                contract = effective_contract(route, state, club)
                evidence = indexed.get((*key, state, club), [])
                a11y = any(GUIDELINES.issubset(e["assertions"]) or WEB_GUIDELINES.issubset(e["assertions"])
                           for e in evidence)
                applicable = contract["applicability"] == "applicable"
                # Protocol handlers return HTTP outcomes; they do not render a
                # DOM/semantics tree to which axe or Flutter guidelines apply.
                accessibility_applicable = applicable and key[2] not in {"api_route", "http_route", "redirect"}
                status = "automated_assertions_executed" if evidence else "assertions_missing" if applicable else "contract_not_applicable"
                counts[status] += 1
                counts["automated_accessibility_executed"] += bool(a11y)
                counts["automated_accessibility_missing"] += accessibility_applicable and not a11y
                counts["accessibility_not_applicable"] += not accessibility_applicable
                surfaces[key[0]]["catalog_cells"] += 1
                surfaces[key[0]][status] += 1
                surfaces[key[0]]["automated_accessibility_executed"] += bool(a11y)
                surfaces[key[0]]["automated_accessibility_missing"] += accessibility_applicable and not a11y
                surfaces[key[0]]["accessibility_not_applicable"] += not accessibility_applicable
                rows.append({"surface": key[0], "route": key[1], "kind": key[2], "state": state,
                             "club": club, "applicability": contract["applicability"],
                             "contract_rationale": contract["rationale"], "status": status,
                             "automated_accessibility": "executed" if a11y else "not_exercised" if accessibility_applicable else "contract_not_applicable",
                             "accessibility_applicability": "applicable" if accessibility_applicable else "not_applicable",
                             "accessibility_rationale": "Rendered interactive state requires automated guidelines." if accessibility_applicable else
                                "Navigation-only redirect has no owned DOM/semantics; actual traversal/admission/provider outcomes remain required and destination accessibility remains independent." if applicable and key[2] == "redirect" else
                                "HTTP handler has no rendered DOM or semantics tree; response-state assertions remain required." if applicable else
                                "The route contract declares this state not applicable.",
                             "evidence": evidence})
    return {"schema_version": 1, "scope": "current source local automated fixtures",
            "declared_routes": len(routes), "states": list(STATES), "clubs": list(CLUBS),
            "catalog_cells": len(rows), "counts": dict(counts), "executions": execution,
            "assertion_record_counts": {
                "raw": len(claims), "unique_cell_test_execution": sum(len(values) for values in indexed.values()),
                "identical_repeated": sum(row["additional_identical_records"] for row in repeated.values()),
            },
            "identical_repeated_assertions": list(repeated.values()),
            "surface_counts": {surface: dict(values) for surface, values in sorted(surfaces.items())},
            "inventory": file_record(root, inventory), "contracts": file_record(root, closure),
            "local_assertion_closure_complete": counts["assertions_missing"] == 0,
            "local_automated_accessibility_closure_complete": counts["automated_accessibility_missing"] == 0,
            "local_route_state_and_accessibility_complete":
                counts["assertions_missing"] == 0 and counts["automated_accessibility_missing"] == 0,
            "governance_registry_modified": False, "governed_review_admitted": False,
            "human_screen_reader_or_device_acceptance": False,
            "cells": rows}


def run_execution(args):
    root = Path(args.root).resolve()
    cwd = root / args.cwd
    require(cwd.is_dir() and cwd.is_relative_to(root) and ".." not in cwd.parts,
            "execution working directory outside workspace")
    cursor = cwd
    while cursor != root:
        require(not cursor.is_symlink(), "symlink execution working directory")
        cursor = cursor.parent
    before = source_snapshot(root, args.source)
    log = root / args.log
    receipt_path = root / args.receipt
    log.parent.mkdir(parents=True, exist_ok=True)
    command = args.command[1:] if args.command and args.command[0] == "--" else args.command
    require(command, "missing execution command")
    with log.open("wb") as handle:
        completed = subprocess.run(command, cwd=cwd, stdout=handle, stderr=subprocess.STDOUT, check=False)
    after = source_snapshot(root, args.source)
    receipt = {"schema_version": 1, "framework": args.framework, "command": command,
               "working_directory": str(cwd.relative_to(root)),
               "exit_code": completed.returncode, "sources_before": before, "sources_after": after,
               "log": file_record(root, log),
               "artifacts": [file_record(root, root / name) for name in args.artifact]}
    receipt_path.write_text(json.dumps(receipt, indent=2) + "\n")
    require(completed.returncode == 0, "execution failed; receipt retained")
    validate_execution(root, receipt_path)
    print(json.dumps({"receipt": str(receipt_path), "exit_code": completed.returncode}))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="mode", required=True)
    run = sub.add_parser("run")
    run.add_argument("--root", default=str(Path.cwd()))
    run.add_argument("--cwd", default=".")
    run.add_argument("--framework", choices=["flutter-json", "playwright-json", "vitest-json"], required=True)
    run.add_argument("--source", action="append", required=True)
    run.add_argument("--log", required=True)
    run.add_argument("--receipt", required=True)
    run.add_argument("--artifact", action="append", default=[])
    run.add_argument("command", nargs=argparse.REMAINDER)
    verify = sub.add_parser("verify")
    verify.add_argument("--root", default=str(Path.cwd()))
    verify.add_argument("--inventory", required=True)
    verify.add_argument("--contracts", required=True)
    verify.add_argument("--receipt", action="append", default=[])
    verify.add_argument("--output", required=True)
    args = parser.parse_args()
    if args.mode == "run":
        run_execution(args)
    else:
        root = Path(args.root).resolve()
        output = coverage_overlay(root, root / args.inventory, root / args.contracts,
                                  [root / path for path in args.receipt])
        path = root / args.output
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(output, indent=2) + "\n")
        print(json.dumps({key: value for key, value in output.items() if key != "cells"}))


if __name__ == "__main__":
    try:
        main()
    except (ValueError, KeyError, TypeError, OSError, json.JSONDecodeError) as error:
        print(json.dumps({"status": "rejected", "reason": str(error)}), file=sys.stderr)
        sys.exit(1)
