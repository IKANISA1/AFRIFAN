#!/usr/bin/env python3
"""Offline pure-Dart verification. Never downloads SDKs, contacts providers or deploys.

This check deliberately does not certify the Flutter external-application bridge,
platform secure storage or any signed application. Missing tools are BLOCKED, not PASS.
"""
from __future__ import annotations
import argparse
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
FEATURE = ROOT / 'packages/features/feat_membership'

def run_check(results: Path) -> int:
    results.mkdir(parents=True, exist_ok=True)
    summary: dict = {'schemaVersion': 1, 'dartExecuted': False,
                     'flutterBridgeVerified': False, 'secureStorageVerified': False,
                     'deviceDialerVerified': False, 'providerRequests': 0,
                     'dependenciesInstalled': False, 'steps': []}
    def finish(status: str, reason: str, code: int) -> int:
        summary.update(status=status, reason=reason)
        (results / 'native-verification.json').write_text(json.dumps(summary, indent=2) + '\n')
        print(json.dumps(summary))
        return code
    dart = shutil.which('dart')
    if dart is None:
        return finish('blocked', 'Dart >=3.10 SDK not installed', 2)
    try:
        version = subprocess.run([dart, '--version'], capture_output=True, text=True,
                                 timeout=20, check=True)
    except (OSError, subprocess.SubprocessError) as exc:
        return finish('blocked', f'Dart version unavailable: {type(exc).__name__}', 2)
    version_text = (version.stdout + version.stderr).strip()
    summary['dartVersion'] = version_text
    match = re.search(r'Dart SDK version:\s*(\d+)\.(\d+)\.(\d+)', version_text)
    if not match or not (3, 10, 0) <= tuple(map(int, match.groups())) < (4, 0, 0):
        return finish('blocked', 'Requires Dart >=3.10.0 <4.0.0; workspace is not weakened', 2)
    required = [FEATURE / 'lib/native_membership.dart',
                FEATURE / 'test/native_checkout/contract_harness.dart',
                FEATURE / 'test/native_checkout/wire-vectors.json',
                FEATURE / 'test/native_checkout/platform_recovery_harness.dart',
                FEATURE / 'test/native_checkout/history_harness.dart']
    if not all(p.is_file() and not p.is_symlink() for p in required):
        return finish('failed', 'Native verification source missing or symlinked', 1)
    with tempfile.TemporaryDirectory(prefix='africlub-native-check-') as temporary:
        target = Path(temporary)
        shutil.copytree(FEATURE / 'lib/src/native_checkout', target / 'lib/src/native_checkout')
        shutil.copy2(required[0], target / 'lib/native_membership.dart')
        (target / 'test/native_checkout').mkdir(parents=True)
        for source in required[1:]:
            shutil.copy2(source, target / 'test/native_checkout' / source.name)
        (target / 'pubspec.yaml').write_text('name: feat_membership\npublish_to: none\nenvironment:\n  sdk: ">=3.10.0 <4.0.0"\n')
        (target / '.dart_tool').mkdir()
        config = {'configVersion': 2, 'packages': [{'name': 'feat_membership',
                  'rootUri': '../', 'packageUri': 'lib/', 'languageVersion': '3.10'}]}
        (target / '.dart_tool/package_config.json').write_text(json.dumps(config))
        commands = [('analyze', [dart, 'analyze', '--fatal-infos', '.']),
                    ('contracts', [dart, '--packages=.dart_tool/package_config.json',
                                   'test/native_checkout/contract_harness.dart']),
                    ('platform-recovery', [dart, '--packages=.dart_tool/package_config.json',
                                           'test/native_checkout/platform_recovery_harness.dart']),
                    ('membership-history', [dart, '--packages=.dart_tool/package_config.json',
                                           'test/native_checkout/history_harness.dart'])]
        for name, command in commands:
            try:
                result = subprocess.run(command, cwd=target, capture_output=True, text=True, timeout=120)
            except (OSError, subprocess.SubprocessError) as exc:
                return finish('failed', f'{name} failed: {type(exc).__name__}', 1)
            summary['dartExecuted'] = True
            (results / f'{name}.log').write_text(result.stdout + result.stderr)
            summary['steps'].append({'name': name, 'exitCode': result.returncode})
            if result.returncode:
                return finish('failed', f'Dart {name} failed', 1)
    return finish('passed_pure_dart_only', 'Flutter bridge and OS/device acceptance still required', 0)

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--results', type=Path, required=True)
    sys.exit(run_check(parser.parse_args().results.resolve()))
