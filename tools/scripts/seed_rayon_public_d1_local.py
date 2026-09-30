#!/usr/bin/env python3
"""Build a deterministic immutable import. Does not publish or replace a snapshot.

Apply migrations 0001, 0002 and 0003 before importing. Generated SQL contains only
INSERTs into the new versioned tables; all legacy source tables are retained.
"""
from __future__ import annotations
import argparse
import datetime as dt
import hashlib
import json
import pathlib
import re
import sys
from inventory_cloudflare_migration import DEFAULT_OUTPUT, write_json
from snapshot_gikundiro_public_for_cloudflare import TABLES

EXPECTED_TABLES = sorted(['clubs', *TABLES])
MAX_MEDIA_BYTES = 32 * 1024 * 1024
HEX = re.compile(r'^[a-f0-9]{64}$')


def canonical(value: object) -> str:
    return json.dumps(value, sort_keys=True, ensure_ascii=False, separators=(',', ':'), allow_nan=False)


def digest(value: bytes | str) -> str:
    return hashlib.sha256(value.encode('utf-8') if isinstance(value, str) else value).hexdigest()


def literal(value: str | int) -> str:
    return "'" + str(value).replace("'", "''") + "'"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def prepare_snapshot(rows_by_table: dict, source_manifest: dict, media_manifest: dict,
                     media_dir: pathlib.Path) -> tuple[str, dict, str]:
    require(source_manifest.get('public_read_only') is True, 'Source must be an explicit public-only export')
    require(isinstance(rows_by_table, dict) and sorted(rows_by_table) == EXPECTED_TABLES,
            'Complete public table set required, including empty tables')
    club_id = str(source_manifest.get('club_id') or '')
    require(bool(club_id), 'Missing source club ID')
    captured_at = source_manifest.get('capture_started_at_utc') or source_manifest.get('captured_at_utc')
    require(isinstance(captured_at, str), 'Missing capture time')
    try:
        captured = dt.datetime.fromisoformat(captured_at.replace('Z', '+00:00'))
        require(captured.tzinfo is not None, 'Capture time must include a timezone')
    except ValueError:
        raise RuntimeError('Invalid capture timestamp') from None
    source_hash = source_manifest.get('rows_sha256', '')
    require(isinstance(source_hash, str) and bool(HEX.fullmatch(source_hash)), 'Missing source export hash')
    counts, record_values, record_manifest = {}, [], []
    assets = {}
    for table in EXPECTED_TABLES:
        rows = rows_by_table[table]
        require(isinstance(rows, list), f'Invalid rows for {table}')
        require(all(isinstance(row, dict) and row.get('id') is not None for row in rows), f'Missing source ID: {table}')
        seen = set()
        for row in sorted(rows, key=lambda item: str(item['id'])):
            source_id = str(row['id'])
            require(bool(source_id) and source_id not in seen, f'Duplicate or empty source ID: {table}')
            seen.add(source_id)
            require(row.get('club_id') is None or str(row['club_id']) == club_id, f'Wrong-club row: {table}')
            if table == 'clubs':
                require(source_id == club_id, 'Wrong source club')
            payload = canonical(row)
            row_hash = digest(payload)
            record_values.append([table, source_id, club_id, payload, row_hash])
            record_manifest.append([table, source_id, row_hash])
            if table == 'media_assets':
                assets[source_id] = row
        counts[table] = len(rows)
    require(counts['clubs'] == 1, 'Exactly one source club is required')
    require(source_manifest.get('counts') == counts, 'Source table counts do not match exported rows')
    objects = media_manifest.get('objects')
    require(isinstance(objects, list) and all(isinstance(item, dict) for item in objects),
            'Missing or malformed media object inventory')
    media_records, media_values, seen_assets, seen_paths = [], [], set(), set()
    for item in sorted(objects, key=lambda obj: str(obj.get('source_id', ''))):
        asset_id = str(item.get('source_id') or '')
        source_path, bucket = item.get('source_path'), item.get('source_bucket')
        require(isinstance(source_path, str) and bool(source_path) and isinstance(bucket, str) and bool(bucket),
                'Missing media source bucket/path')
        require(asset_id and asset_id not in seen_assets and (bucket, source_path) not in seen_paths,
                'Duplicate or missing media identity')
        seen_assets.add(asset_id); seen_paths.add((bucket, source_path))
        require(isinstance(item.get('file'), str), 'Missing media file')
        source = (media_dir / item['file']).resolve()
        require(source.is_relative_to(media_dir.resolve()) and source.is_file(), 'Media file escapes export directory or is missing')
        blob = source.read_bytes()
        require(type(item.get('bytes')) is int and 0 <= item['bytes'] <= MAX_MEDIA_BYTES and
                len(blob) == item['bytes'] and digest(blob) == item.get('sha256'), 'Media byte/hash verification failed')
        scopes, rights = item.get('usage_scopes'), item.get('usage_rights')
        require(isinstance(scopes, list) and all(isinstance(scope, str) for scope in scopes) and
                isinstance(rights, str) and bool(rights.strip()), 'Missing media rights or scopes')
        asset = assets.get(asset_id)
        require(bool(asset) and asset.get('storage_bucket') == bucket and asset.get('storage_path') == source_path and
                str(asset.get('checksum_sha256', '')).lower() == item['sha256'] and
                str(asset.get('usage_rights', '')).strip() == rights and
                isinstance(asset.get('usage_scopes'), list) and
                all(isinstance(scope, str) for scope in asset['usage_scopes']) and
                set(scopes) <= set(asset['usage_scopes']), 'Media source provenance/rights mismatch')
        r2_key = f"assets/{item['sha256']}.bin"
        media_records.append([asset_id, bucket, source_path, item['bytes'], item['sha256'], scopes, rights, r2_key])
        media_values.append([asset_id, bucket, source_path, item['bytes'], item['sha256'], canonical(scopes), rights, r2_key])
    manifest = {'schemaVersion': 1, 'sourceClubId': club_id, 'capturedAt': captured_at,
                'sourceRowsSha256': source_hash, 'tables': counts, 'records': record_manifest,
                'media': media_records, 'sourceConsistency': 'non-transactional-public-export'}
    manifest_json = canonical(manifest)
    snapshot_id = digest(manifest_json)
    # Keep every emitted SQL statement comfortably below D1's statement-size
    # ceiling, including Unicode and quoted source text. Chunks are untrusted
    # until the complete immutable manifest passes Worker-side SHA-256 checks.
    statements = []
    for sequence, offset in enumerate(range(0, len(manifest_json), 8192)):
        statements.append('INSERT INTO public_snapshot_import_chunks(snapshot_id,sequence,chunk) VALUES (' +
                          ','.join(literal(value) for value in [snapshot_id, sequence, manifest_json[offset:offset+8192]]) +
                          ') ON CONFLICT(snapshot_id,sequence) DO NOTHING;')
    statements.append('INSERT INTO public_snapshots(snapshot_id,source_club_id,captured_at_utc,manifest_json) SELECT ' +
                      ','.join(literal(value) for value in [snapshot_id, club_id, captured_at]) +
                      ",group_concat(chunk,'') FROM (SELECT chunk FROM public_snapshot_import_chunks WHERE snapshot_id=" +
                      literal(snapshot_id) + ' ORDER BY sequence) WHERE 1 ON CONFLICT(snapshot_id) DO NOTHING;')
    for values in record_values:
        statements.append('INSERT INTO public_snapshot_records(snapshot_id,source_table,source_id,source_club_id,payload_json,row_sha256) VALUES (' +
                          ','.join(literal(value) for value in [snapshot_id, *values]) +
                          ') ON CONFLICT(snapshot_id,source_table,source_id) DO NOTHING;')
    for values in media_values:
        statements.append('INSERT INTO public_snapshot_media(snapshot_id,source_asset_id,source_bucket,source_path,bytes,sha256,usage_scopes_json,usage_rights,r2_key) VALUES (' +
                          ','.join(literal(value) for value in [snapshot_id, *values]) +
                          ') ON CONFLICT(snapshot_id,source_asset_id) DO NOTHING;')
    require(all(len(statement.encode('utf-8')) < 90_000 for statement in statements),
            'A source record exceeds the bounded SQL importer limit; use a parameterized private import, not truncated content')
    return snapshot_id, manifest, '\n'.join(statements) + '\n'


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-dir', type=pathlib.Path, default=DEFAULT_OUTPUT / 'gikundiro-public')
    parser.add_argument('--output-dir', type=pathlib.Path, default=DEFAULT_OUTPUT / 'cloudflare-rayon-public-local')
    args = parser.parse_args()
    rows_file = args.source_dir / 'rayon-public-source-rows.json'
    source_manifest = json.loads((args.source_dir / 'manifest.json').read_text(encoding='utf-8'))
    require(digest(rows_file.read_bytes()) == source_manifest.get('rows_sha256'), 'Public source snapshot SHA-256 mismatch')
    media_dir = args.source_dir / 'app-media'
    snapshot_id, manifest, sql = prepare_snapshot(json.loads(rows_file.read_text(encoding='utf-8')),
        source_manifest, json.loads((media_dir / 'manifest.json').read_text(encoding='utf-8')), media_dir)
    args.output_dir.mkdir(parents=True, exist_ok=True, mode=0o700)
    args.output_dir.chmod(0o700)
    file = args.output_dir / 'seed.sql'; file.write_text(sql, encoding='utf-8'); file.chmod(0o600)
    write_json(args.output_dir / 'seed-manifest.json', {
        'snapshot_id': snapshot_id, 'seed_sha256': digest(sql), 'source_snapshot_sha256': source_manifest['rows_sha256'],
        'table_counts': manifest['tables'], 'source_rows': len(manifest['records']), 'media_rows': len(manifest['media']),
        'publication_state': 'importing', 'publication_authorized': False,
        'purpose': 'immutable_rayon_public_import_requires_separate_verified_publication',
    })
    print(f"Generated unpublished snapshot {snapshot_id}: {len(manifest['records'])} rows, {len(manifest['media'])} media records")
    return 0

if __name__ == '__main__':
    try:
        sys.exit(main())
    except (RuntimeError, ValueError, TypeError, OSError, KeyError) as error:
        print(f'D1 snapshot import preparation failed: {error}', file=sys.stderr)
        sys.exit(2)
