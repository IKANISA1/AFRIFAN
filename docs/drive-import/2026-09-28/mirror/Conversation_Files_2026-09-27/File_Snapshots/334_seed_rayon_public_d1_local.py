#!/usr/bin/env python3
"""Generate a private, deterministic local or remote D1 staging import."""

from __future__ import annotations

import hashlib
import json
import pathlib
import sys

from inventory_cloudflare_migration import DEFAULT_OUTPUT, write_json


def literal(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"


def main() -> int:
    base = DEFAULT_OUTPUT / "gikundiro-public"
    rows_file = base / "rayon-public-source-rows.json"
    source_manifest = json.loads((base / "manifest.json").read_text(encoding="utf-8"))
    if hashlib.sha256(rows_file.read_bytes()).hexdigest() != source_manifest["rows_sha256"]:
        raise RuntimeError("Public source snapshot SHA-256 mismatch")
    media_manifest = json.loads((base / "app-media" / "manifest.json").read_text(encoding="utf-8"))
    rows_by_table = json.loads(rows_file.read_text(encoding="utf-8"))
    club_id = str(source_manifest["club_id"])
    captured_at = str(source_manifest["captured_at_utc"])
    statements = ["DELETE FROM source_media;", "DELETE FROM source_records;"]
    counts: dict[str, int] = {}
    for table, rows in sorted(rows_by_table.items()):
        counts[table] = len(rows)
        for row in sorted(rows, key=lambda item: str(item["id"])):
            if not row.get("id"):
                raise RuntimeError(f"Public {table} row has no source ID")
            payload = json.dumps(row, sort_keys=True, ensure_ascii=False, separators=(",", ":"))
            digest = hashlib.sha256(payload.encode("utf-8")).hexdigest()
            values = [table, str(row["id"]), club_id, payload, digest, captured_at]
            statements.append(
                "INSERT INTO source_records "
                "(source_table,source_id,source_club_id,payload_json,row_sha256,captured_at_utc) "
                f"VALUES ({','.join(literal(v) for v in values)});"
            )
    for item in sorted(media_manifest["objects"], key=lambda object_: object_["source_id"]):
        media_file = base / "app-media" / item["file"]
        if hashlib.sha256(media_file.read_bytes()).hexdigest() != item["sha256"]:
            raise RuntimeError("App media original SHA-256 mismatch")
        values = [
            str(item["source_id"]), str(item["source_bucket"]), str(item["source_path"]),
            str(item["bytes"]), str(item["sha256"]),
            json.dumps(item["usage_scopes"], separators=(",", ":")),
            str(item["usage_rights"]), captured_at,
        ]
        statements.append(
            "INSERT INTO source_media "
            "(source_asset_id,source_bucket,source_path,bytes,sha256,usage_scopes_json,usage_rights,captured_at_utc) "
            f"VALUES ({','.join(literal(v) for v in values)});"
        )
    output = DEFAULT_OUTPUT / "cloudflare-rayon-public-local"
    output.mkdir(parents=True, exist_ok=True, mode=0o700)
    output.chmod(0o700)
    sql = ("\n".join(statements) + "\n").encode("utf-8")
    file = output / "seed.sql"
    file.write_bytes(sql)
    file.chmod(0o600)
    write_json(output / "seed-manifest.json", {
        "source_snapshot_sha256": source_manifest["rows_sha256"],
        "seed_sha256": hashlib.sha256(sql).hexdigest(),
        "table_counts": counts,
        "source_rows": sum(counts.values()),
        "media_rows": len(media_manifest["objects"]),
        "purpose": "rayon_public_staging_import",
    })
    print(f"Generated D1 staging seed: {sum(counts.values())} public rows and {len(media_manifest['objects'])} media records")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except RuntimeError as error:
        print(f"D1 staging seed failed: {error}", file=sys.stderr)
        sys.exit(2)
