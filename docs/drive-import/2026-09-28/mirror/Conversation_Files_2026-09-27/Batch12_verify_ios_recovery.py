#!/usr/bin/env python3
"""Compile and execute the portable Swift recovery core; never claim iOS acceptance.

No network, SDK installation, user data, Keychain, Flutter, app build or provider call.
A fresh temporary executable is built for each invocation; compiler failure cannot
fall through to a stale executable. Apple-only sources are NOT in this test target.
"""
from __future__ import annotations
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
FEATURE = ROOT / "packages/features/feat_membership/native/ios"

def verify(results: Path) -> int:
    results.mkdir(parents=True, exist_ok=True)
    summary: dict = {"schemaVersion": 1, "swiftExecuted": False,
        "iosHostCompiled": False, "keychainExecuted": False, "flutterCompiled": False,
        "deviceVerified": False, "networkRequests": 0, "releaseReady": False, "steps": []}
    def finish(status: str, reason: str, code: int) -> int:
        summary.update(status=status, reason=reason)
        (results / "ios-recovery-verification.json").write_text(json.dumps(summary, indent=2) + "\n")
        print(json.dumps(summary))
        return code
    compiler = shutil.which("swiftc")
    if compiler is None:
        return finish("blocked", "Swift compiler unavailable", 2)
    try:
        v = subprocess.run([compiler, "--version"], text=True, capture_output=True, timeout=20, check=True)
        summary["compiler"] = (v.stdout + v.stderr).strip()
    except (OSError, subprocess.SubprocessError) as error:
        return finish("blocked", type(error).__name__, 2)
    names = ["RecoveryProtocol.swift", "RecoveryFiles.swift", "RecoveryStore.swift", "RecoveryDispatcher.swift"]
    sources = [FEATURE / "Sources" / name for name in names] + [FEATURE / "Tests/RecoveryHarness.swift"]
    if any(not p.is_file() or p.is_symlink() for p in sources):
        return finish("failed", "Missing or symlinked verification source", 1)
    with tempfile.TemporaryDirectory(prefix="africlub-ios-portable-") as temp:
        binary = Path(temp) / "recovery-harness"
        command = [compiler, "-swift-version", "6", "-warnings-as-errors", *map(str, sources), "-o", str(binary)]
        try:
            compiled = subprocess.run(command, text=True, capture_output=True, timeout=90)
            (results / "swift-compile.log").write_text(compiled.stdout + compiled.stderr)
            summary["steps"].append({"name": "portable_compile", "exitCode": compiled.returncode})
            if compiled.returncode:
                return finish("failed", "Portable Swift compilation failed", 1)
            executed = subprocess.run([str(binary)], text=True, capture_output=True, timeout=45)
            (results / "swift-tests.json").write_text(executed.stdout)
            (results / "swift-tests.stderr.log").write_text(executed.stderr)
            summary["steps"].append({"name": "portable_tests", "exitCode": executed.returncode})
            summary["swiftExecuted"] = True
            if executed.returncode:
                return finish("failed", "Portable recovery tests failed", 1)
            data = json.loads(executed.stdout)
            tests = data["tests"]
            if data["failed"] != 0 or not tests or any(t.get("passed") is not True for t in tests) or data["passed"] != len(tests):
                return finish("failed", "Inconsistent harness summary", 1)
            summary["portableTestsPassed"] = len(tests)
        except (OSError, subprocess.SubprocessError, json.JSONDecodeError, KeyError, TypeError) as error:
            return finish("failed", type(error).__name__, 1)
    return finish("passed_portable_only", "Apple Keychain, iOS host, Dart/Flutter and device checks remain required", 0)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--results", type=Path, required=True)
    args = parser.parse_args()
    sys.exit(verify(args.results.resolve()))
