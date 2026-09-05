from __future__ import annotations

import importlib.util
from contextlib import contextmanager
import hashlib
import json
import plistlib
import subprocess
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path
from unittest import mock


STORE_DIR = Path(__file__).resolve().parents[1]
SCRIPT = STORE_DIR / "validate_store_package.py"
SPEC = importlib.util.spec_from_file_location("validate_store_package", SCRIPT)
assert SPEC and SPEC.loader
validator = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = validator
SPEC.loader.exec_module(validator)


@contextmanager
def pending_release_metadata():
    """Exercise missing approvals without depending on the operator's portal file."""
    read_json = validator._read_json

    def read_fixture(path, result):
        data = read_json(path, result)
        if path.name == "approvals.json":
            for item in data.get("approvals", []):
                if item["id"] == "product_scope":
                    item["status"] = "pending"
        elif path.name == "release_package.json":
            data["blocking_items"] = [{"id": "FIXTURE-POLICY", "status": "blocking"}]
        elif path.name == "portal_values.template.json":
            return {"google_play": {}, "app_store_connect": {}}
        elif path.name == "artwork_manifest.json" and path.parent.name == "app_store":
            data["binary_icon_gate"] = {
                "status": "current_source_local_device_build_icon_presence_verified_exact_signed_archive_parity_pending",
                "requirement": "Verify the fixture signed archive",
            }
        return data

    with mock.patch.object(validator, "_read_json", side_effect=read_fixture):
        yield


