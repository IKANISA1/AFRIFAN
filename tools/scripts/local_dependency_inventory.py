#!/usr/bin/env python3
"""Observe active dependency evidence locally; never fetch, install, approve, or upgrade.

Requires Python >=3.10 and PyYAML==6.0.3. Generated facts are deterministic for
the same input bytes and caches. License declarations are evidence, not approval.
"""
from __future__ import annotations

import argparse
import base64
import collections
import concurrent.futures
import hashlib
import importlib.metadata
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tarfile
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
import zipfile

try:
    import yaml
except ImportError:
    raise SystemExit('PyYAML==6.0.3 is required; install it through the CI toolchain')

APPS = ('rayon_sports', 'as_vita', 'vitalo', 'nkana', 'costa_do_sol')
SCHEMA_VERSION = 1
LICENSE_NAME = re.compile(r'^(licen[sc]e|copying|copyright|notice)(?:$|[._-])', re.I)
DEFAULT_PREFIX = 'docs/release/local-dependency-inventory-2026-09-30'


class InventoryError(ValueError):
    pass


class UniqueYamlLoader(yaml.SafeLoader):
    def construct_mapping(self, node, deep=False):
        self.flatten_mapping(node)
        result = {}
        for key_node, value_node in node.value:
            key = self.construct_object(key_node, deep=deep)
            if key in result:
                raise InventoryError('Duplicate YAML key')
            result[key] = self.construct_object(value_node, deep=deep)
        return result


