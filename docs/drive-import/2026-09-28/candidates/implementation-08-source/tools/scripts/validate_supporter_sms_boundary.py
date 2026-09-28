#!/usr/bin/env python3
"""Validate all five supporter apps; never scan the separate server SMS gateway.

Source validation is not binary certification. Pass --merged-manifests DIR to
also inspect DIR/<app>/AndroidManifest.xml produced by actual Android builds.
"""
from __future__ import annotations
import argparse
import json
import pathlib
import re
import sys
import xml.etree.ElementTree as ET

APPS = ('rayon_sports', 'vitalo', 'as_vita', 'nkana', 'costa_do_sol')
ANDROID = '{http://schemas.android.com/apk/res/android}'
TOOLS = '{http://schemas.android.com/tools}'
FORBIDDEN_PERMISSIONS = frozenset('android.permission.' + name for name in (
    'READ_SMS', 'RECEIVE_SMS', 'SEND_SMS', 'RECEIVE_MMS', 'RECEIVE_WAP_PUSH',
    'READ_CALL_LOG', 'WRITE_CALL_LOG', 'READ_PHONE_STATE', 'READ_PHONE_NUMBERS',
))
FORBIDDEN_PACKAGES = frozenset(('telephony', 'another_telephony', 'flutter_sms_inbox', 'sms_advanced', 'sms'))
RUNTIME_PATTERNS = tuple(re.compile(pattern, re.I) for pattern in (
    r'\bTelephony\s*\.\s*Sms\b', r'\bSmsManager\b', r'\bSMS_RECEIVED\b',
    r'\b(?:querySms|getInboxSms|listenIncomingSms|SmsQuery|SmsReceiver)\b',
    r'content://sms\b',
))
SKIP = {'.git', '.dart_tool', 'build', '.gradle', 'node_modules', 'Pods', 'test', 'integration_test', 'output'}


def strip_comments(source: str) -> str:
    """Keep string literals and line positions, remove nested code comments."""
    out = []; i = 0; quote = None; depth = 0
    while i < len(source):
        if depth:
            if source.startswith('/*', i): depth += 1; out.extend('  '); i += 2
            elif source.startswith('*/', i): depth -= 1; out.extend('  '); i += 2
            else: out.append('\n' if source[i] == '\n' else ' '); i += 1
        elif quote:
            if source[i] == '\\' and i + 1 < len(source): out.extend(source[i:i+2]); i += 2
            elif source.startswith(quote, i): out.extend(quote); i += len(quote); quote = None
            else: out.append(source[i]); i += 1
        elif source.startswith('//', i):
            end = source.find('\n', i); end = len(source) if end < 0 else end
            out.extend(' ' * (end-i)); i = end
        elif source.startswith('/*', i): depth = 1; out.extend('  '); i += 2
        elif source[i] in ('\"', "'"):
            quote = source[i] * 3 if source.startswith(source[i]*3, i) else source[i]
            out.extend(quote); i += len(quote)
        else: out.append(source[i]); i += 1
    return ''.join(out)


def manifest_violations(path: pathlib.Path, *, merged: bool = False) -> list[str]:
    try:
        root = ET.parse(path).getroot()
    except (ET.ParseError, OSError) as error:
        return [f'{path}: unreadable Android manifest ({type(error).__name__})']
    errors = []
    for element in root.iter():
        tag = element.tag.rsplit('}', 1)[-1]
        removal = element.get(TOOLS + 'node') in ('remove', 'removeAll')
        if removal and not merged:
            continue
        if tag in ('uses-permission', 'uses-permission-sdk-23', 'uses-permission-sdk-m'):
            permission = element.get(ANDROID + 'name', '')
            if permission in FORBIDDEN_PERMISSIONS:
                errors.append(f'{path}: active forbidden permission {permission}')
        if tag in ('action', 'receiver', 'service'):
            name = element.get(ANDROID + 'name', '')
            if any(pattern.search(name) for pattern in RUNTIME_PATTERNS):
                errors.append(f'{path}: forbidden SMS receiver/service/action {name}')
    return errors


def yaml_section(source: str, key: str) -> str:
    match = re.search(r'^' + re.escape(key) + r':\s*(?:#.*)?\n', source, re.M)
    if not match: return ''
    rest = source[match.end():]
    end = re.search(r'^[^\s#][^\n]*:', rest, re.M)
    return rest[:end.start()] if end else rest


def runtime_dependencies(path: pathlib.Path) -> set[str]:
    return set(re.findall(r'^  ([a-zA-Z0-9_]+)\s*:', yaml_section(path.read_text(encoding='utf-8'), 'dependencies'), re.M))