class StorePackageValidationTest(unittest.TestCase):
    def test_all_packages_are_internally_consistent(self) -> None:
        result = validator.validate(set(validator.ALL_SURFACES))
        self.assertEqual([], result.errors, "\n".join(str(item) for item in result.errors))
        self.assertIsInstance(result.gates, list)
        self.assertTrue(result.valid(enforce_gates=False))

    def test_release_ready_mode_preserves_truthful_external_gates(self) -> None:
        with pending_release_metadata():
            result = validator.validate(set(validator.ALL_SURFACES), release_ready=True)
        codes = {item.code for item in result.gates}
        self.assertIn("APPROVAL_PENDING", codes)
        self.assertIn("POLICY_BLOCKING", codes)
        self.assertNotIn("ARTWORK_MISSING", codes)
        self.assertNotIn("SCREENSHOTS_MISSING", codes)
        self.assertIn("IOS_ICON_GATE", codes)
        self.assertNotIn("ARTWORK_GATE", codes)
        self.assertIn("PORTAL_VALUE_PENDING", codes)
        self.assertFalse(result.valid(enforce_gates=True))

    def test_candidate_disabled_policy_items_are_not_release_gates(self) -> None:
        result = validator.validate(
            {validator.MOBILE_PLAY, validator.APP_STORE},
            release_ready=True,
        )
        policy_messages = [item.message for item in result.gates if item.code == "POLICY_BLOCKING"]
        approval_messages = [item.message for item in result.gates if item.code == "APPROVAL_PENDING"]
        for policy_id in ("POLICY-PAYMENTS-01", "POLICY-REWARDS-01", "POLICY-UGC-01"):
            self.assertFalse(any(policy_id in message for message in policy_messages))
        for approval_id in (
            "payments_and_digital_goods",
            "rewards_contests_and_gambling",
            "ugc_and_moderation",
        ):
            self.assertFalse(any(approval_id in message for message in approval_messages))

    def test_release_artifact_matches_current_package_and_retained_evidence(self) -> None:
        manifest_path = STORE_DIR / "app_store" / "artwork_manifest.json"
        app_store = json.loads(manifest_path.read_text(encoding="utf-8"))
        mobile = json.loads((STORE_DIR / "release_package.json").read_text())["mobile"]
        artifact = app_store["release_artifact"]
        self.assertEqual(mobile["build_number"], artifact["build_number"])
        self.assertEqual(mobile["version_name"], artifact["version_name"])
        self.assertEqual(mobile["ios_bundle_id"], artifact["bundle_id"])
        evidence_path = manifest_path.parent / app_store["local_release_dry_run"]["evidence"]
        self.assertTrue(evidence_path.is_file())
        self.assertIn(artifact["sha256"], evidence_path.read_text())
        self.assertEqual(artifact["sha256"], app_store["local_release_dry_run"]["artifact_sha256"])

    def test_submission_ready_adds_post_upload_portal_gates(self) -> None:
        with pending_release_metadata():
            upload = validator.validate({validator.MOBILE_PLAY}, release_ready=True)
            submission = validator.validate({validator.MOBILE_PLAY}, submission_ready=True)
        upload_portal = [item for item in upload.gates if item.code == "PORTAL_VALUE_PENDING"]
        submission_portal = [item for item in submission.gates if item.code == "PORTAL_VALUE_PENDING"]
        self.assertGreater(len(submission_portal), len(upload_portal))

    def test_submission_portal_proofs_reject_false_and_blocked_states(self) -> None:
        portal = {
            "google_play": {
                "artifact_uploaded": False,
                "artifact_processing_status": "UPLOAD_REJECTED_RESET_PENDING",
                "submission_status": "NOT_YET_SENT_FOR_REVIEW",
            },
            "app_store_connect": {
                "app_privacy_published": False,
                "build_uploaded": True,
                "build_processing_status": "VALID_APP_STORE_ELIGIBLE",
                "submission_status": "READY_FOR_REVIEW_BLOCKED_APP_PRIVACY",
                "verified_receipt": {
                    "version_item_attached_to_review_submission": False,
                    "submit_for_review_completed": False,
                },
            },
        }
        result = validator.ValidationResult()
        with mock.patch.object(validator, "_read_json", return_value=portal):
            validator._check_portal_values(
                Path("portal-values.json"),
                result,
                sections={"google_play", "app_store_connect"},
                keys={name: set(values) for name, values in portal.items()},
                require_submission=True,
            )

        messages = "\n".join(item.message for item in result.gates)
        self.assertIn("google_play.artifact_uploaded must be true", messages)
        self.assertIn("google_play.artifact_processing_status", messages)
        self.assertIn("google_play.submission_status", messages)
        self.assertIn("app_store_connect.app_privacy_published must be true", messages)
        self.assertIn(
            "app_store_connect.verified_receipt.version_item_attached_to_review_submission must be true",
            messages,
        )
        self.assertIn(
            "app_store_connect.verified_receipt.submit_for_review_completed must be true",
            messages,
        )

    def test_submission_portal_proofs_accept_completed_states(self) -> None:
        portal = {
            "google_play": {
                "artifact_uploaded": True,
                "artifact_processing_status": "AVAILABLE_TO_TESTERS",
                "submission_status": "CHANGES_IN_REVIEW",
            },
            "app_store_connect": {
                "app_privacy_published": True,
                "build_uploaded": True,
                "build_processing_status": "VALID_APP_STORE_ELIGIBLE",
                "tax_and_banking_complete_if_required": "NOT_REQUIRED_FREE_CANDIDATE_NO_IAP",
                "submission_status": "WAITING_FOR_REVIEW",
                "verified_receipt": {
                    "version_item_attached_to_review_submission": True,
                    "submit_for_review_completed": True,
                },
            },
        }
        result = validator.ValidationResult()
        with mock.patch.object(validator, "_read_json", return_value=portal):
            validator._check_portal_values(
                Path("portal-values.json"),
                result,
                sections={"google_play", "app_store_connect"},
                keys={name: set(values) for name, values in portal.items()},
                require_submission=True,
            )

        self.assertEqual([], result.gates)

    def test_ios_upload_artifact_is_hash_and_identity_bound(self) -> None:
        with tempfile.TemporaryDirectory() as temp_directory:
            root = Path(temp_directory)
            manifest_path = root / "store_metadata" / "app_store" / "artwork_manifest.json"
            ipa_path = root / "build" / "ios" / "ipa" / "Gikundiro.ipa"
            ipa_path.parent.mkdir(parents=True)
            manifest_path.parent.mkdir(parents=True)
            info = {
                "CFBundleIdentifier": "rw.ikanisa.rayonSports",
                "CFBundleShortVersionString": "1.0.3",
                "CFBundleVersion": "6",
            }
            with zipfile.ZipFile(ipa_path, "w") as archive:
                archive.writestr("Payload/Runner.app/Info.plist", plistlib.dumps(info))
            artwork = {
                "release_artifact": {
                    "path": "../../build/ios/ipa/Gikundiro.ipa",
                    "sha256": hashlib.sha256(ipa_path.read_bytes()).hexdigest(),
                    "bundle_id": "rw.ikanisa.rayonSports",
                    "version_name": "1.0.3",
                    "build_number": 6,
                }
            }
            mobile = {
                "ios_bundle_id": "rw.ikanisa.rayonSports",
                "version_name": "1.0.3",
                "build_number": 6,
            }

            accepted = validator.ValidationResult()
            validator._check_ios_release_artifact(
                manifest_path,
                artwork,
                mobile,
                ipa_path,
                accepted,
            )
            self.assertEqual([], accepted.errors)

            artwork["release_artifact"]["sha256"] = "0" * 64
            rejected = validator.ValidationResult()
            validator._check_ios_release_artifact(
                manifest_path,
                artwork,
                mobile,
                ipa_path,
                rejected,
            )
            self.assertIn("IPA_SHA256_MISMATCH", {item.code for item in rejected.errors})

    def test_android_upload_artifact_is_hash_package_and_version_bound(self) -> None:
        with tempfile.TemporaryDirectory() as temp_directory:
            app_dir = Path(temp_directory) / "rayon_sports"
            artifact = app_dir / "build/app/outputs/bundle/release/app-release.aab"
            artifact.parent.mkdir(parents=True)
            with zipfile.ZipFile(artifact, "w") as archive:
                archive.writestr("base/manifest/AndroidManifest.xml", b"fixture")

            merged_dir = (
                app_dir
                / "build/app/intermediates/merged_manifests/release/processReleaseManifest"
            )
            merged_dir.mkdir(parents=True)
            (merged_dir / "AndroidManifest.xml").write_text(
                '<manifest xmlns:android="http://schemas.android.com/apk/res/android" '
                'package="rw.gikundiro.app" android:versionName="1.0.3" '
                'android:versionCode="6" />',
                encoding="utf-8",
            )
            (merged_dir / "output-metadata.json").write_text(
                json.dumps(
                    {
                        "artifactType": {"type": "MERGED_MANIFESTS"},
                        "applicationId": "rw.gikundiro.app",
                        "variantName": "release",
                        "elements": [
                            {
                                "versionName": "1.0.3",
                                "versionCode": 6,
                                "outputFile": "AndroidManifest.xml",
                            }
                        ],
                    }
                ),
                encoding="utf-8",
            )
            bundle_dir = (
                app_dir
                / "build/app/intermediates/bundle_ide_model/release/produceReleaseBundleIdeListingFile"
            )
            bundle_dir.mkdir(parents=True)
            (bundle_dir / "output-metadata.json").write_text(
                json.dumps(
                    {
                        "artifactType": {"type": "BUNDLE"},
                        "applicationId": "rw.gikundiro.app",
                        "variantName": "release",
                        "elements": [
                            {
                                "outputFile": "../../../../outputs/bundle/release/app-release.aab"
                            }
                        ],
                    }
                ),
                encoding="utf-8",
            )
            sha256 = hashlib.sha256(artifact.read_bytes()).hexdigest()
            portal_path = app_dir / "store_metadata" / "portal_values.template.json"
            portal_path.parent.mkdir(parents=True)
            portal_path.write_text(
                json.dumps(
                    {
                        "google_play": {
                            "registered_upload_certificate_sha256": "AA:BB",
                            "verified_receipt": {
                                "package_name": "rw.gikundiro.app",
                                "intended_candidate_version_name": "1.0.3",
                                "intended_candidate_version_code": 6,
                                "candidate_aab": {
                                    "sha256": sha256,
                                    "bytes": artifact.stat().st_size,
                                    "embedded_package_name": "rw.gikundiro.app",
                                    "embedded_version_name": "1.0.3",
                                    "embedded_version_code": 6,
                                    "upload_certificate_sha256": "AA:BB",
                                },
                            },
                        }
                    }
                ),
                encoding="utf-8",
            )
            mobile = {
                "android_package": "rw.gikundiro.app",
                "version_name": "1.0.3",
                "build_number": 6,
            }

            accepted = validator.ValidationResult()
            validator._check_android_release_artifact(
                portal_path,
                mobile,
                artifact,
                accepted,
                app_dir=app_dir,
            )
            self.assertEqual([], accepted.errors)

            with artifact.open("ab") as stream:
                stream.write(b"tampered")
            rejected = validator.ValidationResult()
            validator._check_android_release_artifact(
                portal_path,
                mobile,
                artifact,
                rejected,
                app_dir=app_dir,
            )
            self.assertIn("AAB_SHA256_MISMATCH", {item.code for item in rejected.errors})

    def test_fastlane_binary_lanes_validate_the_same_path_they_upload(self) -> None:
        android = (validator.MOBILE_DIR / "android" / "fastlane" / "Fastfile").read_text(
            encoding="utf-8"
        )
        ios = (validator.MOBILE_DIR / "ios" / "fastlane" / "Fastfile").read_text(
            encoding="utf-8"
        )
        self.assertIn("aab_path = File.expand_path", android)
        self.assertRegex(android, r'"--artifact",\s*aab_path')
        self.assertIn("aab: aab_path", android)
        self.assertIn("ipa_path = File.expand_path", ios)
        self.assertRegex(ios, r'"--artifact",\s*ipa_path')
        self.assertIn("ipa: ipa_path", ios)

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
            [sys.executable, str(SCRIPT), "--surface", "mobile-play", "--json"],
            check=False,
            capture_output=True,
            text=True,
        )
        self.assertEqual(0, completed.returncode, completed.stderr)
        payload = json.loads(completed.stdout)
        self.assertEqual(["mobile-play"], payload["surfaces"])
        self.assertTrue(payload["valid"])
        self.assertIsInstance(payload["gates"], list)
        self.assertEqual([], payload["errors"])


if __name__ == "__main__":
    unittest.main()
