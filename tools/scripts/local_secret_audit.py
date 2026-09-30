#!/usr/bin/env python3
"""Read-only, bounded source/history/archive audit. Never report matched values.

Inventories tracked and untracked nonignored source; scans all reachable Git
blobs and explicitly hash-bound sealed archives. Archive members are read in
memory, never extracted. A failed coverage check prevents a passing result.
"""
from __future__ import annotations

import argparse
import base64
import dataclasses
import gzip
import hashlib
import io
import json
import math
import os
from pathlib import Path, PurePosixPath
import re
import stat
import subprocess
import sys
import tarfile
import tempfile
import time
import zipfile
import zlib

from check_sensitive_source import PEM, JWT, path_issue

MIB = 1024 * 1024
HIGH_CONFIDENCE = re.compile(
    r'(?:'
    r'(?:sb_secret_|sk_live_|rk_live_)[A-Za-z0-9_-]{16,256}|'
    r'(?:ghp_|gho_|ghu_|ghs_|ghr_)[A-Za-z0-9]{30,255}|'
    r'github_pat_[A-Za-z0-9_]{40,255}|'
    r'(?:AKIA|ASIA)[A-Z0-9]{16}|'
    r'xox[baprs]-[A-Za-z0-9-]{20,255}|'
    r'SG\.[A-Za-z0-9_-]{20,100}\.[A-Za-z0-9_-]{20,100}|'
    r'sk-(?:proj-|svcacct-)[A-Za-z0-9_-]{20,256}'
    r')(?![A-Za-z0-9_])'
)
ASSIGNMENT = re.compile(
    r'(?i)(?:auth_hmac_key|auth_encryption_key|'
    r'supabase_service_role_key|aws_secret_access_key|cloudflare_api_token|'
    r'client_secret|api_secret|private_key|access_token|refresh_token)\b'
    r'[\"\']?\s*[:=]\s*[\"\']([A-Za-z0-9_+/=.-]{32,256})[\"\']'
)
ASSIGNMENT_FIELDS = ('auth_hmac_key', 'auth_encryption_key', 'supabase_service_role_key',
                     'aws_secret_access_key', 'cloudflare_api_token', 'client_secret',
                     'api_secret', 'private_key', 'access_token', 'refresh_token')
TOKEN_RUNS = re.compile(r'[A-Za-z0-9_.-]{24,}')
UTF16_RUN = re.compile(rb'(?:[\x20-\x7e]\x00){12,}|(?:\x00[\x20-\x7e]){12,}')
PATH_JWT = re.compile(r'eyJ[A-Za-z0-9_-]{8,1024}\.[A-Za-z0-9_-]{8,1024}\.[A-Za-z0-9_-]{8,1024}')
PUBLIC_GOOGLE = re.compile(r'\bAIza[A-Za-z0-9_-]{35}\b')
UNSUPPORTED = ('.7z', '.rar', '.zst', '.bz2', '.xz', '.lz', '.lzma')
ARCHIVE_SUFFIXES = ('.zip', '.jar', '.apk', '.ipa', '.docx', '.xlsx', '.pptx',
                    '.tar', '.tgz', '.tar.gz', '.gz') + UNSUPPORTED
MAX_PATH = 1024


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def safe_path(name: str) -> str:
    """Names can themselves contain credentials; redact known value shapes."""
    normalized = name.replace('\\\\n', '\n').replace('\\n', '\n').replace('\\r', '\r')
    if PEM.search(normalized):
        return '[redacted-private-key-path]'
    value = HIGH_CONFIDENCE.sub('[redacted]', name[:MAX_PATH])
    value = PATH_JWT.sub('[redacted]', value)
    value = ASSIGNMENT.sub('[redacted-assignment]', value)
    value = re.sub(r'(?i)([?&](?:key|token|secret|password)=)[^&\s]+', r'\1[redacted]', value)
    value = ''.join(c if c.isprintable() else '?' for c in value)
    if len(name) > MAX_PATH:
        value += '[bounded-path]'
    return value


def path_record(name: str) -> dict:
    return {'path': safe_path(name), 'pathSha256': digest(name.encode('utf-8', 'surrogateescape'))}


