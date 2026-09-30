#!/usr/bin/env python3
"""Verify dedicated native credential cores in fresh synthetic temporary targets.

No network, real Keychain/Keystore execution, device mutation, signing or deploy.
Optional SDK arguments typecheck actual host sources; they do not prove OS policy.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / "packages/core/core_auth/native"
CLUBS = ["rayon_sports", "as_vita", "vitalo", "nkana", "costa_do_sol"]


def check_registrations(root: Path, swift_sources: list[Path]) -> list[Path]:
    paths = []
    for club in CLUBS:
        app = root / "apps" / club
        activities = list((app / "android/app/src/main/kotlin").rglob("MainActivity.kt"))
        if len(activities) != 1:
            raise RuntimeError("Native credential Android registration is missing or ambiguous")
        activity = activities[0]
        gradle = app / "android/app/build.gradle.kts"
        delegate = app / "ios/Runner/AppDelegate.swift"
        project = app / "ios/Runner.xcodeproj/project.pbxproj"
        selected = [activity, gradle, delegate, project]
        if any(p.is_symlink() or not p.is_file() for p in selected):
            raise RuntimeError("Missing or symlinked native credential registration source")
        if not re.search(r"NativeIdentityCredentialPlugin\(\s*enabled\s*=\s*false\s*,\s*approvedScopes\s*=\s*emptySet\(\)\s*\)", activity.read_text()) or \
                '"../../../../packages/core/core_auth/native/android/identity_credentials/src/main/kotlin"' not in gradle.read_text():
            raise RuntimeError("Android credential registration does not preserve disabled empty scopes or source path")
        if not re.search(r"IOSNativeCredentialRegistration\(\s*messenger: registrar\.messenger\(\),\s*enabled: false,\s*approvedScopes: \[\]\s*\)", delegate.read_text()) or \
                "nativeCredentialRegistration?.dispose()" not in delegate.read_text():
            raise RuntimeError("iOS credential registration does not preserve disabled empty scopes or previous-owner disposal")
        content = project.read_text()
        for source in swift_sources:
            reference = f'path = "../../../packages/core/core_auth/native/ios/IdentityCredentials/Sources/{source.name}"; sourceTree = SOURCE_ROOT;'
            if content.count(reference) != 1 or content.count(f"/* {source.name} in Sources */") != 2:
                raise RuntimeError("iOS credential source is missing, duplicated or absent from app compilation")
        paths.extend(selected)
    return paths


def verify(args: argparse.Namespace) -> int:
    results = args.results.resolve()
    results.mkdir(parents=True, exist_ok=True)
    report = {"schemaVersion": 1, "networkRequests": 0, "keychainExecuted": False,
              "keystoreExecuted": False, "physicalDeviceAccepted": False,
              "releaseReady": False, "androidHostCompiled": False,
              "iosHostTypechecked": False, "steps": [], "sourceHashes": {}}

    def finish(status: str, code: int) -> int:
        report["status"] = status
        (results / "native-identity-credential-verification.json").write_text(
            json.dumps(report, indent=2) + "\n")
        print(json.dumps(report, indent=2))
        return code

    def run(name: str, command: list[str], timeout: int = 120) -> str:
        started = time.monotonic()
        timed_out = False
        try:
            p = subprocess.run(command, capture_output=True, text=True, timeout=timeout)
            output, code = p.stdout + p.stderr, p.returncode
        except subprocess.TimeoutExpired as error:
            def decoded(value):
                return value.decode("utf-8", errors="replace") if isinstance(value, bytes) else value or ""
            output, code = decoded(error.stdout) + decoded(error.stderr), None
            timed_out = True
        log = results / (name + ".log")
        log.write_text(output)
        report["steps"].append({"name": name, "command": command,
                                "exitCode": code, "timedOut": timed_out,
                                "elapsedSeconds": round(time.monotonic() - started, 3),
                                "logSha256": hashlib.sha256(log.read_bytes()).hexdigest()})
        if timed_out or code != 0:
            raise RuntimeError(name + (" timed out" if timed_out else " failed"))
        return output

    if bool(args.ios_sdk) != bool(args.flutter_framework):
        report["reason"] = "iOS SDK and Flutter framework must be supplied together"
        return finish("failed", 1)

    android = BASE / "android/identity_credentials"
    ios = BASE / "ios/IdentityCredentials"
    af = android / "src/main/kotlin/com/africlub/identity"
    sf = ios / "Sources"
    for folder in [android, ios]:
        for p in sorted(folder.rglob("*")):
            if p.is_symlink():
                report["reason"] = "Symlinked verification source"
                return finish("failed", 1)
            if p.is_file():
                report["sourceHashes"][str(p.relative_to(ROOT))] = hashlib.sha256(p.read_bytes()).hexdigest()
    checkout = ROOT / "packages/features/feat_membership/native/ios"
    for source in [*sorted((checkout / "Sources").glob("*.swift")), checkout / "Tests/KeychainRecoveryQueryHarness.swift"]:
        if source.is_symlink() or not source.is_file():
            report["reason"] = "Missing or symlinked checkout query verification source"
            return finish("failed", 1)
        report["sourceHashes"][str(source.relative_to(ROOT))] = hashlib.sha256(source.read_bytes()).hexdigest()
    kernel = [af / (name + ".kt") for name in
              ["CredentialProtocol", "EncryptedCredentialFile", "CredentialStore", "CredentialDispatcher", "CredentialQueueAdmission"]]
    portable = [sf / (name + ".swift") for name in
                ["CredentialProtocol", "CredentialFiles", "CredentialStore", "CredentialDispatcher", "CredentialHostGate"]]
    try:
        for source in check_registrations(ROOT, sorted(sf.glob("*.swift"))):
            report["sourceHashes"][str(source.relative_to(ROOT))] = hashlib.sha256(source.read_bytes()).hexdigest()
        report["disabledAppRegistrationsChecked"] = len(CLUBS) * 2
        android_contract = json.loads((android / "contracts/credential-channel.json").read_text())
        ios_contract = json.loads((ios / "contracts/credential-channel.json").read_text())
        methods = {"describe": ["scope"], "tryAcquire": ["scope", "acquisitionId"],
                   "read": ["scope", "lease"], "compareAndSet": ["scope", "lease", "expected", "value"],
                   "drain": ["scope", "acquisitionId"], "release": ["scope", "acquisitionId"]}
        if android_contract != ios_contract or android_contract.get("schemaVersion") != 1 or \
                isinstance(android_contract.get("schemaVersion"), bool) or \
                android_contract.get("defaultEnabled") is not False or android_contract.get("approvedScopes") != [] or \
                android_contract.get("channel") != "africlub/native-identity-credentials/v1" or \
                android_contract.get("maxJournalUtf8Bytes") != 8192 or android_contract.get("maxScopes") != 64 or \
                android_contract.get("maxSnapshotBytes") != 600000 or android_contract.get("methods") != methods:
            raise RuntimeError("Native credential contracts differ or authorize unsupported defaults")
        report["channelContractsMatched"] = True
        if args.configuration_only:
            report["reason"] = "Disabled registration and channel-source configuration only; no compilation or storage execution"
            return finish("passed_configuration_checks_only", 0)
        kotlin = args.kotlinc or shutil.which("kotlinc")
        java = shutil.which("java")
        swift = shutil.which("swiftc")
        if not kotlin or not java or not swift:
            report["reason"] = "kotlinc, java and swiftc required; no missing tool counts as pass"
            return finish("blocked", 2)
        report["kotlinVersion"] = run("kotlin-version", [kotlin, "-version"], 30).strip()
        report["swiftVersion"] = run("swift-version", [swift, "--version"], 30).strip()
        with tempfile.TemporaryDirectory(prefix="africlub-identity-credentials-") as temp:
            jar = Path(temp) / "credentials.jar"
            binary = Path(temp) / "credentials-swift"
            runtime = [] if args.kotlin_runtime_classpath else ["-include-runtime"]
            run("kotlin-portable-compile", [kotlin, *map(str, kernel),
                str(android / "tests/CredentialContractHarness.kt"), "-Werror",
                *runtime, "-d", str(jar)])
            launch = ([java, "-cp", str(jar) + ":" + args.kotlin_runtime_classpath,
                "com.africlub.identity.CredentialContractHarnessKt"] if args.kotlin_runtime_classpath else [java, "-jar", str(jar)])
            output = run("kotlin-portable-tests", launch)
            passed = len(re.findall(r"^PASS ", output, re.M))
            summary = re.findall(r"^SUMMARY passed=(\d+) failed=0 skipped=0$", output, re.M)
            if len(summary) != 1 or not passed or int(summary[0]) != passed:
                raise RuntimeError("Incomplete Kotlin result")
            report["portableKotlinPassed"] = passed
            run("swift-portable-compile", [swift, "-swift-version", "6", "-warnings-as-errors",
                *map(str, portable), str(ios / "Tests/CredentialHarness.swift"), "-o", str(binary)])
            data = json.loads(run("swift-portable-tests", [str(binary)]))
            if data["failed"] or not data["tests"] or data["passed"] != len(data["tests"]) or any(
                    t["passed"] is not True for t in data["tests"]):
                raise RuntimeError("Incomplete Swift result")
            report["portableSwiftPassed"] = data["passed"]
            if sys.platform == "darwin":
                query_binary = Path(temp) / "keychain-query"
                run("swift-security-query-compile", [swift, "-swift-version", "6", "-warnings-as-errors",
                    *map(str, portable), str(sf / "KeychainCredentialBlob.swift"),
                    str(ios / "Tests/KeychainQueryHarness.swift"), "-o", str(query_binary)])
                queries = json.loads(run("swift-security-query-tests", [str(query_binary)]))
                if queries["failed"] or not queries["tests"] or queries["passed"] != len(queries["tests"]) or any(
                        t["passed"] is not True for t in queries["tests"]) or queries["keychainExecuted"] is not False:
                    raise RuntimeError("Incomplete synthetic Keychain query result")
                report["syntheticSecurityQueryPassed"] = queries["passed"]
                checkout_binary = Path(temp) / "checkout-keychain-query"
                run("swift-checkout-query-compile", [swift, "-swift-version", "6", "-warnings-as-errors",
                    *map(str, sorted((checkout / "Sources").glob("*.swift"))),
                    str(checkout / "Tests/KeychainRecoveryQueryHarness.swift"), "-o", str(checkout_binary)])
                queries = json.loads(run("swift-checkout-query-tests", [str(checkout_binary)]))
                if queries["failed"] or not queries["tests"] or queries["passed"] != len(queries["tests"]) or any(
                        t["passed"] is not True for t in queries["tests"]) or queries["keychainExecuted"] is not False:
                    raise RuntimeError("Incomplete synthetic checkout Keychain query result")
                report["syntheticCheckoutSecurityQueryPassed"] = queries["passed"]
            else:
                report["syntheticSecurityQueryPassed"] = None
                report["syntheticSecurityQueryReason"] = "Apple Security/LocalAuthentication unavailable on this host"
            if args.android_classpath:
                run("android-sdk-compile", [kotlin, *map(str, sorted(af.glob("*.kt"))),
                    "-classpath", args.android_classpath, "-Werror", "-d", str(Path(temp) / "android.jar")])
                report["androidHostCompiled"] = True
            if args.ios_sdk and args.flutter_framework:
                run("ios-sdk-typecheck", [swift, "-typecheck", "-parse-as-library", "-swift-version", "6",
                    "-warnings-as-errors", "-target", "arm64-apple-ios15.5-simulator", "-sdk", args.ios_sdk,
                    "-F", args.flutter_framework, *map(str, sorted(sf.glob("*.swift")))])
                report["iosHostTypechecked"] = True
                for club in CLUBS:
                    app = ROOT / "apps" / club / "ios"
                    run("ios-project-" + club, ["plutil", "-lint", str(app / "Runner.xcodeproj/project.pbxproj")])
                    recovery = ROOT / "packages/features/feat_membership/native/ios/Sources"
                    run("ios-registration-" + club, [swift, "-typecheck", "-parse-as-library", "-swift-version", "6",
                        "-warnings-as-errors", "-target", "arm64-apple-ios15.5-simulator", "-sdk", args.ios_sdk,
                        "-F", args.flutter_framework, "-import-objc-header", str(app / "Runner/GeneratedPluginRegistrant.h"),
                        *map(str, sorted(sf.glob("*.swift"))), *map(str, sorted(recovery.glob("*.swift"))),
                        str(app / "Runner/AppDelegate.swift")])
                report["iosAppRegistrationsTypechecked"] = 5
    except (OSError, subprocess.SubprocessError, RuntimeError, ValueError, KeyError, TypeError) as error:
        report["reason"] = type(error).__name__ + ": " + str(error)
        return finish("failed", 1)
    for relative, expected in report["sourceHashes"].items():
        path = ROOT / relative
        if path.is_symlink() or not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != expected:
            report["reason"] = "Verification source changed during execution"
            return finish("failed", 1)
    report["reason"] = "Synthetic core checks only; actual storage, no-backup, lifecycle and device acceptance remain open"
    return finish("passed_local_checks_only", 0)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--results", type=Path, required=True)
    parser.add_argument("--configuration-only", action="store_true", help="Check disabled source registration only; never reports a compile/test pass")
    parser.add_argument("--kotlinc")
    parser.add_argument("--kotlin-runtime-classpath", help="Optional cached runtime for embeddable compiler; never downloaded")
    parser.add_argument("--android-classpath")
    parser.add_argument("--ios-sdk")
    parser.add_argument("--flutter-framework")
    sys.exit(verify(parser.parse_args()))
