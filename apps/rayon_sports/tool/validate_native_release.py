#!/usr/bin/env python3
"""Validate code-owned Android/iOS release declarations and artwork.

This validator deliberately distinguishes source checks from merged-artifact
checks. Use ``--require-artifacts`` for a release gate after Gradle/Xcode has
produced the candidate artifacts.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import plistlib
import struct
import xml.etree.ElementTree as ET
import zipfile
from dataclasses import dataclass, asdict
from pathlib import Path
from typing import Iterable


ANDROID = "http://schemas.android.com/apk/res/android"
TOOLS = "http://schemas.android.com/tools"
FORBIDDEN_ANDROID_PERMISSIONS = frozenset(
    {
        "com.google.android.gms.permission.AD_ID",
        "android.permission.ACCESS_ADSERVICES_AD_ID",
        "android.permission.ACCESS_ADSERVICES_ATTRIBUTION",
        "android.permission.ACCESS_ADSERVICES_TOPICS",
        "com.google.android.finsky.permission.BIND_GET_INSTALL_REFERRER_SERVICE",
    }
)


@dataclass(frozen=True)
class Finding:
    level: str
    check: str
    detail: str


def _android_attr(name: str) -> str:
    return f"{{{ANDROID}}}{name}"


def _tools_attr(name: str) -> str:
    return f"{{{TOOLS}}}{name}"


def png_dimensions(path: Path) -> tuple[int, int]:
    with path.open("rb") as stream:
        header = stream.read(24)
    if len(header) != 24 or header[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"not a PNG: {path}")
    return struct.unpack(">II", header[16:24])


def _permission_names(root: ET.Element) -> set[str]:
    return {
        permission.get(_android_attr("name"), "")
        for permission in root.findall("uses-permission")
    }


def validate_android_source(project_root: Path) -> list[Finding]:
    path = project_root / "android/app/src/main/AndroidManifest.xml"
    findings: list[Finding] = []
    root = ET.parse(path).getroot()
    declarations = {
        element.get(_android_attr("name"), ""): element
        for element in root.findall("uses-permission")
    }
    for permission in sorted(FORBIDDEN_ANDROID_PERMISSIONS):
        element = declarations.get(permission)
        if element is None:
            findings.append(Finding("error", "android.source.permission", f"missing removal marker: {permission}"))
        elif element.get(_tools_attr("node")) != "remove":
            findings.append(Finding("error", "android.source.permission", f"not marked tools:node=remove: {permission}"))
    if not any(item.level == "error" for item in findings):
        findings.append(Finding("pass", "android.source.permission", "all advertising, ad-services, and install-referrer declarations are removed"))
    application = root.find("application")
    if application is None or application.get(_android_attr("icon")) != "@mipmap/ic_launcher":
        findings.append(Finding("error", "android.source.app_icon", "application must select @mipmap/ic_launcher"))
    icon_sizes = {
        "mipmap-mdpi": (48, 48),
        "mipmap-hdpi": (72, 72),
        "mipmap-xhdpi": (96, 96),
        "mipmap-xxhdpi": (144, 144),
        "mipmap-xxxhdpi": (192, 192),
    }
    icon_errors: list[str] = []
    for folder, expected in icon_sizes.items():
        icon = project_root / "android/app/src/main/res" / folder / "ic_launcher.png"
        if not icon.exists():
            icon_errors.append(f"missing {folder}/ic_launcher.png")
            continue
        try:
            actual = png_dimensions(icon)
        except ValueError as error:
            icon_errors.append(str(error))
            continue
        if actual != expected:
            icon_errors.append(f"{folder}: expected {expected}, found {actual}")
    if icon_errors:
        findings.append(Finding("error", "android.source.app_icon", "; ".join(icon_errors)))
    elif application is not None and application.get(_android_attr("icon")) == "@mipmap/ic_launcher":
        findings.append(Finding("pass", "android.source.app_icon", "launcher icon is declared with exact mdpi through xxxhdpi rasters"))
    return findings


def validate_merged_manifest(path: Path | None, require_artifacts: bool) -> list[Finding]:
    if path is None or not path.exists():
        level = "error" if require_artifacts else "warning"
        return [Finding(level, "android.merged_manifest", "merged release manifest not found")]
    root = ET.parse(path).getroot()
    present = sorted(FORBIDDEN_ANDROID_PERMISSIONS & _permission_names(root))
    if present:
        return [Finding("error", "android.merged_manifest", f"forbidden packaged permissions: {', '.join(present)}")]
    return [Finding("pass", "android.merged_manifest", f"no forbidden permissions in {path}")]


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def validate_aab(path: Path | None, require_artifacts: bool) -> list[Finding]:
    if path is None or not path.exists():
        level = "error" if require_artifacts else "warning"
        return [Finding(level, "android.aab", "release AAB not found")]
    with zipfile.ZipFile(path) as archive:
        try:
            manifest = archive.read("base/manifest/AndroidManifest.xml")
        except KeyError:
            return [Finding("error", "android.aab", "base manifest missing from AAB")]
        entries = set(archive.namelist())
    present = sorted(
        permission
        for permission in FORBIDDEN_ANDROID_PERMISSIONS
        if permission.encode("utf-8") in manifest
    )
    findings: list[Finding] = []
    if present:
        findings.append(Finding("error", "android.aab", f"forbidden permissions embedded in AAB: {', '.join(present)}"))
    else:
        findings.append(Finding("pass", "android.aab", "final base manifest contains no advertising, ad-services, or install-referrer permission strings"))
    required_icons = {
        "base/res/mipmap-mdpi-v4/ic_launcher.png",
        "base/res/mipmap-hdpi-v4/ic_launcher.png",
        "base/res/mipmap-xhdpi-v4/ic_launcher.png",
        "base/res/mipmap-xxhdpi-v4/ic_launcher.png",
        "base/res/mipmap-xxxhdpi-v4/ic_launcher.png",
    }
    missing_icons = sorted(required_icons - entries)
    if b"@mipmap/ic_launcher" not in manifest:
        findings.append(Finding("error", "android.aab.app_icon", "final base manifest does not select @mipmap/ic_launcher"))
    elif missing_icons:
        findings.append(Finding("error", "android.aab.app_icon", f"missing packaged icons: {', '.join(missing_icons)}"))
    else:
        findings.append(Finding("pass", "android.aab.app_icon", "final base manifest selects all five packaged launcher-icon densities"))
    findings.append(Finding("pass", "android.aab.sha256", _sha256(path)))
    return findings


def validate_privacy_manifest(project_root: Path) -> list[Finding]:
    path = project_root / "ios/Runner/PrivacyInfo.xcprivacy"
    with path.open("rb") as stream:
        privacy = plistlib.load(stream)
    entries = privacy.get("NSPrivacyCollectedDataTypes", [])
    matches = [
        entry
        for entry in entries
        if entry.get("NSPrivacyCollectedDataType") == "NSPrivacyCollectedDataTypeOtherUserContent"
    ]
    if len(matches) != 1:
        return [Finding("error", "ios.privacy.other_user_content", f"expected one OtherUserContent entry, found {len(matches)}")]
    entry = matches[0]
    expected_purpose = "NSPrivacyCollectedDataTypePurposeAppFunctionality"
    errors: list[str] = []
    if entry.get("NSPrivacyCollectedDataTypeLinked") is not True:
        errors.append("linked must be true")
    if entry.get("NSPrivacyCollectedDataTypeTracking") is not False:
        errors.append("tracking must be false")
    if expected_purpose not in entry.get("NSPrivacyCollectedDataTypePurposes", []):
        errors.append("AppFunctionality purpose missing")
    if errors:
        return [Finding("error", "ios.privacy.other_user_content", "; ".join(errors))]
    return [Finding("pass", "ios.privacy.other_user_content", "linked, non-tracking OtherUserContent is declared for app functionality")]


def validate_app_icon(project_root: Path) -> list[Finding]:
    app_icon = project_root / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    contents_path = app_icon / "Contents.json"
    findings: list[Finding] = []
    if not contents_path.exists():
        return [Finding("error", "ios.app_icon", "AppIcon Contents.json missing")]
    contents = json.loads(contents_path.read_text(encoding="utf-8"))
    images = contents.get("images", [])
    referenced: set[str] = set()
    for entry in images:
        filename = entry.get("filename")
        if not filename:
            findings.append(Finding("error", "ios.app_icon", f"entry has no filename: {entry}"))
            continue
        referenced.add(filename)
        image_path = app_icon / filename
        if not image_path.exists():
            findings.append(Finding("error", "ios.app_icon", f"referenced file missing: {filename}"))
            continue
        try:
            logical_width, logical_height = (float(part) for part in entry["size"].split("x"))
            scale = float(entry["scale"].removesuffix("x"))
            expected = (round(logical_width * scale), round(logical_height * scale))
            actual = png_dimensions(image_path)
        except (KeyError, TypeError, ValueError) as error:
            findings.append(Finding("error", "ios.app_icon", f"invalid {filename}: {error}"))
            continue
        if actual != expected:
            findings.append(Finding("error", "ios.app_icon", f"{filename}: expected {expected}, found {actual}"))
    marketing = [entry for entry in images if entry.get("idiom") == "ios-marketing"]
    if len(marketing) != 1:
        findings.append(Finding("error", "ios.app_icon", f"expected one iOS marketing icon, found {len(marketing)}"))
    pbxproj = (project_root / "ios/Runner.xcodeproj/project.pbxproj").read_text(encoding="utf-8")
    setting_count = pbxproj.count("ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;")
    if setting_count != 3:
        findings.append(Finding("error", "ios.app_icon", f"AppIcon build setting count is {setting_count}, expected 3"))
    if not any(item.level == "error" for item in findings):
        findings.append(Finding("pass", "ios.app_icon", f"{len(referenced)} referenced icons have exact dimensions; Debug/Profile/Release select AppIcon"))
    return findings


def validate(
    project_root: Path,
    merged_manifest: Path | None,
    aab: Path | None,
    require_artifacts: bool,
) -> list[Finding]:
    findings: list[Finding] = []
    findings.extend(validate_android_source(project_root))
    findings.extend(validate_merged_manifest(merged_manifest, require_artifacts))
    findings.extend(validate_aab(aab, require_artifacts))
    findings.extend(validate_privacy_manifest(project_root))
    findings.extend(validate_app_icon(project_root))
    return findings


def _default_merged_manifest(project_root: Path) -> Path:
    return project_root / "build/app/intermediates/merged_manifests/release/processReleaseManifest/AndroidManifest.xml"


def _default_aab(project_root: Path) -> Path:
    return project_root / "build/app/outputs/bundle/release/app-release.aab"


def _print_text(findings: Iterable[Finding]) -> None:
    for finding in findings:
        print(f"[{finding.level.upper()}] {finding.check}: {finding.detail}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project-root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--merged-manifest", type=Path)
    parser.add_argument("--aab", type=Path)
    parser.add_argument("--require-artifacts", action="store_true")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()
    project_root = args.project_root.resolve()
    merged = args.merged_manifest or _default_merged_manifest(project_root)
    aab = args.aab or _default_aab(project_root)
    findings = validate(project_root, merged, aab, args.require_artifacts)
    if args.json:
        print(json.dumps({"findings": [asdict(item) for item in findings]}, indent=2))
    else:
        _print_text(findings)
    return 1 if any(item.level == "error" for item in findings) else 0


if __name__ == "__main__":
    raise SystemExit(main())
