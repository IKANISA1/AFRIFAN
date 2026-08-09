#!/usr/bin/env python3
"""Validate Gikundiro mobile and Android TV store-delivery packages.

The default mode checks repository-owned structure and copy. Release-ready mode
also enforces artwork, portal-value, policy-decision, and accountable-approval
gates. It never calls a store API and never treats local validation as review or
publication evidence.
"""

from __future__ import annotations

import argparse
import json
import re
import struct
import sys
from dataclasses import asdict, dataclass, field
from pathlib import Path
from typing import Any, Iterable
from urllib.parse import urlparse


STORE_DIR = Path(__file__).resolve().parent
MOBILE_DIR = STORE_DIR.parent
TV_DIR = MOBILE_DIR.parent / "rayon_sports_tv"

MOBILE_PLAY = "mobile-play"
APP_STORE = "app-store"
TV_PLAY = "tv-play"
ALL_SURFACES = {MOBILE_PLAY, APP_STORE, TV_PLAY}


@dataclass(frozen=True)
class Finding:
    code: str
    message: str
    path: str | None = None


@dataclass
class ValidationResult:
    errors: list[Finding] = field(default_factory=list)
    gates: list[Finding] = field(default_factory=list)
    warnings: list[Finding] = field(default_factory=list)

    def valid(self, enforce_gates: bool = False) -> bool:
        return not self.errors and (not enforce_gates or not self.gates)

    def add_error(self, code: str, message: str, path: Path | None = None) -> None:
        self.errors.append(Finding(code, message, _display(path)))

    def add_gate(self, code: str, message: str, path: Path | None = None) -> None:
        self.gates.append(Finding(code, message, _display(path)))

    def add_warning(self, code: str, message: str, path: Path | None = None) -> None:
        self.warnings.append(Finding(code, message, _display(path)))


def _display(path: Path | None) -> str | None:
    if path is None:
        return None
    try:
        return str(path.resolve().relative_to(MOBILE_DIR.parent.parent))
    except ValueError:
        return str(path)


def _read_text(path: Path, result: ValidationResult) -> str:
    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeError) as exc:
        result.add_error("FILE_READ", f"Cannot read UTF-8 text: {exc}", path)
        return ""
    if not text.strip():
        result.add_error("EMPTY_FILE", "Required metadata file is empty", path)
    return text.strip()


def _read_json(path: Path, result: ValidationResult) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        result.add_error("JSON_INVALID", f"Cannot load JSON object: {exc}", path)
        return {}
    if not isinstance(value, dict):
        result.add_error("JSON_OBJECT", "Top-level JSON value must be an object", path)
        return {}
    return value


def _require_files(paths: Iterable[Path], result: ValidationResult) -> None:
    for path in paths:
        if not path.is_file():
            result.add_error("FILE_MISSING", "Required package file is missing", path)
        elif path.stat().st_size == 0:
            result.add_error("EMPTY_FILE", "Required package file is empty", path)


def _check_text_limit(
    path: Path,
    limit: int,
    result: ValidationResult,
    *,
    byte_limit: bool = False,
) -> str:
    text = _read_text(path, result)
    size = len(text.encode("utf-8")) if byte_limit else len(text)
    if size > limit:
        unit = "UTF-8 bytes" if byte_limit else "characters"
        result.add_error("TEXT_LIMIT", f"{size} {unit}; maximum is {limit}", path)
    return text


def _check_url_file(path: Path, result: ValidationResult) -> None:
    value = _read_text(path, result)
    parsed = urlparse(value)
    if parsed.scheme != "https" or not parsed.netloc:
        result.add_error("URL_INVALID", "URL must be an absolute HTTPS URL", path)
    if parsed.hostname in {"example.com", "localhost"}:
        result.add_error("URL_PLACEHOLDER", "Placeholder URL is not uploadable", path)


def _pubspec_version(path: Path, result: ValidationResult) -> tuple[str, int] | None:
    text = _read_text(path, result)
    match = re.search(r"(?m)^version:\s*([^+\s]+)\+(\d+)\s*$", text)
    if not match:
        result.add_error("VERSION_PARSE", "Expected version: name+integer", path)
        return None
    return match.group(1), int(match.group(2))


