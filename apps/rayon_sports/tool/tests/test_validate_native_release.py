from __future__ import annotations

import importlib.util
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path


MODULE_PATH = Path(__file__).resolve().parents[1] / "validate_native_release.py"
SPEC = importlib.util.spec_from_file_location("rayon_native_release", MODULE_PATH)
assert SPEC and SPEC.loader
VALIDATOR = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = VALIDATOR
SPEC.loader.exec_module(VALIDATOR)


class NativeReleaseValidatorTest(unittest.TestCase):
    def test_current_source_package_is_structurally_valid(self) -> None:
        project_root = Path(__file__).resolve().parents[2]
        findings = []
        findings.extend(VALIDATOR.validate_android_source(project_root))
        findings.extend(VALIDATOR.validate_privacy_manifest(project_root))
        findings.extend(VALIDATOR.validate_app_icon(project_root))
        self.assertEqual([], [item for item in findings if item.level == "error"])

    def test_merged_manifest_rejects_advertising_permissions(self) -> None:
        manifest = """<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
  <uses-permission android:name="com.google.android.gms.permission.AD_ID" />
</manifest>
"""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "AndroidManifest.xml"
            path.write_text(manifest, encoding="utf-8")
            findings = VALIDATOR.validate_merged_manifest(path, True)
        self.assertEqual("error", findings[0].level)
        self.assertIn("AD_ID", findings[0].detail)

    def test_restored_marketing_icon_is_exactly_1024_square(self) -> None:
        project_root = Path(__file__).resolve().parents[2]
        icon = project_root / "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png"
        self.assertEqual((1024, 1024), VALIDATOR.png_dimensions(icon))

    def test_restored_android_launcher_icon_has_xxxhdpi_size(self) -> None:
        project_root = Path(__file__).resolve().parents[2]
        icon = project_root / "android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png"
        self.assertEqual((192, 192), VALIDATOR.png_dimensions(icon))

    def test_aab_rejects_advertising_permission_in_final_manifest(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "candidate.aab"
            with zipfile.ZipFile(path, "w") as archive:
                archive.writestr(
                    "base/manifest/AndroidManifest.xml",
                    b"binary-prefix com.google.android.gms.permission.AD_ID binary-suffix",
                )
            findings = VALIDATOR.validate_aab(path, True)
        self.assertEqual("error", findings[0].level)
        self.assertIn("AD_ID", findings[0].detail)


if __name__ == "__main__":
    unittest.main()
