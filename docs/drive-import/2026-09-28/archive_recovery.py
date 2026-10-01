"""Verify and resolve the retained Drive archive without rewriting intake manifests.

Only redundant regular copies in the dated mirror's flat snapshots/output are
eligible. The recovery index is written and checked before any copy is removed.
"""
from __future__ import annotations

import argparse
import collections
import csv
import hashlib
import json
import os
import re
import subprocess
import zipfile
from pathlib import Path
from urllib.parse import unquote, urlsplit

BASE = Path(__file__).resolve().parent
ROOT = BASE.parents[2]
INDEX = "archive-recovery-index.json"
ALLOWED_SUFFIXES = {".zip", ".pdf", ".xlsx", ".md", ".ts", ".mjs", ".js", ".dart", ".py", ".swift", ".kt", ".html", ".css"}
PROTECTED_NAME = re.compile(r"license|notices?|grants?|approv|receipts?|checksum|manifest|verification|upload|signoff|signing|keystore|private|golden|test|harness|localizations|\.sql(?:\.|$)", re.I)
COHERENT = ("candidates/", "git-metadata/", "variants/", "mirror/apps/", "mirror/cloudflare/", "mirror/packages/", "mirror/tools/", "mirror/docs/")


def sha(path: Path) -> str:
    value = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            value.update(chunk)
    return value.hexdigest()


def regular(base: Path, name: str) -> Path:
    relative = Path(name)
    if relative.is_absolute() or ".." in relative.parts:
        raise ValueError(f"Unsafe archive path: {name}")
    target = base / relative
    current = target
    while current != base:
        if current.is_symlink():
            raise ValueError(f"Symlink is outside consolidation: {name}")
        current = current.parent
    if not target.is_file():
        raise ValueError(f"Archive file is missing: {name}")
    return target


def protected(name: str) -> str | None:
    if name.startswith(COHERENT):
        return "coherent_source_or_git_recovery_tree"
    if PROTECTED_NAME.search(Path(name).name):
        return "license_grant_approval_receipt_manifest_migration_test_or_signing_record"
    if Path(name).suffix.lower() == ".md":
        return "historical_document_or_provenance_record"
    if Path(name).suffix.lower() not in ALLOWED_SUFFIXES:
        return "structured_metadata_or_non_payload_file"
    if not (name.startswith("mirror/output/") or
            name.startswith("mirror/Conversation_Files_") and ("/File_Snapshots/" in name or name.endswith((".zip", ".pdf", ".xlsx")))):
        return "original_source_or_intake_manifest"
    return None


def tracked(root: Path) -> dict[str, str]:
    output = subprocess.check_output(["git", "ls-files", "--stage", "-z"], cwd=root)
    result = {}
    for raw in output.split(b"\0"):
        if not raw:
            continue
        metadata, name = raw.decode().split("\t", 1)
        mode, blob, stage = metadata.split()
        if stage != "0":
            raise ValueError("Unmerged index requires resolution before archive cleanup")
        result[name] = blob if mode == "100644" or mode == "100755" else ""
    return result


def references(root: Path, base: Path, names: dict[str, str]) -> dict[str, list[str]]:
    """Retain literal checkout paths and resolvable Markdown/module consumers.

    The immutable TSV/gzip/JSON intake inventories describe original retrieval
    locations. Their removed occurrences resolve through the recovery index.
    """
    prefix = base.relative_to(root).as_posix() + "/"
    targets = set(name[len(prefix):] for name in names if name.startswith(prefix))
    result: dict[str, list[str]] = collections.defaultdict(list)
    consumers = set(names)
    consumers.update(name for name in subprocess.check_output(
        ["git", "ls-files", "--others", "--exclude-standard", "-z"], cwd=root).decode().split("\0") if name)
    for name in sorted(consumers):
        path = root / name
        if path.is_symlink() or not path.is_file() or path.stat().st_size > 8 * 1024 * 1024:
            continue
        if path.suffix.lower() not in {".md", ".py", ".ts", ".tsx", ".dart", ".js", ".mjs", ".json", ".yaml", ".yml", ".sh"}:
            continue
        if name.startswith(prefix) and path.suffix.lower() == ".json":
            continue
        try:
            source = path.read_text(encoding="utf-8")
        except (UnicodeError, OSError):
            continue
        candidates = re.findall(re.escape(prefix) + r'[^\s"\x27`<>\)\]]+', source)
        candidates += re.findall(r"\]\(([^)]+)\)", source)
        candidates += re.findall(r"(?:from\s+|import\s+|require\()([\"\x27])([^\"\x27]+)\1", source)
        for candidate in candidates:
            if isinstance(candidate, tuple):
                candidate = candidate[1]
            candidate = unquote(candidate.strip("<> "))
            if urlsplit(candidate).scheme or candidate.startswith("#"):
                continue
            candidate = candidate.split("#", 1)[0].split("?", 1)[0]
            if candidate.startswith(prefix):
                absolute = root / candidate
            elif candidate.startswith("/"):
                absolute = Path(candidate)
            else:
                absolute = path.parent / candidate
            try:
                archive_name = absolute.resolve().relative_to(base.resolve()).as_posix()
            except ValueError:
                continue
            if archive_name in targets:
                result[archive_name].append(name)
    return {key: sorted(set(value)) for key, value in result.items()}


