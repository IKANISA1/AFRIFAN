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
