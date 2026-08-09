from __future__ import annotations

import importlib.util
import json
import subprocess
import sys
import unittest
from pathlib import Path


STORE_DIR = Path(__file__).resolve().parents[1]
SCRIPT = STORE_DIR / "validate_store_package.py"
SPEC = importlib.util.spec_from_file_location("validate_store_package", SCRIPT)
assert SPEC and SPEC.loader
validator = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = validator
SPEC.loader.exec_module(validator)


class StorePackageValidationTest(unittest.TestCase):
    def test_all_packages_are_internally_consistent(self) -> None:
        result = validator.validate(set(validator.ALL_SURFACES))
        self.assertEqual([], result.errors, "\n".join(str(item) for item in result.errors))
        self.assertGreater(len(result.gates), 0)
        self.assertTrue(result.valid(enforce_gates=False))

    def test_release_ready_mode_preserves_truthful_external_gates(self) -> None:
        result = validator.validate(set(validator.ALL_SURFACES), release_ready=True)
        codes = {item.code for item in result.gates}
        self.assertIn("APPROVAL_PENDING", codes)
        self.assertIn("POLICY_BLOCKING", codes)
        self.assertIn("ARTWORK_MISSING", codes)
        self.assertIn("PORTAL_VALUE_PENDING", codes)
        self.assertFalse(result.valid(enforce_gates=True))

    def test_submission_ready_adds_post_upload_portal_gates(self) -> None:
        upload = validator.validate({validator.MOBILE_PLAY}, release_ready=True)
        submission = validator.validate({validator.MOBILE_PLAY}, submission_ready=True)
        upload_portal = [item for item in upload.gates if item.code == "PORTAL_VALUE_PENDING"]
        submission_portal = [item for item in submission.gates if item.code == "PORTAL_VALUE_PENDING"]
        self.assertGreater(len(submission_portal), len(upload_portal))

    def test_only_supported_portal_locales_are_in_upload_trees(self) -> None:
        play_root = validator.MOBILE_DIR / "android" / "fastlane" / "metadata" / "android"
        apple_root = validator.MOBILE_DIR / "ios" / "fastlane" / "metadata"
        play_locales = {path.name for path in play_root.iterdir() if path.is_dir() and any(path.rglob("*.txt"))}
        apple_locales = {path.name for path in apple_root.iterdir() if path.is_dir() and any(path.rglob("*.txt"))}
        self.assertEqual({"en-US", "fr-FR"}, play_locales)
        self.assertEqual({"en-US", "fr-FR"}, apple_locales)
        self.assertTrue((STORE_DIR / "source_localizations" / "rw-RW" / "README.md").is_file())

    def test_json_cli_is_machine_readable(self) -> None:
        completed = subprocess.run(
            [sys.executable, str(SCRIPT), "--surface", "tv-play", "--json"],
            check=False,
            capture_output=True,
            text=True,
        )
        self.assertEqual(0, completed.returncode, completed.stderr)
        payload = json.loads(completed.stdout)
        self.assertEqual(["tv-play"], payload["surfaces"])
        self.assertTrue(payload["valid"])
        self.assertGreater(len(payload["gates"]), 0)


if __name__ == "__main__":
    unittest.main()
