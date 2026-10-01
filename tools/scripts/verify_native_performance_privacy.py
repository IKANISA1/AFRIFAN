#!/usr/bin/env python3
"""Verify permanent Firebase Performance deactivation on declared native hosts.

This source gate does not initialize an SDK or execute native/provider builds.
Only finite failure codes and source hashes are reported, never config values.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import plistlib
import re
import sys
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
CONTROL = 'firebase_performance_collection_deactivated'
ANDROID = '{http://schemas.android.com/apk/res/android}'
TOOLS = '{http://schemas.android.com/tools}'
CLUBS = frozenset(('as_vita', 'costa_do_sol', 'nkana', 'rayon_sports', 'vitalo'))


class NativeControlError(ValueError):
    def __init__(self, report):
        super().__init__('Native Performance privacy controls failed verification')
        self.report = report


def declared_scopes(root):
    text = (root / 'docs/release/full_stack_qa_plan.md').read_text()
    sections = re.findall(r'<!-- release-scope:start -->(.*?)<!-- release-scope:end -->', text, re.S)
    if len(sections) != 1:
        raise ValueError('Missing or ambiguous native release scope')
    rows = [line.strip().strip('|').split('|') for line in sections[0].splitlines()
            if line.strip().startswith('|')][2:]
    scopes = {}
    for row in rows:
        if len(row) != 6:
            raise ValueError('Invalid native scope row')
        club, tenant, *_ = [cell.strip() for cell in row]
        if club not in CLUBS or not re.fullmatch(r'[1-9][0-9]*', tenant) or club in scopes:
            raise ValueError('Invalid or duplicated native club')
        scopes[club] = tenant
    if set(scopes) != CLUBS or len(set(scopes.values())) != 5:
        raise ValueError('Expected five unique declared club scopes')
    return scopes


def _android_control(data, *, main):
    try:
        tree = ET.fromstring(data)
    except ET.ParseError:
        return 'invalid_android_xml'
    apps = tree.findall('application')
    if tree.tag != 'manifest' or len(apps) > 1 or (main and len(apps) != 1):
        return 'invalid_android_application'
    if apps and apps[0].get(TOOLS + 'node') in ('remove', 'removeAll', 'replace'):
        return 'contradictory_android_override'
    if apps and any(item.get(TOOLS + 'node') == 'removeAll' for item in apps[0].findall('meta-data')):
        return 'contradictory_android_override'
    controls = [item for item in tree.iter('meta-data')
                if item.get(ANDROID + 'name') == CONTROL]
    if len(controls) > 1:
        return 'duplicate_android_control'
    if not controls:
        return 'missing_android_control' if main else None
    control = controls[0]
    if not apps or control not in list(apps[0]):
        return 'misplaced_android_control'
    if control.get(ANDROID + 'value') != 'true' or ANDROID + 'resource' in control.attrib:
        return 'android_control_not_literal_true'
    if control.get(TOOLS + 'node') in ('remove', 'removeAll') or apps[0].get(TOOLS + 'node') in ('remove', 'removeAll'):
        return 'contradictory_android_override'
    if not main:
        return 'duplicate_android_override'
    return None


def _ios_control(data):
    try:
        tree = ET.fromstring(data)
        if tree.tag != 'plist' or len(tree) != 1 or tree[0].tag != 'dict':
            return 'invalid_ios_plist'
        children = list(tree[0])
        if len(children) % 2 or any(children[i].tag != 'key' for i in range(0, len(children), 2)):
            return 'invalid_ios_dictionary'
        keys = [children[i].text for i in range(0, len(children), 2)]
        # plistlib otherwise accepts a duplicate by silently selecting its last value.
        if len(keys) != len(set(keys)):
            return 'duplicate_ios_key'
        if CONTROL not in keys:
            return 'missing_ios_control'
        value = children[keys.index(CONTROL) * 2 + 1]
        parsed = plistlib.loads(data)
        if value.tag != 'true' or value.text not in (None, '') or type(parsed[CONTROL]) is not bool or parsed[CONTROL] is not True:
            return 'ios_control_not_boolean_true'
    except (ET.ParseError, plistlib.InvalidFileException, ValueError, TypeError, KeyError, OverflowError):
        return 'invalid_ios_plist'
    return None


def verify_native_controls(root, scopes):
    """Return ten source-bound target records, raising ValueError on any drift."""
    root = Path(root).resolve()
    if len(scopes) != 5 or set(scopes) != CLUBS:
        raise ValueError('Expected all five declared native clubs')
    targets, inputs, errors = [], {}, []

    def read(path, club, platform):
        relative = path.relative_to(root).as_posix()
        try:
            if path.is_symlink() or not path.is_file() or not path.resolve().is_relative_to(root):
                raise OSError()
            data = path.read_bytes()
        except OSError:
            errors.append({'club': club, 'platform': platform, 'path': relative, 'code': 'missing_or_unsafe_source'})
            return None
        inputs[relative] = {'path': relative, 'sha256': hashlib.sha256(data).hexdigest(), 'bytes': len(data)}
        return data

    for club in sorted(scopes):
        for platform in ('android', 'ios'):
            base = root / 'apps' / club
            source = base / ('android/app/src/main/AndroidManifest.xml' if platform == 'android' else 'ios/Runner/Info.plist')
            target = {'club': club, 'platform': platform, 'path': source.relative_to(root).as_posix()}
            error_count = len(errors)
            data = read(source, club, platform)
            if data is not None:
                code = _android_control(data, main=True) if platform == 'android' else _ios_control(data)
                if code:
                    errors.append({'club': club, 'platform': platform, 'path': target['path'], 'code': code})
            if platform == 'android':
                # Build-type/flavor manifests can override the main manifest before startup.
                for override in sorted((base / 'android/app/src').glob('**/AndroidManifest.xml')):
                    if override == source:
                        continue
                    data = read(override, club, platform)
                    if data is not None:
                        code = _android_control(data, main=False)
                        if code:
                            errors.append({'club': club, 'platform': platform, 'path': override.relative_to(root).as_posix(), 'code': code})
            target['permanentCollectionDeactivated'] = len(errors) == error_count
            targets.append(target)
    report = {'schemaVersion': 1, 'status': 'passed' if not errors else 'failed',
              'configurationVerified': not errors, 'targets': targets,
              'sourceInputs': [inputs[key] for key in sorted(inputs)], 'errors': errors,
              'hostedJobsExecuted': False, 'releaseAccepted': False}
    if errors:
        raise NativeControlError(report)
    return report


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=ROOT)
    parser.add_argument('--report', type=Path)
    args = parser.parse_args(argv)
    root = args.root.resolve()
    try:
        result = verify_native_controls(root, declared_scopes(root))
        scope = root / 'docs/release/full_stack_qa_plan.md'
        result['sourceInputs'].append({'path': scope.relative_to(root).as_posix(),
                                      'sha256': hashlib.sha256(scope.read_bytes()).hexdigest(),
                                      'bytes': scope.stat().st_size})
    except NativeControlError as error:
        result = error.report
    except (ValueError, OSError):
        result = {'schemaVersion': 1, 'status': 'failed', 'configurationVerified': False,
                  'targets': [], 'sourceInputs': [], 'errors': [{'code': 'invalid_release_scope'}],
                  'hostedJobsExecuted': False, 'releaseAccepted': False}
    output = json.dumps(result, indent=2) + '\n'
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(output)
    sys.stdout.write(output)
    return 0 if result['configurationVerified'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
