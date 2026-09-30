#!/usr/bin/env python3
"""Fail-closed verifier regressions with synthetic subprocess results only."""
import argparse
import contextlib
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
import shutil
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("credential_verifier", Path(__file__).with_name("verify_native_identity_credentials.py"))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class CredentialVerifierTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="africlub-verifier-fixture-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.base = self.root / "packages/core/core_auth/native"
        self.android = self.base / "android/identity_credentials"
        self.ios = self.base / "ios/IdentityCredentials"
        original = module.BASE / "android/identity_credentials/contracts/credential-channel.json"
        for folder in [self.android, self.ios]:
            (folder / "contracts").mkdir(parents=True)
            (folder / "contracts/credential-channel.json").write_bytes(original.read_bytes())
        source = self.android / "src/main/kotlin/com/africlub/identity/CredentialProtocol.kt"
        source.parent.mkdir(parents=True); source.write_text("synthetic source\n")
        self.source = source
        checkout = self.root / "packages/features/feat_membership/native/ios"
        (checkout / "Sources").mkdir(parents=True)
        (checkout / "Sources/KeychainRecoveryBlob.swift").write_text("synthetic checkout Swift source\n")
        (checkout / "Tests").mkdir()
        (checkout / "Tests/KeychainRecoveryQueryHarness.swift").write_text("synthetic checkout harness\n")
        for original in (module.BASE / "ios/IdentityCredentials/Sources").glob("*.swift"):
            destination = self.ios / "Sources" / original.name
            destination.parent.mkdir(parents=True, exist_ok=True); destination.write_text("synthetic Swift source\n")
        for club in module.CLUBS:
            app = module.ROOT / "apps" / club
            paths = [*list((app / "android/app/src/main/kotlin").rglob("MainActivity.kt")),
                app / "android/app/build.gradle.kts", app / "ios/Runner/AppDelegate.swift",
                app / "ios/Runner.xcodeproj/project.pbxproj"]
            for original in paths:
                destination = self.root / original.relative_to(module.ROOT)
                destination.parent.mkdir(parents=True, exist_ok=True); shutil.copyfile(original, destination)
        self.args = argparse.Namespace(results=self.root / "results", kotlinc="synthetic-kotlinc",
            kotlin_runtime_classpath=None, android_classpath=None, ios_sdk=None, flutter_framework=None, configuration_only=False)
        self.commands = []
        self.effect = None

    def fake_run(self, command, **kwargs):
        self.commands.append(command)
        if self.effect:
            effect = self.effect(command)
            if effect is not None: return effect
        if "-version" in command or "--version" in command:
            output = "synthetic tool version\n"
        elif "-jar" in command or "com.africlub.identity.CredentialContractHarnessKt" in command:
            output = "PASS binding\nPASS lock\nSUMMARY passed=2 failed=0 skipped=0\n"
        elif Path(command[0]).name in {"credentials-swift", "keychain-query", "checkout-keychain-query"}:
            output = json.dumps({"passed": 2, "failed": 0, "tests": [{"passed": True}, {"passed": True}], "keychainExecuted": False})
        else: output = ""
        return subprocess.CompletedProcess(command, 0, stdout=output, stderr="")

    def verify(self, *, which=lambda name: "/synthetic/" + name):
        with patch.object(module, "ROOT", self.root), patch.object(module, "BASE", self.base), \
             patch.object(module.shutil, "which", side_effect=which), \
             patch.object(module.subprocess, "run", side_effect=self.fake_run), \
             patch.object(module.sys, "platform", "darwin"), contextlib.redirect_stdout(io.StringIO()):
            code = module.verify(self.args)
        report = json.loads((self.args.results / "native-identity-credential-verification.json").read_text())
        return code, report

    def test_missing_tool_never_counts_as_pass(self):
        code, report = self.verify(which=lambda name: None if name == "java" else "/synthetic/" + name)
        self.assertEqual(code, 2); self.assertEqual(report["status"], "blocked"); self.assertEqual(self.commands, [])

    def test_unpaired_ios_inputs_rejected_before_execution(self):
        self.args.ios_sdk = "/synthetic/sdk"
        code, report = self.verify()
        self.assertEqual(code, 1); self.assertEqual(report["steps"], [])

    def test_contract_disagreement_fails_before_compile(self):
        path = self.ios / "contracts/credential-channel.json"
        value = json.loads(path.read_text()); value["approvedScopes"] = ["unauthorized"]
        path.write_text(json.dumps(value))
        code, report = self.verify()
        self.assertEqual(code, 1); self.assertEqual(report["steps"], [])

    def test_enabled_host_registration_fails_before_compile(self):
        path = next((self.root / "apps/rayon_sports/android/app/src/main/kotlin").rglob("MainActivity.kt"))
        path.write_text(path.read_text().replace("NativeIdentityCredentialPlugin(enabled = false", "NativeIdentityCredentialPlugin(enabled = true"))
        code, report = self.verify(); self.assertEqual(code, 1); self.assertEqual(report["steps"], [])

    def test_missing_build_source_path_fails_before_compile(self):
        path = self.root / "apps/nkana/android/app/build.gradle.kts"
        path.write_text(path.read_text().replace("core_auth/native/android/identity_credentials", "unapproved"))
        code, report = self.verify(); self.assertEqual(code, 1); self.assertEqual(report["steps"], [])

    def test_missing_xcode_compilation_reference_fails_before_compile(self):
        path = self.root / "apps/costa_do_sol/ios/Runner.xcodeproj/project.pbxproj"
        path.write_text(path.read_text().replace("/* CredentialHostGate.swift in Sources */", "/* Missing.swift in Sources */", 1))
        code, report = self.verify(); self.assertEqual(code, 1); self.assertEqual(report["steps"], [])

    def test_bool_contract_version_is_not_numeric_version(self):
        for folder in [self.android, self.ios]:
            path = folder / "contracts/credential-channel.json"
            value = json.loads(path.read_text()); value["schemaVersion"] = True; path.write_text(json.dumps(value))
        code, _ = self.verify(); self.assertEqual(code, 1)

    def test_symlink_source_fails_closed(self):
        (self.android / "source-alias.kt").symlink_to(self.source)
        code, report = self.verify(); self.assertEqual(code, 1); self.assertEqual(report["steps"], [])

    def test_incomplete_kotlin_summary_rejected(self):
        self.effect = lambda c: subprocess.CompletedProcess(c, 0, "PASS one\nSUMMARY passed=2 failed=0 skipped=0\n", "") if "-jar" in c else None
        code, report = self.verify(); self.assertEqual(code, 1); self.assertNotIn("portableKotlinPassed", report)

    def test_swift_failed_test_cannot_be_hidden_by_exit_zero(self):
        self.effect = lambda c: subprocess.CompletedProcess(c, 0, json.dumps({"passed": 1, "failed": 0, "tests": [{"passed": False}]}), "") if Path(c[0]).name == "credentials-swift" else None
        code, report = self.verify(); self.assertEqual(code, 1); self.assertNotIn("portableSwiftPassed", report)

    def test_timeout_is_retained_as_failed_execution_with_partial_log(self):
        def effect(command):
            if "-Werror" in command: raise subprocess.TimeoutExpired(command, 120, output=b"partial compiler output", stderr=b"timeout")
        self.effect = effect
        code, report = self.verify(); self.assertEqual(code, 1)
        step = report["steps"][-1]; self.assertTrue(step["timedOut"]); self.assertIsNone(step["exitCode"])
        self.assertIn("partial compiler output", (self.args.results / (step["name"] + ".log")).read_text())

    def test_optional_cached_runtime_does_not_require_jar_repacking(self):
        self.args.kotlin_runtime_classpath = "/synthetic/cached-runtime.jar"
        code, report = self.verify(); self.assertEqual(code, 0)
        compile_command = next(c for c in self.commands if "-Werror" in c)
        self.assertNotIn("-include-runtime", compile_command)
        command = next(c for c in self.commands if "com.africlub.identity.CredentialContractHarnessKt" in c)
        self.assertIn("-cp", command); self.assertIn(self.args.kotlin_runtime_classpath, command[2])
        self.assertFalse(report["physicalDeviceAccepted"]); self.assertFalse(report["releaseReady"])

    def test_source_mutation_during_execution_invalidates_success(self):
        def effect(command):
            if "-Werror" in command: self.source.write_text("changed synthetic source\n")
        self.effect = effect
        code, report = self.verify(); self.assertEqual(code, 1); self.assertIn("changed", report["reason"])

    def test_requested_ios_sources_and_all_five_app_registrations_typechecked(self):
        self.args.ios_sdk = "/synthetic/sdk"; self.args.flutter_framework = "/synthetic/engine"
        code, report = self.verify(); self.assertEqual(code, 0)
        self.assertEqual(report["iosAppRegistrationsTypechecked"], 5)
        apps = [c for c in self.commands if any(str(arg).endswith("AppDelegate.swift") for arg in c)]
        self.assertEqual(len(apps), 5)
        self.assertTrue(all("-import-objc-header" in c and "-warnings-as-errors" in c for c in apps))
        self.assertFalse(report["keychainExecuted"]); self.assertFalse(report["keystoreExecuted"])

    def test_configuration_only_does_not_require_tools_or_claim_test_execution(self):
        self.args.configuration_only = True
        code, report = self.verify(which=lambda name: None)
        self.assertEqual(code, 0); self.assertEqual(report["status"], "passed_configuration_checks_only")
        self.assertEqual(report["disabledAppRegistrationsChecked"], 10); self.assertEqual(report["steps"], [])
        self.assertFalse(report["iosHostTypechecked"]); self.assertFalse(report["androidHostCompiled"])
        self.assertNotIn("portableKotlinPassed", report)


if __name__ == "__main__": unittest.main()
