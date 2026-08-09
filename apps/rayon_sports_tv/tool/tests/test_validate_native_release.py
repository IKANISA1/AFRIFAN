from __future__ import annotations

import importlib.util
import struct
import sys
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).resolve().parents[1] / "validate_native_release.py"
SPEC = importlib.util.spec_from_file_location("rayon_tv_native_release", MODULE_PATH)
assert SPEC and SPEC.loader
VALIDATOR = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = VALIDATOR
SPEC.loader.exec_module(VALIDATOR)


def _elf64_with_load_alignment(alignment: int) -> bytes:
    data = bytearray(64 + 56)
    data[:4] = b"\x7fELF"
    data[4] = 2  # ELFCLASS64
    data[5] = 1  # little endian
    struct.pack_into("<Q", data, 32, 64)
    struct.pack_into("<H", data, 54, 56)
    struct.pack_into("<H", data, 56, 1)
    struct.pack_into("<I", data, 64, 1)  # PT_LOAD
    struct.pack_into("<Q", data, 64 + 48, alignment)
    return bytes(data)


class TvNativeReleaseValidatorTest(unittest.TestCase):
    def test_current_source_package_is_structurally_valid(self) -> None:
        project_root = Path(__file__).resolve().parents[2]
        findings = VALIDATOR.validate_source(project_root)
        self.assertEqual([], [item for item in findings if item.level == "error"])

    def test_elf_parser_reads_16k_load_alignment(self) -> None:
        self.assertEqual([16384], VALIDATOR.elf_load_alignments(_elf64_with_load_alignment(16384)))

    def test_elf_parser_exposes_4k_load_alignment(self) -> None:
        self.assertEqual([4096], VALIDATOR.elf_load_alignments(_elf64_with_load_alignment(4096)))

    def test_launcher_artwork_has_exact_dimensions(self) -> None:
        project_root = Path(__file__).resolve().parents[2]
        banner = project_root / "android/app/src/main/res/drawable-xhdpi/tv_banner.png"
        icon = project_root / "android/app/src/main/res/mipmap-xhdpi/ic_launcher.png"
        self.assertEqual((320, 180), VALIDATOR.png_dimensions(banner))
        self.assertEqual((160, 160), VALIDATOR.png_dimensions(icon))


if __name__ == "__main__":
    unittest.main()