def source_files(base: pathlib.Path):
    if not base.exists(): return
    for entry in sorted(base.iterdir()):
        if entry.is_symlink():
            yield entry
        elif entry.is_dir() and entry.name not in SKIP and not entry.name.startswith('.'):
            yield from source_files(entry)
        elif entry.is_file() and entry.suffix in ('.dart', '.kt', '.java', '.xml', '.swift', '.m', '.mm'):
            yield entry


def validate(root: pathlib.Path, merged_manifests: pathlib.Path | None = None) -> dict:
    errors = []; manifests = []; scanned = 0; package_count = 0
    root = root.resolve()
    pubspec = root / 'pubspec.yaml'
    if not pubspec.is_file():
        return {'passed': False, 'errors': ['Missing root pubspec.yaml'], 'apps': list(APPS)}
    workspace = yaml_section(pubspec.read_text(encoding='utf-8'), 'workspace')
    paths = re.findall(r'^\s+-\s+([a-zA-Z0-9_/.-]+)\s*(?:#.*)?$', workspace, re.M)
    app_paths = [path for path in paths if path.startswith('apps/')]
    if sorted(app_paths) != sorted('apps/' + app for app in APPS):
        errors.append('Workspace must contain exactly the five governed supporter app paths')
    for app in APPS:
        base = root / 'apps' / app
        for required in [base / 'pubspec.yaml', base / 'lib', base / 'android/app/src/main/AndroidManifest.xml']:
            if not required.exists(): errors.append(f'{required}: required supporter source missing')
    for relative in paths:
        if relative.startswith('packages/testing/'): continue
        package = root / relative
        if '..' in pathlib.PurePosixPath(relative).parts or package.is_symlink() or not package.resolve().is_relative_to(root):
            errors.append(f'{relative}: unsafe workspace package path'); continue
        manifest = package / 'pubspec.yaml'
        if not manifest.is_file(): errors.append(f'{manifest}: missing workspace package'); continue
        package_count += 1
        try:
            for dependency in runtime_dependencies(manifest) & FORBIDDEN_PACKAGES:
                errors.append(f'{manifest}: forbidden runtime dependency {dependency}')
        except (OSError, UnicodeError):
            errors.append(f'{manifest}: unreadable package manifest')
        roots = [package / 'lib']
        if relative.startswith('apps/'):
            roots.append(package / 'android/app/src')
            roots.append(package / 'ios/Runner')
        for source_root in roots:
            for file in source_files(source_root):
                if file.is_symlink():
                    errors.append(f'{file}: source symlink must be resolved for inspection'); continue
                scanned += 1
                if file.name == 'AndroidManifest.xml':
                    manifests.append(str(file.relative_to(root))); errors.extend(manifest_violations(file)); continue
                try: text = strip_comments(file.read_text(encoding='utf-8'))
                except (OSError, UnicodeError): errors.append(f'{file}: unreadable source'); continue
                for pattern in RUNTIME_PATTERNS:
                    if pattern.search(text): errors.append(f'{file}: SMS collector API in supporter runtime')
                for package_name in re.findall(r"(?:import|export)\s+['\"]package:([^/'\"]+)/", text):
                    if package_name in FORBIDDEN_PACKAGES:
                        errors.append(f'{file}: SMS collector package in supporter runtime')
    merged_count = 0
    if merged_manifests is not None:
        for app in APPS:
            file = merged_manifests / app / 'AndroidManifest.xml'
            errors.extend(manifest_violations(file, merged=True))
            if file.is_file(): merged_count += 1
    return {'schemaVersion': 1, 'passed': not errors, 'apps': list(APPS), 'errors': sorted(set(errors)),
            'workspacePackagesChecked': package_count, 'sourceFilesChecked': scanned,
            'sourceManifestsChecked': manifests, 'mergedManifestsChecked': merged_count,
            'binaryCertification': False,
            'scope': 'Supporter runtime sources; server SMS ingestion/reconciliation is deliberately excluded.'}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('root', nargs='?', type=pathlib.Path, default=pathlib.Path.cwd())
    parser.add_argument('--merged-manifests', type=pathlib.Path)
    parser.add_argument('--json-out', type=pathlib.Path)
    args = parser.parse_args(); result = validate(args.root, args.merged_manifests)
    if args.json_out:
        args.json_out.parent.mkdir(parents=True, exist_ok=True)
        args.json_out.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    if result['passed']:
        print(f"Supporter SMS source boundary passed: {len(APPS)} apps, {result['sourceFilesChecked']} source files; "
              f"{result['mergedManifestsChecked']} merged manifests checked. Not binary certification.")
        return 0
    print('Supporter SMS boundary failed:\n- ' + '\n- '.join(result['errors']), file=sys.stderr)
    return 1

if __name__ == '__main__':
    sys.exit(main())