def _check_copy(text_paths: Iterable[Path], result: ValidationResult) -> None:
    banned = {
        r"\bofficial\s+rayon sports(?: fc)?\s+(?:fan\s+)?(?:super-)?app\b": "Unapproved official-app claim",
        r"\bpurchase\b.{0,30}\bdirectly\b": "Unsupported direct-purchase claim",
        r"\bevery match\b": "Unsupported completeness claim",
        r"\bsms ledger\b": "SMS-ledger feature is not in the public candidate",
        r"\bguaranteed rewards?\b": "Unsupported guaranteed-reward claim",
        r"\bearn cash\b|\bcash rewards?\b": "Unsupported cash-value claim",
    }
    for path in text_paths:
        if not path.is_file():
            continue
        text = path.read_text(encoding="utf-8")
        for pattern, message in banned.items():
            if re.search(pattern, text, flags=re.IGNORECASE | re.DOTALL):
                result.add_error("COPY_OVERCLAIM", message, path)


def _check_secret_material(paths: Iterable[Path], result: ValidationResult) -> None:
    patterns = {
        r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----": "Private key",
        r'"private_key"\s*:\s*"-----BEGIN': "Service-account private key",
        r"\bAIza[0-9A-Za-z_-]{30,}\b": "Google API key",
        r"\bgh[pousr]_[0-9A-Za-z]{30,}\b": "GitHub token",
        r"\bsk_(?:live|test)_[0-9A-Za-z]{16,}\b": "Payment secret",
    }
    for root in paths:
        if not root.exists():
            continue
        candidates = [root] if root.is_file() else root.rglob("*")
        for path in candidates:
            if not path.is_file() or path.suffix.lower() in {".png", ".jpg", ".jpeg"}:
                continue
            try:
                text = path.read_text(encoding="utf-8")
            except (OSError, UnicodeError):
                continue
            for pattern, label in patterns.items():
                if re.search(pattern, text):
                    result.add_error("SECRET_MATERIAL", f"{label} must not be committed", path)


def _image_dimensions(path: Path) -> tuple[int, int] | None:
    try:
        data = path.read_bytes()
    except OSError:
        return None
    if data.startswith(b"\x89PNG\r\n\x1a\n") and len(data) >= 24:
        return struct.unpack(">II", data[16:24])
    if data.startswith(b"\xff\xd8"):
        index = 2
        while index + 9 < len(data):
            if data[index] != 0xFF:
                index += 1
                continue
            marker = data[index + 1]
            index += 2
            if marker in {0xD8, 0xD9}:
                continue
            if index + 2 > len(data):
                break
            length = int.from_bytes(data[index : index + 2], "big")
            if marker in {0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7, 0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF} and index + 7 < len(data):
                return (
                    int.from_bytes(data[index + 5 : index + 7], "big"),
                    int.from_bytes(data[index + 3 : index + 5], "big"),
                )
            if length < 2:
                break
            index += length
    return None


def _png_color_type(path: Path) -> int | None:
    try:
        data = path.read_bytes()[:26]
    except OSError:
        return None
    if data.startswith(b"\x89PNG\r\n\x1a\n") and len(data) >= 26:
        return data[25]
    return None


def _check_no_alpha(path: Path, result: ValidationResult) -> None:
    if path.suffix.lower() == ".png" and _png_color_type(path) in {4, 6}:
        result.add_error("IMAGE_ALPHA", "Store image must not contain an alpha channel", path)


def _check_play_screenshot(path: Path, result: ValidationResult) -> None:
    dimensions = _image_dimensions(path)
    if dimensions is None:
        result.add_error("IMAGE_FORMAT", "Screenshot must be a readable PNG or JPEG", path)
        return
    shorter, longer = sorted(dimensions)
    if shorter < 320 or longer > 3840 or longer > 2 * shorter:
        result.add_error(
            "PLAY_SCREENSHOT_SIZE",
            f"Screenshot {dimensions[0]}x{dimensions[1]} violates Play's 320–3840px and 2:1 limits",
            path,
        )
    _check_no_alpha(path, result)


def _resolve_manifest_path(manifest_path: Path, value: str) -> Path:
    return (manifest_path.parent / value).resolve()


