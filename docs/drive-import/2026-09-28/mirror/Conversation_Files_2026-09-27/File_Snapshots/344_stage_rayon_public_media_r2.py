#!/usr/bin/env python3
"""Upload approved Rayon public media to isolated R2 staging and verify bytes."""

from __future__ import annotations

import hashlib
import json
import mimetypes
import pathlib
import subprocess
import sys
import tempfile

from inventory_cloudflare_migration import DEFAULT_OUTPUT, ROOT


BUCKET = "africlub-rayon-public-media-staging"
WRANGLER = ROOT / "apps/rayon_sports/web/node_modules/.bin/wrangler"
MEDIA = DEFAULT_OUTPUT / "gikundiro-public/app-media"


def run(*args: str) -> None:
    subprocess.run([str(WRANGLER), *args], cwd=ROOT, check=True,
                   stdout=subprocess.DEVNULL)


def main() -> int:
    items = json.loads((MEDIA / "manifest.json").read_text(encoding="utf-8"))["objects"]
    verified = 0
    for item in items:
        source = MEDIA / item["file"]
        data = source.read_bytes()
        if len(data) != item["bytes"] or hashlib.sha256(data).hexdigest() != item["sha256"]:
            raise RuntimeError(f"Local source media hash failed for {item['source_id']}")
        mime = mimetypes.guess_type(item["source_path"])[0]
        if mime not in {"image/jpeg", "image/png", "image/webp", "image/avif", "image/svg+xml"}:
            raise RuntimeError(f"Unsupported media type for {item['source_id']}")
        key = f"{BUCKET}/assets/{item['source_id']}.bin"
        run("r2", "object", "put", key, "--remote", "--file", str(source),
            "--content-type", mime, "--cache-control", "public, max-age=3600", "--force")
        with tempfile.TemporaryDirectory(prefix="rayon-r2-verify-") as directory:
            target = pathlib.Path(directory) / "object.bin"
            run("r2", "object", "get", key, "--remote", "--file", str(target))
            if hashlib.sha256(target.read_bytes()).hexdigest() != item["sha256"]:
                raise RuntimeError(f"R2 byte readback failed for {item['source_id']}")
        verified += 1
    print(f"R2 staging byte parity passed: {verified} media objects")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (RuntimeError, subprocess.CalledProcessError) as error:
        print(f"R2 staging incomplete: {error}", file=sys.stderr)
        sys.exit(2)
