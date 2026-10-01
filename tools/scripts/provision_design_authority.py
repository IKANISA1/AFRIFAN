#!/usr/bin/env python3
"""Pack/provision only hash-bound Revolut text references; never approve visuals.

The private source collection, account images, fonts and trial binaries are not
included. The explicit download command reads a pinned private GitHub release
asset with the caller's existing read access. No plugin is installed.
"""
import argparse
import gzip
import hashlib
import io
import json
from pathlib import Path
import re
import selectors
import shutil
import subprocess
import tarfile
import tempfile
import time

LIMIT = 4 * 1024 * 1024
ROOT = Path(__file__).resolve().parents[2]


def unique_pairs(items):
    result = {}
    for key, value in items:
        if key in result:
            raise ValueError('Duplicate authority binding key')
        result[key] = value
    return result


def bindings(root):
    document = json.loads((root / 'docs/governance/design-exceptions.json').read_text(), object_pairs_hook=unique_pairs)
    authority = document['design_authority']
    result = subprocess.run(['node', '--input-type=module', '-e',
                             "import { requiredAuthorityFiles } from './tools/scripts/validate_design_authority.mjs'; process.stdout.write(JSON.stringify(requiredAuthorityFiles));"],
                            cwd=root, check=True, capture_output=True, text=True)
    required = json.loads(result.stdout)
    entries = authority['bound_files']
    if authority.get('skill') != 'revolut-design' or len(entries) != len(required):
        raise ValueError('Only the selected Revolut authority bindings may be packaged')
    mapped = {entry['path']: entry['sha256'] for entry in entries}
    if len(mapped) != len(entries) or set(mapped) != set(required):
        raise ValueError('Authority reference inventory differs from the source validator')
    for name, digest in mapped.items():
        if not isinstance(digest, str) or not re.fullmatch(r'[a-f0-9]{64}', digest) or name.startswith('/') or any(p in ('', '.', '..') for p in name.split('/')):
            raise ValueError('Unsafe authority binding')
    return mapped


def validate_source(root, authority):
    source = authority / 'SKILL.md'
    result = subprocess.run(['node', '--input-type=module', '-e',
                             "import { validateDesignAuthority } from './tools/scripts/validate_design_authority.mjs'; const [root, authorityRoot] = process.argv.slice(1); const result = validateDesignAuthority({root, register: root + '/docs/governance/design-exceptions.json', authorityRoot}); if (result.status !== 'pass') { process.stderr.write(result.errors.join('\\n')); process.exit(1); }",
                             str(root), str(source.parent)], cwd=root, capture_output=True, text=True)
    if result.returncode:
        raise ValueError('Selected authority or product adapter binding does not verify')


def pack(root, authority, output):
    expected = bindings(root)
    validate_source(root, authority)
    payloads = {}
    for name, digest in sorted(expected.items()):
        cursor = authority
        if cursor.is_symlink():
            raise ValueError('Authority links are not allowed')
        for part in name.split('/'):
            cursor = cursor / part
            if cursor.is_symlink():
                raise ValueError('Authority links are not allowed')
        if not cursor.is_file() or cursor.stat().st_size > LIMIT:
            raise ValueError('Authority reference is missing or oversized')
        data = cursor.read_bytes()
        if hashlib.sha256(data).hexdigest() != digest:
            raise ValueError('Authority reference changed during packaging')
        payloads[name] = data
    if sum(map(len, payloads.values())) > LIMIT:
        raise ValueError('Authority bundle exceeds finite size bound')
    body = io.BytesIO()
    with gzip.GzipFile(fileobj=body, mode='wb', filename='', mtime=0) as compressed:
        with tarfile.open(fileobj=compressed, mode='w', format=tarfile.USTAR_FORMAT) as archive:
            for name, data in payloads.items():
                entry = tarfile.TarInfo(name)
                entry.size, entry.mode, entry.mtime = len(data), 0o644, 0
                archive.addfile(entry, io.BytesIO(data))
    with output.open('xb') as target:
        target.write(body.getvalue())
    output.chmod(0o600)
    return hashlib.sha256(body.getvalue()).hexdigest()


def provision(root, archive_path, expected_digest, destination):
    if not re.fullmatch(r'[a-f0-9]{64}', expected_digest):
        raise ValueError('A pinned bundle SHA256 is required')
    if archive_path.is_symlink() or not archive_path.is_file() or archive_path.stat().st_size > LIMIT:
        raise ValueError('Authority archive must be a bounded regular file')
    body = archive_path.read_bytes()
    if hashlib.sha256(body).hexdigest() != expected_digest:
        raise ValueError('Authority bundle digest differs')
    expected, payloads, total = bindings(root), {}, 0
    with tarfile.open(fileobj=io.BytesIO(body), mode='r:gz') as archive:
        for member in archive:
            if member.name not in expected or member.name in payloads or not member.isfile() or member.size < 0 or member.size > LIMIT:
                raise ValueError('Unexpected, repeated or unsafe authority archive entry')
            total += member.size
            if total > LIMIT:
                raise ValueError('Authority archive exceeds finite decoded size bound')
            stream = archive.extractfile(member)
            data = stream.read(member.size + 1)
            if len(data) != member.size or hashlib.sha256(data).hexdigest() != expected[member.name]:
                raise ValueError('Authority reference digest differs')
            payloads[member.name] = data
    if set(payloads) != set(expected):
        raise ValueError('Authority archive does not contain every selected reference')
    if destination.exists() or destination.is_symlink():
        raise ValueError('Authority destination must be fresh; existing files are preserved')
    destination.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='.revolut-authority-', dir=destination.parent) as temporary:
        staged = Path(temporary) / 'authority'
        staged.mkdir()
        for name, data in payloads.items():
            target = staged / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
            target.chmod(0o644)
        validate_source(root, staged)
        # No extraction occurs before the complete archive and source binding pass.
        destination.mkdir()
        try:
            for item in staged.iterdir():
                item.rename(destination / item.name)
        except OSError:
            shutil.rmtree(destination)
            raise
    return len(payloads)


