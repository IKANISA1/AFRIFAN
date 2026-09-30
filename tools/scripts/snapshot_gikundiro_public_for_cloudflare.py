#!/usr/bin/env python3
"""Capture Rayon app-facing approved public Gikundiro rows for migration.

This is a read-only, anonymous public-source snapshot. It excludes source-site
member, order, payment and prediction-entry records.
"""

from __future__ import annotations

import datetime as dt
import hashlib
import json
import pathlib
import sys
import urllib.error
import urllib.parse
import urllib.request

from inventory_cloudflare_migration import DEFAULT_ENV, DEFAULT_OUTPUT, read_env, write_json


EXPECTED_HOST = "loxcwbfukbqziuxgkfcm.supabase.co"
PAGE_SIZE = 500
PUBLIC = {"approval_status": "eq.approved", "active": "eq.true", "visibility": "eq.public"}
TABLES = {
    "news_posts": ("*", PUBLIC),
    "players": ("*", PUBLIC),
    "fanclubs": ("*", PUBLIC),
    "partners": ("*", PUBLIC),
    "marketplace_products": ("*", PUBLIC),
    "media_assets": ("*", PUBLIC),
    "prediction_fixtures": ("*", PUBLIC),
    "ticket_sales": ("*", PUBLIC),
    "ticket_sale_categories": ("id,ticket_sale_id,category_name,price_rwf,capacity,available,sale_enabled,sort_order", {}),
    "membership_tiers": ("*", PUBLIC),
    "prediction_teams": ("id,name,short_name,crest_url,is_rayon_sports", {}),
    "prediction_competitions": ("id,name,country,priority,active", {"active": "eq.true"}),
    "marketplace_categories": ("id,name,label,active", {"active": "eq.true"}),
    "prediction_pools": ("id,fixture_id,stake_fet,mode,status,opens_at,locks_at", {"status": "eq.open"}),
}


class NoPublicSourceRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, response, code, message, headers, new_url):
        # urllib otherwise forwards API headers across redirected origins.
        raise RuntimeError("Public source redirect refused")


def validated_public_base(value: str) -> str:
    try:
        parsed = urllib.parse.urlsplit(value)
        valid = (parsed.scheme == "https" and parsed.hostname == EXPECTED_HOST and
                 parsed.port in (None, 443) and not parsed.username and not parsed.password and
                 parsed.path in ("", "/") and not parsed.query and not parsed.fragment)
    except (ValueError, TypeError):
        valid = False
    if not valid:
        raise RuntimeError("Configured Gikundiro public source is unavailable")
    return value.rstrip("/")


def fetch(base: str, key: str, table: str, params: dict[str, str]) -> list[dict[str, object]]:
    base = validated_public_base(base)
    if not isinstance(key, str) or not key:
        raise RuntimeError("Configured Gikundiro public source is unavailable")
    if table not in {"clubs", *TABLES}:
        raise RuntimeError("Unsupported public source table")
    query = urllib.parse.urlencode(params)
    url = f"{base}/rest/v1/{table}?{query}"
    request = urllib.request.Request(
        url, headers={"apikey": key, "Authorization": f"Bearer {key}", "Accept": "application/json"},
        method="GET",
    )
    try:
        with urllib.request.build_opener(NoPublicSourceRedirect).open(request, timeout=30) as response:
            rows = json.load(response)
    except urllib.error.HTTPError as error:
        raise RuntimeError(f"Public {table} query returned HTTP {error.code}") from None
    if not isinstance(rows, list) or any(not isinstance(row, dict) for row in rows):
        raise RuntimeError(f"Public {table} response is not a row list")
    return rows


def main() -> int:
    capture_started_at = dt.datetime.now(dt.timezone.utc).isoformat()
    env = read_env(DEFAULT_ENV)
    configured = env.get("GIKUNDIRO_PUBLIC_SUPABASE_URL", "")
    key = env.get("GIKUNDIRO_PUBLIC_SUPABASE_ANON_KEY", "")
    base = validated_public_base(configured)
    if not key:
        raise RuntimeError("Configured Gikundiro public source is unavailable")
    clubs = fetch(base, key, "clubs", {"select": "id,slug,name,short_name", "slug": "eq.rayon-sports", "limit": "2"})
    if len(clubs) != 1 or not clubs[0].get("id"):
        raise RuntimeError("Rayon source club must resolve to exactly one row")
    club_id = str(clubs[0]["id"])
    captured: dict[str, object] = {"clubs": clubs}
    counts: dict[str, int] = {"clubs": 1}
    for table, (selection, filters) in TABLES.items():
        all_rows: list[dict[str, object]] = []
        offset = 0
        while True:
            rows = fetch(base, key, table, {
                "select": selection, "club_id": f"eq.{club_id}", **filters,
                "order": "id.asc", "limit": str(PAGE_SIZE), "offset": str(offset),
            })
            all_rows.extend(rows)
            if len(rows) < PAGE_SIZE:
                break
            offset += PAGE_SIZE
        captured[table] = all_rows
        counts[table] = len(all_rows)
    output = DEFAULT_OUTPUT / "gikundiro-public"
    output.mkdir(parents=True, exist_ok=True, mode=0o700)
    output.chmod(0o700)
    write_json(output / "rayon-public-source-rows.json", captured)
    write_json(output / "manifest.json", {
        "captured_at_utc": capture_started_at,
        "capture_started_at_utc": capture_started_at,
        "capture_completed_at_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
        "source_host": EXPECTED_HOST, "club_id": club_id,
        "counts": counts,
        "rows_file": "rayon-public-source-rows.json",
        "rows_sha256": hashlib.sha256((output / "rayon-public-source-rows.json").read_bytes()).hexdigest(),
        "public_read_only": True,
        "transactionally_consistent": False,
        "media_originals_exported": False,
    })
    print("Gikundiro public snapshot counts:", json.dumps(counts, sort_keys=True))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except RuntimeError as error:
        print(f"Public snapshot incomplete: {error}", file=sys.stderr)
        sys.exit(2)
