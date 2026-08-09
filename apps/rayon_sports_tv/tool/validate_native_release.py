#!/usr/bin/env python3
"""Validate Android TV native release requirements against source and APK.

The strict gate verifies the release manifest, 32/64-bit ABI pairing, every
native library's ELF LOAD alignment, and APK 16 KiB ZIP alignment. It does not
stand in for a physical 16 KiB device/emulator run or Google Play review.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import struct
import subprocess
import xml.etree.ElementTree as ET
import zipfile
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Iterable


ANDROID = "http://schemas.android.com/apk/res/android"
MIN_ELF_ALIGNMENT = 16 * 1024
REQUIRED_ABIS = frozenset({"armeabi-v7a", "arm64-v8a"})


@dataclass(frozen=True)
class Finding:
    level: str
    check: str
    detail: str


def _android_attr(name: str) -> str:
    return f"{{{ANDROID}}}{name}"


def png_dimensions(path: Path) -> tuple[int, int]:
    with path.open("rb") as stream:
        header = stream.read(26)
    if len(header) != 26 or header[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"not a PNG: {path}")
    return struct.unpack(">II", header[16:24])


def _png_has_alpha(path: Path) -> bool:
    with path.open("rb") as stream:
        header = stream.read(26)
    if len(header) != 26 or header[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"not a PNG: {path}")
    return header[25] in {4, 6}


def _manifest_features(root: ET.Element) -> dict[str, str | None]:
    return {
        element.get(_android_attr("name"), ""): element.get(_android_attr("required"))
        for element in root.findall("uses-feature")
    }


def _validate_manifest_root(
    root: ET.Element,
    check_prefix: str,
    require_generated_extract_setting: bool,
) -> list[Finding]:
    findings: list[Finding] = []
    features = _manifest_features(root)
    if features.get("android.software.leanback") != "true":
        findings.append(Finding("error", f"{check_prefix}.feature", "android.software.leanback must be required"))
    if features.get("android.hardware.touchscreen") != "false":
        findings.append(Finding("error", f"{check_prefix}.feature", "android.hardware.touchscreen must be optional"))
    application = root.find("application")
    if application is None:
        findings.append(Finding("error", f"{check_prefix}.application", "application element missing"))
        return findings
    expected_application = {
        "banner": "@drawable/tv_banner",
        "icon": "@mipmap/ic_launcher",
    }
    if require_generated_extract_setting:
        expected_application["extractNativeLibs"] = "false"
    for attribute, expected in expected_application.items():
        actual = application.get(_android_attr(attribute))
        if actual != expected:
            findings.append(Finding("error", f"{check_prefix}.application", f"android:{attribute} expected {expected}, found {actual}"))
    activities = application.findall("activity")
    leanback_activities = []
    for activity in activities:
        for intent_filter in activity.findall("intent-filter"):
            categories = {
                item.get(_android_attr("name"), "")
                for item in intent_filter.findall("category")
            }
            if "android.intent.category.LEANBACK_LAUNCHER" in categories:
                leanback_activities.append(activity)
    if len(leanback_activities) != 1:
        findings.append(Finding("error", f"{check_prefix}.launcher", f"expected one leanback launcher activity, found {len(leanback_activities)}"))
    elif leanback_activities[0].get(_android_attr("screenOrientation")) != "landscape":
        findings.append(Finding("error", f"{check_prefix}.launcher", "leanback launcher activity must be landscape"))
    if not findings:
        detail = "leanback/touchscreen, icon/banner, and landscape declarations are valid"
        if require_generated_extract_setting:
            detail += "; generated native extraction setting is false"
        findings.append(Finding("pass", check_prefix, detail))
    return findings


def validate_source(project_root: Path) -> list[Finding]:
    manifest = project_root / "android/app/src/main/AndroidManifest.xml"
    findings = _validate_manifest_root(
        ET.parse(manifest).getroot(),
        "tv.source_manifest",
        require_generated_extract_setting=False,
    )
    banner = project_root / "android/app/src/main/res/drawable-xhdpi/tv_banner.png"
    icon = project_root / "android/app/src/main/res/mipmap-xhdpi/ic_launcher.png"
    legacy_banner = project_root / "android/app/src/main/res/drawable/tv_banner.xml"
    expected_artwork = ((banner, (320, 180), "banner"), (icon, (160, 160), "icon"))
    for path, expected, label in expected_artwork:
        if not path.exists():
            findings.append(Finding("error", f"tv.artwork.{label}", f"missing {path}"))
            continue
        try:
            actual = png_dimensions(path)
            has_alpha = _png_has_alpha(path)
        except ValueError as error:
            findings.append(Finding("error", f"tv.artwork.{label}", str(error)))
            continue
        if actual != expected:
            findings.append(Finding("error", f"tv.artwork.{label}", f"expected {expected}, found {actual}"))
        elif has_alpha:
            findings.append(Finding("error", f"tv.artwork.{label}", "launcher artwork must be an opaque raster"))
        else:
            findings.append(Finding("pass", f"tv.artwork.{label}", f"opaque RGB PNG is exactly {actual[0]}x{actual[1]} xhdpi"))
    if legacy_banner.exists():
        findings.append(Finding("error", "tv.artwork.banner", "legacy drawable/tv_banner.xml still shadows the raster"))

    gradle = (project_root / "android/app/build.gradle.kts").read_text(encoding="utf-8")
    if "useLegacyPackaging = false" not in gradle:
        findings.append(Finding("error", "tv.gradle.packaging", "useLegacyPackaging=false is missing"))
    else:
        findings.append(Finding("pass", "tv.gradle.packaging", "native libraries use modern uncompressed packaging"))
    settings = (project_root / "android/settings.gradle.kts").read_text(encoding="utf-8")
    version_match = re.search(r'id\("com\.android\.application"\) version "([0-9.]+)"', settings)
    if version_match is None:
        findings.append(Finding("error", "tv.gradle.agp", "Android Gradle Plugin version not found"))
    else:
        version = tuple(int(part) for part in version_match.group(1).split("."))
        padded = version + (0,) * (3 - len(version))
        if padded < (8, 5, 1):
            findings.append(Finding("error", "tv.gradle.agp", f"AGP {version_match.group(1)} is below 8.5.1"))
        else:
            findings.append(Finding("pass", "tv.gradle.agp", f"AGP {version_match.group(1)} supports 16 KiB ZIP alignment"))
    return findings


def validate_merged_manifest(path: Path | None, require_artifacts: bool) -> list[Finding]:
    if path is None or not path.exists():
        level = "error" if require_artifacts else "warning"
        return [Finding(level, "tv.merged_manifest", "merged release manifest not found")]
    root = ET.parse(path).getroot()
    findings = _validate_manifest_root(
        root,
        "tv.merged_manifest",
        require_generated_extract_setting=True,
    )
    uses_sdk = root.find("uses-sdk")
    if uses_sdk is None:
        findings.append(Finding("error", "tv.merged_manifest.sdk", "uses-sdk element missing"))
    else:
        try:
            min_sdk = int(uses_sdk.get(_android_attr("minSdkVersion"), "0"))
            target_sdk = int(uses_sdk.get(_android_attr("targetSdkVersion"), "0"))
        except ValueError:
            findings.append(Finding("error", "tv.merged_manifest.sdk", "SDK versions are not numeric"))
        else:
            if min_sdk > 31:
                findings.append(Finding("error", "tv.merged_manifest.sdk", f"minSdk {min_sdk} exceeds TV quality limit 31"))
            elif target_sdk < 34:
                findings.append(Finding("error", "tv.merged_manifest.sdk", f"targetSdk {target_sdk} is below current TV submission floor 34"))
            else:
                findings.append(Finding("pass", "tv.merged_manifest.sdk", f"minSdk={min_sdk}, targetSdk={target_sdk}"))
    return findings


def elf_load_alignments(data: bytes) -> list[int]:
    if len(data) < 64 or data[:4] != b"\x7fELF":
        raise ValueError("invalid ELF header")
    elf_class = data[4]
    data_encoding = data[5]
    if data_encoding not in {1, 2}:
        raise ValueError("unsupported ELF byte order")
    endian = "<" if data_encoding == 1 else ">"
    if elf_class == 2:
        phoff = struct.unpack_from(f"{endian}Q", data, 32)[0]
        phentsize = struct.unpack_from(f"{endian}H", data, 54)[0]
        phnum = struct.unpack_from(f"{endian}H", data, 56)[0]
        align_offset, align_format = 48, "Q"
    elif elf_class == 1:
        phoff = struct.unpack_from(f"{endian}I", data, 28)[0]
        phentsize = struct.unpack_from(f"{endian}H", data, 42)[0]
        phnum = struct.unpack_from(f"{endian}H", data, 44)[0]
        align_offset, align_format = 28, "I"
    else:
        raise ValueError(f"unsupported ELF class {elf_class}")
    if not phentsize or not phnum:
        raise ValueError("ELF has no program headers")
    alignments: list[int] = []
    for index in range(phnum):
        offset = phoff + index * phentsize
        if offset + phentsize > len(data):
            raise ValueError("truncated ELF program header table")
        program_type = struct.unpack_from(f"{endian}I", data, offset)[0]
        if program_type == 1:  # PT_LOAD
            alignments.append(struct.unpack_from(f"{endian}{align_format}", data, offset + align_offset)[0])
    if not alignments:
        raise ValueError("ELF has no PT_LOAD segments")
    return alignments


def _version_key(path: Path) -> tuple[int, ...]:
    try:
        return tuple(int(part) for part in path.parent.name.split("."))
    except ValueError:
        return (0,)


def find_zipalign() -> Path | None:
    on_path = shutil.which("zipalign")
    if on_path:
        return Path(on_path)
    candidates: list[Path] = []
    for variable in ("ANDROID_SDK_ROOT", "ANDROID_HOME"):
        sdk = os.environ.get(variable)
        if sdk:
            candidates.extend(Path(sdk).glob("build-tools/*/zipalign"))
    return max(candidates, key=_version_key) if candidates else None


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def validate_apk(path: Path | None, require_artifacts: bool, zipalign: Path | None) -> list[Finding]:
    if path is None or not path.exists():
        level = "error" if require_artifacts else "warning"
        return [Finding(level, "tv.apk", "release APK not found")]
    findings: list[Finding] = []
    with zipfile.ZipFile(path) as archive:
        native_entries = [item for item in archive.infolist() if item.filename.startswith("lib/") and item.filename.endswith(".so")]
        abis = {item.filename.split("/")[1] for item in native_entries}
        missing = sorted(REQUIRED_ABIS - abis)
        if missing:
            findings.append(Finding("error", "tv.apk.abi", f"missing required ABI(s): {', '.join(missing)}; found {sorted(abis)}"))
        else:
            findings.append(Finding("pass", "tv.apk.abi", f"32/64-bit pairing present: {', '.join(sorted(abis))}"))
        if not native_entries:
            findings.append(Finding("error", "tv.apk.elf", "APK contains no native libraries"))
        unaligned: list[str] = []
        compressed: list[str] = []
        for entry in native_entries:
            if entry.compress_type != zipfile.ZIP_STORED:
                compressed.append(entry.filename)
            try:
                alignments = elf_load_alignments(archive.read(entry))
            except ValueError as error:
                unaligned.append(f"{entry.filename} ({error})")
                continue
            minimum = min(alignments)
            if minimum < MIN_ELF_ALIGNMENT:
                unaligned.append(f"{entry.filename} (min p_align={minimum})")
        if compressed:
            findings.append(Finding("error", "tv.apk.packaging", f"compressed native libraries: {', '.join(compressed)}"))
        elif native_entries:
            findings.append(Finding("pass", "tv.apk.packaging", f"all {len(native_entries)} native libraries are stored uncompressed"))
        if unaligned:
            findings.append(Finding("error", "tv.apk.elf", f"16 KiB ELF alignment failures: {', '.join(unaligned)}"))
        elif native_entries:
            findings.append(Finding("pass", "tv.apk.elf", f"all {len(native_entries)} native libraries have PT_LOAD p_align >= 16384"))
    zipalign_path = zipalign or find_zipalign()
    if zipalign_path is None:
        level = "error" if require_artifacts else "warning"
        findings.append(Finding(level, "tv.apk.zipalign", "zipalign tool not found"))
    else:
        process = subprocess.run(
            [str(zipalign_path), "-c", "-P", "16", "-v", "4", str(path)],
            capture_output=True,
            text=True,
            check=False,
        )
        if process.returncode:
            detail = (process.stderr or process.stdout).strip().splitlines()[-1]
            findings.append(Finding("error", "tv.apk.zipalign", f"zipalign failed: {detail}"))
        else:
            findings.append(Finding("pass", "tv.apk.zipalign", f"16 KiB ZIP alignment verified with {zipalign_path}"))
    findings.append(Finding("pass", "tv.apk.sha256", _sha256(path)))
    return findings


def validate_aab(path: Path | None, require_artifacts: bool) -> list[Finding]:
    if path is None or not path.exists():
        level = "error" if require_artifacts else "warning"
        return [Finding(level, "tv.aab", "release AAB not found")]
    findings: list[Finding] = []
    with zipfile.ZipFile(path) as archive:
        native_entries = [
            item
            for item in archive.infolist()
            if item.filename.startswith("base/lib/") and item.filename.endswith(".so")
        ]
        abis = {item.filename.split("/")[2] for item in native_entries}
        missing = sorted(REQUIRED_ABIS - abis)
        if missing:
            findings.append(Finding("error", "tv.aab.abi", f"missing required ABI(s): {', '.join(missing)}; found {sorted(abis)}"))
        else:
            findings.append(Finding("pass", "tv.aab.abi", f"32/64-bit pairing present: {', '.join(sorted(abis))}"))
        unaligned: list[str] = []
        for entry in native_entries:
            try:
                minimum = min(elf_load_alignments(archive.read(entry)))
            except ValueError as error:
                unaligned.append(f"{entry.filename} ({error})")
                continue
            if minimum < MIN_ELF_ALIGNMENT:
                unaligned.append(f"{entry.filename} (min p_align={minimum})")
        if not native_entries:
            findings.append(Finding("error", "tv.aab.elf", "AAB contains no native libraries"))
        elif unaligned:
            findings.append(Finding("error", "tv.aab.elf", f"16 KiB ELF alignment failures: {', '.join(unaligned)}"))
        else:
            findings.append(Finding("pass", "tv.aab.elf", f"all {len(native_entries)} native libraries have PT_LOAD p_align >= 16384"))
    findings.append(Finding("pass", "tv.aab.sha256", _sha256(path)))
    return findings


def validate(
    project_root: Path,
    merged_manifest: Path | None,
    apk: Path | None,
    aab: Path | None,
    require_artifacts: bool,
    zipalign: Path | None = None,
) -> list[Finding]:
    findings: list[Finding] = []
    findings.extend(validate_source(project_root))
    findings.extend(validate_merged_manifest(merged_manifest, require_artifacts))
    findings.extend(validate_apk(apk, require_artifacts, zipalign))
    findings.extend(validate_aab(aab, require_artifacts))
    return findings


def _default_manifest(project_root: Path) -> Path:
    return project_root / "build/app/intermediates/merged_manifests/release/processReleaseManifest/AndroidManifest.xml"


def _default_apk(project_root: Path) -> Path:
    return project_root / "build/app/outputs/apk/release/app-release.apk"


def _default_aab(project_root: Path) -> Path:
    return project_root / "build/app/outputs/bundle/release/app-release.aab"


def _print_text(findings: Iterable[Finding]) -> None:
    for finding in findings:
        print(f"[{finding.level.upper()}] {finding.check}: {finding.detail}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project-root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--merged-manifest", type=Path)
    parser.add_argument("--apk", type=Path)
    parser.add_argument("--aab", type=Path)
    parser.add_argument("--zipalign", type=Path)
    parser.add_argument("--require-artifacts", action="store_true")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()
    project_root = args.project_root.resolve()
    findings = validate(
        project_root,
        args.merged_manifest or _default_manifest(project_root),
        args.apk or _default_apk(project_root),
        args.aab or _default_aab(project_root),
        args.require_artifacts,
        args.zipalign,
    )
    if args.json:
        print(json.dumps({"findings": [asdict(item) for item in findings]}, indent=2))
    else:
        _print_text(findings)
    return 1 if any(item.level == "error" for item in findings) else 0


if __name__ == "__main__":
    raise SystemExit(main())