def download(root, repository, asset_id, digest, destination, timeout=45):
    if not re.fullmatch(r'[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+', repository) or not re.fullmatch(r'[1-9][0-9]{0,19}', asset_id):
        raise ValueError('Explicit repository and numeric immutable asset ID required')
    if not re.fullmatch(r'[a-f0-9]{64}', digest):
        raise ValueError('Pinned authority bundle SHA256 required')
    if destination.exists() or destination.is_symlink():
        raise ValueError('Authority destination must be fresh')
    private = subprocess.run(['gh', 'api', 'repos/' + repository, '--jq', '.private'], check=True,
                             capture_output=True, text=True, timeout=15).stdout.strip()
    if private != 'true':
        raise ValueError('Design authority may only be retrieved from a private repository')
    endpoint = 'repos/' + repository + '/releases/assets/' + asset_id
    metadata = json.loads(subprocess.run(['gh', 'api', endpoint], check=True,
                                        capture_output=True, text=True, timeout=15).stdout, object_pairs_hook=unique_pairs)
    if metadata.get('state') != 'uploaded' or type(metadata.get('size')) is not int or not 0 < metadata['size'] <= LIMIT:
        raise ValueError('Authority release asset is absent or exceeds size bounds')
    process = subprocess.Popen(['gh', 'api', endpoint, '-H', 'Accept: application/octet-stream'],
                               stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    payload = bytearray()
    deadline = time.monotonic() + timeout
    try:
        with selectors.DefaultSelector() as selector:
            selector.register(process.stdout, selectors.EVENT_READ)
            while True:
                remaining = deadline - time.monotonic()
                if remaining <= 0 or not selector.select(remaining):
                    raise ValueError('Authority asset download deadline exceeded')
                chunk = process.stdout.read1(64 * 1024)
                if not chunk:
                    break
                payload.extend(chunk)
                if len(payload) > LIMIT:
                    raise ValueError('Authority asset download exceeds byte bound')
        if process.wait(timeout=max(0.01, deadline - time.monotonic())) != 0:
            raise ValueError('Authority release asset retrieval failed')
    finally:
        if process.poll() is None:
            process.kill()
        process.wait(timeout=5)
        process.stdout.close()
    if len(payload) != metadata['size'] or hashlib.sha256(payload).hexdigest() != digest:
        raise ValueError('Downloaded authority release asset differs from pinned identity')
    with tempfile.TemporaryDirectory(prefix='revolut-authority-download-') as temporary:
        archive = Path(temporary) / 'authority.tar.gz'
        archive.write_bytes(payload)
        archive.chmod(0o600)
        return provision(root, archive, digest, destination)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=ROOT)
    commands = parser.add_subparsers(dest='command', required=True)
    create = commands.add_parser('pack')
    create.add_argument('--authority-root', type=Path, required=True)
    create.add_argument('--output', type=Path, required=True)
    extract = commands.add_parser('provision')
    extract.add_argument('--archive', type=Path, required=True)
    extract.add_argument('--sha256', required=True)
    extract.add_argument('--destination', type=Path, required=True)
    retrieve = commands.add_parser('download')
    retrieve.add_argument('--repository', required=True)
    retrieve.add_argument('--asset-id', required=True)
    retrieve.add_argument('--sha256', required=True)
    retrieve.add_argument('--destination', type=Path, required=True)
    args = parser.parse_args()
    try:
        if args.command == 'pack':
            digest = pack(args.root, args.authority_root, args.output)
            print(json.dumps({'scope': 'design_authority_binding_only', 'bundleSha256': digest, 'referenceCount': len(bindings(args.root)), 'designComplete': False}))
        elif args.command == 'provision':
            count = provision(args.root, args.archive, args.sha256, args.destination)
            print(json.dumps({'scope': 'design_authority_binding_only', 'referenceCount': count, 'designComplete': False}))
        else:
            count = download(args.root, args.repository, args.asset_id, args.sha256, args.destination)
            print(json.dumps({'scope': 'design_authority_binding_only', 'referenceCount': count, 'designComplete': False}))
    except (ValueError, KeyError, TypeError, EOFError, OSError, tarfile.TarError, subprocess.SubprocessError):
        parser.exit(1, 'Selected design authority provisioning failed; verify source bindings, pinned bundle and a fresh destination.\n')


if __name__ == '__main__':
    main()
