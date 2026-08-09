from __future__ import annotations

import importlib.util
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
        self.assertNotIn("ARTWORK_MISSING", codes)
        self.assertNotIn("SCREENSHOTS_MISSING", codes)
        self.assertNotIn("IOS_ICON_GATE", codes)
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

    def test_tv_artwork_approvals_match_controlled_approvals(self) -> None:
        tv_store = validator.TV_DIR / "store_metadata"
        artwork = json.loads((tv_store / "artwork_manifest.json").read_text(encoding="utf-8"))
        approvals = json.loads((tv_store / "approvals.json").read_text(encoding="utf-8"))
        self.assertIn("rayon_brand_and_content_rights", artwork["approvals_required"])
        self.assertEqual(
            {item["id"] for item in approvals["approvals"]},
            set(artwork["approvals_required"]),
        )

    def test_exact_release_artifact_provenance_is_recorded(self) -> None:
        app_store = json.loads(
            (validator.STORE_DIR / "app_store" / "artwork_manifest.json").read_text(
                encoding="utf-8"
            )
        )
        self.assertEqual(
            "606739bff02260103ac0ad55eb1b2d1c223f8aea60e9de1c4099ca7572c477bc",
            app_store["release_artifact"]["sha256"],
        )
        self.assertEqual(6, app_store["release_artifact"]["build_number"])
        self.assertEqual(
            "archive_icon_presence_verified",
            app_store["binary_icon_gate"]["status"],
        )

        tv_store = validator.TV_DIR / "store_metadata"
        tv_artwork = json.loads(
            (tv_store / "artwork_manifest.json").read_text(encoding="utf-8")
        )
        self.assertEqual(
            "37bfdbd7a7206c7002c4ba6fad55bfc43247e3df133a6d656b72828ff7f1ae77",
            tv_artwork["production_release_artifact"]["sha256"],
        )
        launcher = next(
            item for item in tv_artwork["assets"] if item["id"] == "launcher_banner_in_aab"
        )
        self.assertTrue(launcher["byte_parity_verified"])
        self.assertEqual(launcher["source_sha256"], launcher["production_aab_embedded_sha256"])

    def test_submission_ready_adds_post_upload_portal_gates(self) -> None:
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