def canonical_path(name: str) -> bool:
    return bool(name) and not PurePosixPath(name).is_absolute() and '\\' not in name and '\x00' not in name and \
        not re.match(r'^[A-Za-z]:', name) and all(p not in ('', '.', '..') for p in name.split('/'))


def retained(name: str) -> bool:
    return name.startswith(('docs/drive-import/', '.recovery/'))


def entropy(value: str) -> float:
    return -sum((value.count(c)/len(value))*math.log2(value.count(c)/len(value)) for c in set(value))


def classify(data: bytes) -> tuple[list[str], list[str]]:
    """Run the same detectors in binary bytes and common UTF encodings.

    Anonymous client JWTs are public configuration, not backend credentials.
    A test filename or a token's testOnly claim never suppresses a private key
    or privileged token. The audit does not validate tokens or contact providers.
    """
    findings, classes = set(), set()
    texts = [data.decode('utf-8', 'replace')]
    # A binary prefix and NUL separators must not hide embedded UTF-16 text.
    if b'\x00' in data and UTF16_RUN.search(data):
        for offset in (0, 1):
            texts.append(data[offset:].decode('utf-16-le', 'replace'))
            texts.append(data[offset:].decode('utf-16-be', 'replace'))
    for text in texts:
        expanded = text.replace('\\\\n', '\n').replace('\\n', '\n').replace('\\r', '\r')
        if PEM.search(expanded):
            findings.add('private_key_material')
        if HIGH_CONFIDENCE.search(text):
            findings.add('high_confidence_credential')
        lower = text.lower()
        for field in ASSIGNMENT_FIELDS:
            start = lower.find(field)
            while start >= 0:
                match = ASSIGNMENT.match(text, start)
                if match:
                    value = match.group(1)
                    if value.startswith(('REPLACE_', 'INSERT_', 'EXAMPLE_', 'SET_', 'NOT_')):
                        classes.add('configuration_placeholder')
                    elif len(set(value)) >= 10 and entropy(value) >= 3:
                        findings.add('secret_assignment_requires_review')
                start = lower.find(field, start+len(field))
        if PUBLIC_GOOGLE.search(text):
            classes.add('public_google_client_key_requires_provider_restrictions')
        for payload in jwt_payloads(text):
            if payload is None:
                findings.add('oversized_bearer_encoding_requires_review')
                continue
            try:
                decoded = json.loads(base64.urlsafe_b64decode(payload+'='*((-len(payload)) % 4)))
                if type(decoded) is not dict:
                    continue
                role = decoded.get('role')
                if role == 'service_role':
                    findings.add('privileged_backend_token')
                elif role == 'anon':
                    classes.add('public_anonymous_client_token')
                else:
                    findings.add('bearer_token_requires_review')
            except (ValueError, UnicodeError, TypeError, RecursionError):
                # Malformed parser examples are not asserted to be credentials.
                pass
        if '"service_account"' in text and '"private_key"' in text:
            try:
                value = json.loads(text)
                if type(value) is dict and value.get('type') == 'service_account' and value.get('private_key'):
                    findings.add('service_account_private_key')
            except (ValueError, RecursionError):
                pass
    return sorted(findings), sorted(classes)


def jwt_payloads(text: str):
    """Linear lexical runs avoid quadratic retry on adversarial eyJ repetition."""
    if 'eyJ' not in text:
        return
    for match in TOKEN_RUNS.finditer(text):
        run = match.group()
        if 'eyJ' not in run or '.' not in run:
            continue
        parts = run.split('.')
        for index in range(len(parts)-2):
            at = parts[index].find('eyJ')
            if at < 0:
                continue
            header, payload, signature = parts[index][at:], parts[index+1], parts[index+2]
            if len(header) < 11 or len(payload) < 8 or len(signature) < 8:
                continue
            if len(header) > 4096 or len(payload) > 65536 or len(signature) > 4096:
                yield None
            elif JWT.fullmatch(header+'.'+payload+'.'+signature):
                yield payload


@dataclasses.dataclass(frozen=True)
class Limits:
    max_blob_bytes: int = 64 * MIB
    max_member_bytes: int = 64 * MIB
    max_total_bytes: int = 4 * 1024 * MIB
    max_expanded_bytes: int = 2 * 1024 * MIB
    max_members: int = 200000
    max_depth: int = 8
    max_seconds: int = 600


