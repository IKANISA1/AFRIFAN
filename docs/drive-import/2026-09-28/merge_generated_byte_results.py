"""Merge resumable raw download results into the AFRICLUB review registers."""

import csv
import gzip
import json
import os
import sqlite3
from collections import Counter
from pathlib import Path


BASE = Path(__file__).resolve().parent
BYTE_REGISTER = BASE / "full-tree-generated-byte-comparison.tsv.gz"
FILE_REGISTER = BASE / "full-tree-file-analysis.tsv.gz"
SIZE_REGISTER = BASE / "full-tree-generated-size-comparison.tsv.gz"
COVERAGE = BASE / "full-tree-coverage.json"
PROGRESS = BASE / ".generated-byte-progress.sqlite3"
COMPLETE = {
    "identical", "different", "local_missing",
    "identical_local_changed_since_index", "different_local_changed_since_index",
    "local_missing_local_changed_since_index",
}


def rewrite_gzip(path, transform):
    target = path.with_suffix(path.suffix + ".next")
    with gzip.open(path, "rt", encoding="utf-8", newline="") as source, gzip.open(target, "wt", encoding="utf-8", newline="") as dest:
        reader = csv.DictReader(source, delimiter="\t")
        writer = csv.DictWriter(dest, fieldnames=reader.fieldnames, delimiter="\t", lineterminator="\n")
        writer.writeheader()
        for row in reader:
            writer.writerow(transform(row))
    os.replace(target, path)


db = sqlite3.connect(PROGRESS)
prior_verified = set()
with gzip.open(FILE_REGISTER, "rt", encoding="utf-8", newline="") as source:
    for row in csv.DictReader(source, delimiter="\t"):
        if row["role"] in ("generated_build", "dependency_install", "qa_output", "generated_tooling") and row["drive_byte_comparison"] == "identical":
            prior_verified.add((row["drive_path"], row["drive_id"]))
new = {
    (path, file_id): (status, drive_bytes, drive_hash, local_bytes, local_hash, error)
    for path, file_id, status, drive_bytes, drive_hash, local_bytes, local_hash, error
    in db.execute("SELECT path,id,status,drive_bytes,drive_sha256,local_bytes,local_sha256,error FROM checks")
    if status != "stopped"
}


def byte_row(row):
    key = (row["drive_path"], row["drive_id"])
    result = new.get(key)
    if key in prior_verified and row["comparison_status"] in ("not_attempted", "error") and (result is None or result[0] not in COMPLETE):
        row["comparison_status"] = "identical"
        row["drive_bytes"] = row["local_bytes"]
        row["drive_sha256"] = row["local_sha256"]
        row["error"] = ""
        return row
    if result is None or row["comparison_status"] in ("identical", "different") and result[0] not in COMPLETE:
        return row
    status, drive_bytes, drive_hash, local_bytes, local_hash, error = result
    row["comparison_status"] = status
    row["drive_bytes"] = "" if drive_bytes is None else drive_bytes
    row["drive_sha256"] = drive_hash or ""
    row["local_bytes"] = "" if local_bytes is None else local_bytes
    row["local_sha256"] = local_hash or ""
    row["error"] = error or ""
    return row


rewrite_gzip(BYTE_REGISTER, byte_row)
byte_map = {}
all_counts = Counter()
with gzip.open(BYTE_REGISTER, "rt", encoding="utf-8", newline="") as source:
    for row in csv.DictReader(source, delimiter="\t"):
        byte_map[(row["drive_path"], row["drive_id"])] = row
        all_counts[row["comparison_status"]] += 1


def file_row(row):
    item = byte_map.get((row["drive_path"], row["drive_id"]))
    if item is not None:
        if row["drive_byte_comparison"] != "identical" or item["comparison_status"] in COMPLETE:
            row["drive_byte_comparison"] = item["comparison_status"]
        if item["comparison_status"].endswith("_local_changed_since_index"):
            row["local_bytes"] = item["local_bytes"]
            row["local_sha256"] = item["local_sha256"]
            row["analysis_result"] = "local_changed_reanalysis_required"
    return row


rewrite_gzip(FILE_REGISTER, file_row)
canonical = set()
with gzip.open(SIZE_REGISTER, "rt", encoding="utf-8", newline="") as source:
    for row in csv.DictReader(source, delimiter="\t"):
        canonical.add((row["drive_path"], row["drive_id"]))
unique_counts = Counter(byte_map[key]["comparison_status"] for key in canonical)
assert sum(unique_counts.values()) == len(canonical) == 253864
coverage = json.loads(COVERAGE.read_text(encoding="utf-8"))
coverage["generated_drive_byte_comparison"] = dict(unique_counts)
coverage["generated_byte_comparison_not_attempted"] = unique_counts["not_attempted"]
coverage["generated_file_occurrence_byte_comparison"] = dict(all_counts)
COVERAGE.write_text(json.dumps(coverage, indent=2, sort_keys=True) + "\n", encoding="utf-8")
print("unique generated files", dict(unique_counts))
print("generated occurrences", dict(all_counts))
