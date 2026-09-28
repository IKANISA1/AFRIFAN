#!/usr/bin/env python3
"""Archive deployed Edge Function bodies and metadata for the Supabase exit.

All output is private and git-ignored. This only reads the Management API.
"""

from __future__ import annotations

import datetime as dt
import hashlib
import pathlib
import re
import sys
import urllib.error
import urllib.parse
import urllib.request

from inventory_cloudflare_migration import (
    DEFAULT_ENV, DEFAULT_OUTPUT, get_management_list, read_env, write_json,
)


def main() -> int:
    env = read_env(DEFAULT_ENV)
    host = urllib.parse.urlsplit(env.get("NEXT_PUBLIC_SUPABASE_URL", "")).hostname or ""
    token = env.get("SUPABASE_ACCESS_TOKEN", "")
    if not host.endswith(".supabase.co") or not token:
        raise RuntimeError("Source project credentials unavailable")
    ref = host.split(".")[0]
    functions = get_management_list(ref, token, "functions")
    destination = DEFAULT_OUTPUT / "edge-functions"
    destination.mkdir(parents=True, exist_ok=True, mode=0o700)
    destination.chmod(0o700)
    records: list[dict[str, object]] = []
    for item in functions:
        slug = str(item.get("slug", ""))
        if not re.fullmatch(r"[a-z0-9][a-z0-9-]{0,99}", slug):
            raise RuntimeError("Invalid deployed function slug")
        url = f"https://api.supabase.com/v1/projects/{ref}/functions/{slug}/body"
        request = urllib.request.Request(url, headers={"Authorization": f"Bearer {token}"})
        temporary = destination / f"{slug}.part"
        target = destination / f"{slug}.body"
        try:
            with urllib.request.urlopen(request, timeout=90) as response, temporary.open("wb") as output:
                temporary.chmod(0o600)
                digest = hashlib.sha256()
                size = 0
                while chunk := response.read(1024 * 1024):
                    size += len(chunk)
                    if size > 30_000_000:
                        raise RuntimeError(f"Deployed function {slug} exceeded archive size cap")
                    output.write(chunk)
                    digest.update(chunk)
                content_type = response.headers.get("Content-Type", "")
        except urllib.error.HTTPError as error:
            temporary.unlink(missing_ok=True)
            raise RuntimeError(f"Function {slug} body returned HTTP {error.code}") from None
        if size == 0:
            temporary.unlink(missing_ok=True)
            raise RuntimeError(f"Function {slug} returned an empty body")
        temporary.replace(target)
        records.append({
            "slug": slug, "version": item.get("version"),
            "verify_jwt": item.get("verify_jwt"),
            "bytes": size, "sha256": digest.hexdigest(),
            "content_type": content_type, "local_file": target.name,
        })
    write_json(destination / "manifest.json", {
        "captured_at_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
        "project_ref": ref, "functions": records,
    })
    print(f"Archived {len(records)} deployed Edge Function bodies; "
          f"{sum(int(row['bytes']) for row in records)} bytes")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except RuntimeError as error:
        print(f"Edge Function export incomplete: {error}", file=sys.stderr)
        sys.exit(2)
