#!/usr/bin/env python3
"""Export only current Rayon app media with registered public usage rights."""

from __future__ import annotations

import datetime as dt
import hashlib
import json
import pathlib
import re
import sys
import urllib.error
import urllib.parse
import urllib.request

from inventory_cloudflare_migration import DEFAULT_OUTPUT, write_json


HOST = "loxcwbfukbqziuxgkfcm.supabase.co"
BUCKET = "gikundiro-media"


def main() -> int:
    source = DEFAULT_OUTPUT / "gikundiro-public" / "rayon-public-source-rows.json"
    data = json.loads(source.read_text(encoding="utf-8"))
    assets = {item["id"]: item for item in data["media_assets"]}
    selected: dict[str, set[str]] = {}
    for table, field, scope in (
        ("players", "photo_asset_id", "squad"),
        ("partners", "logo_asset_id", "partners"),
    ):
        for row in data[table]:
            asset_id = row.get(field)
            if asset_id:
                selected.setdefault(asset_id, set()).add(scope)
    now = dt.datetime.now(dt.timezone.utc)
    season = now.year if now.month >= 7 else now.year - 1
    current_status = f"current_media_verified_{season}_{(season + 1) % 100:02d}"
    for row in data["marketplace_products"]:
        asset_id = row.get("image_asset_id")
        if asset_id and row.get("verification_status") == current_status:
            selected.setdefault(asset_id, set()).add("shop")
    output = DEFAULT_OUTPUT / "gikundiro-public" / "app-media"
    output.mkdir(parents=True, exist_ok=True, mode=0o700)
    output.chmod(0o700)
    manifest: list[dict[str, object]] = []
    for asset_id, scopes in sorted(selected.items()):
        asset = assets.get(asset_id)
        if not asset:
            raise RuntimeError(f"Referenced media asset {asset_id} is unavailable")
        rights = str(asset.get("usage_rights") or "").strip()
        allowed = set(asset.get("usage_scopes") or [])
        if not rights or not scopes <= allowed:
            raise RuntimeError(f"Referenced media asset {asset_id} lacks usage rights")
        if "shop" in scopes and re.search(
            r"generated|pending|review-before-commercial-reuse|unverified", rights, re.I,
        ):
            raise RuntimeError(f"Shop asset {asset_id} is not approved for commercial reuse")
        path = str(asset.get("storage_path") or "")
        url = str(asset.get("asset_url") or "")
        parsed = urllib.parse.urlsplit(url)
        expected_path = f"/storage/v1/object/public/{BUCKET}/{path}"
        if (parsed.scheme != "https" or parsed.hostname != HOST or parsed.query or
            asset.get("storage_bucket") != BUCKET or not path or
            urllib.parse.unquote(parsed.path) != expected_path):
            raise RuntimeError(f"Referenced media asset {asset_id} has an invalid source URL")
        request = urllib.request.Request(url, method="GET")
        try:
            with urllib.request.urlopen(request, timeout=60) as response:
                blob = response.read()
        except urllib.error.HTTPError as error:
            raise RuntimeError(f"Media asset {asset_id} returned HTTP {error.code}") from None
        digest = hashlib.sha256(blob).hexdigest()
        if len(blob) != int(asset.get("file_size_bytes") or -1) or digest != str(asset.get("checksum_sha256") or "").lower():
            raise RuntimeError(f"Media asset {asset_id} failed source size or SHA-256 verification")
        file = output / f"{asset_id}.bin"
        file.write_bytes(blob)
        file.chmod(0o600)
        manifest.append({
            "source_id": asset_id, "source_bucket": BUCKET, "source_path": path,
            "file": file.name, "bytes": len(blob), "sha256": digest,
            "usage_scopes": sorted(scopes), "usage_rights": rights,
        })
    write_json(output / "manifest.json", {
        "captured_at_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
        "objects": manifest, "source_rows_file": source.name,
    })
    print(f"Exported and source-hash-verified {len(manifest)} Rayon app media originals")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except RuntimeError as error:
        print(f"App media export incomplete: {error}", file=sys.stderr)
        sys.exit(2)
