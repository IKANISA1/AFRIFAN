#!/usr/bin/env python3
"""Check local D1 or a remote D1 SQL export against source manifests."""

from __future__ import annotations

import hashlib
import argparse
import json
import pathlib
import sqlite3
import sys

from inventory_cloudflare_migration import DEFAULT_OUTPUT, ROOT


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--sql-export", type=pathlib.Path)
    args = parser.parse_args()
    base = DEFAULT_OUTPUT / "gikundiro-public"
    source = json.loads((base / "rayon-public-source-rows.json").read_text(encoding="utf-8"))
    expected = {
        (table, str(row["id"])): row
        for table, rows in source.items() for row in rows
    }
    media = json.loads((base / "app-media" / "manifest.json").read_text(encoding="utf-8"))["objects"]
    if args.sql_export:
        connection = sqlite3.connect(":memory:")
        connection.executescript(args.sql_export.read_text(encoding="utf-8"))
        label = "Remote D1 export"
    else:
        directory = ROOT / "cloudflare/rayon-public/.wrangler/state/v3/d1/miniflare-D1DatabaseObject"
        files = [path for path in directory.glob("*.sqlite") if path.name != "metadata.sqlite"]
        if len(files) != 1:
            raise RuntimeError("Expected exactly one local D1 staging database")
        connection = sqlite3.connect(files[0].resolve().as_uri() + "?mode=ro", uri=True)
        label = "Local D1"
    try:
        if connection.execute("PRAGMA integrity_check").fetchone()[0] != "ok":
            raise RuntimeError(f"{label} SQLite integrity check failed")
        found: set[tuple[str, str]] = set()
        for table, source_id, payload, digest in connection.execute(
            "SELECT source_table,source_id,payload_json,row_sha256 FROM source_records"
        ):
            key = (table, source_id)
            if key not in expected or key in found:
                raise RuntimeError(f"{label} contains an unexpected or duplicate source row")
            canonical = json.dumps(expected[key], sort_keys=True, ensure_ascii=False, separators=(",", ":"))
            if payload != canonical or hashlib.sha256(payload.encode("utf-8")).hexdigest() != digest:
                raise RuntimeError(f"{label} source row parity failed for {key}")
            found.add(key)
        if found != set(expected):
            raise RuntimeError(f"{label} is missing source rows")
        actual_media = {
            row[0]: row for row in connection.execute(
                "SELECT source_asset_id,source_bucket,source_path,bytes,sha256,usage_scopes_json,usage_rights FROM source_media"
            )
        }
        if len(actual_media) != len(media):
            raise RuntimeError(f"{label} media manifest count mismatch")
        for item in media:
            row = actual_media.get(item["source_id"])
            if not row or row[1] != item["source_bucket"] or row[2] != item["source_path"] or row[3] != item["bytes"] or row[4] != item["sha256"]:
                raise RuntimeError(f"{label} media metadata mismatch")
            if json.loads(row[5]) != item["usage_scopes"] or row[6] != item["usage_rights"]:
                raise RuntimeError(f"{label} media rights mismatch")
        print(f"{label} parity passed: {len(found)} source rows, {len(media)} media metadata records")
    finally:
        connection.close()
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except RuntimeError as error:
        print(f"Local D1 parity failed: {error}", file=sys.stderr)
        sys.exit(2)