def _check_artwork(manifest_path: Path, result: ValidationResult) -> None:
    manifest = _read_json(manifest_path, result)
    for asset in manifest.get("assets", []):
        if not isinstance(asset, dict) or not asset.get("required"):
            continue
        asset_id = str(asset.get("id", "unknown"))
        path_value = asset.get("path")
        directory_value = asset.get("directory")
        if isinstance(path_value, str):
            path = _resolve_manifest_path(manifest_path, path_value)
            if not path.is_file():
                result.add_gate("ARTWORK_MISSING", f"Required artwork is missing: {asset_id}", path)
                continue
            dimensions = _image_dimensions(path)
            expected = (asset.get("width"), asset.get("height"))
            if all(isinstance(value, int) for value in expected) and dimensions != expected:
                result.add_error("ARTWORK_SIZE", f"Expected {expected[0]}x{expected[1]}, found {dimensions}", path)
            max_bytes = asset.get("max_bytes")
            if isinstance(max_bytes, int) and path.stat().st_size > max_bytes:
                result.add_error("ARTWORK_BYTES", f"File exceeds {max_bytes} bytes", path)
            format_rule = str(asset.get("format", "")).lower()
            if "with alpha" in format_rule and _png_color_type(path) != 6:
                result.add_error("IMAGE_FORMAT", "Expected a 32-bit truecolor PNG with alpha", path)
            if "without alpha" in format_rule:
                _check_no_alpha(path, result)
        elif isinstance(directory_value, str):
            directory = _resolve_manifest_path(manifest_path, directory_value)
            images = [] if not directory.is_dir() else [
                path for path in directory.iterdir()
                if path.is_file() and path.suffix.lower() in {".png", ".jpg", ".jpeg"}
            ]
            minimum = int(asset.get("minimum_count", 1))
            if len(images) < minimum:
                result.add_gate(
                    "SCREENSHOTS_MISSING",
                    f"{asset_id} needs at least {minimum} image(s); found {len(images)}",
                    directory,
                )
            if len(images) > 8:
                result.add_error("PLAY_SCREENSHOT_COUNT", f"Play accepts at most 8 screenshots per device type; found {len(images)}", directory)
            for image in images:
                _check_play_screenshot(image, result)
        else:
            status = asset.get("status")
            if status != "approved":
                result.add_gate("ARTWORK_GATE", f"Required artifact is not approved: {asset_id}", manifest_path)


def _check_apple_screenshots(manifest_path: Path, result: ValidationResult) -> None:
    manifest = _read_json(manifest_path, result)
    for screenshot_set in manifest.get("sets", []):
        if not isinstance(screenshot_set, dict) or not screenshot_set.get("required"):
            continue
        directory = _resolve_manifest_path(manifest_path, str(screenshot_set.get("directory", "")))
        accepted = {
            tuple(int(part) for part in value.split("x"))
            for value in screenshot_set.get("accepted_portrait_sizes", [])
            if re.fullmatch(r"\d+x\d+", str(value))
        }
        matches = []
        if directory.is_dir():
            for path in directory.iterdir():
                if path.suffix.lower() in {".png", ".jpg", ".jpeg"}:
                    if _image_dimensions(path) in accepted:
                        matches.append(path)
                    _check_no_alpha(path, result)
            all_images = [path for path in directory.iterdir() if path.suffix.lower() in {".png", ".jpg", ".jpeg"}]
            if len(all_images) > 10:
                result.add_error("APPLE_SCREENSHOT_COUNT", f"Apple accepts at most 10 screenshots; found {len(all_images)}", directory)
        if not matches:
            result.add_gate(
                "SCREENSHOTS_MISSING",
                f"No screenshot matches required set {screenshot_set.get('id')}",
                directory,
            )
    icon_gate = manifest.get("binary_icon_gate")
    if isinstance(icon_gate, dict) and icon_gate.get("status") != "approved":
        result.add_gate("IOS_ICON_GATE", str(icon_gate.get("requirement", "Verify the archive app icon")), manifest_path)
    elif isinstance(icon_gate, str) and icon_gate:
        result.add_gate("IOS_ICON_GATE", icon_gate, manifest_path)