def build_plan(root: Path, base: Path) -> dict:
    root, base = root.resolve(), base.resolve()
    names = tracked(root)
    prefix = base.relative_to(root).as_posix() + "/"
    archival_names = sorted(name for name in names if name.startswith(prefix))
    if any("\n" in name or "\r" in name or name.startswith('"') for name in archival_names):
        raise ValueError("Unusual archive filename requires explicit preservation")
    current_blobs = subprocess.check_output(["git", "hash-object", "--stdin-paths"], cwd=root,
                                           input=("\n".join(archival_names) + "\n").encode()).decode().splitlines()
    if len(current_blobs) != len(archival_names):
        raise ValueError("Incomplete current archival Git hash inventory")
    current = dict(zip(archival_names, current_blobs))
    consumers = references(root, base, names)
    inventory = []
    groups: dict[tuple[int, str], list[dict]] = collections.defaultdict(list)
    for name, blob in sorted(names.items()):
        if not name.startswith(prefix):
            continue
        relative = name[len(prefix):]
        path = regular(base, relative)
        digest = sha(path)
        # Dirty archival source cannot silently become a cleanup baseline.
        git_blob = current[name]
        if not blob or git_blob != blob:
            raise ValueError(f"Changed or nonregular archive source: {name}")
        record = {"original_path": relative, "canonical_path": relative, "bytes": path.stat().st_size, "sha256": digest, "git_blob": blob}
        inventory.append(record)
        if record["bytes"]:
            groups[(record["bytes"], digest)].append(record)
    blocked = []
    removed = []
    for (size, digest), records in sorted(groups.items()):
        if len(records) < 2:
            continue
        keep = []
        candidates = []
        reasons = {}
        for record in records:
            name = record["original_path"]
            reason = protected(name)
            if consumers.get(name):
                reason = "actual_documentation_or_module_consumer"
            if reason:
                keep.append(record)
                reasons[name] = {"reason": reason, "consumers": consumers.get(name, [])}
            else:
                candidates.append(record)
        # Keep existing coherent source first; otherwise keep a named output
        # payload rather than a numbered conversation snapshot of it.
        canonical = min(keep or candidates, key=lambda r: (not r["original_path"].startswith(COHERENT),
                        "/File_Snapshots/" in r["original_path"], not r["original_path"].startswith("mirror/output/"), r["original_path"]))
        for record in candidates:
            if record is canonical:
                continue
            record["canonical_path"] = canonical["original_path"]
            removed.append(record["original_path"])
        remaining = [r["original_path"] for r in records if r["original_path"] == r["canonical_path"]]
        if len(remaining) > 1:
            blocked.append({"sha256": digest, "bytes_per_copy": size, "retained_paths": remaining,
                            "blocked_redundant_bytes": size * (len(remaining) - 1), "path_reasons": reasons})
    protected_intake = [{"path": r["original_path"], "sha256": r["sha256"]} for r in inventory if "/" not in r["original_path"]]
    by_name = {r["original_path"]: r for r in inventory}
    discrepancies = {}
    for manifest in ("direct-files.tsv", "full-tree-additions.tsv", "candidate-08-vs-checkout.tsv"):
        if not (base / manifest).is_file():
            continue
        with (base / manifest).open(encoding="utf-8", newline="") as stream:
            for occurrence in csv.DictReader(stream, delimiter="\t"):
                derived = manifest == "candidate-08-vs-checkout.tsv"
                original = "candidates/implementation-08-source/" + occurrence["repository_path"] if derived else occurrence.get("local_copy_relative_to_import") or "mirror/" + occurrence.get("drive_relative_path", "")
                expected = occurrence.get("candidate_sha256") if derived else occurrence.get("sha256")
                if not expected:
                    continue
                record = by_name.get(original)
                provenance = {"manifest": manifest, "drive_id": occurrence.get("drive_id"), "intake_sha256": expected}
                if record and original != record["canonical_path"]:
                    record.setdefault("retrieval_occurrences", []).append(provenance)
                if record is None or record["sha256"] != expected:
                    discrepancies[original] = {"original_path": original, "intake_sha256": expected,
                        "state_before_consolidation": "missing" if record is None else "different",
                        "retrieval_manifest": manifest, "drive_id": occurrence.get("drive_id")}
    # Earlier exclusive-design cleanup changed some imported records. Verify
    # their original intake bytes in the existing import commit rather than
    # recreating retired specifications or altering the historical manifest.
    if discrepancies:
        import_commit = subprocess.check_output(["git", "rev-parse", "345c9309^{commit}"], cwd=root).decode().strip()
        for original, record in discrepancies.items():
            git_path = prefix + original
            payload = subprocess.check_output(["git", "show", f"{import_commit}:{git_path}"], cwd=root)
            if hashlib.sha256(payload).hexdigest() != record["intake_sha256"]:
                raise ValueError(f"Historical intake revision is not recoverable: {original}")
            record["verified_original_git_commit"] = import_commit
            record["original_bytes"] = len(payload)
    return {"schema_version": 1, "scope": prefix.rstrip("/"),
            "source_commit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root).decode().strip(),
            "intake_manifests_unchanged": protected_intake,
            "inventory": inventory, "removed_regular_paths": sorted(removed), "blocked_groups": blocked,
            "preexisting_intake_revision_recovery": list(discrepancies.values()),
            "summary": {"tracked_original_files": len(inventory), "duplicate_groups": sum(len(r) > 1 for r in groups.values()),
                        "removed_regular_files": len(removed), "removed_bytes": sum(r["bytes"] for r in inventory if r["original_path"] != r["canonical_path"]),
                        "blocked_groups": len(blocked), "blocked_redundant_bytes": sum(g["blocked_redundant_bytes"] for g in blocked)},
            "external_acceptance": {"drive_acl_verified": False, "retention_approved": False, "production_release_claimed": False}}


