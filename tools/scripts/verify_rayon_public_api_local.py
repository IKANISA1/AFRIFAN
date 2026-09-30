#!/usr/bin/env python3
"""Exercise the D1-backed Rayon public Worker without exposing source records."""

from __future__ import annotations

import datetime as dt
import hashlib
import json
import os
import pathlib
import re
import urllib.parse
import sys
import urllib.error
import urllib.request


BASE = os.environ.get("RAYON_PUBLIC_API_BASE", "http://127.0.0.1:8799").rstrip("/") + "/v1/public/rayon/"
ROUTES = (
    "fixtures", "news", "squad", "fanclubs", "partners", "shop",
    "tickets", "membership-tiers", "predict-pools",
)


def fetch(route: str, method: str = "GET") -> tuple[int, dict[str, object]]:
    request = urllib.request.Request(BASE + route, method=method,
                                     headers={"User-Agent": "curl/8.7.1"})
    try:
        with urllib.request.urlopen(request, timeout=15) as response:
            return response.status, json.load(response)
    except urllib.error.HTTPError as error:
        try:
            return error.code, json.load(error)
        except json.JSONDecodeError:
            raise RuntimeError(f"Public API returned non-JSON HTTP {error.code}") from None


def ensure(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def main() -> int:
    observed: dict[str, int] = {}
    shop_images: list[str] = []
    snapshot_ids: set[str] = set()
    now = dt.datetime.now(dt.timezone.utc)
    for route in ROUTES:
        status, body = fetch(route)
        ensure(status == 200 and body.get("schemaVersion") == 1 and body.get("route") == route,
               f"Invalid {route} response")
        ensure(isinstance(body.get("sourceCapturedAt"), str) and isinstance(body.get("rows"), list),
               f"Missing {route} freshness or rows")
        rows = body["rows"]
        snapshot_id = body.get("snapshotId")
        ensure(isinstance(snapshot_id, str) and re.fullmatch(r"[a-f0-9]{64}", snapshot_id) is not None,
               f"Missing immutable {route} snapshot identity")
        snapshot_ids.add(snapshot_id)
        captured = dt.datetime.fromisoformat(body["sourceCapturedAt"].replace("Z", "+00:00"))
        ensure(captured.tzinfo is not None and now - dt.timedelta(hours=24) < captured <= now + dt.timedelta(minutes=5),
               f"Stale or future {route} publication")
        # A valid approved snapshot may intentionally have no rows for a route.
        ensure(all(isinstance(row, dict) for row in rows), f"Invalid {route} row shape")
        ensure(all("payload_json" not in row and "buyer_phone" not in row and
                   "leader_contact_public" not in row for row in rows),
               f"Raw or private fields escaped on {route}")
        if route == "fixtures":
            ensure(all(row.get("predictionEntryEnabled") is False and
                       row.get("sourceUrl", "").startswith("https://") and
                       dt.datetime.fromisoformat(row["kickoffAt"].replace("Z", "+00:00")) > now
                       for row in rows), "Fixture publication rule failed")
        if route == "news":
            ensure(all(row.get("sourceUrl", "").startswith("https://") and
                       dt.datetime.fromisoformat(row["publishedAt"].replace("Z", "+00:00")) <= now
                       for row in rows), "News publication rule failed")
        if route == "shop":
            ensure(all(row.get("commerceMode") == "enquiry" and
                       row.get("checkoutEnabled") is False and
                       row.get("imageUrl", "").startswith(BASE)
                       for row in rows), "Shop safety rule failed")
            shop_images = [row["imageUrl"] for row in rows]
        if route == "partners":
            ensure(all(row.get("logoUrl") is None or row["logoUrl"].startswith(BASE) for row in rows),
                   "Partner media escaped the rights-checked Worker")
        if route == "tickets":
            ensure(all(row.get("reservationOnly") is True and
                       row.get("paidTicketIssuanceEnabled") is False
                       for row in rows), "Ticket reservation rule failed")
        if route == "membership-tiers":
            ensure(all(row.get("purchaseEnabled") is False for row in rows),
                   "Source tier must not authorize app purchase")
        if route == "predict-pools":
            ensure(all(row.get("entryEnabled") is False for row in rows),
                   "Source pool must not authorize app prediction")
        observed[route] = len(rows)
    ensure(len(snapshot_ids) == 1, "Snapshot changed during smoke test; retry against one stable approved publication")
    ensure(fetch("news", method="POST")[0] == 405, "Public API accepted a write method")
    ensure(fetch("unknown")[0] == 404, "Public API accepted an unknown route")
    if BASE.startswith("https://"):
        manifest_path = (pathlib.Path(__file__).resolve().parents[2] /
                         "output/migration/cloudflare-stage0/gikundiro-public/app-media/manifest.json")
        media = {item["source_id"]: item for item in json.loads(manifest_path.read_text())["objects"]}
        for url in shop_images:
            asset_id = urllib.parse.urlsplit(url).path.rsplit("/", 1)[-1]
            request = urllib.request.Request(url, headers={"User-Agent": "curl/8.7.1"})
            with urllib.request.urlopen(request, timeout=15) as response:
                body = response.read()
                ensure(response.status == 200 and response.headers.get("content-type", "").startswith("image/"),
                       "Published media response invalid")
            ensure(len(body) == media[asset_id]["bytes"] and
                   hashlib.sha256(body).hexdigest() == media[asset_id]["sha256"],
                   "Published media differs from source")
        for item in media.values():
            if "review-before-commercial-reuse" in item["usage_rights"]:
                ensure(fetch(f"media/{item['source_id']}")[0] == 404,
                       "Uncleared media was publicly served")
    print("D1 public API passed:", json.dumps(observed, sort_keys=True))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (RuntimeError, OSError, ValueError, KeyError, TypeError) as error:
        print(f"Local public API failed: {error}", file=sys.stderr)
        sys.exit(2)