def _check_approvals(
    path: Path,
    result: ValidationResult,
    *,
    excluded_ids: set[str] | None = None,
) -> None:
    data = _read_json(path, result)
    approvals = data.get("approvals")
    if not isinstance(approvals, list) or not approvals:
        result.add_error("APPROVALS_SCHEMA", "Approvals must be a non-empty list", path)
        return
    seen: set[str] = set()
    for approval in approvals:
        if not isinstance(approval, dict) or not isinstance(approval.get("id"), str):
            result.add_error("APPROVALS_SCHEMA", "Each approval needs a string id", path)
            continue
        approval_id = approval["id"]
        if approval_id in seen:
            result.add_error("APPROVAL_DUPLICATE", f"Duplicate approval id: {approval_id}", path)
        seen.add(approval_id)
        if excluded_ids and approval_id in excluded_ids:
            continue
        if approval.get("status") != "approved":
            result.add_gate("APPROVAL_PENDING", f"Approval is not complete: {approval_id}", path)
        elif not all(approval.get(key) for key in ("approver", "approved_at", "evidence")):
            result.add_error("APPROVAL_EVIDENCE", f"Approved item lacks approver/date/evidence: {approval_id}", path)


def _check_portal_values(
    path: Path,
    result: ValidationResult,
    *,
    sections: set[str] | None = None,
    keys: dict[str, set[str]] | None = None,
) -> None:
    data = _read_json(path, result)
    for store_name, values in data.items():
        if store_name in {"schema_version", "status", "warning"}:
            continue
        if sections is not None and store_name not in sections:
            continue
        if not isinstance(values, dict):
            result.add_error("PORTAL_SCHEMA", f"{store_name} must be an object", path)
            continue
        for key, value in values.items():
            if keys is not None and key not in keys.get(store_name, set()):
                continue
            if value is None or value == [] or value == "":
                result.add_gate("PORTAL_VALUE_PENDING", f"Portal value not recorded: {store_name}.{key}", path)


def _check_policy_blockers(path: Path, result: ValidationResult) -> None:
    data = _read_json(path, result)
    for key in ("blocking_classifications", "blocking_items"):
        for item in data.get(key, []):
            if isinstance(item, dict) and item.get("status") == "blocking":
                result.add_gate(
                    "POLICY_BLOCKING",
                    f"{item.get('id', 'unnamed')}: {item.get('required_outcome', item.get('question', 'resolve policy item'))}",
                    path,
                )


def _play_metadata(root: Path, locales: set[str], version_code: int, result: ValidationResult) -> list[Path]:
    metadata_root = root / "android" / "fastlane" / "metadata" / "android"
    actual = {
        path.name
        for path in metadata_root.iterdir()
        if path.is_dir() and any(path.rglob("*.txt"))
    } if metadata_root.is_dir() else set()
    if actual != locales:
        result.add_error("PLAY_LOCALES", f"Expected upload locales {sorted(locales)}, found {sorted(actual)}", metadata_root)
    text_paths: list[Path] = []
    for locale in sorted(locales):
        locale_dir = metadata_root / locale
        title = locale_dir / "title.txt"
        short = locale_dir / "short_description.txt"
        full = locale_dir / "full_description.txt"
        changelog = locale_dir / "changelogs" / f"{version_code}.txt"
        _require_files([title, short, full, changelog], result)
        if title.is_file():
            _check_text_limit(title, 30, result)
        if short.is_file():
            _check_text_limit(short, 80, result)
        if full.is_file():
            _check_text_limit(full, 4000, result)
        if changelog.is_file():
            _check_text_limit(changelog, 500, result)
        text_paths.extend([title, short, full, changelog])
    return text_paths


def _validate_mobile_play(result: ValidationResult) -> None:
    required = [
        STORE_DIR / "README.md",
        STORE_DIR / "release_package.json",
        STORE_DIR / "approvals.json",
        STORE_DIR / "portal_values.template.json",
        STORE_DIR / "official_sources.md",
        STORE_DIR / "source_evidence.md",
        STORE_DIR / "privacy_policy.html",
        STORE_DIR / "release_policy_assessment.md",
        STORE_DIR / "play_store" / "listing.md",
        STORE_DIR / "play_store" / "data_safety.md",
        STORE_DIR / "play_store" / "app_content_answers.md",
        STORE_DIR / "play_store" / "reviewer_access.md",
        STORE_DIR / "play_store" / "payments_rewards_ugc_decisions.md",
        STORE_DIR / "play_store" / "artwork_manifest.json",
        STORE_DIR / "play_store" / "localization_status.json",
        STORE_DIR / "play_store" / "portal_entry_checklist.md",
        MOBILE_DIR / "android" / "fastlane" / "Appfile",
        MOBILE_DIR / "android" / "fastlane" / "Fastfile",
        MOBILE_DIR / "android" / "fastlane" / "README.md",
    ]
    _require_files(required, result)
    package = _read_json(STORE_DIR / "release_package.json", result)
    version = _pubspec_version(MOBILE_DIR / "pubspec.yaml", result)
    mobile = package.get("mobile", {})
    if version and (mobile.get("version_name"), mobile.get("build_number")) != version:
        result.add_error("VERSION_MISMATCH", f"Package records {mobile.get('version_name')}+{mobile.get('build_number')}, pubspec records {version[0]}+{version[1]}", STORE_DIR / "release_package.json")
    gradle = _read_text(MOBILE_DIR / "android" / "app" / "build.gradle.kts", result)
    if mobile.get("android_package") not in gradle:
        result.add_error("PACKAGE_MISMATCH", "Android package is not present in build configuration", MOBILE_DIR / "android" / "app" / "build.gradle.kts")
    texts = _play_metadata(MOBILE_DIR, {"en-US", "fr-FR"}, 5, result)
    _check_copy(texts, result)
    source_only = STORE_DIR / "source_localizations" / "rw-RW" / "google_play"
    _require_files([source_only / "title.txt", source_only / "short_description.txt", source_only / "full_description.txt", source_only / "changelog_5.txt"], result)


