#!/usr/bin/env python3
"""Read-only, checksum-verified Storage object export for the Supabase exit.

The output is private and git-ignored. It is a media export, not a database backup.
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

from inventory_cloudflare_migration import (
    DEFAULT_ENV, DEFAULT_OUTPUT, read_env, run_read_only, write_json,
)


def main() -> int:
    env = read_env(DEFAULT_ENV)
    source = env.get("NEXT_PUBLIC_SUPABASE_URL", "").rstrip("/")
    host = urllib.parse.urlsplit(source).hostname or ""
    token = env.get("SUPABASE_ACCESS_TOKEN", "")
    service_key = env.get("SUPABASE_SERVICE_ROLE_KEY", "")
    if not host.endswith(".supabase.co") or not token or not service_key:
        raise SystemExit("Storage export credentials are unavailable")
    ref = host.split(".")[0]
    rows = run_read_only(ref, token, """
      select bucket_id, name, id::text as source_id,
        case when metadata->>'size' ~ '^[0-9]+$'
          then (metadata->>'size')::bigint else null end as metadata_bytes
      from storage.objects order by bucket_id, name
    """)
    base = DEFAULT_OUTPUT / "storage"
    base.mkdir(parents=True, exist_ok=True, mode=0o700)
    base.chmod(0o700)
    manifest: list[dict[str, object]] = []
    for row in rows:
        bucket = str(row["bucket_id"])
        name = str(row["name"])
        source_id = str(row["source_id"])
        quoted = urllib.parse.quote(name, safe="/")
        url = f"{source}/storage/v1/object/authenticated/{urllib.parse.quote(bucket, safe='')}/{quoted}"
        destination = base / f"{source_id}.bin"
        temporary = base / f"{source_id}.part"
        request = urllib.request.Request(
            url, headers={"Authorization": f"Bearer {service_key}", "apikey": service_key}, method="GET",
        )
        try:
            with urllib.request.urlopen(request, timeout=90) as response, temporary.open("wb") as output:
                temporary.chmod(0o600)
                digest = hashlib.sha256()
                size = 0
                while chunk := response.read(1024 * 1024):
                    output.write(chunk)
                    digest.update(chunk)
                    size += len(chunk)
        except urllib.error.HTTPError as error:
            temporary.unlink(missing_ok=True)
            raise RuntimeError(f"Storage object download returned HTTP {error.code}") from None
        expected = row["metadata_bytes"]
        if expected is not None and int(expected) != size:
            temporary.unlink(missing_ok=True)
            raise RuntimeError(f"Storage object size mismatch for source ID {source_id}")
        temporary.replace(destination)
        manifest.append({
            "bucket": bucket, "source_key": name, "source_id": source_id,
            "local_file": destination.name, "bytes": size, "sha256": digest.hexdigest(),
        })
    write_json(DEFAULT_OUTPUT / "storage-manifest.json", {
        "captured_at_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
        "project_ref": ref, "objects": manifest,
    })
    print(f"Exported {len(manifest)} Storage originals; total bytes {sum(x['bytes'] for x in manifest)}")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except RuntimeError as error:
        print(f"Storage export incomplete: {error}", file=sys.stderr)
        sys.exit(2)
