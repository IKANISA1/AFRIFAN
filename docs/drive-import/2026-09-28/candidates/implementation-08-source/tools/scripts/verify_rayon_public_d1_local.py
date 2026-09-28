#!/usr/bin/env python3
"""Verify one immutable imported snapshot against the original public export.

This checks SQLite row/hash/rights parity, not production D1 concurrency, R2
objects, authentication, or business transactions. --require-active additionally
requires the approved publication head to reference the verified snapshot.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import pathlib
import re
import sqlite3
import sys
from inventory_cloudflare_migration import DEFAULT_OUTPUT, ROOT
from seed_rayon_public_d1_local import prepare_snapshot, canonical, digest


def verify(connection: sqlite3.Connection, source_dir: pathlib.Path,
           snapshot_id: str | None = None, require_active: bool = False) -> dict:
    if connection.execute('PRAGMA integrity_check').fetchone()[0] != 'ok':
        raise RuntimeError('SQLite integrity check failed')
    if connection.execute('PRAGMA foreign_key_check').fetchone():
        raise RuntimeError('SQLite foreign-key check failed')
    source_file = source_dir / 'rayon-public-source-rows.json'
    source = json.loads(source_file.read_text(encoding='utf-8'))
    source_manifest = json.loads((source_dir / 'manifest.json').read_text(encoding='utf-8'))
    if digest(source_file.read_bytes()) != source_manifest.get('rows_sha256'):
        raise RuntimeError('Source export hash mismatch')
    media_dir = source_dir / 'app-media'
    expected_id, manifest, _ = prepare_snapshot(source, source_manifest,
        json.loads((media_dir / 'manifest.json').read_text(encoding='utf-8')), media_dir)
    if snapshot_id is not None and snapshot_id != expected_id:
        raise RuntimeError('Requested snapshot does not match this source export')
    snapshot_id = expected_id
    row = connection.execute('SELECT manifest_json,status,approved_by,approval_ref FROM public_snapshots WHERE snapshot_id=?',
                             (snapshot_id,)).fetchone()
    if not row or row[0] != canonical(manifest) or digest(row[0]) != snapshot_id:
        raise RuntimeError('Stored snapshot manifest is absent or differs from source')
    rows = connection.execute('SELECT source_table,source_id,source_club_id,payload_json,row_sha256 FROM public_snapshot_records '
                              'WHERE snapshot_id=? ORDER BY source_table,source_id', (snapshot_id,)).fetchall()
    expected = {(table, str(item['id'])): canonical(item) for table, values in source.items() for item in values}
    found = set()
    for table, source_id, club_id, payload, row_hash in rows:
        key = (table, source_id)
        if key in found or expected.get(key) != payload or digest(payload) != row_hash or club_id != manifest['sourceClubId']:
            raise RuntimeError('Snapshot record identity, tenant, content, or hash differs from source')
        found.add(key)
    if found != set(expected): raise RuntimeError('Incomplete snapshot record set')
    actual_media = connection.execute('SELECT source_asset_id,source_bucket,source_path,bytes,sha256,usage_scopes_json,usage_rights,r2_key '
                                      'FROM public_snapshot_media WHERE snapshot_id=? ORDER BY source_asset_id', (snapshot_id,)).fetchall()
    normalized = [[*item[:5], json.loads(item[5]), *item[6:]] for item in actual_media]
    if normalized != manifest['media']: raise RuntimeError('Snapshot media provenance, integrity, or rights differ from source')
    head = connection.execute('SELECT snapshot_id FROM public_snapshot_head WHERE singleton=1').fetchone()
    active = bool(head and head[0] == snapshot_id and row[1] == 'active' and row[2] and row[3])
    if require_active and not active: raise RuntimeError('Snapshot has not been approved and activated')
    return {'snapshotId': snapshot_id, 'sourceRows': len(rows), 'mediaRows': len(actual_media),
            'state': row[1], 'approvedActiveHead': active, 'r2VerifiedByThisCheck': False}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group()
    group.add_argument('--database', type=pathlib.Path)
    group.add_argument('--sql-export', type=pathlib.Path)
    parser.add_argument('--source-dir', type=pathlib.Path, default=DEFAULT_OUTPUT / 'gikundiro-public')
    parser.add_argument('--snapshot-id')
    parser.add_argument('--require-active', action='store_true')
    args = parser.parse_args()
    if args.sql_export:
        connection = sqlite3.connect(':memory:')
        connection.executescript(args.sql_export.read_text(encoding='utf-8'))
    else:
        path = args.database
        if path is None:
            directory = ROOT / 'cloudflare/rayon-public/.wrangler/state/v3/d1/miniflare-D1DatabaseObject'
            paths = [p for p in directory.glob('*.sqlite') if p.name != 'metadata.sqlite']
            if len(paths) != 1: raise RuntimeError('Specify --database: no single unambiguous local database')
            path = paths[0]
        connection = sqlite3.connect(path.resolve().as_uri() + '?mode=ro', uri=True)
    try: result = verify(connection, args.source_dir, args.snapshot_id, args.require_active)
    finally: connection.close()
    print('Immutable public snapshot parity passed: ' + json.dumps(result, sort_keys=True))
    return 0

if __name__ == '__main__':
    try: sys.exit(main())
    except (RuntimeError, OSError, ValueError, sqlite3.Error, KeyError, TypeError) as error:
        print(f'Public snapshot parity failed: {error}', file=sys.stderr); sys.exit(2)