def _validate_app_store(result: ValidationResult) -> None:
    required = [
        STORE_DIR / "app_store" / "listing.md",
        STORE_DIR / "app_store" / "privacy_nutrition.md",
        STORE_DIR / "app_store" / "age_rating_answers.md",
        STORE_DIR / "app_store" / "app_review_information.md",
        STORE_DIR / "app_store" / "export_compliance.md",
        STORE_DIR / "app_store" / "content_rights_payments_and_dsa.md",
        STORE_DIR / "app_store" / "artwork_manifest.json",
        STORE_DIR / "app_store" / "localization_status.json",
        STORE_DIR / "app_store" / "portal_entry_checklist.md",
        MOBILE_DIR / "ios" / "fastlane" / "Appfile",
        MOBILE_DIR / "ios" / "fastlane" / "Fastfile",
        MOBILE_DIR / "ios" / "fastlane" / "README.md",
    ]
    _require_files(required, result)
    package = _read_json(STORE_DIR / "release_package.json", result)
    mobile = package.get("mobile", {})
    pbxproj = _read_text(MOBILE_DIR / "ios" / "Runner.xcodeproj" / "project.pbxproj", result)
    if mobile.get("ios_bundle_id") not in pbxproj:
        result.add_error("BUNDLE_MISMATCH", "iOS bundle identifier is not present in Xcode project", MOBILE_DIR / "ios" / "Runner.xcodeproj" / "project.pbxproj")
    metadata_root = MOBILE_DIR / "ios" / "fastlane" / "metadata"
    locales = {
        path.name
        for path in metadata_root.iterdir()
        if path.is_dir() and any(path.rglob("*.txt"))
    } if metadata_root.is_dir() else set()
    expected_locales = {"en-US", "fr-FR"}
    if locales != expected_locales:
        result.add_error("APPLE_LOCALES", f"Expected upload locales {sorted(expected_locales)}, found {sorted(locales)}", metadata_root)
    texts: list[Path] = []
    for locale in sorted(expected_locales):
        locale_dir = metadata_root / locale
        fields = {
            "name.txt": (30, False),
            "subtitle.txt": (30, False),
            "promotional_text.txt": (170, False),
            "description.txt": (4000, False),
            "keywords.txt": (100, True),
            "release_notes.txt": (4000, False),
        }
        url_names = ["privacy_url.txt", "support_url.txt", "marketing_url.txt"]
        _require_files([locale_dir / name for name in [*fields, *url_names]], result)
        for name, (limit, byte_limit) in fields.items():
            path = locale_dir / name
            if path.is_file():
                _check_text_limit(path, limit, result, byte_limit=byte_limit)
                texts.append(path)
        for name in url_names:
            path = locale_dir / name
            if path.is_file():
                _check_url_file(path, result)
    _check_copy(texts, result)
    source_only = STORE_DIR / "source_localizations" / "rw-RW" / "app_store"
    _require_files([source_only / name for name in ("name.txt", "subtitle.txt", "promotional_text.txt", "description.txt", "keywords.txt", "release_notes.txt")], result)