class Audit:
    def __init__(self, limits: Limits | None = None, *, progress=False):
        self.limits = limits or Limits()
        if any(type(v) is not int or v <= 0 for v in dataclasses.asdict(self.limits).values()):
            raise ValueError('invalid_audit_limits')
        maxima = Limits(1024*MIB, 1024*MIB, 64*1024*MIB, 32*1024*MIB, 1000000, 32, 3600)
        if any(getattr(self.limits, f.name) > getattr(maxima, f.name) for f in dataclasses.fields(Limits)):
            raise ValueError('invalid_audit_limits')
        self.started = time.monotonic()
        self.contents: dict[str, dict] = {}
        self.occurrences: list[dict] = []
        self.members: list[dict] = []
        self.gaps: list[dict] = []
        self.bytes_read = 0
        self.expanded_bytes = 0
        self.member_count = 0
        self.source_states: dict[str, tuple] = {}
        self.progress_enabled = progress

    def checkpoint(self, stage: str, count: int):
        if self.progress_enabled:
            print(json.dumps({'stage': stage, 'processed': count, 'uniqueContents': len(self.contents),
                              'archiveMembers': len(self.members), 'coverageGaps': len(self.gaps),
                              'elapsedSeconds': round(time.monotonic()-self.started, 1)}), flush=True)

    def gap(self, category: str, **location):
        # Exception details and member/file bytes never enter the report.
        self.gaps.append({'category': category, **location})

    def budget(self, size: int, *, expanded=False) -> bool:
        if time.monotonic()-self.started > self.limits.max_seconds:
            return False
        if self.bytes_read + size > self.limits.max_total_bytes:
            return False
        if expanded and self.expanded_bytes + size > self.limits.max_expanded_bytes:
            return False
        return True

    def stream(self, stream, limit: int) -> bytes | None:
        chunks, size = [], 0
        while True:
            chunk = stream.read(min(MIB, limit-size+1))
            if not chunk:
                return b''.join(chunks)
            size += len(chunk)
            if size > limit or not self.budget(size, expanded=True):
                return None
            chunks.append(chunk)

    def content(self, data: bytes, name: str, *, depth=0, expanded=False) -> str | None:
        sha = digest(data)
        lower = name.lower()
        kind = 'zip' if data[:4] in (b'PK\x03\x04', b'PK\x05\x06', b'PK\x07\x08') else \
            'gzip' if data[:2] == b'\x1f\x8b' else 'tar' if (len(data) >= 265 and data[257:262] == b'ustar') else None
        # Names are occurrence policy, so a cached innocent name cannot hide an
        # unsupported/corrupt archive with identical bytes at another location.
        archive_problem = 'unsupported_archive' if kind is None and lower.endswith(UNSUPPORTED) else \
            'invalid_archive_format' if kind is None and lower.endswith(ARCHIVE_SUFFIXES) else None
        if kind is None and data.startswith((b'7z\xbc\xaf\x27\x1c', b'Rar!\x1a\x07', b'\x28\xb5\x2f\xfd', b'BZh', b'\xfd7zXZ\x00')):
            archive_problem = 'unsupported_archive'
        if archive_problem:
            self.gap(archive_problem, sha256=sha, **path_record(name))
        if sha in self.contents:
            if archive_problem:
                self.contents[sha]['scanStatus'] = 'partial'
            return sha
        if not self.budget(len(data), expanded=expanded):
            self.gap('scan_budget_exhausted', sha256=sha)
            return None
        self.bytes_read += len(data)
        if expanded:
            self.expanded_bytes += len(data)
        findings, classes = classify(data)
        record = {'sha256': sha, 'bytes': len(data), 'type': 'binary' if b'\x00' in data else 'text',
                  'categories': findings, 'classifications': classes, 'scanStatus': 'scanned'}
        self.contents[sha] = record
        if archive_problem:
            record['scanStatus'] = 'partial'
        elif kind:
            record['type'] = kind
            if depth >= self.limits.max_depth:
                record['scanStatus'] = 'partial'
                self.gap('archive_depth_exceeded', sha256=sha)
            else:
                before = len(self.gaps)
                try:
                    if kind == 'zip':
                        self.zip_members(data, sha, depth)
                    elif kind == 'tar':
                        self.tar_members(data, sha, depth)
                    else:
                        with gzip.GzipFile(fileobj=io.BytesIO(data)) as f:
                            uncompressed = self.stream(f, self.limits.max_member_bytes)
                        if uncompressed is None:
                            self.gap('oversized_or_budgeted_archive_member', parentSha256=sha)
                        else:
                            child_name = name[:-3] if lower.endswith('.gz') else 'gzip-content'
                            self.member(sha, child_name, 'file', uncompressed, depth)
                except (OSError, ValueError, EOFError, zipfile.BadZipFile, zipfile.LargeZipFile, tarfile.TarError, RuntimeError, zlib.error):
                    self.gap('archive_read_or_integrity_failure', sha256=sha)
                if len(self.gaps) != before:
                    record['scanStatus'] = 'partial'
        return sha

    def member(self, parent: str, name: str, kind: str, data: bytes | None, depth: int):
        row = {'parentSha256': parent, **path_record(name), 'type': kind, 'sha256': None,
               'bytes': len(data) if data is not None else None, 'categories': []}
        self.members.append(row)
        if len(self.members) % 5000 == 0:
            self.checkpoint('archive_members', len(self.members))
        if not canonical_path(name):
            row['categories'].append('unsafe_archive_path')
            self.gap('unsafe_archive_path', parentSha256=parent, **path_record(name))
        problem = path_issue(name)
        if problem and problem != 'unsafe_source_path':
            row['categories'].append(problem)
        if data is not None:
            row['sha256'] = self.content(data, name, depth=depth+1, expanded=True)

    def allow_member(self, parent: str, name: str, size: int) -> bool:
        self.member_count += 1
        if self.member_count > self.limits.max_members:
            self.gap('archive_member_limit_exceeded', parentSha256=parent)
            return False
        if size < 0 or size > self.limits.max_member_bytes or not self.budget(size, expanded=True):
            self.gap('oversized_or_budgeted_archive_member', parentSha256=parent, **path_record(name), bytes=size)
            return False
        return True

    def zip_members(self, data: bytes, parent: str, depth: int):
        names = set()
        with zipfile.ZipFile(io.BytesIO(data)) as archive:
            self.contents[parent]['declaredArchiveMembers'] = len(archive.infolist())
            for item in archive.infolist():
                name = item.filename.rstrip('/') if item.is_dir() else item.filename
                if name in names:
                    self.gap('duplicate_archive_path', parentSha256=parent, **path_record(name))
                names.add(name)
                if not self.allow_member(parent, name, item.file_size):
                    if self.member_count > self.limits.max_members:
                        break
                    continue
                mode = (item.external_attr >> 16) & 0o170000
                if stat.S_ISLNK(mode) or mode not in (0, stat.S_IFREG, stat.S_IFDIR):
                    self.member(parent, name, 'symlink_or_special', None, depth)
                    self.gap('archive_symlink_or_special', parentSha256=parent, **path_record(name))
                    continue
                if item.flag_bits & 1:
                    self.gap('encrypted_archive_member', parentSha256=parent, **path_record(name))
                    continue
                if item.is_dir():
                    self.member(parent, name, 'directory', None, depth)
                    continue
                with archive.open(item) as stream:
                    member_data = self.stream(stream, self.limits.max_member_bytes)
                if member_data is None or len(member_data) != item.file_size:
                    self.gap('archive_member_read_incomplete', parentSha256=parent, **path_record(name))
                    continue
                self.member(parent, name, 'file', member_data, depth)

    def tar_members(self, data: bytes, parent: str, depth: int):
        names = set()
        with tarfile.open(fileobj=io.BytesIO(data), mode='r:') as archive:
            for item in archive:
                name = item.name.rstrip('/') if item.isdir() else item.name
                if name in names:
                    self.gap('duplicate_archive_path', parentSha256=parent, **path_record(name))
                names.add(name)
                if not self.allow_member(parent, name, item.size):
                    if self.member_count > self.limits.max_members:
                        break
                    continue
                if not item.isfile() and not item.isdir():
                    self.member(parent, name, 'symlink_or_special', None, depth)
                    self.gap('archive_symlink_or_special', parentSha256=parent, **path_record(name))
                    continue
                if item.isdir():
                    self.member(parent, name, 'directory', None, depth)
                    continue
                with archive.extractfile(item) as stream:
                    value = self.stream(stream, self.limits.max_member_bytes)
                if value is None or len(value) != item.size:
                    self.gap('archive_member_read_incomplete', parentSha256=parent, **path_record(name))
                else:
                    self.member(parent, name, 'file', value, depth)

    def source(self, root: Path, names: list[str]):
        for position, name in enumerate(sorted(set(names)), 1):
            if position % 500 == 0:
                self.checkpoint('source', position)
            row = {'scope': 'retained_evidence' if retained(name) else 'active_source',
                   **path_record(name), 'type': 'file', 'sha256': None, 'categories': []}
            self.occurrences.append(row)
            if not canonical_path(name):
                self.gap('unsafe_source_path', **path_record(name))
                continue
            problem = path_issue(name)
            if problem:
                row['categories'].append(problem)
            path = root
            bad = False
            for part in PurePosixPath(name).parts:
                path /= part
                if path.is_symlink():
                    bad = True
                    break
            if bad:
                row['type'] = 'symlink'
                self.gap('source_symlink_requires_review', **path_record(name))
                continue
            if not path.exists():
                # Preserve deletion as a state, not a successful source read.
                row['type'] = 'deleted_worktree_path'
                continue
            try:
                with source_open(root, name) as f:
                    before = os.fstat(f.fileno())
                    if not stat.S_ISREG(before.st_mode):
                        self.gap('non_regular_source', **path_record(name))
                        continue
                    if before.st_size > self.limits.max_blob_bytes or not self.budget(before.st_size):
                        self.gap('oversized_or_budgeted_source', **path_record(name), bytes=before.st_size)
                        continue
                    data = f.read(self.limits.max_blob_bytes+1)
                    after = os.fstat(f.fileno())
                if (before.st_ino, before.st_size, before.st_mtime_ns) != (after.st_ino, after.st_size, after.st_mtime_ns) or len(data) != before.st_size:
                    self.gap('source_changed_during_read', **path_record(name))
                    continue
                self.source_states[name] = (after.st_ino, after.st_size, after.st_mtime_ns)
                row['sha256'] = self.content(data, name)
            except OSError:
                self.gap('source_read_unavailable', **path_record(name))

    def verify_source_states(self, root: Path):
        for name, before in self.source_states.items():
            try:
                with source_open(root, name) as f:
                    after = os.fstat(f.fileno())
                if before != (after.st_ino, after.st_size, after.st_mtime_ns):
                    self.gap('source_changed_after_scan', **path_record(name))
            except OSError:
                self.gap('source_changed_after_scan', **path_record(name))

    def history(self, root: Path):
        try:
            raw = git(root, ['rev-list', '--objects', '--all', '--missing=print'])
            objects = {}
            for line in raw.splitlines():
                if line.startswith(b'?'):
                    self.gap('missing_reachable_git_object')
                    continue
                oid, _, path = line.partition(b' ')
                objects[oid.decode('ascii')] = path.decode('utf-8', 'surrogateescape')
            check = git(root, ['cat-file', '--batch-check=%(objectname) %(objecttype) %(objectsize)'],
                        ('\n'.join(objects)+'\n').encode())
            blobs = []
            for line in check.splitlines():
                fields = line.decode('ascii').split()
                if len(fields) != 3 or fields[1] not in ('blob', 'tree', 'commit', 'tag'):
                    self.gap('git_object_inventory_incomplete')
                elif fields[1] == 'blob':
                    blobs.append((fields[0], int(fields[2])))
            with subprocess.Popen(['git', 'cat-file', '--batch'], cwd=root, stdin=subprocess.PIPE,
                                  stdout=subprocess.PIPE, stderr=subprocess.DEVNULL) as process:
                try:
                    for position, (oid, size) in enumerate(blobs, 1):
                        if position % 1000 == 0:
                            self.checkpoint('history', position)
                        name = objects[oid]
                        row = {'scope': 'reachable_git_blob', 'gitObject': oid, **path_record(name),
                               'type': 'blob', 'sha256': None, 'bytes': size, 'categories': []}
                        self.occurrences.append(row)
                        problem = path_issue(name) if name else None
                        if problem:
                            row['categories'].append(problem)
                        if size > self.limits.max_blob_bytes or not self.budget(size):
                            self.gap('oversized_or_budgeted_git_blob', gitObject=oid, bytes=size)
                            continue
                        process.stdin.write((oid+'\n').encode()); process.stdin.flush()
                        header = process.stdout.readline().decode('ascii').split()
                        if header != [oid, 'blob', str(size)]:
                            self.gap('git_blob_read_incomplete', gitObject=oid)
                            break
                        data = process.stdout.read(size)
                        delimiter = process.stdout.read(1)
                        if len(data) != size or delimiter != b'\n':
                            self.gap('git_blob_read_incomplete', gitObject=oid)
                            break
                        row['sha256'] = self.content(data, name)
                    process.stdin.close()
                    process.wait(timeout=30)
                    if process.returncode:
                        self.gap('git_blob_reader_failed')
                finally:
                    if process.poll() is None:
                        process.kill(); process.wait()
        except (OSError, ValueError, UnicodeError, subprocess.SubprocessError):
            self.gap('git_history_inventory_unavailable')

    def sealed(self, path: Path, expected_sha256: str):
        location = path_record(str(path))
        row = {'scope': 'sealed_candidate', **location, 'type': 'archive', 'sha256': None, 'categories': []}
        self.occurrences.append(row)
        if not re.fullmatch(r'[0-9a-f]{64}', expected_sha256):
            self.gap('invalid_sealed_archive_hash', **location)
            return
        try:
            if path.is_symlink() or not path.is_file():
                self.gap('sealed_archive_not_regular', **location)
                return
            size = path.stat().st_size
            if size > self.limits.max_blob_bytes or not self.budget(size):
                self.gap('oversized_or_budgeted_sealed_archive', **location)
                return
            data = path.read_bytes()
            if digest(data) != expected_sha256:
                self.gap('sealed_archive_hash_mismatch', **location)
                return
            row['sha256'] = self.content(data, path.name)
        except OSError:
            self.gap('sealed_archive_unavailable', **location)

    def report(self) -> dict:
        findings = [{'sha256': sha, 'category': category} for sha, row in sorted(self.contents.items()) for category in row['categories']]
        path_findings = [{'scope': row.get('scope', 'archive_member'), **{k: row[k] for k in ('path', 'pathSha256', 'sha256')},
                          'category': category} for row in self.occurrences+self.members for category in row['categories']]
        return {'schemaVersion': 1, 'passed': not self.gaps and not findings and not path_findings,
                'coverageComplete': not self.gaps, 'matchedValuesIncluded': False, 'networkCalls': 0,
                'limits': dataclasses.asdict(self.limits), 'summary': {'sourceOccurrences': sum(r['scope'] in ('active_source', 'retained_evidence') for r in self.occurrences),
                'reachableGitBlobs': sum(r['scope'] == 'reachable_git_blob' for r in self.occurrences),
                'sealedArchives': sum(r['scope'] == 'sealed_candidate' for r in self.occurrences),
                'uniqueContents': len(self.contents), 'archiveMembers': len(self.members), 'uniqueBytesRead': self.bytes_read,
                'uniqueExpandedBytes': self.expanded_bytes, 'contentFindings': len(findings), 'pathFindings': len(path_findings), 'coverageGaps': len(self.gaps)},
                'contentFindings': findings, 'pathFindings': path_findings, 'coverageGaps': self.gaps,
                'occurrences': self.occurrences, 'archiveMembers': self.members,
                'contents': [self.contents[k] for k in sorted(self.contents)],
                'scopeNotes': ['Git source inventory includes tracked and untracked nonignored files; ignored workstation dependencies/credentials are outside active source scope.',
                    'Reachable Git objects use all local refs. Reflog-only/dangling objects and unavailable remote refs are outside this scope.',
                    'Git object paths are representative names from rev-list, not a complete per-commit path history.',
                    'Content is scanned once per SHA-256; occurrences and archive member edges retain all inventoried locations.',
                    'Binary bytes and UTF-16 text are scanned; supported ZIP/TAR/gzip contents recurse without extraction. Unsupported/encrypted/oversized/missing material fails coverage.',
                    'Public client-key classification does not prove provider restrictions; no credential validity, rotation, permissions or production safety is asserted.']}


