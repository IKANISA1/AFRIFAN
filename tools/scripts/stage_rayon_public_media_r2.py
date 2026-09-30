#!/usr/bin/env python3
"""Verify content-addressed media; upload to staging only with --execute.

No existing object is overwritten with different bytes: keys contain SHA-256.
No production bucket is accepted by this staging helper. The publication Worker
independently rechecks every object before activating any imported snapshot.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import mimetypes
import pathlib
import re
import subprocess
import sys
import tempfile
from inventory_cloudflare_migration import DEFAULT_OUTPUT, ROOT

BUCKET = 'africlub-rayon-public-media-staging'
WRANGLER = ROOT / 'apps/rayon_sports/web/node_modules/.bin/wrangler'
MEDIA = DEFAULT_OUTPUT / 'gikundiro-public/app-media'
ALLOWED_TYPES = {'image/jpeg', 'image/png', 'image/webp', 'image/avif', 'image/svg+xml'}

def verified_objects(directory: pathlib.Path) -> list[dict]:
    data = json.loads((directory / 'manifest.json').read_text(encoding='utf-8'))
    objects = data.get('objects')
    if not isinstance(objects, list): raise RuntimeError('Missing object inventory')
    seen, result = set(), []
    for item in objects:
        if not isinstance(item, dict) or not isinstance(item.get('file'), str):
            raise RuntimeError('Malformed media item')
        source = (directory / item['file']).resolve()
        if not source.is_relative_to(directory.resolve()) or not source.is_file():
            raise RuntimeError('Media file is missing or escapes the export directory')
        blob = source.read_bytes()
        digest = hashlib.sha256(blob).hexdigest()
        if type(item.get('bytes')) is not int or len(blob) != item['bytes'] or len(blob) > 32*1024*1024 or digest != item.get('sha256'):
            raise RuntimeError('Local media byte/hash verification failed')
        mime = mimetypes.guess_type(str(item.get('source_path', '')))[0]
        if mime not in ALLOWED_TYPES: raise RuntimeError('Unsupported media type')
        key = f'assets/{digest}.bin'
        if key not in seen:
            result.append({'file': source, 'key': key, 'sha256': digest, 'mime': mime, 'bytes': len(blob)})
            seen.add(key)
    return result

def run(wrangler: pathlib.Path, *args: str) -> None:
    subprocess.run([str(wrangler), *args], cwd=ROOT, check=True, stdout=subprocess.DEVNULL)

def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--media-dir', type=pathlib.Path, default=MEDIA)
    parser.add_argument('--wrangler', type=pathlib.Path, default=WRANGLER)
    parser.add_argument('--execute', action='store_true', help='Explicitly upload/read back the fixed isolated staging bucket')
    args = parser.parse_args()
    objects = verified_objects(args.media_dir)
    if not args.execute:
        print(f'Dry run: {len(objects)} content-addressed objects verified locally; no remote changes')
        return 0
    if not args.wrangler.is_file(): raise RuntimeError('Configured Wrangler executable is unavailable')
    for item in objects:
        key = f"{BUCKET}/{item['key']}"
        run(args.wrangler, 'r2', 'object', 'put', key, '--remote', '--file', str(item['file']),
            '--content-type', item['mime'], '--cache-control', 'private, no-store', '--force')
        with tempfile.TemporaryDirectory(prefix='africlub-r2-readback-') as tmp:
            target = pathlib.Path(tmp) / 'object.bin'
            run(args.wrangler, 'r2', 'object', 'get', key, '--remote', '--file', str(target))
            data = target.read_bytes()
            if len(data) != item['bytes'] or hashlib.sha256(data).hexdigest() != item['sha256']:
                raise RuntimeError('R2 readback differs from locally verified source')
    print(f'Staging R2 upload and byte readback passed for {len(objects)} objects; no snapshot was published')
    return 0

if __name__ == '__main__':
    try: sys.exit(main())
    except (RuntimeError, OSError, ValueError, subprocess.CalledProcessError) as error:
        print(f'R2 staging failed: {error}', file=sys.stderr); sys.exit(2)