def _validate_tv_play(result: ValidationResult) -> None:
    store = TV_DIR / "store_metadata"
    required = [
        store / "README.md",
        store / "listing.md",
        store / "release_package.json",
        store / "approvals.json",
        store / "portal_values.template.json",
        store / "data_safety.md",
        store / "app_content_answers.md",
        store / "reviewer_access.md",
        store / "artwork_manifest.json",
        store / "localization_status.json",
        store / "portal_entry_checklist.md",
        store / "official_sources.md",
        store / "source_evidence.md",
        TV_DIR / "android" / "fastlane" / "Appfile",
        TV_DIR / "android" / "fastlane" / "Fastfile",
        TV_DIR / "android" / "fastlane" / "README.md",
    ]
    _require_files(required, result)
    package = _read_json(store / "release_package.json", result)
    app = package.get("app", {})
    version = _pubspec_version(TV_DIR / "pubspec.yaml", result)
    if version and (app.get("version_name"), app.get("version_code")) != version:
        result.add_error("TV_VERSION_MISMATCH", f"Package records {app.get('version_name')}+{app.get('version_code')}, pubspec records {version[0]}+{version[1]}", store / "release_package.json")
    gradle = _read_text(TV_DIR / "android" / "app" / "build.gradle.kts", result)
    if app.get("package_name") not in gradle:
        result.add_error("TV_PACKAGE_MISMATCH", "TV package is not present in build configuration", TV_DIR / "android" / "app" / "build.gradle.kts")
    manifest = _read_text(TV_DIR / "android" / "app" / "src" / "main" / "AndroidManifest.xml", result)
    for value in ("android.software.leanback", 'android.hardware.touchscreen', 'android:required="false"'):
        if value not in manifest:
            result.add_error("TV_MANIFEST", f"Required Android TV manifest contract missing: {value}", TV_DIR / "android" / "app" / "src" / "main" / "AndroidManifest.xml")
    texts = _play_metadata(TV_DIR, {"en-US", "fr-FR"}, 1, result)
    _check_copy(texts, result)
    club_config = _read_text(
        TV_DIR.parent.parent / "packages" / "clubs" / "club_rayon_sports" / "lib" / "src" / "rayon_sports_config.dart",
        result,
    )
    main_dart = _read_text(TV_DIR / "lib" / "main.dart", result)
    if "String get language => 'rw'" not in club_config:
        result.add_error("TV_LOCALE_FACT", "Expected the audited Rayon production content locale to be rw", TV_DIR / "lib" / "main.dart")
    if "appLocale.languageCode == 'rw' ? const Locale('en')" not in main_dart:
        result.add_error("TV_LOCALE_FACT", "Expected the audited English Material fallback for rw", TV_DIR / "lib" / "main.dart")
    source_only = store / "source_localizations" / "rw-RW"
    _require_files(
        [
            source_only / "README.md",
            source_only / "title.txt",
            source_only / "short_description.txt",
            source_only / "full_description.txt",
            source_only / "changelog_1.txt",
        ],
        result,
    )


PREUPLOAD_PORTAL_KEYS = {
    "google_play": {
        "developer_account_type",
        "developer_account_verified",
        "app_record_exists",
        "play_console_app_id",
        "play_app_signing_enrolled",
        "registered_upload_certificate_sha256",
        "play_app_signing_certificate_sha256",
        "version_code_available",
        "managed_private_distribution_confirmed",
        "organization_ids_or_managed_configuration_complete",
    },
    "app_store_connect": {
        "organization_membership_active",
        "app_record_exists",
        "apple_id",
        "sku",
        "bundle_id_registered",
        "build_number_available",
        "agreements_active",
        "tax_and_banking_complete_if_required",
    },
}