def unique_pairs(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise InventoryError('Duplicate JSON key')
        result[key] = value
    return result


def load_json(path):
    return json.loads(Path(path).read_text(), object_pairs_hook=unique_pairs)


def load_yaml(path):
    return yaml.load(Path(path).read_text(), Loader=UniqueYamlLoader)


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'), ensure_ascii=False)


def digest_file(path, algorithm='sha256'):
    h = hashlib.new(algorithm)
    with Path(path).open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()


def safe_url(value):
    """Never write URL credentials or query tokens into an inventory."""
    if not value:
        return value
    parsed = urllib.parse.urlsplit(str(value))
    query = urllib.parse.parse_qsl(parsed.query, keep_blank_values=True)
    safe_build_query = parsed.hostname == 'esm.sh' and all(key == 'target' and re.fullmatch('[A-Za-z0-9_-]+', val) for key, val in query)
    if parsed.username or parsed.password or (parsed.query and not safe_build_query) or parsed.fragment:
        raise InventoryError('Dependency source URL contains credentials, query, or fragment')
    return str(value)


def exact_version(value):
    return isinstance(value, str) and bool(re.fullmatch(r'\d+\.\d+\.\d+(?:[-+][A-Za-z0-9.+_-]+)?', value))


def license_paths(root):
    """Only package-owned text locations, never nested dependency trees."""
    root = Path(root).resolve()
    if not root.is_dir():
        return []
    candidates = list(root.iterdir())
    for name in ('licenses', 'license', 'LICENSES', 'legal', 'Legal'):
        directory = root / name
        if directory.is_dir() and directory.resolve().is_relative_to(root):
            candidates.extend(directory.glob('*'))
    result = []
    for path in sorted(set(candidates)):
        if path.is_file() and LICENSE_NAME.match(path.name):
            if not path.resolve().is_relative_to(root):
                raise InventoryError('License symlink escapes package root')
            if path.stat().st_size <= 4 * 1024 * 1024:
                result.append(path)
    return result


def npm_name(location, entry):
    return entry.get('name') or location.rsplit('node_modules/', 1)[-1]


def npm_resolve(packages, location, name):
    """Resolve an edge with Node's nearest ancestor node_modules rules."""
    current = location
    while True:
        candidate = (current + '/' if current else '') + 'node_modules/' + name
        if candidate in packages:
            return candidate
        if not current:
            return None
        current = current.rsplit('/node_modules/', 1)[0] if '/node_modules/' in current else ''


def sri_records(value):
    result = []
    for item in str(value or '').split():
        algorithm, sep, encoded = item.partition('-')
        if not sep or algorithm not in ('sha256', 'sha384', 'sha512', 'sha1'):
            raise InventoryError('Malformed or unsupported SRI integrity')
        try:
            raw = base64.b64decode(encoded, validate=True)
        except ValueError as error:
            raise InventoryError('Malformed SRI base64') from error
        if len(raw) != hashlib.new(algorithm).digest_size:
            raise InventoryError('Incorrect SRI digest length')
        result.append({'algorithm': algorithm, 'value': raw.hex(), 'basis': 'lockfile-declared archive'})
    return result


class Inventory:
    def __init__(self, root, android_resolutions=None, pub_cache=None, npm_cache=None, swift_cache=None, action_sources=None):
        self.root = Path(root).resolve()
        self.pub_cache = Path(pub_cache or Path.home() / '.pub-cache')
        self.npm_cache = Path(npm_cache or Path.home() / '.npm')
        self.swift_cache = Path(swift_cache or Path.home() / 'Library/Developer/Xcode/DerivedData')
        self.android_resolutions = Path(android_resolutions) if android_resolutions else None
        self.action_sources = Path(action_sources) if action_sources else None
        self.evidence = {}
        self.components = {}
        self.edges = set()
        self.gaps = {}
        self.coverage = {}
        self.dart_by_name = {}

    def path_name(self, path):
        path = Path(path).absolute()
        try:
            return str(path.relative_to(self.root))
        except ValueError:
            return str(path)

    def file_evidence(self, path, role):
        path = Path(path)
        key = self.path_name(path)
        if not path.is_file():
            self.gap('missing-evidence', key, role)
            return None
        value = {'kind': 'file', 'path': key, 'sha256': digest_file(path), 'bytes': path.stat().st_size, 'roles': []}
        if key in self.evidence and self.evidence[key]['sha256'] != value['sha256']:
            raise InventoryError('Input changed during observation')
        value['roles'] = sorted(set(self.evidence.get(key, {}).get('roles', []) + [role]))
        self.evidence[key] = value
        return key

    def bytes_evidence(self, kind, fields, content, role):
        key = kind + ':' + hashlib.sha256(canonical(fields).encode()).hexdigest()
        self.evidence[key] = {'kind': kind, **fields, 'sha256': hashlib.sha256(content).hexdigest(),
                              'bytes': len(content), 'roles': [role]}
        return key

    def gap(self, kind, subject, detail, exact=False):
        value = {'kind': kind, 'subject': subject, 'detail': detail, 'blocksExact': exact}
        self.gaps[canonical(value)] = value

    def component(self, ecosystem, name, version, source, **fields):
        identity = {'ecosystem': ecosystem, 'name': name, 'version': version, 'source': source}
        ref = 'dependency:' + hashlib.sha256(canonical(identity).encode()).hexdigest()[:24]
        if ref not in self.components:
            self.components[ref] = {'ref': ref, **identity, 'occurrences': [], 'evidence': [], 'integrities': [],
                                    'licenseDeclarations': [], 'licenseEvidence': [], **fields}
        return self.components[ref]

    def licenses(self, component, root):
        for path in license_paths(root):
            key = self.file_evidence(path, 'license-text')
            if key:
                component['licenseEvidence'].append(key)

    def read_dart(self):
        root_manifest = self.root / 'pubspec.yaml'
        self.file_evidence(root_manifest, 'workspace-manifest')
        manifest = load_yaml(root_manifest)
        lock_path = self.root / 'pubspec.lock'
        lock_key = self.file_evidence(lock_path, 'dart-lockfile')
        locked = load_yaml(lock_path)['packages']
        config_path = self.root / '.dart_tool/package_config.json'
        config_key = self.file_evidence(config_path, 'dart-active-resolution')
        config = load_json(config_path)
        resolved = {}
        for item in config['packages']:
            if item['name'] in resolved:
                raise InventoryError('Duplicate package_config package')
            uri = urllib.parse.urlsplit(item['rootUri'])
            if uri.scheme == 'file':
                path = Path(urllib.parse.unquote(uri.path))
            elif not uri.scheme:
                path = (config_path.parent / urllib.parse.unquote(item['rootUri'])).resolve()
            else:
                raise InventoryError('Unsupported package_config root URI')
            resolved[item['name']] = path
        flutter_uri = config.get('flutterRoot', '')
        flutter_root = Path(urllib.parse.unquote(urllib.parse.urlsplit(flutter_uri).path))
        sdk_path = flutter_root / 'bin/cache/flutter.version.json'
        sdk_key = self.file_evidence(sdk_path, 'actual-flutter-sdk')
        sdk = load_json(sdk_path) if sdk_key else {}
        fvm_path = self.root / '.fvmrc'
        fvm_key = self.file_evidence(fvm_path, 'repository-flutter-pin')
        if fvm_key:
            pinned = fvm_path.read_text().strip()
            if pinned.startswith('{'):
                pinned = load_json(fvm_path).get('flutter')
            if pinned != sdk.get('frameworkVersion'):
                raise InventoryError('Actual Flutter SDK differs from repository pin')
        sdk_component = self.component('sdk', 'flutter', sdk.get('frameworkVersion'),
                                       {'kind': 'sdk', 'revision': sdk.get('frameworkRevision'), 'engineRevision': sdk.get('engineRevision')})
        sdk_component['evidence'].extend([sdk_key, fvm_key])
        self.licenses(sdk_component, flutter_root)
        self.flutter_component = sdk_component
        member_paths = [Path('.')] + [Path(p) for p in manifest.get('workspace', [])]
        if len(set(member_paths)) != len(member_paths):
            raise InventoryError('Duplicate workspace member')
        for member in member_paths:
            path = self.root / member / 'pubspec.yaml'
            if not path.resolve().is_relative_to(self.root):
                raise InventoryError('Workspace member escapes repository')
            key = self.file_evidence(path, 'active-workspace-pubspec')
            pub = load_yaml(path)
            item = self.component('dart-local', pub['name'], str(pub.get('version', 'unspecified')),
                                  {'kind': 'workspace', 'path': str(member)})
            item['evidence'].append(key)
            item['occurrences'].append(str(member))
            self.licenses(item, path.parent)
            self.dart_by_name[pub['name']] = item
        for name, entry in sorted(locked.items()):
            version, kind = entry['version'], entry['source']
            description = entry['description']
            source = {'kind': kind}
            if kind == 'hosted':
                source['url'] = safe_url(description['url'])
            elif kind == 'sdk':
                source.update(sdk='flutter', revision=sdk.get('frameworkRevision'))
            else:
                self.gap('unsupported-dart-source', name, kind, True)
            item = self.component('dart', name, version, source, dependencyClass=entry['dependency'])
            item['evidence'].extend([lock_key, config_key])
            package_root = resolved.get(name)
            if not package_root:
                self.gap('dart-not-resolved', name, 'Locked package absent from package_config', True)
            else:
                item['occurrences'].append(self.path_name(package_root))
                pubspec = package_root / 'pubspec.yaml'
                key = self.file_evidence(pubspec, 'cached-dart-pubspec')
                if key:
                    actual = load_yaml(pubspec)
                    if actual.get('name') != name or (kind == 'hosted' and str(actual.get('version')) != version):
                        raise InventoryError('Dart cached package differs from lockfile')
                    item['evidence'].append(key)
                    if actual.get('license'):
                        item['licenseDeclarations'].append(str(actual['license']))
                self.licenses(item, package_root)
            if kind == 'hosted':
                declared = description.get('sha256')
                if not re.fullmatch('[0-9a-f]{64}', str(declared)):
                    self.gap('dart-archive-integrity-missing', name, 'No exact hosted SHA256', True)
                else:
                    item['integrities'].append({'algorithm': 'sha256', 'value': declared, 'basis': 'pub-lockfile-declared archive'})
                    host = urllib.parse.urlsplit(source['url']).hostname
                    hash_path = self.pub_cache / 'hosted-hashes' / host / (name + '-' + version + '.sha256')
                    hash_key = self.file_evidence(hash_path, 'pub-cache-archive-hash-record')
                    if hash_key:
                        if hash_path.read_text().strip() != declared:
                            raise InventoryError('Pub cache archive hash record differs from lockfile')
                        item['evidence'].append(hash_key)
            else:
                item['integrities'].append({'algorithm': 'sha1', 'value': sdk.get('frameworkRevision', ''), 'basis': 'sdk-git-revision; not archive digest'})
            self.dart_by_name[name] = item
        # Pubspec declarations are mapped to the selected workspace resolution;
        # dev_dependencies are included only for active workspace members.
        for name, item in self.dart_by_name.items():
            package_root = resolved.get(name)
            if not package_root or not (package_root / 'pubspec.yaml').is_file():
                continue
            pub = load_yaml(package_root / 'pubspec.yaml')
            kinds = ['dependencies'] + (['dev_dependencies'] if item['ecosystem'] == 'dart-local' else [])
            for kind in kinds:
                for target in pub.get(kind, {}) or {}:
                    if target in self.dart_by_name:
                        self.edges.add((item['ref'], self.dart_by_name[target]['ref'], 'dart:' + kind))
                    else:
                        self.gap('dart-edge-unresolved', name + ':' + target, kind, True)
        extras = sorted(set(resolved) - set(self.dart_by_name))
        for name in extras:
            self.gap('dart-active-unlocked', name, 'Package config has no workspace or lockfile entry', True)
        self.coverage['dart'] = {'workspaceMembers': len(member_paths) - 1, 'workspaceWithRoot': len(member_paths),
                                 'lockedPackages': len(locked), 'hostedPackages': sum(e['source'] == 'hosted' for e in locked.values()),
                                 'activeResolvedPackages': len(resolved), 'flutterVersion': sdk.get('frameworkVersion'),
                                 'dartVersion': sdk.get('dartSdkVersion')}

    def read_npm(self):
        web = self.root / 'apps/rayon_sports/web'
        lock_key = self.file_evidence(web / 'package-lock.json', 'npm-lockfile')
        manifest_key = self.file_evidence(web / 'package.json', 'npm-manifest')
        lock = load_json(web / 'package-lock.json')
        if lock.get('lockfileVersion') != 3:
            raise InventoryError('Expected npm lockfileVersion3')
        packages = lock['packages']
        by_location = {}
        installed = archive_verified = 0
        for location, entry in sorted(packages.items()):
            if location and (location.startswith('/') or '..' in Path(location).parts or not location.startswith('node_modules/')):
                raise InventoryError('Npm lock location escapes installation')
            name = npm_name(location, entry) if location else lock['name']
            version = entry.get('version')
            if not version:
                self.gap('npm-version-missing', location, 'No lockfile version', True)
            source = {'kind': 'npm-registry', 'url': safe_url(entry.get('resolved'))} if location else {'kind': 'workspace', 'path': 'apps/rayon_sports/web'}
            bundle_container = None
            if entry.get('inBundle'):
                bundle_container = location.rsplit('/node_modules/', 1)[0]
                while bundle_container and packages[bundle_container].get('inBundle'):
                    bundle_container = bundle_container.rsplit('/node_modules/', 1)[0]
                if not bundle_container or not packages[bundle_container].get('integrity'):
                    raise InventoryError('Bundled dependency has no integrity-bearing container')
                source = {'kind': 'npm-bundle', 'container': bundle_container,
                          'url': safe_url(packages[bundle_container].get('resolved'))}
            item = self.component('npm', name, version, source)
            item['evidence'].append(lock_key)
            item['occurrences'].append('apps/rayon_sports/web/' + location)
            item.setdefault('platforms', []).append({key: entry[key] for key in ('os', 'cpu', 'libc', 'optional', 'dev') if key in entry})
            item['licenseDeclarations'].extend([str(entry['license'])] if entry.get('license') else [])
            integrities = sri_records(packages[bundle_container]['integrity'] if bundle_container else entry.get('integrity'))
            if bundle_container:
                for integrity in integrities:
                    integrity['basis'] = 'lockfile-declared containing bundle archive; not child archive'
            item['integrities'].extend(integrities)
            if location and not integrities:
                self.gap('npm-integrity-missing', name + '@' + str(version), 'Registry archive has no SRI', True)
            package_root = web / location
            path = package_root / 'package.json'
            if path.is_file():
                actual = load_json(path)
                key = self.file_evidence(path, 'installed-npm-manifest')
                item['evidence'].append(key)
                if str(actual.get('version')) != version:
                    raise InventoryError('Installed npm package version differs from lockfile')
                installed += bool(location)
                if actual.get('license'):
                    item['licenseDeclarations'].append(canonical(actual['license']) if isinstance(actual['license'], dict) else str(actual['license']))
                self.licenses(item, package_root)
            elif location:
                item.setdefault('absentInstalledOccurrences', []).append(location)
            for integrity in integrities:
                value = integrity['value']
                cached = self.npm_cache / '_cacache/content-v2' / integrity['algorithm'] / value[:2] / value[2:4] / value[4:]
                if cached.is_file():
                    if digest_file(cached, integrity['algorithm']) != value:
                        raise InventoryError('Cached npm archive differs from locked SRI')
                    key = self.file_evidence(cached, 'npm-archive-matches-SRI')
                    item['evidence'].append(key)
                    if bundle_container:
                        prefix = 'package/' + location[len(bundle_container) + 1:] + '/'
                        with tarfile.open(cached, 'r:*') as archive:
                            for member in archive.getmembers():
                                if member.isfile() and member.name.startswith(prefix) and LICENSE_NAME.match(Path(member.name).name):
                                    license_key = self.bytes_evidence('tar-member', {'archive': self.path_name(cached), 'member': member.name},
                                                                     archive.extractfile(member).read(), 'license-text')
                                    item['licenseEvidence'].append(license_key)
                    archive_verified += 1
                    break
            by_location[location] = item
        for location, entry in sorted(packages.items()):
            for kind in ('dependencies', 'devDependencies', 'optionalDependencies', 'peerDependencies'):
                if location and kind == 'devDependencies':
                    continue
                for name in entry.get(kind, {}):
                    target = npm_resolve(packages, location, name)
                    if target is not None:
                        self.edges.add((by_location[location]['ref'], by_location[target]['ref'], 'npm:' + kind))
                    elif kind not in ('optionalDependencies', 'peerDependencies'):
                        self.gap('npm-edge-unresolved', location + ':' + name, kind, True)
        root_manifest = load_json(web / 'package.json')
        for kind in ('dependencies', 'devDependencies', 'optionalDependencies'):
            if root_manifest.get(kind, {}) != packages[''].get(kind, {}):
                raise InventoryError('Npm manifest constraints differ from lockfile root')
        by_location['']['evidence'].append(manifest_key)
        self.coverage['npm'] = {'lockedLocations': len(packages) - 1, 'installedLocations': installed,
                                'cacheArchivesVerifiedAgainstSRI': archive_verified,
                                'platformOptionalAbsentLocations': sum(len(c.get('absentInstalledOccurrences', [])) for c in self.components.values()),
                                'lockfileVersion': 3, 'packageManager': root_manifest.get('packageManager')}

    def git_bytes(self, repository, revision, name):
        result = subprocess.run(['git', '-C', str(repository), 'show', revision + ':' + name], capture_output=True, timeout=15)
        return result.stdout if result.returncode == 0 else None

    def swift_git_evidence(self, item, identity, revision):
        normalized = identity.lower()
        candidates = sorted(p for p in self.swift_cache.glob('*/SourcePackages/checkouts/*') if p.name.lower() == normalized)
        for repository in candidates:
            result = subprocess.run(['git', '-C', str(repository), 'cat-file', '-e', revision + '^{commit}'], capture_output=True, timeout=15)
            if result.returncode:
                continue
            tree = subprocess.run(['git', '-C', str(repository), 'ls-tree', '-r', '--name-only', revision], capture_output=True, text=True, check=True, timeout=15).stdout.splitlines()
            for name in tree:
                parts = Path(name).parts
                is_license = len(parts) <= 2 and LICENSE_NAME.match(parts[-1])
                if name == 'Package.swift' or is_license:
                    content = self.git_bytes(repository, revision, name)
                    key = self.bytes_evidence('git-object', {'repository': str(repository), 'revision': revision, 'gitPath': name}, content,
                                              'license-text' if is_license else 'exact-swift-package-manifest')
                    item['licenseEvidence' if is_license else 'evidence'].append(key)
                    if name == 'Package.swift':
                        # Immutable binary declarations are separate archive evidence.
                        text = content.decode('utf-8')
                        for match in re.finditer(r'\.binaryTarget\s*\(\s*name:\s*"([^"]+)"\s*,\s*url:\s*"([^"]+)"\s*,\s*checksum:\s*"([0-9a-f]{64})"', text, re.S):
                            item.setdefault('binaryDeclarations', []).append({'name': match[1], 'url': safe_url(match[2]),
                                                                             'sha256': match[3], 'basis': 'exact-revision manifest declaration; archive not rehashed'})
            item['source']['licenseRevisionVerified'] = revision
            return
        self.gap('swift-revision-source-unavailable', identity + '@' + revision, 'No matching commit object in local Xcode checkout cache')

    def read_ios(self):
        targets = {}
        for app in APPS:
            ios = self.root / 'apps' / app / 'ios'
            target = {'swiftLockfiles': [], 'remotePins': 0, 'localFlutterPackages': 0, 'podLockfile': None}
            pin_sets = []
            for container in ('Runner.xcodeproj/project.xcworkspace', 'Runner.xcworkspace'):
                path = ios / container / 'xcshareddata/swiftpm/Package.resolved'
                key = self.file_evidence(path, 'swift-lockfile:' + app)
                if not key:
                    continue
                lock = load_json(path)
                pins = lock.get('pins', lock.get('object', {}).get('pins', []))
                pin_sets.append({p['identity']: (p['location'], p['state']) for p in pins})
                target['swiftLockfiles'].append(key)
                for pin in pins:
                    state = pin['state']; revision = state.get('revision')
                    if not re.fullmatch('[0-9a-f]{40}', str(revision)):
                        self.gap('swift-revision-missing', app + ':' + pin['identity'], 'Pin has no exact git revision', True)
                    item = self.component('swift', pin['identity'], state.get('version', revision),
                                          {'kind': 'git', 'url': safe_url(pin['location']), 'revision': revision})
                    item['evidence'].append(key)
                    item['occurrences'].append('ios:' + app)
                    item['integrities'].append({'algorithm': 'sha1', 'value': revision, 'basis': 'git-commit identity; not archive digest'})
                    if not item.get('gitInspected'):
                        self.swift_git_evidence(item, pin['identity'], revision)
                        item['gitInspected'] = True
            if len(pin_sets) == 2 and pin_sets[0] != pin_sets[1]:
                self.gap('swift-container-pins-differ', app, 'Project and workspace lockfiles differ', True)
            target['remotePins'] = len(pin_sets[0]) if pin_sets else 0
            generated = ios / 'Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage/Package.swift'
            key = self.file_evidence(generated, 'generated-swift-plugin-map:' + app)
            if key:
                text = generated.read_text()
                for name, path in re.findall(r'\.package\(name:\s*"([^"]+)",\s*path:\s*"([^"]+)"\)', text):
                    manifest = (generated.parent / path / 'Package.swift').resolve()
                    manifest_key = self.file_evidence(manifest, 'local-swift-plugin-manifest:' + app)
                    component = self.dart_by_name.get(name) or (self.flutter_component if name == 'FlutterFramework' else None)
                    if component:
                        component['evidence'].extend([key, manifest_key])
                        component['occurrences'].append('ios:' + app + ':' + name)
                    else:
                        self.gap('swift-local-plugin-unmapped', app + ':' + name, 'No locked Dart/SDK package', True)
                    target['localFlutterPackages'] += 1
            pod_lock = ios / 'Podfile.lock'
            if pod_lock.is_file():
                key = self.file_evidence(pod_lock, 'cocoapods-lockfile:' + app)
                target['podLockfile'] = key
                lock = load_yaml(pod_lock)
                self.file_evidence(ios / 'Podfile', 'cocoapods-manifest:' + app)
                installed_lock = ios / 'Pods/Manifest.lock'
                if installed_lock.is_file():
                    self.file_evidence(installed_lock, 'installed-cocoapods-lock:' + app)
                    if load_yaml(installed_lock) != lock:
                        self.gap('pod-installed-lock-differs', app, 'Pods/Manifest.lock differs', True)
                for declaration in lock.get('PODS', []):
                    declaration = next(iter(declaration)) if isinstance(declaration, dict) else declaration
                    match = re.fullmatch(r'(.+) \(([^)]+)\)', declaration)
                    if not match:
                        self.gap('unparsed-pod-declaration', app, str(declaration), True); continue
                    name, version = match.groups()
                    source = lock.get('EXTERNAL SOURCES', {}).get(name, {})
                    item = self.component('cocoapods', name, version, {'kind': 'cocoapods', 'external': source})
                    item['evidence'].append(key); item['occurrences'].append('ios:' + app)
                    checksum = lock.get('SPEC CHECKSUMS', {}).get(name)
                    if checksum:
                        item['integrities'].append({'algorithm': 'sha1', 'value': checksum, 'basis': 'podspec checksum; not binary digest'})
                    podspec = ios / 'Pods/Local Podspecs' / (name + '.podspec.json')
                    if podspec.is_file():
                        item['evidence'].append(self.file_evidence(podspec, 'installed-podspec'))
                        spec = load_json(podspec)
                        if spec.get('license'):
                            item['licenseDeclarations'].append(canonical(spec['license']))
                    if name == 'Flutter':
                        self.edges.add((item['ref'], self.flutter_component['ref'], 'cocoapods:SDK-wrapper'))
                        item['licenseEvidence'].extend(self.flutter_component['licenseEvidence'])
            else:
                target['podLockfileAbsenceReason'] = 'Target uses generated Flutter SwiftPM packages; absence does not imply missing native inventory'
            targets[app] = target
        self.coverage['ios'] = targets

    def read_android(self):
        targets = {}
        module_cache = Path.home() / '.gradle/caches/modules-2/files-2.1'
        enriched = set()
        for app in APPS:
            android = self.root / 'apps' / app / 'android'
            for relative in ('settings.gradle.kts', 'build.gradle.kts', 'app/build.gradle.kts', 'gradle/wrapper/gradle-wrapper.properties'):
                self.file_evidence(android / relative, 'android-declaration:' + app)
            path = self.android_resolutions / (app + '.json') if self.android_resolutions else None
            if not path or not path.is_file():
                self.gap('android-resolution-unavailable', app, 'Run the offline Gradle collector for this target', True)
                targets[app] = {'resolution': None}; continue
            key = self.file_evidence(path, 'actual-offline-gradle-resolution:' + app)
            snapshot = load_json(path)
            if snapshot.get('schemaVersion') != 1 or snapshot.get('offline') is not True:
                raise InventoryError('Android snapshot must be schema1 and offline')
            if Path(snapshot['rootDirectory']).resolve() != android.resolve():
                raise InventoryError('Android snapshot belongs to another target')
            if not snapshot.get('sourceInputs'):
                self.gap('android-source-binding-unavailable', app, 'Snapshot predates collector source binding', True)
            for input_path, expected in snapshot.get('sourceInputs', {}).items():
                input_key = self.file_evidence(input_path, 'native-resolution-source-input')
                if input_key and self.evidence[input_key]['sha256'] != expected:
                    raise InventoryError('Android resolution source changed since collection')
            app_configs = {c['configuration'] for c in snapshot['configurations'] if c['project'] == ':app'}
            if not {'debugCompileClasspath', 'debugRuntimeClasspath', 'releaseCompileClasspath', 'releaseRuntimeClasspath'}.issubset(app_configs):
                self.gap('android-app-configurations-incomplete', app, 'Required debug/release compile/runtime observations absent', True)
            mirror = Path(snapshot['mavenMirror']) if snapshot.get('mavenMirror') else None
            provenance = load_json(mirror / 'africlub-mirror-provenance.json') if mirror and (mirror / 'africlub-mirror-provenance.json').is_file() else {}
            if provenance:
                self.file_evidence(mirror / 'africlub-mirror-provenance.json', 'public-immutable-maven-provenance')
            if snapshot.get('javaVersion') and snapshot.get('javaHome'):
                java_root = Path(snapshot['javaHome'])
                java = self.component('sdk', 'jdk', snapshot['javaVersion'], {'kind': 'jdk', 'vendor': snapshot.get('javaVendor')})
                java['evidence'].append(key)
                release_key = self.file_evidence(java_root / 'release', 'actual-java-runtime-metadata')
                if release_key:
                    java['evidence'].append(release_key)
                    java['integrities'].append({'algorithm': 'sha256', 'value': self.evidence[release_key]['sha256'], 'basis': 'actual JDK release metadata'})
                self.licenses(java, java_root)
            nodes = {}; unresolved = 0
            for config in snapshot['configurations']:
                context = 'android:' + app + ':' + config['project'] + ':' + config['configuration']
                for node in config['components']:
                    if node.get('localProject'):
                        continue
                    item = self.component('maven', node['group'] + ':' + node['name'], node['version'], {'kind': 'gradle-module-cache'})
                    item['evidence'].append(key); item['occurrences'].append(context)
                    nodes[node['id']] = item
                    if item['ref'] in enriched:
                        continue
                    enriched.add(item['ref'])
                    cache = module_cache / node['group'] / node['name'] / node['version']
                    artifacts = list(cache.glob('*/*'))
                    if mirror:
                        artifacts.extend((mirror / node['group'].replace('.', '/') / node['name'] / node['version']).glob('*'))
                    for artifact in sorted(set(artifacts)):
                        if not artifact.is_file() or artifact.suffix not in ('.pom', '.jar', '.aar', '.module'):
                            continue
                        artifact_key = self.file_evidence(artifact, 'resolved-native-cache-artifact')
                        item['evidence'].append(artifact_key)
                        if mirror and artifact.is_relative_to(mirror):
                            origin = provenance.get('files', {}).get(str(artifact.relative_to(mirror)))
                            if origin and origin.get('sha256') != self.evidence[artifact_key]['sha256']:
                                raise InventoryError('Native mirror artifact differs from public provenance')
                            if origin and origin.get('url'):
                                item.setdefault('artifactOrigins', []).append({'url': safe_url(origin['url']),
                                                                              'evidence': artifact_key, 'sha256': origin['sha256']})
                        sha1 = digest_file(artifact, 'sha1')
                        if re.fullmatch('[0-9a-f]{40}', artifact.parent.name) and sha1 != artifact.parent.name:
                            raise InventoryError('Gradle artifact digest differs from content-addressed cache')
                        item['integrities'].append({'algorithm': 'sha256', 'value': self.evidence[artifact_key]['sha256'],
                                                    'basis': 'rehash of cached ' + artifact.name})
                        if artifact.suffix == '.pom':
                            tree = ET.parse(artifact).getroot()
                            for license_node in tree.findall('.//{*}licenses/{*}license'):
                                declaration = {child.tag.rsplit('}', 1)[-1]: child.text for child in license_node}
                                item['licenseDeclarations'].append(canonical(declaration))
                        elif artifact.suffix in ('.jar', '.aar'):
                            with zipfile.ZipFile(artifact) as archive:
                                for member in archive.namelist():
                                    if len(Path(member).parts) <= 3 and LICENSE_NAME.match(Path(member).name) and archive.getinfo(member).file_size <= 4 * 1024 * 1024:
                                        content = archive.read(member)
                                        license_key = self.bytes_evidence('zip-member', {'archive': self.path_name(artifact), 'member': member}, content, 'license-text')
                                        item['licenseEvidence'].append(license_key)
                    if not item['integrities']:
                        self.gap('android-artifact-integrity-unavailable', node['id'], 'Resolved component has no local cached artifact bytes', True)
                for artifact in config['artifacts']:
                    item = nodes.get(artifact['component'])
                    artifact_key = self.file_evidence(artifact['file'], 'selected-gradle-classpath-bytes')
                    if item and artifact_key:
                        item['evidence'].append(artifact_key)
                for edge in config['edges']:
                    if edge['from'] in nodes and edge['to'] in nodes:
                        self.edges.add((nodes[edge['from']]['ref'], nodes[edge['to']]['ref'], context))
                for failure in config['unresolved']:
                    unresolved += 1
                    self.gap('android-unresolved', context, canonical(failure), True)
            targets[app] = {'resolution': key, 'gradleVersion': snapshot['gradleVersion'],
                             'configurationsObserved': len(snapshot['configurations']), 'unresolvedObservations': unresolved,
                             'appConfigurations': [{'name': c['configuration'], 'components': len(c['components']),
                                                    'artifacts': len(c['artifacts']), 'unresolved': len(c['unresolved'])}
                                                   for c in snapshot['configurations'] if c['project'] == ':app']}
        self.coverage['android'] = targets

    def read_backend_imports(self):
        pattern = re.compile(r'(?:\bfrom\s*|\bimport\s*\(\s*|\bimport\s*)[\'"]((?:https?://|npm:|jsr:)[^\'\"]+)[\'"]')
        imports = collections.defaultdict(list)
        for directory in ('supabase/functions', 'cloudflare'):
            for path in sorted((self.root / directory).rglob('*')):
                if not path.is_file() or path.suffix not in ('.ts', '.js', '.mjs', '.tsx') or 'node_modules' in path.parts:
                    continue
                for match in pattern.finditer(path.read_text()):
                    imports[match[1]].append(self.path_name(path))
                    self.file_evidence(path, 'backend-external-import-source')
        lock_path = self.root / 'supabase/deno.lock'
        map_path = self.root / 'supabase/deno.import-map.json'
        lock_key = self.file_evidence(lock_path, 'exact-backend-lock') if lock_path.is_file() else None
        map_key = self.file_evidence(map_path, 'explicit-backend-import-freezes') if map_path.is_file() else None
        lock = load_json(lock_path) if lock_key else {}
        import_map = load_json(map_path).get('imports', {}) if map_key else {}
        if lock and lock.get('version') != '5':
            raise InventoryError('Expected Deno lock version5')
        cache = Path.home() / 'Library/Caches/deno'
        remote_cache = {}
        for path in sorted((cache / 'remote/https').glob('*/*')):
            if not path.is_file():
                continue
            raw = path.read_bytes(); marker = b'\n// denoCacheMetadata='; offset = raw.rfind(marker)
            if offset < 0:
                continue
            metadata = json.loads(raw[offset + len(marker):])
            remote_cache[metadata.get('url')] = (path, raw[:offset])

        def observe_body(url, expected=None):
            cached = remote_cache.get(url)
            if not cached:
                self.gap('deno-cached-body-unavailable', url, 'Immutable source checksum exists but cached body absent')
                return None, None
            path, body = cached
            if expected and hashlib.sha256(body).hexdigest() != expected:
                raise InventoryError('Deno cached source differs from locked checksum')
            self.file_evidence(path, 'deno-source-cache-record')
            key = self.bytes_evidence('deno-cache-body', {'cacheFile': self.path_name(path), 'url': safe_url(url)}, body, 'verified-original-source-body')
            return key, body

        selected = {}
        for ecosystem in ('jsr', 'npm'):
            for identifier, entry in sorted(lock.get(ecosystem, {}).items()):
                name, version = identifier.rsplit('@', 1)
                url = ('https://jsr.io/' + name + '/' + version) if ecosystem == 'jsr' else ('https://registry.npmjs.org/' + name)
                item = self.component('deno-' + ecosystem, name, version, {'kind': ecosystem, 'url': safe_url(url)})
                item['evidence'].extend([lock_key, map_key]); item['occurrences'].append('supabase:deno.lock')
                if ecosystem == 'npm':
                    item['integrities'].extend(sri_records(entry['integrity']))
                    package_root = cache / 'npm/registry.npmjs.org' / name / version
                    manifest = package_root / 'package.json'
                    if manifest.is_file():
                        actual = load_json(manifest)
                        if actual.get('name') != name or str(actual.get('version')) != version:
                            raise InventoryError('Deno npm cache package differs from lock')
                        item['evidence'].append(self.file_evidence(manifest, 'deno-npm-package-manifest'))
                        if actual.get('license'):
                            item['licenseDeclarations'].append(str(actual['license']))
                        self.licenses(item, package_root)
                    else:
                        self.gap('deno-npm-package-unavailable', identifier, 'Locked npm package missing from Deno cache')
                    registry_path = cache / 'npm/registry.npmjs.org' / name / 'registry.json'
                    if registry_path.is_file():
                        registry = load_json(registry_path); release = registry.get('versions', {}).get(version)
                        if release:
                            if release.get('dist', {}).get('integrity') != entry['integrity']:
                                raise InventoryError('Deno npm registry archive integrity differs from lock')
                            item['evidence'].append(self.file_evidence(registry_path, 'deno-npm-version-registry-metadata'))
                            item['source']['archiveUrl'] = safe_url(release['dist']['tarball'])
                            # Source enrichment changes identity, so component references
                            # retain only immutable registry identity fields.
                else:
                    expected = entry['integrity']
                    item['integrities'].append({'algorithm': 'sha256', 'value': expected, 'basis': 'Deno-lock JSR version manifest'})
                    meta_key, body = observe_body(url + '_meta.json', expected)
                    if meta_key:
                        item['evidence'].append(meta_key)
                        meta = json.loads(body)
                        for file_name, declaration in sorted(meta.get('manifest', {}).items()):
                            file_url = url + file_name
                            if file_url not in remote_cache:
                                continue
                            checksum = declaration['checksum'].removeprefix('sha256-')
                            file_key, file_body = observe_body(file_url, checksum)
                            item['evidence'].append(file_key)
                            if LICENSE_NAME.match(Path(file_name).name):
                                item['licenseEvidence'].append(file_key)
                            for line in file_body.decode('utf-8', errors='replace').splitlines()[:8]:
                                match = re.search(r'\b(MIT|BSD-3-Clause|Apache-2\.0)\s+[Ll]icen[sc]e', line)
                                if match:
                                    item['licenseDeclarations'].append(match[1])
                selected[ecosystem + ':' + identifier] = item
        for ecosystem in ('jsr', 'npm'):
            for identifier, entry in sorted(lock.get(ecosystem, {}).items()):
                item = selected[ecosystem + ':' + identifier]
                for requested in entry.get('dependencies', []):
                    dep_ecosystem, name = requested.split(':', 1) if ':' in requested else ('npm', requested)
                    candidates = [target for key, target in selected.items() if key == dep_ecosystem + ':' + name or
                                  (key.startswith(dep_ecosystem + ':') and target['name'] == name)]
                    if len(candidates) == 1:
                        self.edges.add((item['ref'], candidates[0]['ref'], 'deno:locked-dependency'))
                    else:
                        self.gap('deno-lock-edge-ambiguous', identifier + ':' + requested, 'No unique locked dependency', True)
        for url, checksum in sorted(lock.get('remote', {}).items()):
            safe_url(url)
            version_match = re.search(r'@(\d+\.\d+\.\d+)', url)
            item = self.component('deno-remote', url, version_match[1] if version_match else checksum,
                                  {'kind': 'http', 'url': url})
            item['evidence'].extend([lock_key, map_key]); item['occurrences'].append('supabase:deno.lock')
            item['integrities'].append({'algorithm': 'sha256', 'value': checksum, 'basis': 'Deno-lock original HTTP source body'})
            key, body = observe_body(url, checksum)
            if key:
                item['evidence'].append(key)
                for line in body.decode('utf-8', errors='replace').splitlines()[:8]:
                    match = re.search(r'\b(MIT|BSD-3-Clause|Apache-2\.0)\s+[Ll]icen[sc]e', line)
                    if match:
                        item['licenseDeclarations'].append(match[1])
            selected[url] = item
        for specifier, occurrences in sorted(imports.items()):
            if specifier.startswith(('https://', 'http://')):
                safe_url(specifier)
            match = re.search(r'@(\d+\.\d+\.\d+(?:[-+][\w.-]+)?)', specifier)
            version = match[1] if match else None
            resolved_specifier = import_map.get(specifier, specifier)
            if resolved_specifier.startswith(('npm:', 'jsr:')):
                match = re.match(r'(npm|jsr):(@[^/]+/[^/@]+|[^/@]+)(?:@([^/]+))?', resolved_specifier)
                key = match[1] + ':' + match[2] + '@' + match[3] if match and match[3] else None
                target = selected.get(key)
            else:
                resolved_url = lock.get('redirects', {}).get(resolved_specifier, resolved_specifier)
                target = selected.get(resolved_url)
            version = target['version'] if target else version
            item = self.component('backend-import', specifier, version,
                                  {'kind': 'source-import', 'specifier': specifier, 'resolvedSpecifier': resolved_specifier})
            item['occurrences'].extend(occurrences)
            item['evidence'].extend(occurrences)
            if target:
                item['evidence'].extend([lock_key, map_key])
                self.edges.add((item['ref'], target['ref'], 'backend:explicit-freeze'))
            else:
                self.gap('backend-import-unlocked', specifier, 'No exact lock selection and body integrity for this import', True)
        self.coverage['backend'] = {'externalImportSpecifiers': len(imports), 'committedDenoLock': bool(lock_key),
                                     'lockedJsrPackages': len(lock.get('jsr', {})), 'lockedNpmPackages': len(lock.get('npm', {})),
                                     'lockedHttpModules': len(lock.get('remote', {})), 'explicitFreezes': import_map,
                                     'versionSelectionCorrection': 'Floating backend declarations had no prior repo selection evidence; reviewed explicit freezes are new exact selections',
                                     'scope': 'Static remote/npm/jsr imports in active Supabase and Cloudflare JS/TS sources, including tests'}

    def read_python_and_ci(self):
        node_pin = self.root / '.nvmrc'
        if node_pin.is_file():
            version = node_pin.read_text().strip().removeprefix('v')
            if not exact_version(version):
                raise InventoryError('Node runtime pin is not exact')
            node = self.component('sdk', 'node', version, {'kind': 'node-runtime', 'url': 'https://nodejs.org/dist/v' + version + '/'})
            node['evidence'].append(self.file_evidence(node_pin, 'repository-node-pin'))
            node_root = Path.home() / '.nvm/versions/node' / ('v' + version)
            if (node_root / 'bin/node').is_file():
                observed = subprocess.run([str(node_root / 'bin/node'), '--version'], capture_output=True, text=True, check=True, timeout=10).stdout.strip().removeprefix('v')
                if observed != version:
                    raise InventoryError('Actual Node runtime differs from repository pin')
                key = self.file_evidence(node_root / 'bin/node', 'actual-pinned-node-binary')
                node['evidence'].append(key)
                node['integrities'].append({'algorithm': 'sha256', 'value': self.evidence[key]['sha256'], 'basis': 'actual Node runtime executable'})
                self.licenses(node, node_root)
        requirement = self.root / 'tools/requirements-local-verification.txt'
        requirement_key = self.file_evidence(requirement, 'verification-python-requirements')
        names = []
        if requirement_key:
            for line in requirement.read_text().splitlines():
                line = line.partition('#')[0].strip()
                if not line:
                    continue
                match = re.fullmatch(r'([\w.-]+)==([^\s]+)', line)
                if not match:
                    self.gap('python-requirement-not-exact', 'tools/requirements-local-verification.txt', line, True)
                    continue
                name, version = match.groups(); names.append(name)
                item = self.component('python', name, version, {'kind': 'pypi', 'url': 'https://pypi.org/project/' + name + '/' + version + '/'})
                item['evidence'].append(requirement_key)
                try:
                    distribution = importlib.metadata.distribution(name)
                except importlib.metadata.PackageNotFoundError:
                    self.gap('python-required-distribution-missing', name, version, True); continue
                if distribution.version != version:
                    raise InventoryError('Installed Python package differs from pinned verification requirement')
                for entry in distribution.files or []:
                    path = Path(distribution.locate_file(entry))
                    if path.is_file() and (LICENSE_NAME.match(path.name) or path.name in ('METADATA', 'RECORD')):
                        key = self.file_evidence(path, 'license-text' if LICENSE_NAME.match(path.name) else 'installed-python-distribution-metadata')
                        item['licenseEvidence' if LICENSE_NAME.match(path.name) else 'evidence'].append(key)
                        if path.name == 'METADATA':
                            item['integrities'].append({'algorithm': 'sha256', 'value': self.evidence[key]['sha256'], 'basis': 'installed-distribution metadata; not wheel archive'})
                declaration = distribution.metadata.get('License-Expression') or distribution.metadata.get('License')
                if declaration:
                    item['licenseDeclarations'].append(declaration)
                item['occurrences'].append('local-verification-toolchain')
        workflows = 0
        action_provenance = []
        if self.action_sources and (self.action_sources / 'action-source-provenance.json').is_file():
            action_provenance = load_json(self.action_sources / 'action-source-provenance.json')
            self.file_evidence(self.action_sources / 'action-source-provenance.json', 'immutable-action-source-provenance')
        action_paths = list((self.root / '.github/workflows').glob('*')) + list((self.root / '.github/actions').glob('**/action.y*ml'))
        for path in sorted(action_paths):
            if path.suffix not in ('.yaml', '.yml'):
                continue
            workflow = load_yaml(path); key = None; workflows += 'workflows' in path.parts
            jobs = list(workflow.get('jobs', {}).values())
            if workflow.get('runs', {}).get('using') == 'composite':
                jobs.append(workflow['runs'])
            for job in jobs:
                steps = job.get('steps', [])
                declarations = [job['uses']] if 'uses' in job else []
                declarations.extend(step['uses'] for step in steps if 'uses' in step)
                for declaration in declarations:
                    if declaration.startswith('./'):
                        continue
                    if key is None:
                        key = self.file_evidence(path, 'active-workflow-action-declarations')
                    name, separator, revision = declaration.rpartition('@')
                    if not separator:
                        self.gap('ci-action-unparsed', declaration, 'No action revision', True); continue
                    item = self.component('github-action', name, revision,
                                          {'kind': 'git', 'url': 'https://github.com/' + '/'.join(name.split('/')[:2]), 'revision': revision})
                    item['evidence'].append(key); item['occurrences'].append(key)
                    if re.fullmatch('[0-9a-f]{40}', revision):
                        item['integrities'].append({'algorithm': 'sha1', 'value': revision, 'basis': 'workflow-declared Git commit identity'})
                        if self.action_sources:
                            source_root = self.action_sources / name.replace('/', '__') / revision
                            if source_root.is_dir():
                                for source in source_root.iterdir():
                                    if source.is_file():
                                        source_key = self.file_evidence(source, 'pinned-action-source-license' if LICENSE_NAME.match(source.name) else 'pinned-action-source-definition')
                                        origins = [f for f in action_provenance if f['action'] == name and f['revision'] == revision and f['file'] == source.name]
                                        if len(origins) != 1 or origins[0]['sha256'] != self.evidence[source_key]['sha256']:
                                            raise InventoryError('Action source bytes differ from immutable-source provenance')
                                        item.setdefault('sourceOrigins', []).append(origins[0])
                                        item['licenseEvidence' if LICENSE_NAME.match(source.name) else 'evidence'].append(source_key)
                    else:
                        self.gap('ci-action-floating-reference', declaration, key, True)
        self.coverage['verificationToolchain'] = {'pythonRequirements': names, 'workflowFiles': workflows,
                                                   'scope': 'Pinned local Python requirements and action declarations; action source/license caches not yet supplied'}

    def build(self):
        self.read_dart(); self.read_npm(); self.read_ios(); self.read_android(); self.read_backend_imports(); self.read_python_and_ci()
        self.file_evidence(Path(__file__), 'inventory-generator')
        self.file_evidence(self.root / 'tools/scripts/collect_android_dependency_inventory.gradle', 'android-collector')
        for item in self.components.values():
            for field in ('occurrences', 'evidence', 'licenseDeclarations', 'licenseEvidence', 'integrities', 'platforms', 'binaryDeclarations', 'artifactOrigins', 'sourceOrigins'):
                if field in item:
                    item[field] = [json.loads(value) for value in sorted(set(canonical(x) for x in item[field] if x is not None))]
            if item['ecosystem'] not in ('dart-local', 'backend-import') and not item['licenseDeclarations'] and not item['licenseEvidence']:
                self.gap('license-evidence-unavailable', item['ref'], item['name'] + '@' + str(item['version']))
        components = sorted(self.components.values(), key=lambda c: c['ref'])
        gaps = sorted(self.gaps.values(), key=canonical)
        edge_contexts = collections.defaultdict(set)
        for a, b, context in self.edges:
            edge_contexts[a, b].add(context)
        inventory = {'schemaVersion': SCHEMA_VERSION, 'repositoryRoot': str(self.root),
                     'scope': 'Active workspace dependencies and five native targets; historical Drive archives excluded',
                     'licenseApproval': 'not assessed; declarations and text evidence only',
                     'runtime': {'pythonRequirement': '>=3.10', 'yamlRequirement': 'PyYAML==6.0.3'},
                     'coverage': self.coverage, 'components': components,
                     'edges': [{'from': a, 'to': b, 'contexts': sorted(contexts)} for (a, b), contexts in sorted(edge_contexts.items())],
                     'evidence': dict(sorted(self.evidence.items())), 'unresolved': gaps,
                     'summary': {'components': len(components), 'byEcosystem': dict(sorted(collections.Counter(c['ecosystem'] for c in components).items())),
                                 'evidenceItems': len(self.evidence), 'dependencyEdges': len(edge_contexts),
                                 'dependencyEdgeOccurrences': len(self.edges), 'unresolvedFields': len(gaps),
                                 'exactInventoryComplete': not any(g['blocksExact'] for g in gaps),
                                 'componentsWithLicenseText': sum(bool(c['licenseEvidence']) for c in components),
                                 'componentsWithLicenseDeclaration': sum(bool(c['licenseDeclarations']) for c in components)}}
        # Verify that source/evidence did not change while hashes and facts were read.
        validate_inventory(inventory)
        return inventory


def evidence_bytes(item, root):
    if item['kind'] == 'file':
        return (root / item['path']).read_bytes()
    if item['kind'] == 'git-object':
        result = subprocess.run(['git', '-C', item['repository'], 'show', item['revision'] + ':' + item['gitPath']], capture_output=True, timeout=15)
        if result.returncode:
            raise InventoryError('Git evidence object is unavailable')
        return result.stdout
    if item['kind'] == 'zip-member':
        with zipfile.ZipFile(root / item['archive']) as archive:
            return archive.read(item['member'])
    if item['kind'] == 'tar-member':
        with tarfile.open(root / item['archive'], 'r:*') as archive:
            return archive.extractfile(item['member']).read()
    if item['kind'] == 'deno-cache-body':
        raw = (root / item['cacheFile']).read_bytes()
        marker = b'\n// denoCacheMetadata='; offset = raw.rfind(marker)
        if offset < 0 or json.loads(raw[offset + len(marker):]).get('url') != item['url']:
            raise InventoryError('Deno cache source identity differs')
        return raw[:offset]
    raise InventoryError('Unsupported evidence kind')


def validate_inventory(inventory, require_exact=False):
    if inventory.get('schemaVersion') != SCHEMA_VERSION:
        raise InventoryError('Unsupported inventory schema')
    root = Path(inventory['repositoryRoot'])
    components = inventory['components']; references = [c['ref'] for c in components]
    if len(references) != len(set(references)):
        raise InventoryError('Duplicate component reference')
    known = set(references)
    for edge in inventory['edges']:
        if edge['from'] not in known or edge['to'] not in known:
            raise InventoryError('Dependency edge points to absent component')
    for key, item in inventory['evidence'].items():
        content = evidence_bytes(item, root)
        if len(content) != item['bytes'] or hashlib.sha256(content).hexdigest() != item['sha256']:
            raise InventoryError('Evidence changed or corrupt: ' + key)
    for component in components:
        identity = {key: component[key] for key in ('ecosystem', 'name', 'version', 'source')}
        # Enrichment flags are evidence observations, not package identity.
        identity['source'] = {k: v for k, v in component['source'].items() if k not in ('licenseRevisionVerified', 'archiveUrl')}
        expected_ref = 'dependency:' + hashlib.sha256(canonical(identity).encode()).hexdigest()[:24]
        if component['ref'] != expected_ref:
            raise InventoryError('Component identity differs from reference')
        for key in component['evidence'] + component['licenseEvidence']:
            if key not in inventory['evidence']:
                raise InventoryError('Component references absent evidence')
        for integrity in component['integrities']:
            if integrity['algorithm'] not in ('sha1', 'sha256', 'sha384', 'sha512') or not re.fullmatch('[0-9a-f]+', str(integrity['value'])):
                raise InventoryError('Invalid component integrity')
            if len(integrity['value']) != hashlib.new(integrity['algorithm']).digest_size * 2:
                raise InventoryError('Incorrect component integrity length')
    complete = not any(g['blocksExact'] for g in inventory['unresolved'])
    if complete != inventory['summary']['exactInventoryComplete'] or len(components) != inventory['summary']['components']:
        raise InventoryError('Inventory summary differs from facts')
    if require_exact and not complete:
        raise InventoryError('Exact dependency inventory is incomplete; inspect unresolved fields')


def component_purl(component):
    ecosystem = component['ecosystem']; name = component['name']; version = component['version']
    quote = lambda value: urllib.parse.quote(str(value), safe='.-_~')
    if version is None or ecosystem in ('dart-local', 'sdk', 'backend-import'):
        return None
    if ecosystem == 'maven':
        group, artifact = name.split(':', 1)
        return 'pkg:maven/' + quote(group) + '/' + quote(artifact) + '@' + quote(version)
    if ecosystem == 'npm':
        path = '/'.join(quote(part) for part in name.split('/'))
        return 'pkg:npm/' + path + '@' + quote(version)
    if ecosystem == 'dart':
        return 'pkg:pub/' + quote(name) + '@' + quote(version)
    if ecosystem == 'cocoapods':
        return 'pkg:cocoapods/' + quote(name) + '@' + quote(version)
    if ecosystem == 'swift':
        return 'pkg:swift/' + quote(name) + '@' + quote(version) + '?vcs_url=' + quote(component['source']['url'] + '@' + component['source']['revision'])
    if ecosystem == 'python':
        return 'pkg:pypi/' + quote(name.lower().replace('_', '-')) + '@' + quote(version)
    if ecosystem == 'deno-npm':
        return 'pkg:npm/' + '/'.join(quote(part) for part in name.split('/')) + '@' + quote(version)
    return None


def cyclonedx(inventory):
    components = []
    for item in inventory['components']:
        component = {'type': 'library', 'bom-ref': item['ref'], 'name': item['name'],
                     'properties': [{'name': 'africlub:ecosystem', 'value': item['ecosystem']},
                                    {'name': 'africlub:source', 'value': canonical(item['source'])},
                                    {'name': 'africlub:occurrences', 'value': canonical(item['occurrences'])},
                                    {'name': 'africlub:integrity-bases', 'value': canonical(item['integrities'])},
                                    {'name': 'africlub:license-evidence', 'value': canonical(item['licenseEvidence'])}]}
        if item['version']:
            component['version'] = item['version']
        purl = component_purl(item)
        if purl:
            component['purl'] = purl
        if item['licenseDeclarations']:
            component['licenses'] = [{'license': {'name': value}} for value in item['licenseDeclarations']]
        # Lockfile archive/checksum, podspec and Git identity hashes have different
        # meanings. Preserve bases as properties; do not conflate them as one binary hash.
        components.append(component)
    dependencies = collections.defaultdict(set)
    for edge in inventory['edges']:
        dependencies[edge['from']].add(edge['to'])
    return {'$schema': 'http://cyclonedx.org/schema/bom-1.6.schema.json', 'bomFormat': 'CycloneDX', 'specVersion': '1.6', 'version': 1,
            'components': components,
            'dependencies': [{'ref': ref, 'dependsOn': sorted(dependencies[ref])} for ref in sorted(dependencies)],
            'compositions': [{'aggregate': 'incomplete' if not inventory['summary']['exactInventoryComplete'] else 'complete'}],
            'metadata': {'properties': [{'name': 'africlub:scope', 'value': inventory['scope']},
                                        {'name': 'africlub:unresolved', 'value': canonical(inventory['unresolved'])},
                                        {'name': 'africlub:license-approval', 'value': inventory['licenseApproval']}]}}


def report_markdown(inventory):
    s = inventory['summary']
    lines = ['# Local dependency inventory — 2026-09-30', '', inventory['scope'] + '.', '',
             '**Exact inventory complete: ' + str(s['exactInventoryComplete']).lower() + '.**', '',
             'This is local source/cache evidence. License approval, vulnerability clearance, deployed dependencies, and device/store acceptance are not assessed.', '',
             '## Coverage', '', '| Ecosystem | Unique components |', '| --- | ---: |']
    lines.extend('| ' + key + ' | ' + str(value) + ' |' for key, value in s['byEcosystem'].items())
    lines.extend(['', f"Evidence items: {s['evidenceItems']}; dependency edges: {s['dependencyEdges']}; components with license text: {s['componentsWithLicenseText']}; with license declarations: {s['componentsWithLicenseDeclaration']}.", '',
                  'Dart: one workspace lock and active package_config reconciled against cached pubspecs and hosted hash records. Npm: every lock location retained, including absent platform optional packages; available cached archives rehashed against SRI. iOS: both SwiftPM lock containers for each app, immutable commit manifests/license blobs, generated local plugin manifests, and four CocoaPods locks. Android: offline resolved component/artifact graphs for each supplied target; unresolved selectors are retained.', '',
                  'A pub cache hash record confirms the stored archive declaration, not a fresh archive rehash. Git commit identities and CocoaPods spec checksums are not binary archive hashes. Cached Maven and available npm archive bytes are rehashed. Swift binary checksums remain exact-revision manifest declarations unless archive bytes are available.', '',
                  '## Reproduce', '', 'Requires Python >=3.10, PyYAML==6.0.3, cached Dart/npm/Swift/Maven packages, and the pinned JDK/Gradle/Flutter environment. No network or Flutter compilation is required.', '', '```sh',
                  'python3 tools/scripts/local_dependency_inventory.py collect-android --output-dir output/dependency-inventory/android --jdk /path/to/jdk',
                  'python3 tools/scripts/local_dependency_inventory.py generate --android-resolutions output/dependency-inventory/android --output-prefix ' + DEFAULT_PREFIX,
                  'python3 tools/scripts/local_dependency_inventory.py validate --inventory ' + DEFAULT_PREFIX + '.json',
                  '# Release exactness gate; fails whenever any exactness-blocking field is unresolved:',
                  'python3 tools/scripts/local_dependency_inventory.py validate --inventory ' + DEFAULT_PREFIX + '.json --require-exact',
                  'python3 -m unittest discover -s tools/scripts -p test_local_dependency_inventory.py', '```', '',
                  'Validation rehashes every evidence file, Git blob and archive license member; confirms graph references and summary facts; and checks the companion SBOM for exact equality with the inventory-derived document.', '',
                  '## Remaining evidence fields', '', '| Kind | Count | Blocks exactness |', '| --- | ---: | --- |'])
    for kind, count in sorted(collections.Counter(g['kind'] for g in inventory['unresolved']).items()):
        lines.append('| ' + kind + ' | ' + str(count) + ' | ' + str(any(g['blocksExact'] for g in inventory['unresolved'] if g['kind'] == kind)).lower() + ' |')
    lines.extend(['', 'Each unresolved field, target/configuration, source input SHA256, license declaration and text evidence SHA256 is listed in the JSON. The license TSV has one row per component, with exact version/source and evidence references.', '',
                  'Backend floating npm/jsr imports and remote imports without a committed dependency lock remain explicit. Offline native cache gaps are not repaired by assigning a different version. Lock absence is supplemented by actual Gradle resolution and generated SwiftPM inputs.', '',
                  '## Added files and rationale', '',
                  '- Generator/validator: repeatable exact source, integrity, dependency-edge and license evidence reconciliation.',
                  '- Gradle collector: observes all five active targets and plugin configurations using actual offline resolution.',
                  '- Regression tests: reject duplicate input keys, integrity mismatches, unsafe paths/URLs, stale evidence, unresolved exactness, and graph corruption.',
                  '- JSON, CycloneDX1.6, license TSV and this report: reviewable inventory with explicit incompleteness; none grants license approval.', '',
                  'Standards: [CycloneDX1.6 JSON schema](https://raw.githubusercontent.com/CycloneDX/specification/1.6/schema/bom-1.6.schema.json), [Package URL specification](https://www.packageurl.org/docs/purl/introduction).', ''])
    return '\n'.join(lines)


def write_reports(inventory, prefix):
    prefix = Path(prefix); prefix.parent.mkdir(parents=True, exist_ok=True)
    for suffix, value in (('.json', inventory), ('.cdx.json', cyclonedx(inventory))):
        Path(str(prefix) + suffix).write_text(json.dumps(value, indent=2, sort_keys=True, ensure_ascii=False) + '\n')
    rows = ['ref\tecosystem\tname\tversion\tsource\tlicense_declarations\tlicense_evidence']
    for item in inventory['components']:
        fields = [item['ref'], item['ecosystem'], item['name'], str(item['version'] or ''), canonical(item['source']),
                  canonical(item['licenseDeclarations']), canonical(item['licenseEvidence'])]
        rows.append('\t'.join(value.replace('\t', '\\t').replace('\n', '\\n') for value in fields))
    Path(str(prefix) + '.licenses.tsv').write_text('\n'.join(rows) + '\n')
    Path(str(prefix) + '.md').write_text(report_markdown(inventory))


def collect_android(root, output, jdk):
    root = root.resolve(); output = output.resolve(); output.mkdir(parents=True, exist_ok=True)
    environment = os.environ.copy()
    if jdk:
        environment['JAVA_HOME'] = str(jdk)
        environment['PATH'] = str(jdk / 'bin') + os.pathsep + environment['PATH']
    failures = []
    for app in APPS:
        snapshot = output / (app + '.json')
        snapshot.unlink(missing_ok=True)  # Never accept a stale previous successful snapshot.
        command = ['./gradlew', '-I', str(root / 'tools/scripts/collect_android_dependency_inventory.gradle'),
                   'collectAfriDependencyInventory', '-PafriInventoryOutput=' + str(snapshot), '--offline', '--console=plain', '--max-workers=2']
        with (output / (app + '.log')).open('w') as log:
            result = subprocess.run(command, cwd=root / 'apps' / app / 'android', env=environment,
                                    stdout=log, stderr=subprocess.STDOUT, timeout=300)
        if result.returncode or not snapshot.is_file():
            failures.append(app)
    if failures:
        raise InventoryError('Android collection failed: ' + ', '.join(failures))


def hydrate_maven(snapshots, mirror):
    """Fetch immutable public metadata/artifacts for observed coordinates only.

    This does not install dependencies or alter an app build. Cached immutable
    artifact bytes are linked into a disposable Maven mirror; public downloads
    are checked against published SHA1 where supplied. Origins are retained.
    """
    mirror = mirror.resolve(); mirror.mkdir(parents=True, exist_ok=True)
    coordinates = set()
    for path in sorted(snapshots.glob('*.json')):
        snapshot = load_json(path)
        for config in snapshot['configurations']:
            if config['kind'] != 'buildscript' and not re.fullmatch(r'(?:qa)?(?:debug|release|profile)(?:compile|runtime)classpath', config['configuration'].lower()):
                continue
            coordinates.update((n['group'], n['name'], n['version']) for n in config['components'] if n.get('group'))
            for failure in config['unresolved']:
                parts = failure.get('requested', '').split(':')
                if len(parts) == 3 and exact_version(parts[-1]):
                    coordinates.add(tuple(parts))
    coordinates.add(('androidx.test', 'runner', '1.2.0'))
    cache = Path.home() / '.gradle/caches/modules-2/files-2.1'
    facts = {}; errors = []

    def base_url(group):
        if group == 'io.flutter':
            return 'https://storage.googleapis.com/download.flutter.io/'
        if group.startswith(('androidx.', 'com.android.', 'com.google.android.', 'com.google.firebase', 'com.google.gms', 'com.google.testing.platform')):
            return 'https://dl.google.com/dl/android/maven2/'
        return 'https://repo.maven.apache.org/maven2/'

    def fetch(url):
        try:
            with urllib.request.urlopen(url, timeout=15) as response:
                return response.read()
        except urllib.error.HTTPError as error:
            if error.code == 404:
                return None
            raise

    def download(url, path):
        if path.is_file():
            return path.read_bytes()
        data = fetch(url)
        if data is None:
            return None
        checksum = fetch(url + '.sha1')
        if checksum:
            expected = checksum.decode().strip().split()[0].lower()
            if not re.fullmatch('[0-9a-f]{40}', expected) or hashlib.sha1(data).hexdigest() != expected:
                raise InventoryError('Public Maven artifact differs from published SHA1')
        path.parent.mkdir(parents=True, exist_ok=True); path.write_bytes(data)
        facts[str(path.relative_to(mirror))] = {'url': safe_url(url), 'sha256': hashlib.sha256(data).hexdigest(),
                                              'sha1Verified': bool(checksum), 'bytes': len(data)}
        return data

    def hydrate(coordinate):
        group, name, version = coordinate
        if not all(re.fullmatch('[A-Za-z0-9_.+-]+', value) for value in coordinate):
            raise InventoryError('Unsafe Maven coordinate')
        relative = group.replace('.', '/') + '/' + name + '/' + version + '/'
        target = mirror / relative; target.mkdir(parents=True, exist_ok=True)
        for source in sorted((cache / group / name / version).glob('*/*')):
            if source.is_file() and source.suffix in ('.jar', '.aar'):
                expected = source.parent.name
                if re.fullmatch('[0-9a-f]{40}', expected) and digest_file(source, 'sha1') != expected:
                    raise InventoryError('Cached Maven artifact SHA1 mismatch')
                destination = target / source.name
                if not destination.exists():
                    destination.symlink_to(source)
                facts[str(destination.relative_to(mirror))] = {'cacheSource': str(source), 'sha256': digest_file(source), 'bytes': source.stat().st_size}
        base = base_url(group) + relative
        pom = download(base + name + '-' + version + '.pom', target / (name + '-' + version + '.pom'))
        download(base + name + '-' + version + '.module', target / (name + '-' + version + '.module'))
        follow = set()
        packaging = 'jar'
        if pom:
            tree = ET.fromstring(pom)
            packaging = tree.findtext('{*}packaging', 'jar')
            for parent in tree.findall('{*}parent'):
                parts = tuple(parent.findtext('{*}' + key, '') for key in ('groupId', 'artifactId', 'version'))
                if all(re.fullmatch('[A-Za-z0-9_.+-]+', part) for part in parts):
                    follow.add(parts)
            if coordinate == ('androidx.test', 'runner', '1.2.0'):
                for dependency in tree.findall('.//{*}dependencies/{*}dependency'):
                    parts = tuple(dependency.findtext('{*}' + key, '') for key in ('groupId', 'artifactId', 'version'))
                    if all(re.fullmatch('[A-Za-z0-9_.+-]+', part) for part in parts):
                        follow.add(parts)
        if packaging in ('jar', 'aar') and not (target / (name + '-' + version + '.' + packaging)).exists():
            download(base + name + '-' + version + '.' + packaging, target / (name + '-' + version + '.' + packaging))
        return follow

    seen = set()
    while coordinates:
        pending = sorted(coordinates - seen); coordinates = set(); seen.update(pending)
        if not pending:
            break
        with concurrent.futures.ThreadPoolExecutor(max_workers=12) as pool:
            futures = {pool.submit(hydrate, coordinate): coordinate for coordinate in pending}
            for future in concurrent.futures.as_completed(futures):
                try:
                    coordinates.update(future.result())
                except Exception as error:
                    errors.append({'coordinate': list(futures[future]), 'failureType': type(error).__name__})
        print('Maven coordinates observed=' + str(len(seen)) + ' public/cache facts=' + str(len(facts)), flush=True)
    metadata_url = 'https://dl.google.com/dl/android/maven2/androidx/test/runner/maven-metadata.xml'
    download(metadata_url, mirror / 'androidx/test/runner/maven-metadata.xml')
    report = {'schemaVersion': 1, 'purpose': 'Temporary immutable observed-version Maven mirror',
              'coordinates': [list(c) for c in sorted(seen)], 'files': dict(sorted(facts.items())), 'errors': errors}
    (mirror / 'africlub-mirror-provenance.json').write_text(json.dumps(report, indent=2, sort_keys=True) + '\n')
    if errors:
        print('Maven metadata unresolved=' + str(len(errors)), file=sys.stderr)
    return report


def hydrate_actions(root, output):
    output.mkdir(parents=True, exist_ok=True)
    references = set()
    paths = list((root / '.github/workflows').glob('*.y*ml')) + list((root / '.github/actions').glob('**/action.y*ml'))
    for path in paths:
        for name, revision in re.findall(r'uses:\s*([\w.-]+/[\w.-]+)@([0-9a-f]{40})', path.read_text()):
            references.add((name, revision))
    facts = []
    for name, revision in sorted(references):
        target = output / name.replace('/', '__') / revision; target.mkdir(parents=True, exist_ok=True)
        for file_name in ('action.yml', 'action.yaml', 'LICENSE', 'LICENSE.md', 'LICENSE.txt', 'license', 'package.json'):
            url = 'https://raw.githubusercontent.com/' + name + '/' + revision + '/' + file_name
            try:
                with urllib.request.urlopen(url, timeout=15) as response:
                    content = response.read()
            except urllib.error.HTTPError as error:
                if error.code == 404:
                    continue
                raise
            (target / file_name).write_bytes(content)
            facts.append({'action': name, 'revision': revision, 'file': file_name, 'url': url,
                          'sha256': hashlib.sha256(content).hexdigest()})
    (output / 'action-source-provenance.json').write_text(json.dumps(facts, indent=2, sort_keys=True) + '\n')
    print('Immutable action source facts=' + str(len(facts)))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[2])
    commands = parser.add_subparsers(dest='command', required=True)
    generate = commands.add_parser('generate')
    generate.add_argument('--output-prefix', default=DEFAULT_PREFIX)
    generate.add_argument('--android-resolutions', type=Path)
    generate.add_argument('--pub-cache', type=Path)
    generate.add_argument('--npm-cache', type=Path)
    generate.add_argument('--swift-cache', type=Path)
    generate.add_argument('--action-sources', type=Path)
    validate = commands.add_parser('validate')
    validate.add_argument('--inventory', type=Path, required=True)
    validate.add_argument('--require-exact', action='store_true')
    collect = commands.add_parser('collect-android')
    collect.add_argument('--output-dir', type=Path, required=True)
    collect.add_argument('--jdk', type=Path)
    hydrate = commands.add_parser('hydrate-maven')
    hydrate.add_argument('--android-resolutions', type=Path, required=True)
    hydrate.add_argument('--mirror', type=Path, required=True)
    actions = commands.add_parser('hydrate-actions')
    actions.add_argument('--output-dir', type=Path, required=True)
    args = parser.parse_args()
    try:
        if args.command == 'generate':
            inventory = Inventory(args.root, args.android_resolutions, args.pub_cache, args.npm_cache, args.swift_cache, args.action_sources).build()
            write_reports(inventory, args.output_prefix)
            print(canonical(inventory['summary']))
        elif args.command == 'validate':
            inventory = load_json(args.inventory)
            validate_inventory(inventory, args.require_exact)
            companion = args.inventory.with_name(args.inventory.stem + '.cdx.json')
            if not companion.is_file() or load_json(companion) != cyclonedx(inventory):
                raise InventoryError('Companion SBOM missing or differs from inventory')
            print('Inventory and companion SBOM verified; exact=' + str(inventory['summary']['exactInventoryComplete']).lower())
        elif args.command == 'collect-android':
            collect_android(args.root, args.output_dir, args.jdk)
            print('Collected all five Android targets offline')
        elif args.command == 'hydrate-maven':
            hydrate_maven(args.android_resolutions, args.mirror)
        else:
            hydrate_actions(args.root, args.output_dir)
    except (InventoryError, OSError, KeyError, yaml.YAMLError, json.JSONDecodeError, subprocess.SubprocessError, zipfile.BadZipFile) as error:
        # Do not dump manifests, source URLs, or credential-bearing exception contents.
        if isinstance(error, InventoryError):
            print(str(error), file=sys.stderr)
        else:
            print('Inventory operation failed: ' + type(error).__name__, file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
