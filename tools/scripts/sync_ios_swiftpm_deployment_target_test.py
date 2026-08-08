from __future__ import annotations

import importlib.util
import pathlib
import tempfile
import unittest


SCRIPT_PATH = pathlib.Path(__file__).with_name(
    "sync_ios_swiftpm_deployment_target.py"
)
SPEC = importlib.util.spec_from_file_location("ios_swiftpm_sync", SCRIPT_PATH)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError(f"Unable to load {SCRIPT_PATH}")
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


def package_manifest(version: str) -> str:
    return (
        "import PackageDescription\n\n"
        "let package = Package(\n"
        "    name: \"Fixture\",\n"
        "    platforms: [\n"
        f"        .iOS(\"{version}\")\n"
        "    ]\n"
        ")\n"
    )


class SwiftPmDeploymentTargetTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp_dir = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp_dir.cleanup)
        self.manifest = pathlib.Path(self.temp_dir.name) / "Package.swift"

    def test_raises_a_lower_generated_target(self) -> None:
        self.manifest.write_text(package_manifest("13.0"), encoding="utf-8")

        version, changed = MODULE.synchronize_manifest(self.manifest, "15.5")

        self.assertEqual(version, "15.5")
        self.assertTrue(changed)
        self.assertIn('.iOS("15.5")', self.manifest.read_text(encoding="utf-8"))

    def test_does_not_downgrade_a_higher_target(self) -> None:
        self.manifest.write_text(package_manifest("16.0"), encoding="utf-8")

        version, changed = MODULE.synchronize_manifest(self.manifest, "15.5")

        self.assertEqual(version, "16.0")
        self.assertFalse(changed)

    def test_check_mode_fails_closed_for_a_lower_target(self) -> None:
        self.manifest.write_text(package_manifest("13.0"), encoding="utf-8")

        with self.assertRaisesRegex(ValueError, "below required 15.5"):
            MODULE.synchronize_manifest(
                self.manifest,
                "15.5",
                check_only=True,
            )

    def test_rejects_an_ambiguous_manifest(self) -> None:
        self.manifest.write_text(
            package_manifest("13.0") + package_manifest("14.0"),
            encoding="utf-8",
        )

        with self.assertRaisesRegex(ValueError, "exactly one"):
            MODULE.synchronize_manifest(self.manifest, "15.5")


if __name__ == "__main__":
    unittest.main()