def verify(base: Path, index: dict, *, before_removal: bool = False, allow_pending: bool = False) -> dict:
    records = {r["original_path"]: r for r in index["inventory"]}
    if index.get("schema_version") != 1 or len(records) != len(index["inventory"]):
        raise ValueError("Invalid or duplicate original recovery inventory")
    expected_removed = sorted(name for name, record in records.items() if name != record["canonical_path"])
    if sorted(index["removed_regular_paths"]) != expected_removed:
        raise ValueError("Removal list differs from the verified aliases")
    checked = set()
    archive_containers = 0
    for name, record in records.items():
        canonical = record["canonical_path"]
        if canonical not in records or records[canonical]["canonical_path"] != canonical:
            raise ValueError(f"Alias chain or unknown canonical file: {name}")
        if records[canonical]["sha256"] != record["sha256"] or records[canonical]["bytes"] != record["bytes"]:
            raise ValueError(f"Alias content mismatch: {name}")
        if canonical not in checked:
            path = regular(base, canonical)
            if path.stat().st_size != record["bytes"] or sha(path) != record["sha256"]:
                raise ValueError(f"Canonical content changed: {canonical}")
            if path.suffix.lower() == ".zip":
                with zipfile.ZipFile(path) as archive:
                    if archive.testzip() is not None:
                        raise ValueError(f"ZIP CRC failed: {canonical}")
                archive_containers += 1
            checked.add(canonical)
        if name != canonical:
            if protected(name):
                raise ValueError(f"Protected file cannot be removed: {name}")
            old = base / name
            if before_removal or allow_pending and (old.exists() or old.is_symlink()):
                old = regular(base, name)
                if old.stat().st_size != record["bytes"] or sha(old) != record["sha256"]:
                    raise ValueError(f"Removal content changed: {name}")
            elif old.exists() or old.is_symlink():
                raise ValueError(f"Redundant copy remains: {name}")
    for manifest in index["intake_manifests_unchanged"]:
        if sha(regular(base, manifest["path"])) != manifest["sha256"]:
            raise ValueError(f"Intake manifest changed: {manifest['path']}")
    for record in index.get("preexisting_intake_revision_recovery", []):
        payload = subprocess.check_output(["git", "show", f"{record['verified_original_git_commit']}:{index['scope']}/{record['original_path']}"], cwd=base.parents[2])
        if len(payload) != record["original_bytes"] or hashlib.sha256(payload).hexdigest() != record["intake_sha256"]:
            raise ValueError("Original preexisting intake revision is no longer recoverable")
    return {"verified_original_paths": len(records), "verified_retained_files": len(checked),
            "verified_unique_sha256": len({r["sha256"] for r in records.values()}),
            "verified_zip_containers": archive_containers, "removed_regular_files": len(index["removed_regular_paths"]),
            "verified_preexisting_intake_revisions_in_git": len(index.get("preexisting_intake_revision_recovery", []))}


