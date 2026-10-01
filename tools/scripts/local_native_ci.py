#!/usr/bin/env python3
"""Verify the ten-target CI definition and prepare synthetic compile-only inputs."""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import re
import shlex
import sys
import yaml
from verify_native_performance_privacy import verify_native_controls

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
    verify_native_performance_gate(steps)
    build_steps = {step.get('if'): step['run'] for step in steps if 'flutter build' in step.get('run', '')}
    if len(build_steps) != 2 or 'flutter build apk' not in build_steps.get("matrix.platform == 'android'", '') or \
            'flutter build ios' not in build_steps.get("matrix.platform == 'ios'", ''):
        raise ValueError('Native build commands must be gated by their exact platform')
    promotion = workflow['jobs']['promote-web']['needs']
    if 'native-target-ci' not in promotion:
        raise ValueError('Release promotion must wait for the ten-target source gate')
    return {'targets': [{'club': club, 'platform': platform} for club, platform in sorted(actual)],
            'configurationVerified': True, 'nativePerformanceGateVerified': True,
            'hostedJobsExecuted': False, 'releaseAccepted': False}


def verify_native_performance_gate(steps):
    command = 'python3 tools/scripts/verify_native_performance_privacy.py'
    gates = [(index, step) for index, step in enumerate(steps)
             if step.get('run', '').strip() == command]
    builds = [index for index, step in enumerate(steps) if 'flutter build' in step.get('run', '')]
    if len(gates) != 1 or not builds:
        raise ValueError('Native performance privacy needs one required gate before compilation')
    index, gate = gates[0]
    if 'if' in gate or gate.get('continue-on-error', 'false') != 'false' or index >= min(builds):
        raise ValueError('Native performance privacy gate cannot be skipped, ignored or run after compilation')


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


def verify_adapter_configuration(package_text, workflow_texts):
    """Check source wiring to the controlled adapter without running a build."""
    package = json.loads(package_text, object_pairs_hook=unique_json)
    wrapper = 'node scripts/build-opennext-isolated.mjs'
    for name in ('preview', 'deploy', 'upload'):
        command = package['scripts'][name]
        if command.count(wrapper) != 1 or 'opennextjs-cloudflare build' in command:
            raise ValueError('Web package command bypasses the isolated adapter')
        consumer = 'opennextjs-cloudflare ' + name
        if consumer not in command or command.index(wrapper) >= command.index(consumer):
            raise ValueError('Isolated adapter must run before consuming its artifact')
    environment_tests = ['scripts/artifact-public-environment.node-test.mjs',
                         'scripts/artifact-installed-inputs.node-test.mjs',
                         'scripts/sync-cloudflare-dev-vars.node-test.mjs',
                         '../../../tools/scripts/local_validation_network_guard.node-test.mjs']
    arguments = shlex.split(package['scripts'].get('test:artifact-environment', ''))
    if arguments[:2] != ['node', '--test'] or sorted(arguments[2:]) != sorted(environment_tests):
        raise ValueError('Artifact environment gate must run all reviewed environment, private-vars and network guard regressions')
    for name, text in workflow_texts.items():
        workflow = yaml.load(text, Loader=StrictYaml)
        commands = [step.get('run', '') for job in workflow['jobs'].values() for step in job.get('steps', [])]
        if sum(command.count(wrapper) for command in commands) != 1:
            raise ValueError('Workflow needs exactly one isolated adapter conversion')
        if any(re.search(r'opennextjs-cloudflare\s+build', command) for command in commands):
            raise ValueError('Workflow bypasses the isolated adapter')
        if name == '.github/workflows/ci.yaml':
            conversions = [(job, index) for job in workflow['jobs'].values()
                           for index, step in enumerate(job.get('steps', [])) if wrapper in step.get('run', '')]
            job, conversion_index = conversions[0]
            gates = [(index, step) for index, step in enumerate(job['steps'])
                     if step.get('run', '').strip() == 'corepack npm run test:artifact-environment']
            if len(gates) != 1 or gates[0][0] >= conversion_index or \
                    'if' in gates[0][1] or gates[0][1].get('continue-on-error', 'false') != 'false':
                raise ValueError('CI must require the artifact environment gate before adapter conversion')
    return {'packageCommands': ['preview', 'deploy', 'upload'],
            'workflowDefinitions': sorted(workflow_texts), 'isolatedAdapterWiringVerified': True,
            'artifactEnvironmentRegressionInputs': environment_tests, 'requiredCiEnvironmentGateVerified': True,
            'adapterExecutedByThisCheck': False}


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
            web = ROOT / 'apps/rayon_sports/web'
            definitions = {str(path.relative_to(ROOT)): path.read_text() for path in
                           (source, ROOT / '.github/workflows/free_self_hosted_release.yml')}
            result['webAdapterConfiguration'] = verify_adapter_configuration((web / 'package.json').read_text(), definitions)
            result['nativePerformanceConfiguration'] = verify_native_controls(ROOT, scopes)
            inputs = [source, ROOT / '.github/workflows/free_self_hosted_release.yml', action,
                      ROOT / '.fvmrc', ROOT / 'docs/release/full_stack_qa_plan.md', web / 'package.json',
                      web / 'scripts/build-opennext-isolated.mjs', web / 'scripts/artifact-public-environment.mjs',
                      web / 'scripts/artifact-installed-inputs.mjs', web / 'scripts/artifact-installed-inputs.node-test.mjs',
                      web / 'scripts/web-build-provenance.mjs', Path(__file__),
                      ROOT / 'tools/scripts/test_local_native_ci.py',
                      web / 'scripts/artifact-public-environment.node-test.mjs',
                      web / 'scripts/sync-cloudflare-dev-vars.mjs', web / 'scripts/sync-cloudflare-dev-vars.node-test.mjs',
                      ROOT / 'tools/scripts/local_validation_network_guard.node-test.mjs',
                      ROOT / 'tools/scripts/local_ops_rehearsal_no_network.cjs',
                      ROOT / 'tools/scripts/local_web_server_no_network.cjs']
            inputs += [ROOT / 'tools/scripts/verify_native_performance_privacy.py',
                       ROOT / 'tools/scripts/test_verify_native_performance_privacy.py']
            inputs += [ROOT / source['path'] for source in result['nativePerformanceConfiguration']['sourceInputs']]
            result['syntheticClubConfigurations'] = []
            for club in sorted(scopes):
                flavor = ROOT / 'apps' / club / 'assets/flavors/production.json'
                value = synthetic_configuration(ROOT, club, scopes)
                inputs.append(flavor)
                result['syntheticClubConfigurations'].append({'club': club, 'clubId': scopes[club],
                    'platforms': ['android', 'ios'], 'syntheticOnly': True,
                    'configurationSha256': hashlib.sha256(json.dumps(value, sort_keys=True, separators=(',', ':')).encode()).hexdigest()})
            result['sourceInputs'] = [{'path': str(path.relative_to(ROOT)), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
                                      'bytes': path.stat().st_size} for path in inputs]
            result['remainingGates'] = ['Hosted native jobs were not executed by this source check',
                                      'Five Android and five iOS compilation outcomes need their own build evidence',
                                      'Provider, signing, device/store and deployment acceptance remain external to configuration verification']
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