def validate(
    surfaces: set[str],
    release_ready: bool = False,
    submission_ready: bool = False,
) -> ValidationResult:
    result = ValidationResult()
    if MOBILE_PLAY in surfaces:
        _validate_mobile_play(result)
    if APP_STORE in surfaces:
        _validate_app_store(result)
    if TV_PLAY in surfaces:
        _validate_tv_play(result)

    roots: list[Path] = []
    if surfaces & {MOBILE_PLAY, APP_STORE}:
        roots.extend([STORE_DIR, MOBILE_DIR / "android" / "fastlane", MOBILE_DIR / "ios" / "fastlane"])
    if TV_PLAY in surfaces:
        roots.extend([TV_DIR / "store_metadata", TV_DIR / "android" / "fastlane"])
    _check_secret_material(roots, result)

    if surfaces & {MOBILE_PLAY, APP_STORE}:
        excluded: set[str] = set()
        if MOBILE_PLAY not in surfaces:
            excluded.add("google_play_release_owner")
        if APP_STORE not in surfaces:
            excluded.add("apple_app_store_release_owner")
        _check_approvals(STORE_DIR / "approvals.json", result, excluded_ids=excluded)
        _check_policy_blockers(STORE_DIR / "release_package.json", result)
        portal_sections: set[str] = set()
        if MOBILE_PLAY in surfaces:
            portal_sections.add("google_play")
        if APP_STORE in surfaces:
            portal_sections.add("app_store_connect")
        portal_keys = PREUPLOAD_PORTAL_KEYS if release_ready and not submission_ready else None
        _check_portal_values(
            STORE_DIR / "portal_values.template.json",
            result,
            sections=portal_sections,
            keys=portal_keys,
        )
    if MOBILE_PLAY in surfaces:
        _check_artwork(STORE_DIR / "play_store" / "artwork_manifest.json", result)
    if APP_STORE in surfaces:
        _check_apple_screenshots(STORE_DIR / "app_store" / "artwork_manifest.json", result)
    if TV_PLAY in surfaces:
        store = TV_DIR / "store_metadata"
        _check_approvals(store / "approvals.json", result)
        _check_policy_blockers(store / "release_package.json", result)
        portal_keys = PREUPLOAD_PORTAL_KEYS if release_ready and not submission_ready else None
        _check_portal_values(store / "portal_values.template.json", result, keys=portal_keys)
        _check_artwork(store / "artwork_manifest.json", result)

    if not (release_ready or submission_ready) and result.gates:
        result.add_warning(
            "RELEASE_NOT_READY",
            f"Repository package is draft-controlled; {len(result.gates)} release gate(s) remain. Use --release-ready to enforce them.",
        )
    return result


def _selected_surfaces(args: argparse.Namespace) -> set[str]:
    if args.surface:
        return {args.surface}
    if args.mobile_only:
        return {MOBILE_PLAY, APP_STORE}
    if args.tv_only:
        return {TV_PLAY}
    return set(ALL_SURFACES)


def _print_text(result: ValidationResult, enforce_gates: bool) -> None:
    for label, findings in (("ERROR", result.errors), ("GATE", result.gates), ("WARNING", result.warnings)):
        for finding in findings:
            location = f" [{finding.path}]" if finding.path else ""
            print(f"{label} {finding.code}{location}: {finding.message}")
    if result.valid(enforce_gates):
        if result.gates:
            print(f"PASS: repository package is internally consistent; {len(result.gates)} release gate(s) remain")
        else:
            print("PASS: selected store package is release-ready by repository-owned checks")
    else:
        print(f"FAIL: {len(result.errors)} structural error(s), {len(result.gates)} release gate(s)")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    selection = parser.add_mutually_exclusive_group()
    selection.add_argument("--mobile-only", action="store_true", help="Validate mobile Play and App Store packages")
    selection.add_argument("--tv-only", action="store_true", help="Validate only the Android TV package")
    selection.add_argument("--surface", choices=sorted(ALL_SURFACES), help="Validate one upload surface")
    parser.add_argument("--release-ready", action="store_true", help="Fail on pending external/approval/artwork gates")
    parser.add_argument("--submission-ready", action="store_true", help="Fail unless post-upload portal and submission evidence is complete")
    parser.add_argument("--json", action="store_true", help="Print machine-readable findings")
    args = parser.parse_args(argv)
    surfaces = _selected_surfaces(args)
    if args.release_ready and args.submission_ready:
        parser.error("choose either --release-ready or --submission-ready")
    enforce_gates = args.release_ready or args.submission_ready
    result = validate(
        surfaces,
        release_ready=args.release_ready,
        submission_ready=args.submission_ready,
    )
    if args.json:
        print(json.dumps({
            "surfaces": sorted(surfaces),
            "release_ready": args.release_ready,
            "submission_ready": args.submission_ready,
            "valid": result.valid(enforce_gates),
            "errors": [asdict(item) for item in result.errors],
            "gates": [asdict(item) for item in result.gates],
            "warnings": [asdict(item) for item in result.warnings],
        }, indent=2))
    else:
        _print_text(result, enforce_gates)
    return 0 if result.valid(enforce_gates) else 2


if __name__ == "__main__":
    sys.exit(main())
