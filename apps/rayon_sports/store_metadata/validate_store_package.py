#!/usr/bin/env python3
"""Validate Gikundiro mobile store-delivery packages.

The default mode checks repository-owned structure and copy. Release-ready mode
also enforces artwork, portal-value, policy-decision, and accountable-approval
gates. It never calls a store API and never treats local validation as review or
publication evidence.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import plistlib
import re
import struct
import sys
import zipfile
from dataclasses import asdict, dataclass, field
from pathlib import Path
from typing import Any, Iterable
from urllib.parse import urlparse
from xml.etree import ElementTree


STORE_DIR = Path(__file__).resolve().parent
MOBILE_DIR = STORE_DIR.parent
MOBILE_PLAY = "mobile-play"
APP_STORE = "app-store"
ALL_SURFACES = {MOBILE_PLAY, APP_STORE}


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
            if status not in {"approved", "verified_in_production_aab"}:
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
    if isinstance(icon_gate, dict) and icon_gate.get("status") not in {
        "approved",
        "archive_icon_presence_verified",
    }:
        result.add_gate(
            "IOS_ICON_GATE",
            str(icon_gate.get("requirement", "Verify the archive app icon")),
            manifest_path,
        )
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
        if approval.get("status") == "not_applicable_candidate_disabled":
            if not approval.get("evidence"):
                result.add_error(
                    "APPROVAL_NOT_APPLICABLE_EVIDENCE",
                    f"Disabled/not-applicable item lacks evidence: {approval_id}",
                    path,
                )
            continue
        if approval.get("status") != "approved":
            result.add_gate("APPROVAL_PENDING", f"Approval is not complete: {approval_id}", path)
        elif not all(approval.get(key) for key in ("approver", "approved_at", "evidence")):
            result.add_error("APPROVAL_EVIDENCE", f"Approved item lacks approver/date/evidence: {approval_id}", path)


def _check_artwork_approval_alignment(
    manifest_path: Path,
    approvals_path: Path,
    result: ValidationResult,
) -> None:
    manifest = _read_json(manifest_path, result)
    approval_data = _read_json(approvals_path, result)
    required = manifest.get("approvals_required")
    approvals = approval_data.get("approvals")
    if not isinstance(required, list) or not required or not all(isinstance(item, str) for item in required):
        result.add_error(
            "ARTWORK_APPROVALS_SCHEMA",
            "Artwork manifest approvals_required must be a non-empty string array",
            manifest_path,
        )
        return
    if len(required) != len(set(required)):
        result.add_error("ARTWORK_APPROVALS_DUPLICATE", "Artwork approval ids must be unique", manifest_path)
    available = {
        item["id"]
        for item in approvals or []
        if isinstance(item, dict) and isinstance(item.get("id"), str)
    }
    if set(required) != available:
        result.add_error(
            "ARTWORK_APPROVALS_MISMATCH",
            f"Artwork approvals {sorted(set(required))} do not match controlled approvals {sorted(available)}",
            manifest_path,
        )
    if "rayon_brand_and_content_rights" not in required:
        result.add_error(
            "ARTWORK_RIGHTS_APPROVAL_MISSING",
            "Artwork manifest must require rayon_brand_and_content_rights",
            manifest_path,
        )


def _check_checksum_manifest(path: Path, result: ValidationResult) -> None:
    repository_root = MOBILE_DIR.parent.parent.resolve()
    text = _read_text(path, result)
    for line_number, line in enumerate(text.splitlines(), start=1):
        match = re.fullmatch(r"([0-9a-f]{64})  (.+)", line)
        if not match:
            result.add_error("CHECKSUM_SCHEMA", f"Invalid SHA-256 record on line {line_number}", path)
            continue
        target = (repository_root / match.group(2)).resolve()
        try:
            target.relative_to(repository_root)
        except ValueError:
            result.add_error("CHECKSUM_PATH", f"Checksum target escapes repository on line {line_number}", path)
            continue
        if not target.is_file():
            result.add_error("CHECKSUM_FILE_MISSING", f"Checksum target is missing on line {line_number}", target)
            continue
        actual = _sha256_file(target)
        if actual != match.group(1):
            result.add_error(
                "CHECKSUM_MISMATCH",
                f"Expected {match.group(1)}, found {actual}",
                target,
            )


def _sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


PORTAL_TRUE_PROOF_KEYS = {
    "google_play": {
        "developer_account_verified",
        "app_record_exists",
        "play_app_signing_enrolled",
        "version_code_available",
        "internal_testing_track_verified",
        "required_closed_test_completed",
        "reviewer_access_configured",
        "data_safety_published",
        "app_content_forms_complete",
        "artifact_uploaded",
        "aab_uploaded",
    },
    "app_store_connect": {
        "organization_membership_active",
        "app_record_exists",
        "bundle_id_registered",
        "build_number_available",
        "agreements_active",
        "tax_and_banking_complete_if_required",
        "dsa_trader_status_complete",
        "reviewer_access_configured",
        "app_privacy_published",
        "build_uploaded",
        "testflight_validation_complete",
    },
}

PORTAL_EXPLICIT_NOT_REQUIRED_PROOF_KEYS = {
    "app_store_connect": {
        "tax_and_banking_complete_if_required",
    }
}

PORTAL_PROCESSING_PROOFS = {
    "google_play": {
        ("artifact_processing_status",),
        ("aab_processing_status",),
        ("verified_receipt", "tester_availability"),
    },
    "app_store_connect": {
        ("build_processing_status",),
        ("verified_receipt", "processing_state"),
        ("verified_receipt", "build_store_eligibility"),
    },
}

PORTAL_SUBMISSION_PROOFS = {
    "google_play": {
        ("submission_status",),
        ("verified_receipt", "dashboard_status"),
    },
    "app_store_connect": {
        ("submission_status",),
        ("verified_receipt", "review_submission_state"),
    },
}

PORTAL_NESTED_TRUE_PROOFS = {
    "google_play": {
        ("verified_receipt", "valid_candidate_aab_present"),
        ("verified_receipt", "publishing_overview", "submit_enabled"),
    },
    "app_store_connect": {
        ("verified_receipt", "build_attached_to_version"),
        ("verified_receipt", "version_item_attached_to_review_submission"),
        ("verified_receipt", "submit_for_review_completed"),
    },
}

PORTAL_COMPLETION_ONLY_PROOFS = {
    "google_play": {
        ("verified_receipt", "upload_key_reset", "status"),
    },
    "app_store_connect": set(),
}

PORTAL_BLOCKING_STATUS_MARKERS = (
    "BLOCKED",
    "DRAFT",
    "ERROR",
    "FAILED",
    "INCOMPLETE",
    "NOT_",
    "_NOT_",
    "PENDING",
    "REJECTED",
    "UNAVAILABLE",
)
PORTAL_PROCESSING_STATUS_MARKERS = (
    "AVAILABLE",
    "COMPLETE",
    "ELIGIBLE",
    "PROCESSED",
    "READY",
    "VALID",
)
PORTAL_SUBMISSION_STATUS_MARKERS = (
    "APPROVED",
    "CHANGES_IN_REVIEW",
    "IN_REVIEW",
    "PUBLISHED",
    "READY_FOR_SALE",
    "RELEASED",
    "SUBMITTED",
    "UNDER_REVIEW",
    "WAITING_FOR_REVIEW",
)
PORTAL_COMPLETION_STATUS_MARKERS = (
    "ACTIVE",
    "APPROVED",
    "COMPLETE",
    "COMPLETED",
    "CONFIRMED",
    "VERIFIED",
)


_PORTAL_MISSING = object()


def _portal_path_value(values: dict[str, Any], parts: tuple[str, ...]) -> Any:
    current: Any = values
    for part in parts:
        if not isinstance(current, dict) or part not in current:
            return _PORTAL_MISSING
        current = current[part]
    return current


def _portal_path_label(store_name: str, parts: tuple[str, ...]) -> str:
    return ".".join((store_name, *parts))


def _portal_status_is_complete(value: Any, positive_markers: tuple[str, ...]) -> bool:
    if not isinstance(value, str) or not value.strip():
        return False
    normalized = re.sub(r"[^A-Z0-9]+", "_", value.upper()).strip("_")
    if any(marker in normalized for marker in PORTAL_BLOCKING_STATUS_MARKERS):
        return False
    return any(marker in normalized for marker in positive_markers)


def _portal_boolean_proof_is_complete(store_name: str, key: str, value: Any) -> bool:
    if value is True:
        return True
    if key not in PORTAL_EXPLICIT_NOT_REQUIRED_PROOF_KEYS.get(store_name, set()):
        return False
    normalized = re.sub(r"[^A-Z0-9]+", "_", str(value).upper()).strip("_")
    return bool(re.fullmatch(r"NOT_REQUIRED(?:_[A-Z0-9]+)+", normalized))


def _check_portal_values(
    path: Path,
    result: ValidationResult,
    *,
    sections: set[str] | None = None,
    keys: dict[str, set[str]] | None = None,
    require_submission: bool = False,
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
        selected_keys = set(values) if keys is None else keys.get(store_name, set())
        for key in sorted(selected_keys - set(values)):
            result.add_gate(
                "PORTAL_VALUE_PENDING",
                f"Portal value not recorded: {store_name}.{key}",
                path,
            )
        for key in sorted(selected_keys & set(values)):
            value = values[key]
            if value is None or value == [] or value == "":
                result.add_gate("PORTAL_VALUE_PENDING", f"Portal value not recorded: {store_name}.{key}", path)
                continue
            if key in PORTAL_TRUE_PROOF_KEYS.get(store_name, set()) and not _portal_boolean_proof_is_complete(
                store_name,
                key,
                value,
            ):
                result.add_gate(
                    "PORTAL_PROOF_INCOMPLETE",
                    f"Portal completion proof {store_name}.{key} must be true; found {value!r}",
                    path,
                )

        if not require_submission:
            continue
        for parts in sorted(PORTAL_NESTED_TRUE_PROOFS.get(store_name, set())):
            if parts[0] not in selected_keys:
                continue
            value = _portal_path_value(values, parts)
            if value is not _PORTAL_MISSING and value is not True:
                result.add_gate(
                    "PORTAL_PROOF_INCOMPLETE",
                    f"Portal completion proof {_portal_path_label(store_name, parts)} must be true; found {value!r}",
                    path,
                )
        status_proofs = (
            (PORTAL_PROCESSING_PROOFS, PORTAL_PROCESSING_STATUS_MARKERS),
            (PORTAL_SUBMISSION_PROOFS, PORTAL_SUBMISSION_STATUS_MARKERS),
            (PORTAL_COMPLETION_ONLY_PROOFS, PORTAL_COMPLETION_STATUS_MARKERS),
        )
        for proof_map, positive_markers in status_proofs:
            for parts in sorted(proof_map.get(store_name, set())):
                if parts[0] not in selected_keys:
                    continue
                value = _portal_path_value(values, parts)
                if value is _PORTAL_MISSING:
                    continue
                if not _portal_status_is_complete(value, positive_markers):
                    result.add_gate(
                        "PORTAL_PROOF_INCOMPLETE",
                        f"Portal completion proof {_portal_path_label(store_name, parts)} is not complete: {value!r}",
                        path,
                    )


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


def _check_disabled_candidate_alignment(
    release_path: Path,
    approvals_path: Path,
    result: ValidationResult,
) -> None:
    release = _read_json(release_path, result)
    approvals = _read_json(approvals_path, result)
    policy_status = {
        item.get("id"): item.get("status")
        for item in release.get("blocking_classifications", [])
        if isinstance(item, dict)
    }
    approval_status = {
        item.get("id"): item.get("status")
        for item in approvals.get("approvals", [])
        if isinstance(item, dict)
    }
    for policy_id in ("POLICY-PAYMENTS-01", "POLICY-REWARDS-01", "POLICY-UGC-01"):
        if policy_status.get(policy_id) != "not_applicable_candidate_disabled":
            result.add_error(
                "CANDIDATE_POLICY_ALIGNMENT",
                f"{policy_id} must record the evidence-backed disabled candidate status",
                release_path,
            )
    for approval_id in (
        "payments_and_digital_goods",
        "rewards_contests_and_gambling",
        "ugc_and_moderation",
    ):
        if approval_status.get(approval_id) != "not_applicable_candidate_disabled":
            result.add_error(
                "CANDIDATE_APPROVAL_ALIGNMENT",
                f"{approval_id} must match the disabled candidate classification",
                approvals_path,
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


def _resolve_release_artifact(
    artifact_path: Path,
    expected_path: Path,
    result: ValidationResult,
    *,
    code_prefix: str,
) -> Path | None:
    try:
        resolved = artifact_path.expanduser().resolve(strict=True)
    except OSError as exc:
        result.add_error(
            f"{code_prefix}_FILE_MISSING",
            f"Release artifact is missing or unreadable: {exc}",
            artifact_path,
        )
        return None
    if not resolved.is_file() or resolved.stat().st_size == 0:
        result.add_error(
            f"{code_prefix}_FILE_INVALID",
            "Release artifact must be a non-empty regular file",
            resolved,
        )
        return None
    expected = expected_path.expanduser().resolve()
    if resolved != expected:
        result.add_error(
            f"{code_prefix}_PATH_MISMATCH",
            f"Validated artifact path {resolved} does not match controlled upload path {expected}",
            resolved,
        )
    return resolved


def _single_metadata_element(
    metadata: dict[str, Any],
    label: str,
    path: Path,
    result: ValidationResult,
) -> dict[str, Any] | None:
    elements = metadata.get("elements")
    if not isinstance(elements, list) or len(elements) != 1 or not isinstance(elements[0], dict):
        result.add_error(
            "AAB_BUILD_METADATA",
            f"{label} must describe exactly one release artifact",
            path,
        )
        return None
    return elements[0]


def _normalized_certificate(value: Any) -> str:
    return re.sub(r"[^0-9A-F]", "", str(value).upper())


def _check_android_portal_artifact_evidence(
    portal_path: Path,
    mobile: dict[str, Any],
    result: ValidationResult,
) -> dict[str, Any] | None:
    portal = _read_json(portal_path, result)
    google_play = portal.get("google_play")
    if not isinstance(google_play, dict):
        result.add_error("AAB_EVIDENCE_SCHEMA", "google_play portal evidence must be an object", portal_path)
        return None
    receipt = google_play.get("verified_receipt")
    if not isinstance(receipt, dict):
        result.add_error("AAB_EVIDENCE_SCHEMA", "Google Play verified_receipt must be an object", portal_path)
        return None
    candidate = receipt.get("candidate_aab")
    if not isinstance(candidate, dict):
        result.add_error("AAB_EVIDENCE_SCHEMA", "Google Play candidate_aab must be an object", portal_path)
        return None

    comparisons = (
        (receipt.get("package_name"), mobile.get("android_package"), "receipt package name"),
        (
            receipt.get("intended_candidate_version_name"),
            mobile.get("version_name"),
            "receipt version name",
        ),
        (
            receipt.get("intended_candidate_version_code"),
            mobile.get("build_number"),
            "receipt version code",
        ),
        (
            candidate.get("embedded_package_name"),
            mobile.get("android_package"),
            "embedded package name",
        ),
        (
            candidate.get("embedded_version_name"),
            mobile.get("version_name"),
            "embedded version name",
        ),
        (
            candidate.get("embedded_version_code"),
            mobile.get("build_number"),
            "embedded version code",
        ),
    )
    for actual, expected, label in comparisons:
        if str(actual) != str(expected):
            result.add_error(
                "AAB_EVIDENCE_MISMATCH",
                f"Google Play {label} must match the controlled release: expected {expected}, found {actual}",
                portal_path,
            )
    registered_certificate = google_play.get("registered_upload_certificate_sha256")
    candidate_certificate = candidate.get("upload_certificate_sha256")
    if not _normalized_certificate(registered_certificate) or (
        _normalized_certificate(candidate_certificate)
        != _normalized_certificate(registered_certificate)
    ):
        result.add_error(
            "AAB_CERTIFICATE_MISMATCH",
            "Candidate AAB upload certificate must match the registered Play upload certificate",
            portal_path,
        )
    return candidate


def _check_android_build_metadata(
    app_dir: Path,
    artifact: Path,
    mobile: dict[str, Any],
    result: ValidationResult,
) -> None:
    merged_metadata_path = (
        app_dir
        / "build/app/intermediates/merged_manifests/release/processReleaseManifest/output-metadata.json"
    )
    bundle_metadata_path = (
        app_dir
        / "build/app/intermediates/bundle_ide_model/release/produceReleaseBundleIdeListingFile/output-metadata.json"
    )
    merged = _read_json(merged_metadata_path, result)
    bundle = _read_json(bundle_metadata_path, result)
    for metadata, path, expected_type in (
        (merged, merged_metadata_path, "MERGED_MANIFESTS"),
        (bundle, bundle_metadata_path, "BUNDLE"),
    ):
        if metadata.get("artifactType", {}).get("type") != expected_type:
            result.add_error(
                "AAB_BUILD_METADATA",
                f"Expected {expected_type} release metadata",
                path,
            )
        if metadata.get("variantName") != "release":
            result.add_error("AAB_BUILD_METADATA", "Android artifact metadata must use the release variant", path)
        if metadata.get("applicationId") != mobile.get("android_package"):
            result.add_error(
                "AAB_PACKAGE_MISMATCH",
                f"Android artifact metadata package must be {mobile.get('android_package')}",
                path,
            )

    bundle_element = _single_metadata_element(bundle, "Bundle output metadata", bundle_metadata_path, result)
    if bundle_element is not None:
        output_file = bundle_element.get("outputFile")
        if not isinstance(output_file, str) or not output_file:
            result.add_error("AAB_BUILD_METADATA", "Bundle output metadata has no outputFile", bundle_metadata_path)
        elif (bundle_metadata_path.parent / output_file).resolve() != artifact:
            result.add_error(
                "AAB_PATH_MISMATCH",
                "The validated AAB is not the exact release artifact named by bundle metadata",
                artifact,
            )

    merged_element = _single_metadata_element(merged, "Merged-manifest metadata", merged_metadata_path, result)
    if merged_element is None:
        return
    for key, expected in (
        ("versionName", mobile.get("version_name")),
        ("versionCode", mobile.get("build_number")),
    ):
        if str(merged_element.get(key)) != str(expected):
            result.add_error(
                "AAB_VERSION_MISMATCH",
                f"Merged-manifest {key} must be {expected}; found {merged_element.get(key)}",
                merged_metadata_path,
            )
    output_file = merged_element.get("outputFile")
    if not isinstance(output_file, str) or not output_file:
        result.add_error("AAB_BUILD_METADATA", "Merged-manifest metadata has no outputFile", merged_metadata_path)
        return
    manifest_path = (merged_metadata_path.parent / output_file).resolve()
    try:
        manifest = ElementTree.parse(manifest_path).getroot()
    except (OSError, ElementTree.ParseError) as exc:
        result.add_error("AAB_BUILD_METADATA", f"Cannot read merged release manifest: {exc}", manifest_path)
        return
    android_namespace = "http://schemas.android.com/apk/res/android"
    manifest_values = (
        (manifest.get("package"), mobile.get("android_package"), "package", "AAB_PACKAGE_MISMATCH"),
        (
            manifest.get(f"{{{android_namespace}}}versionName"),
            mobile.get("version_name"),
            "versionName",
            "AAB_VERSION_MISMATCH",
        ),
        (
            manifest.get(f"{{{android_namespace}}}versionCode"),
            mobile.get("build_number"),
            "versionCode",
            "AAB_VERSION_MISMATCH",
        ),
    )
    for actual, expected, label, code in manifest_values:
        if str(actual) != str(expected):
            result.add_error(
                code,
                f"Merged release manifest {label} must be {expected}; found {actual}",
                manifest_path,
            )


def _check_android_release_artifact(
    portal_path: Path,
    mobile: dict[str, Any],
    artifact_path: Path,
    result: ValidationResult,
    *,
    app_dir: Path = MOBILE_DIR,
) -> None:
    expected_path = app_dir / "build/app/outputs/bundle/release/app-release.aab"
    artifact = _resolve_release_artifact(
        artifact_path,
        expected_path,
        result,
        code_prefix="AAB",
    )
    if artifact is None:
        return
    if not zipfile.is_zipfile(artifact):
        result.add_error("AAB_FILE_INVALID", "Android App Bundle must be a ZIP/JAR artifact", artifact)
        return
    candidate = _check_android_portal_artifact_evidence(portal_path, mobile, result)
    if candidate is not None:
        expected_sha256 = str(candidate.get("sha256", ""))
        if not re.fullmatch(r"[0-9a-f]{64}", expected_sha256):
            result.add_error("AAB_SHA256", "Candidate AAB evidence needs a lowercase SHA-256", portal_path)
        else:
            actual_sha256 = _sha256_file(artifact)
            if actual_sha256 != expected_sha256:
                result.add_error(
                    "AAB_SHA256_MISMATCH",
                    f"Exact upload AAB SHA-256 must be {expected_sha256}; found {actual_sha256}",
                    artifact,
                )
        expected_bytes = candidate.get("bytes")
        if not isinstance(expected_bytes, int) or expected_bytes != artifact.stat().st_size:
            result.add_error(
                "AAB_BYTES_MISMATCH",
                f"Exact upload AAB size must be {expected_bytes}; found {artifact.stat().st_size}",
                artifact,
            )
    _check_android_build_metadata(app_dir, artifact, mobile, result)


def _check_ios_release_artifact(
    manifest_path: Path,
    artwork: dict[str, Any],
    mobile: dict[str, Any],
    artifact_path: Path,
    result: ValidationResult,
) -> None:
    release_artifact = artwork.get("release_artifact")
    if not isinstance(release_artifact, dict):
        result.add_error("IPA_EVIDENCE_SCHEMA", "release_artifact must be an object", manifest_path)
        return
    recorded_path = release_artifact.get("path")
    if not isinstance(recorded_path, str) or not recorded_path:
        result.add_error("IPA_EVIDENCE_SCHEMA", "release_artifact.path must be recorded", manifest_path)
        return
    artifact = _resolve_release_artifact(
        artifact_path,
        _resolve_manifest_path(manifest_path, recorded_path),
        result,
        code_prefix="IPA",
    )
    if artifact is None:
        return
    expected_sha256 = str(release_artifact.get("sha256", ""))
    if not re.fullmatch(r"[0-9a-f]{64}", expected_sha256):
        result.add_error("IPA_SHA256", "App Store artifact provenance needs a lowercase SHA-256", manifest_path)
    else:
        actual_sha256 = _sha256_file(artifact)
        if actual_sha256 != expected_sha256:
            result.add_error(
                "IPA_SHA256_MISMATCH",
                f"Exact upload IPA SHA-256 must be {expected_sha256}; found {actual_sha256}",
                artifact,
            )
    try:
        with zipfile.ZipFile(artifact) as archive:
            info_paths = [
                name
                for name in archive.namelist()
                if re.fullmatch(r"Payload/[^/]+\.app/Info\.plist", name)
            ]
            if len(info_paths) != 1:
                result.add_error(
                    "IPA_STRUCTURE",
                    f"IPA must contain exactly one app Info.plist; found {len(info_paths)}",
                    artifact,
                )
                return
            info = plistlib.loads(archive.read(info_paths[0]))
    except (OSError, KeyError, plistlib.InvalidFileException, zipfile.BadZipFile) as exc:
        result.add_error("IPA_STRUCTURE", f"Cannot inspect IPA Info.plist: {exc}", artifact)
        return
    if not isinstance(info, dict):
        result.add_error("IPA_STRUCTURE", "IPA Info.plist must be a dictionary", artifact)
        return
    comparisons = (
        (info.get("CFBundleIdentifier"), mobile.get("ios_bundle_id"), "bundle identifier", "IPA_BUNDLE_MISMATCH"),
        (
            info.get("CFBundleShortVersionString"),
            mobile.get("version_name"),
            "version name",
            "IPA_VERSION_MISMATCH",
        ),
        (info.get("CFBundleVersion"), mobile.get("build_number"), "build number", "IPA_VERSION_MISMATCH"),
    )
    for actual, expected, label, code in comparisons:
        if str(actual) != str(expected):
            result.add_error(
                code,
                f"Exact upload IPA {label} must be {expected}; found {actual}",
                artifact,
            )


def _check_app_store_portal_artifact_evidence(
    portal_path: Path,
    artwork: dict[str, Any],
    mobile: dict[str, Any],
    result: ValidationResult,
) -> None:
    portal = _read_json(portal_path, result)
    app_store = portal.get("app_store_connect")
    receipt = app_store.get("verified_receipt") if isinstance(app_store, dict) else None
    release_artifact = artwork.get("release_artifact")
    if not isinstance(receipt, dict) or not isinstance(release_artifact, dict):
        result.add_error(
            "IPA_PORTAL_EVIDENCE",
            "App Store submission requires verified receipt and release artifact objects",
            portal_path,
        )
        return
    comparisons = (
        (receipt.get("ipa_sha256"), release_artifact.get("sha256"), "IPA SHA-256"),
        (receipt.get("bundle_id"), mobile.get("ios_bundle_id"), "bundle identifier"),
        (receipt.get("version"), mobile.get("version_name"), "version name"),
        (receipt.get("build_number"), mobile.get("build_number"), "build number"),
    )
    for actual, expected, label in comparisons:
        if str(actual) != str(expected):
            result.add_error(
                "IPA_PORTAL_EVIDENCE",
                f"App Store receipt {label} must match the controlled release: expected {expected}, found {actual}",
                portal_path,
            )


def _validate_mobile_play(
    result: ValidationResult,
    *,
    artifact_path: Path | None = None,
    require_submission: bool = False,
) -> None:
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
        STORE_DIR / "store_media.sha256",
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
    current_build = version[1] if version else int(mobile.get("build_number", 0))
    texts = _play_metadata(MOBILE_DIR, {"en-US", "fr-FR"}, current_build, result)
    _check_copy(texts, result)
    source_only = STORE_DIR / "source_localizations" / "rw-RW" / "google_play"
    _require_files(
        [
            source_only / "title.txt",
            source_only / "short_description.txt",
            source_only / "full_description.txt",
            source_only / f"changelog_{current_build}.txt",
        ],
        result,
    )
    if artifact_path is not None:
        _check_android_release_artifact(
            STORE_DIR / "portal_values.template.json",
            mobile,
            artifact_path,
            result,
        )
    elif require_submission:
        _check_android_portal_artifact_evidence(
            STORE_DIR / "portal_values.template.json",
            mobile,
            result,
        )


def _validate_app_store(
    result: ValidationResult,
    *,
    artifact_path: Path | None = None,
    require_submission: bool = False,
) -> None:
    required = [
        STORE_DIR / "app_store" / "listing.md",
        STORE_DIR / "app_store" / "privacy_nutrition.md",
        STORE_DIR / "app_store" / "age_rating_answers.md",
        STORE_DIR / "app_store" / "app_review_information.md",
        STORE_DIR / "app_store" / "export_compliance.md",
        STORE_DIR / "app_store" / "content_rights_payments_and_dsa.md",
        STORE_DIR / "app_store" / "artwork_manifest.json",
        STORE_DIR / "store_media.sha256",
        STORE_DIR / "app_store" / "localization_status.json",
        STORE_DIR / "app_store" / "portal_entry_checklist.md",
        MOBILE_DIR / "ios" / "fastlane" / "Appfile",
        MOBILE_DIR / "ios" / "fastlane" / "Fastfile",
        MOBILE_DIR / "ios" / "fastlane" / "README.md",
    ]
    _require_files(required, result)
    package = _read_json(STORE_DIR / "release_package.json", result)
    mobile = package.get("mobile", {})
    artwork = _read_json(STORE_DIR / "app_store" / "artwork_manifest.json", result)
    release_artifact = artwork.get("release_artifact", {})
    if (
        release_artifact.get("bundle_id"),
        release_artifact.get("version_name"),
        release_artifact.get("build_number"),
    ) != (
        mobile.get("ios_bundle_id"),
        mobile.get("version_name"),
        mobile.get("build_number"),
    ):
        result.add_error(
            "IPA_VERSION_MISMATCH",
            "App Store artifact provenance must match the current bundle/version/build",
            STORE_DIR / "app_store" / "artwork_manifest.json",
        )
    if not re.fullmatch(r"[0-9a-f]{64}", str(release_artifact.get("sha256", ""))):
        result.add_error(
            "IPA_SHA256",
            "App Store artifact provenance needs a lowercase SHA-256",
            STORE_DIR / "app_store" / "artwork_manifest.json",
        )
    icon_gate = artwork.get("binary_icon_gate", {})
    if not isinstance(icon_gate, dict) or icon_gate.get("status") != "archive_icon_presence_verified":
        result.add_error(
            "IPA_ICON_PROVENANCE",
            "Exact-IPA app-icon presence must be recorded separately from rights approval",
            STORE_DIR / "app_store" / "artwork_manifest.json",
        )
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
    if artifact_path is not None:
        _check_ios_release_artifact(
            STORE_DIR / "app_store" / "artwork_manifest.json",
            artwork,
            mobile,
            artifact_path,
            result,
        )
    if require_submission:
        _check_app_store_portal_artifact_evidence(
            STORE_DIR / "portal_values.template.json",
            artwork,
            mobile,
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

SUBMISSION_PORTAL_KEYS = {
    "google_play": {
        "developer_account_type",
        "developer_account_verified",
        "app_record_exists",
        "play_console_app_id",
        "play_app_signing_enrolled",
        "registered_upload_certificate_sha256",
        "play_app_signing_certificate_sha256",
        "version_code_available",
        "production_access_status",
        "required_closed_test_completed",
        "target_countries",
        "reviewer_access_configured",
        "data_safety_published",
        "app_content_forms_complete",
        "artifact_uploaded",
        "artifact_processing_status",
        "submission_status",
        "verified_receipt",
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
        "dsa_trader_status_complete",
        "target_countries",
        "reviewer_access_configured",
        "app_privacy_published",
        "build_uploaded",
        "build_processing_status",
        "testflight_validation_complete",
        "submission_status",
        "verified_receipt",
    },
}

def validate(
    surfaces: set[str],
    release_ready: bool = False,
    submission_ready: bool = False,
    artifact_path: Path | None = None,
) -> ValidationResult:
    result = ValidationResult()
    if artifact_path is not None and surfaces not in ({MOBILE_PLAY}, {APP_STORE}):
        result.add_error(
            "ARTIFACT_SURFACE",
            "One upload artifact can be validated only with --surface mobile-play or --surface app-store",
            artifact_path,
        )
        artifact_path = None
    if MOBILE_PLAY in surfaces:
        _validate_mobile_play(
            result,
            artifact_path=artifact_path if surfaces == {MOBILE_PLAY} else None,
            require_submission=submission_ready,
        )
    if APP_STORE in surfaces:
        _validate_app_store(
            result,
            artifact_path=artifact_path if surfaces == {APP_STORE} else None,
            require_submission=submission_ready,
        )
    roots: list[Path] = []
    if surfaces & {MOBILE_PLAY, APP_STORE}:
        roots.extend([STORE_DIR, MOBILE_DIR / "android" / "fastlane", MOBILE_DIR / "ios" / "fastlane"])
    _check_secret_material(roots, result)

    if surfaces & {MOBILE_PLAY, APP_STORE}:
        excluded: set[str] = set()
        if MOBILE_PLAY not in surfaces:
            excluded.add("google_play_release_owner")
        if APP_STORE not in surfaces:
            excluded.add("apple_app_store_release_owner")
        _check_approvals(STORE_DIR / "approvals.json", result, excluded_ids=excluded)
        _check_disabled_candidate_alignment(
            STORE_DIR / "release_package.json",
            STORE_DIR / "approvals.json",
            result,
        )
        _check_policy_blockers(STORE_DIR / "release_package.json", result)
        portal_sections: set[str] = set()
        if MOBILE_PLAY in surfaces:
            portal_sections.add("google_play")
        if APP_STORE in surfaces:
            portal_sections.add("app_store_connect")
        if submission_ready:
            portal_keys = SUBMISSION_PORTAL_KEYS
        elif release_ready:
            portal_keys = PREUPLOAD_PORTAL_KEYS
        else:
            portal_keys = None
        _check_portal_values(
            STORE_DIR / "portal_values.template.json",
            result,
            sections=portal_sections,
            keys=portal_keys,
            require_submission=submission_ready,
        )
        _check_checksum_manifest(STORE_DIR / "store_media.sha256", result)
    if MOBILE_PLAY in surfaces:
        _check_artwork(STORE_DIR / "play_store" / "artwork_manifest.json", result)
    if APP_STORE in surfaces:
        _check_apple_screenshots(STORE_DIR / "app_store" / "artwork_manifest.json", result)
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
    selection.add_argument("--surface", choices=sorted(ALL_SURFACES), help="Validate one upload surface")
    parser.add_argument("--release-ready", action="store_true", help="Fail on pending external/approval/artwork gates")
    parser.add_argument("--submission-ready", action="store_true", help="Fail unless post-upload portal and submission evidence is complete")
    parser.add_argument(
        "--artifact",
        type=Path,
        help="Exact mobile AAB or IPA path to hash and identity-bind before binary upload",
    )
    parser.add_argument("--json", action="store_true", help="Print machine-readable findings")
    args = parser.parse_args(argv)
    surfaces = _selected_surfaces(args)
    if args.release_ready and args.submission_ready:
        parser.error("choose either --release-ready or --submission-ready")
    if args.artifact is not None:
        if not args.release_ready:
            parser.error("--artifact requires --release-ready")
        if surfaces not in ({MOBILE_PLAY}, {APP_STORE}):
            parser.error("--artifact requires --surface mobile-play or --surface app-store")
    enforce_gates = args.release_ready or args.submission_ready
    result = validate(
        surfaces,
        release_ready=args.release_ready,
        submission_ready=args.submission_ready,
        artifact_path=args.artifact,
    )
    if args.json:
        print(json.dumps({
            "surfaces": sorted(surfaces),
            "release_ready": args.release_ready,
            "submission_ready": args.submission_ready,
            "artifact": str(args.artifact) if args.artifact is not None else None,
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