def apply(root: Path, base: Path, index: dict) -> dict:
    root, base = root.resolve(), base.resolve()
    if base.relative_to(root).as_posix() != index["scope"]:
        raise ValueError("Recovery scope differs from the requested archive")
    # Every original path has a hash-verified retained file before any unlink.
    target = base / INDEX
    if target.exists():
        raise ValueError("An existing recovery index must be verified; do not replace archival history")
    verify(base, index, before_removal=True)
    with target.open("x", encoding="utf-8") as stream:
        stream.write(json.dumps(index, indent=2, sort_keys=True) + "\n")
        stream.flush()
        os.fsync(stream.fileno())
    directory = os.open(base, os.O_RDONLY)
    try:
        os.fsync(directory)
    finally:
        os.close(directory)
    saved = json.loads(target.read_text(encoding="utf-8"))
    verify(base, saved, before_removal=True)
    return complete_removal(root, base, saved)


def complete_removal(root: Path, base: Path, saved: dict) -> dict:
    root, base = root.resolve(), base.resolve()
    if base.relative_to(root).as_posix() != saved["scope"]:
        raise ValueError("Recovery scope differs from the requested archive")
    verify(base, saved, allow_pending=True)
    current_consumers = references(root, base, tracked(root))
    if any(current_consumers.get(name) for name in saved["removed_regular_paths"]):
        raise ValueError("A new consumer requires the original archive path; no copies removed")
    for name in saved["removed_regular_paths"]:
        record = next(r for r in saved["inventory"] if r["original_path"] == name)
        # Recheck both bytes immediately before removal; never delete changed
        # source or delete an only remaining revision after preflight.
        if not (base / name).exists() and not (base / name).is_symlink():
            continue
        old = regular(base, name)
        canonical = regular(base, record["canonical_path"])
        if sha(old) != record["sha256"] or sha(canonical) != record["sha256"]:
            raise ValueError(f"Archive changed during cleanup: {name}")
        old.unlink()
    return verify(base, saved)


def resolve(base: Path, name: str, index: dict) -> Path:
    record = next((r for r in index["inventory"] if r["original_path"] == name), None)
    if record is None:
        raise ValueError("Path is not in the frozen archive recovery inventory")
    path = regular(base, record["canonical_path"])
    if sha(path) != record["sha256"] or path.stat().st_size != record["bytes"]:
        raise ValueError("Resolved canonical file differs from the original occurrence")
    return path


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    action = parser.add_mutually_exclusive_group()
    action.add_argument("--apply", action="store_true")
    action.add_argument("--resume", action="store_true")
    action.add_argument("--verify", action="store_true")
    action.add_argument("--resolve", metavar="ORIGINAL_PATH")
    args = parser.parse_args()
    existing_index = (BASE / INDEX).is_file()
    if args.apply and existing_index:
        raise ValueError("An existing recovery index must be verified; do not replace archival history")
    if args.verify or args.resolve or args.resume or existing_index and not args.apply:
        index = json.loads((BASE / INDEX).read_text(encoding="utf-8"))
        result = str(resolve(BASE, args.resolve, index)) if args.resolve else complete_removal(ROOT, BASE, index) if args.resume else verify(BASE, index)
    else:
        index = build_plan(ROOT, BASE)
        result = apply(ROOT, BASE, index) if args.apply else index
    print(result if isinstance(result, str) else json.dumps(result, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