def git(root: Path, args: list[str], data=None) -> bytes:
    return subprocess.run(['git', *args], cwd=root, input=data, stdout=subprocess.PIPE,
                          stderr=subprocess.DEVNULL, check=True, timeout=60).stdout


def source_open(root: Path, name: str):
    """Open relative source through no-follow directory FDs, including parents."""
    directory = os.open(root, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    try:
        parts = PurePosixPath(name).parts
        for part in parts[:-1]:
            following = os.open(part, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=directory)
            os.close(directory)
            directory = following
        descriptor = os.open(parts[-1], os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK, dir_fd=directory)
        return os.fdopen(descriptor, 'rb')
    finally:
        os.close(directory)


def run(root: Path, archives: list[tuple[Path, str]], limits: Limits | None = None, *, progress=False) -> dict:
    audit = Audit(limits, progress=progress)
    try:
        refs_before = git(root, ['show-ref'])
        names_raw = git(root, ['ls-files', '--cached', '--others', '--exclude-standard', '-z'])
        names = [n.decode('utf-8', 'surrogateescape') for n in names_raw.split(b'\x00') if n]
        audit.source(root, names)
        audit.history(root)
        for path, expected in archives:
            audit.sealed(path, expected)
        audit.verify_source_states(root)
        if refs_before != git(root, ['show-ref']):
            audit.gap('git_refs_changed_during_scan')
        if names_raw != git(root, ['ls-files', '--cached', '--others', '--exclude-standard', '-z']):
            audit.gap('source_inventory_changed_during_scan')
    except (OSError, UnicodeError, subprocess.SubprocessError):
        audit.gap('source_inventory_unavailable')
    return audit.report()


class SafeArgumentParser(argparse.ArgumentParser):
    def error(self, message):
        self.exit(2, 'invalid_audit_arguments\n')


def report_destination(root: Path, path: Path, archives: list[tuple[Path, str]]) -> Path:
    destination = path.absolute()
    if destination.is_symlink() or any(parent.is_symlink() for parent in destination.parents):
        raise ValueError('invalid_report_destination')
    if destination == Path(__file__).absolute() or destination in [p.absolute() for p, _ in archives]:
        raise ValueError('invalid_report_destination')
    try:
        relative = destination.relative_to(root)
    except ValueError:
        return destination
    if '.git' in relative.parts:
        raise ValueError('invalid_report_destination')
    tracked = subprocess.run(['git', 'ls-files', '--error-unmatch', '--', str(relative)], cwd=root,
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    ignored = subprocess.run(['git', 'check-ignore', '--quiet', '--no-index', '--', str(relative)], cwd=root,
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    if tracked.returncode == 0 or ignored.returncode != 0:
        raise ValueError('invalid_report_destination')
    return destination


def write_report(path: Path, report: dict):
    path.parent.mkdir(parents=True, exist_ok=True)
    name = None
    try:
        with tempfile.NamedTemporaryFile(mode='w', dir=path.parent, prefix='.audit-report-', delete=False) as f:
            name = f.name
            f.write(json.dumps(report, indent=2, ensure_ascii=True)+'\n')
            f.flush(); os.fsync(f.fileno())
        os.replace(name, path)
    finally:
        if name is not None and os.path.exists(name):
            os.unlink(name)


def main(argv=None) -> int:
    parser = SafeArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path.cwd())
    parser.add_argument('--report', type=Path, required=True)
    parser.add_argument('--sealed', nargs=2, action='append', metavar=('PATH', 'SHA256'), default=[])
    parser.add_argument('--progress', action='store_true')
    for field, default in dataclasses.asdict(Limits()).items():
        parser.add_argument('--'+field.replace('_', '-'), type=int, default=default)
    args = parser.parse_args(argv)
    try:
        limits = Limits(**{f.name: getattr(args, f.name) for f in dataclasses.fields(Limits)})
        root = args.root.resolve()
        archives = [(Path(p), h) for p, h in args.sealed]
        destination = report_destination(root, args.report, archives)
        report = run(root, archives, limits, progress=args.progress)
        write_report(destination, report)
        print(json.dumps({'passed': report['passed'], 'coverageComplete': report['coverageComplete'],
                          'summary': report['summary'], 'report': safe_path(str(args.report))}))
        return 0 if report['passed'] else 1
    except Exception:
        print(json.dumps({'passed': False, 'coverageComplete': False, 'error': 'audit_or_report_unavailable'}))
        return 2


if __name__ == '__main__':
    sys.exit(main())
