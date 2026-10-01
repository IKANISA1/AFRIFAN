import copy
import json
from pathlib import Path
import tempfile
import unittest
import yaml
import local_native_ci as ci


class NativeCIContractTests(unittest.TestCase):
    def setUp(self):
        self.scopes = ci.clubs()
        self.text = (ci.ROOT / '.github/workflows/ci.yaml').read_text()
        self.workflow = yaml.load(self.text, Loader=ci.StrictYaml)

    def rejected(self, mutate):
        value = copy.deepcopy(self.workflow)
        mutate(value)
        with self.assertRaises(ValueError):
            ci.verify_workflow(yaml.safe_dump(value), self.scopes)

    def test_real_definition_matches_all_ten_declared_targets(self):
        result = ci.verify_workflow(self.text, self.scopes)
        self.assertEqual(len(result['targets']), 10)
        self.assertFalse(result['hostedJobsExecuted'])
        self.assertFalse(result['releaseAccepted'])

    def test_native_performance_gate_is_required_before_compilation(self):
        workflow = copy.deepcopy(self.workflow)
        steps = workflow['jobs']['native-target-ci']['steps']
        command = 'python3 tools/scripts/verify_native_performance_privacy.py'
        if not any(step.get('run', '').strip() == command for step in steps):
            first_build = next(i for i, step in enumerate(steps) if 'flutter build' in step.get('run', ''))
            steps.insert(first_build, {'name': 'Verify native performance privacy', 'run': command})
        value = ci.verify_workflow(yaml.safe_dump(workflow), self.scopes)
        self.assertTrue(value['nativePerformanceGateVerified'])
        for fault in ('missing', 'conditional', 'ignored', 'duplicate', 'late'):
            changed = copy.deepcopy(workflow)
            altered = changed['jobs']['native-target-ci']['steps']
            index = next(i for i, step in enumerate(altered) if step.get('run', '').strip() == command)
            if fault == 'missing': altered.pop(index)
            elif fault == 'conditional': altered[index]['if'] = 'false'
            elif fault == 'ignored': altered[index]['continue-on-error'] = 'true'
            elif fault == 'duplicate': altered.insert(index, copy.deepcopy(altered[index]))
            else: altered.append(altered.pop(index))
            with self.subTest(fault=fault), self.assertRaisesRegex(ValueError, 'performance'):
                ci.verify_workflow(yaml.safe_dump(changed), self.scopes)

    def test_native_performance_configuration_covers_ten_current_targets(self):
        value = ci.verify_native_controls(ci.ROOT, self.scopes)
        self.assertEqual(len(value['targets']), 10)
        self.assertTrue(value['configurationVerified'])
        self.assertFalse(value['hostedJobsExecuted'])
        self.assertFalse(value['releaseAccepted'])

    def adapter_inputs(self):
        package = json.loads((ci.ROOT / 'apps/rayon_sports/web/package.json').read_text())
        workflows = {str(path.relative_to(ci.ROOT)): path.read_text() for path in
                     (ci.ROOT / '.github/workflows/ci.yaml', ci.ROOT / '.github/workflows/free_self_hosted_release.yml')}
        return package, workflows

    def test_current_package_and_ci_use_the_isolated_adapter(self):
        package, workflows = self.adapter_inputs()
        value = ci.verify_adapter_configuration(json.dumps(package), workflows)
        self.assertTrue(value['isolatedAdapterWiringVerified'])
        self.assertTrue(value['requiredCiEnvironmentGateVerified'])
        self.assertFalse(value['adapterExecutedByThisCheck'])

    def test_raw_package_adapter_or_wrong_conversion_order_rejected(self):
        for command in ('opennextjs-cloudflare build && opennextjs-cloudflare preview',
                        'opennextjs-cloudflare preview && node scripts/build-opennext-isolated.mjs'):
            package, workflows = self.adapter_inputs(); package['scripts']['preview'] = command
            with self.subTest(command=command), self.assertRaises(ValueError):
                ci.verify_adapter_configuration(json.dumps(package), workflows)

    def test_ci_cannot_bypass_or_duplicate_adapter_conversion(self):
        for replacement in ('opennextjs-cloudflare build',
                            'node scripts/build-opennext-isolated.mjs\n          node scripts/build-opennext-isolated.mjs'):
            package, workflows = self.adapter_inputs()
            workflows['.github/workflows/ci.yaml'] = workflows['.github/workflows/ci.yaml'].replace('node scripts/build-opennext-isolated.mjs', replacement)
            with self.subTest(replacement=replacement), self.assertRaises(ValueError):
                ci.verify_adapter_configuration(json.dumps(package), workflows)

    def test_artifact_environment_gate_cannot_omit_regressions_skip_failures_or_run_late(self):
        package, workflows = self.adapter_inputs()
        for omitted in ('scripts/artifact-public-environment.node-test.mjs',
                        'scripts/artifact-installed-inputs.node-test.mjs',
                        'scripts/sync-cloudflare-dev-vars.node-test.mjs',
                        '../../../tools/scripts/local_validation_network_guard.node-test.mjs'):
            changed = copy.deepcopy(package)
            changed['scripts']['test:artifact-environment'] = changed['scripts']['test:artifact-environment'].replace(omitted, '')
            with self.subTest(omitted=omitted), self.assertRaises(ValueError):
                ci.verify_adapter_configuration(json.dumps(changed), workflows)
        original = yaml.load(workflows['.github/workflows/ci.yaml'], Loader=ci.StrictYaml)
        for fault in ('missing', 'conditional', 'ignored', 'late'):
            workflow = copy.deepcopy(original)
            job = next(job for job in workflow['jobs'].values()
                       if any('node scripts/build-opennext-isolated.mjs' in s.get('run', '') for s in job.get('steps', [])))
            index = next(i for i, s in enumerate(job['steps']) if s.get('run') == 'corepack npm run test:artifact-environment')
            if fault == 'missing': job['steps'].pop(index)
            elif fault == 'conditional': job['steps'][index]['if'] = 'false'
            elif fault == 'ignored': job['steps'][index]['continue-on-error'] = 'true'
            else: job['steps'].append(job['steps'].pop(index))
            changed = dict(workflows); changed['.github/workflows/ci.yaml'] = yaml.safe_dump(workflow)
            with self.subTest(fault=fault), self.assertRaises(ValueError):
                ci.verify_adapter_configuration(json.dumps(package), changed)

    def test_missing_target_cannot_pass_by_count(self):
        self.rejected(lambda d: d['jobs']['native-target-ci']['strategy']['matrix']['include'].pop())

    def test_duplicate_target_rejected(self):
        self.rejected(lambda d: d['jobs']['native-target-ci']['strategy']['matrix']['include'].__setitem__(
            0, d['jobs']['native-target-ci']['strategy']['matrix']['include'][1]))

    def test_unapproved_club_rejected(self):
        self.rejected(lambda d: d['jobs']['native-target-ci']['strategy']['matrix']['include'][0].update(club='foreign'))

    def test_mismatched_platform_rejected(self):
        self.rejected(lambda d: d['jobs']['native-target-ci']['strategy']['matrix']['include'][0].update(platform='web'))

    def test_write_permissions_rejected(self):
        self.rejected(lambda d: d['jobs']['native-target-ci'].update(permissions={'contents': 'write'}))

    def test_mutable_action_reference_rejected(self):
        self.rejected(lambda d: d['jobs']['native-target-ci']['steps'][0].update(uses='actions/checkout@v4'))

    def test_missing_native_build_gate_rejected(self):
        self.rejected(lambda d: d['jobs']['native-target-ci']['steps'].pop())

    def test_build_requires_exact_platform(self):
        self.rejected(lambda d: d['jobs']['native-target-ci']['steps'][-1].update({'if': 'always()'}))

    def test_provider_credentials_are_not_compile_input(self):
        self.rejected(lambda d: d['jobs']['native-target-ci']['steps'][0].update(env={'TOKEN': '${{ secrets.TOKEN }}'}))

    def test_promotion_cannot_omit_native_gate(self):
        self.rejected(lambda d: d['jobs']['promote-web']['needs'].remove('native-target-ci'))

    def test_duplicate_yaml_key_is_rejected(self):
        with self.assertRaises(ValueError):
            yaml.load('jobs: {}\njobs: {}\n', Loader=ci.StrictYaml)

    def test_flutter_setup_reads_raw_exact_pin_using_supported_action_input(self):
        text = (ci.ROOT / '.github/actions/setup-flutter/action.yml').read_text()
        ci.verify_flutter_action(text)
        for old, changed in [('flutter-version: ${{ steps.pin.outputs.version }}', 'flutter-version-file: .fvmrc'),
                             ('$GITHUB_WORKSPACE/.fvmrc', '$GITHUB_WORKSPACE/alternative.txt'),
                             ('@fd55f4c5af5b953cc57a2be44cb082c8f6635e8e', '@v2')]:
            with self.assertRaises(ValueError):
                ci.verify_flutter_action(text.replace(old, changed))

    def test_all_active_workflows_use_immutable_external_actions(self):
        for path in (ci.ROOT / '.github/workflows').glob('*'):
            workflow = yaml.load(path.read_text(), Loader=ci.StrictYaml)
            def walk(value):
                if isinstance(value, dict):
                    for key, item in value.items():
                        if key == 'uses' and not item.startswith('./'):
                            self.assertRegex(item, r'^[\w-]+/[\w-]+@[0-9a-f]{40}$', str(path))
                        walk(item)
                elif isinstance(value, list):
                    for item in value:
                        walk(item)
            walk(workflow)

    def test_all_five_synthetic_configs_keep_club_and_replace_backend_access(self):
        for club, tenant in self.scopes.items():
            value = ci.synthetic_configuration(ci.ROOT, club, self.scopes)
            self.assertEqual(value['CLUB_ID'], tenant)
            self.assertEqual(value['ENVIRONMENT'], 'test')
            for key, item in value.items():
                if 'SUPABASE' in key and key.endswith('URL'):
                    self.assertEqual(item, 'https://local-native-ci.invalid')
                if 'SUPABASE' in key and key.endswith('KEY'):
                    self.assertEqual(item, 'synthetic-public-client-key-for-local-native-ci')

    def test_foreign_configuration_and_flavor_scope_changes_fail_closed(self):
        with self.assertRaises(ValueError):
            ci.synthetic_configuration(ci.ROOT, 'foreign', self.scopes)
        with tempfile.TemporaryDirectory() as temp:
            source = Path(temp) / 'apps/rayon_sports/assets/flavors/production.json'
            source.parent.mkdir(parents=True)
            source.write_text(json.dumps({'CLUB_ID': '44'}))
            with self.assertRaises(ValueError):
                ci.synthetic_configuration(Path(temp), 'rayon_sports', self.scopes)
            source.write_text('{"CLUB_ID":"24","CLUB_ID":"24"}')
            with self.assertRaises(ValueError):
                ci.synthetic_configuration(Path(temp), 'rayon_sports', self.scopes)


if __name__ == '__main__':
    unittest.main()
