#!/usr/bin/env python3
"""Verify the ten-target CI definition and prepare synthetic compile-only inputs."""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import re
import sys
import yaml

ROOT = Path(__file__).resolve().parents[2]


class StrictYaml(yaml.BaseLoader):
    pass


def unique_mapping(loader, node):
    result = {}
    for key_node, value_node in node.value:
        key = loader.construct_object(key_node)
        if key in result:
            raise ValueError('Duplicate workflow key')
        result[key] = loader.construct_object(value_node)
    return result


StrictYaml.add_constructor(yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, unique_mapping)


def unique_json(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError('Duplicate configuration key')
        result[key] = value
    return result


def clubs(root=ROOT):
    text = (root / 'docs/release/full_stack_qa_plan.md').read_text()
    sections = re.findall(r'<!-- release-scope:start -->(.*?)<!-- release-scope:end -->', text, re.S)
    if len(sections) != 1:
        raise ValueError('Missing or ambiguous native release scope')
    rows = [line.strip().strip('|').split('|') for line in sections[0].splitlines() if line.strip().startswith('|')][2:]
    result = {}
    for row in rows:
        if len(row) != 6:
            raise ValueError('Invalid native scope row')
        slug, tenant, *_ = [cell.strip() for cell in row]
        if not re.fullmatch(r'[a-z][a-z0-9_]*', slug) or not re.fullmatch(r'[1-9][0-9]*', tenant) or slug in result:
            raise ValueError('Invalid or duplicated native club')
        result[slug] = tenant
    if len(result) != 5 or len(set(result.values())) != 5:
        raise ValueError('Expected five unique club scopes')
    return result


def verify_workflow(text, scopes):
    workflow = yaml.load(text, Loader=StrictYaml)
    job = workflow['jobs']['native-target-ci']
    entries = job['strategy']['matrix']['include']
    expected = {(club, platform) for club in scopes for platform in ['android', 'ios']}
    actual = [(row['club'], row['platform']) for row in entries]
    if len(actual) != 10 or set(actual) != expected or len(actual) != len(set(actual)):
        raise ValueError('Native CI must cover each of the ten distinct targets')
    if job['permissions'] != {'contents': 'read'} or job['strategy']['fail-fast'] != 'false':
        raise ValueError('Native CI needs independent read-only target checks')
    if job['runs-on'] != "${{ matrix.platform == 'ios' && 'macos-latest' || 'ubuntu-latest' }}":
        raise ValueError('Native platform runner mapping changed')
    steps = job['steps']
    for step in steps:
        if 'uses' in step and step['uses'] != './.github/actions/setup-flutter' and not re.fullmatch(r'[A-Za-z0-9_-]+/[A-Za-z0-9_-]+@[0-9a-f]{40}', step['uses']):
            raise ValueError('Native CI action must have an immutable commit pin')
        if 'secrets.' in json.dumps(step) or 'deploy' in step.get('run', '').lower():
            raise ValueError('Compile-only target checks cannot require secrets or deploy')
    commands = '\n'.join(step.get('run', '') for step in steps)
    required = ['flutter pub get --enforce-lockfile', 'local_native_ci.py prepare',
                'flutter test --no-pub', 'flutter build apk --debug --no-pub',
                'flutter build ios --simulator --debug --no-codesign --no-pub',
                'verify_native_identity_credentials.py --configuration-only']
    if any(command not in commands for command in required):
        raise ValueError('Missing required native CI source/configuration/build check')
    build_steps = {step.get('if'): step['run'] for step in steps if 'flutter build' in step.get('run', '')}
    if len(build_steps) != 2 or 'flutter build apk' not in build_steps.get("matrix.platform == 'android'", '') or \
            'flutter build ios' not in build_steps.get("matrix.platform == 'ios'", ''):
        raise ValueError('Native build commands must be gated by their exact platform')
    promotion = workflow['jobs']['promote-web']['needs']
    if 'native-target-ci' not in promotion:
        raise ValueError('Release promotion must wait for the ten-target source gate')
    return {'targets': [{'club': club, 'platform': platform} for club, platform in sorted(actual)],
            'configurationVerified': True, 'hostedJobsExecuted': False, 'releaseAccepted': False}


def verify_flutter_action(text):
    action = yaml.load(text, Loader=StrictYaml)
    steps = action['runs']['steps']
    if action['runs']['using'] != 'composite' or len(steps) != 2:
        raise ValueError('Controlled Flutter setup contract changed')
    if steps[1]['uses'] != 'subosito/flutter-action@fd55f4c5af5b953cc57a2be44cb082c8f6635e8e' or \
            steps[1]['with'] != {'flutter-version': '${{ steps.pin.outputs.version }}', 'channel': 'stable', 'cache': 'true'}:
        raise ValueError('Flutter setup action must use the exact repository pin and immutable action')
    if steps[0]['id'] != 'pin' or steps[0]['shell'] != 'bash' or \
            '$GITHUB_WORKSPACE/.fvmrc' not in steps[0]['run'] or \
            '[[ "$flutter_version" =~ ^[0-9]+\\.[0-9]+\\.[0-9]+$ ]]' not in steps[0]['run'] or \
            'echo "version=$flutter_version" >> "$GITHUB_OUTPUT"' not in steps[0]['run']:
        raise ValueError('Missing exact runtime pin extraction')


def synthetic_configuration(root, club, scopes):
    if club not in scopes:
        raise ValueError('Club is outside declared scope')
    source = root / 'apps' / club / 'assets/flavors/production.json'
    config = json.loads(source.read_text(), object_pairs_hook=unique_json)
    if config.get('CLUB_ID') != scopes[club]:
        raise ValueError('Flavor and declared club scope differ')
    # Compile-only public inputs. No actual backend access, provider secrets,
    # signing credentials or invented live endpoint are needed for this gate.
    for key in list(config):
        if 'SUPABASE' in key and key.endswith('URL'):
            config[key] = 'https://local-native-ci.invalid'
        elif 'SUPABASE' in key and key.endswith('KEY'):
            config[key] = 'synthetic-public-client-key-for-local-native-ci'
    config.update(ENVIRONMENT='test', AFRICLUB_INTERNAL_MOBILE_ADMIN=False)
    return config


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    check = commands.add_parser('verify'); check.add_argument('--report', type=Path)
    prepare = commands.add_parser('prepare'); prepare.add_argument('--club', required=True)
    prepare.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    try:
        scopes = clubs()
        if args.command == 'verify':
            source = ROOT / '.github/workflows/ci.yaml'
            result = verify_workflow(source.read_text(), scopes)
            action = ROOT / '.github/actions/setup-flutter/action.yml'
            verify_flutter_action(action.read_text())
            result['flutterSetupActionSha256'] = hashlib.sha256(action.read_bytes()).hexdigest()
            result['workflowSha256'] = hashlib.sha256(source.read_bytes()).hexdigest()
            if args.report:
                args.report.parent.mkdir(parents=True, exist_ok=True)
                args.report.write_text(json.dumps(result, indent=2) + '\n')
        else:
            value = synthetic_configuration(ROOT, args.club, scopes)
            args.output.parent.mkdir(parents=True, exist_ok=True)
            args.output.write_text(json.dumps(value, indent=2) + '\n')
            result = {'club': args.club, 'syntheticOnly': True,
                      'sha256': hashlib.sha256(args.output.read_bytes()).hexdigest()}
        print(json.dumps(result)); return 0
    except Exception:
        print('local_native_ci_configuration_rejected', file=sys.stderr); return 1


if __name__ == '__main__':
    sys.exit(main())
