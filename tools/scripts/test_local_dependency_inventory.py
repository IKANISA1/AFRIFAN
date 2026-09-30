"""Regressions for actual lock/evidence boundaries, without registry or SDK access."""
import base64
import copy
import hashlib
import json
from pathlib import Path
import tempfile
import unittest

import local_dependency_inventory as inventory


class InventoryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()

    def write(self, relative, value):
        path = self.root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(value) if isinstance(value, (dict, list)) else value)
        return path

    def test_duplicate_json_keys_are_rejected(self):
        path = self.write('lock.json', '{"version":"1","version":"2"}')
        with self.assertRaises(inventory.InventoryError):
            inventory.load_json(path)

    def test_duplicate_yaml_keys_are_rejected(self):
        path = self.write('pubspec.yaml', 'name: one\nname: two\n')
        with self.assertRaises(inventory.InventoryError):
            inventory.load_yaml(path)

    def test_yaml_tag_cannot_execute(self):
        path = self.write('pubspec.yaml', '!!python/object/apply:os.system ["false"]')
        with self.assertRaises(inventory.yaml.YAMLError):
            inventory.load_yaml(path)

    def test_sri_is_decoded_without_losing_archive_basis(self):
        raw = hashlib.sha512(b'archive').digest()
        result = inventory.sri_records('sha512-' + base64.b64encode(raw).decode())
        self.assertEqual(result[0]['value'], raw.hex())
        self.assertIn('archive', result[0]['basis'])

    def test_malformed_sri_length_or_base64_is_rejected(self):
        for value in ('sha512-YQ==', 'sha256-!!!', 'md5-Zm9v'):
            with self.subTest(value=value), self.assertRaises(inventory.InventoryError):
                inventory.sri_records(value)

    def test_source_credentials_never_enter_report(self):
        for value in ('https://user:secret@registry.test/p.tgz', 'https://registry.test/p?token=secret', 'https://registry.test/p#token'):
            with self.subTest(value=value), self.assertRaises(inventory.InventoryError) as context:
                inventory.safe_url(value)
            self.assertNotIn('secret', str(context.exception))

    def test_license_symlink_cannot_escape_package(self):
        package = self.root / 'package'; package.mkdir()
        secret = self.write('outside.txt', 'private')
        (package / 'LICENSE').symlink_to(secret)
        with self.assertRaises(inventory.InventoryError):
            inventory.license_paths(package)

    def test_license_scan_does_not_collect_nested_dependencies(self):
        self.write('package/LICENSE', 'own license')
        self.write('package/node_modules/other/LICENSE', 'other license')
        paths = inventory.license_paths(self.root / 'package')
        self.assertEqual(paths, [self.root / 'package/LICENSE'])

    def test_npm_edges_choose_nearest_locked_dependency(self):
        packages = {'node_modules/a': {}, 'node_modules/x': {}, 'node_modules/a/node_modules/x': {}}
        self.assertEqual(inventory.npm_resolve(packages, 'node_modules/a', 'x'), 'node_modules/a/node_modules/x')
        self.assertEqual(inventory.npm_resolve(packages, 'node_modules/b', 'x'), 'node_modules/x')

    def npm_fixture(self, bundled=False):
        archive = b'archive'
        sri = 'sha512-' + base64.b64encode(hashlib.sha512(archive).digest()).decode()
        root = {'name': 'web', 'version': '0.1.0', 'dependencies': {'dep': '1.0.0'}}
        self.write('apps/rayon_sports/web/package.json', root)
        dep = {'version': '1.0.0', 'resolved': 'https://registry.npmjs.org/dep/-/dep-1.0.0.tgz', 'integrity': sri}
        packages = {'': root, 'node_modules/dep': dep}
        if bundled:
            dep['dependencies'] = {'child': '2.0.0'}
            packages['node_modules/dep/node_modules/child'] = {'version': '2.0.0', 'inBundle': True, 'license': 'MIT'}
        self.write('apps/rayon_sports/web/package-lock.json', {'name': 'web', 'lockfileVersion': 3, 'packages': packages})
        return packages, archive

    def test_bundled_npm_integrity_is_bound_to_container(self):
        self.npm_fixture(bundled=True)
        observed = inventory.Inventory(self.root)
        observed.read_npm()
        child = next(c for c in observed.components.values() if c['name'] == 'child')
        self.assertEqual(child['source']['kind'], 'npm-bundle')
        self.assertIn('containing bundle', child['integrities'][0]['basis'])
        self.assertFalse(any(g['kind'] == 'npm-integrity-missing' for g in observed.gaps.values()))

    def test_npm_installed_version_drift_is_rejected(self):
        self.npm_fixture()
        self.write('apps/rayon_sports/web/node_modules/dep/package.json', {'name': 'dep', 'version': '1.0.1'})
        with self.assertRaises(inventory.InventoryError):
            inventory.Inventory(self.root).read_npm()

    def test_npm_cache_corruption_is_rejected(self):
        packages, archive = self.npm_fixture()
        digest = hashlib.sha512(archive).hexdigest()
        cache = self.root / 'npm-cache'
        path = cache / '_cacache/content-v2/sha512' / digest[:2] / digest[2:4] / digest[4:]
        path.parent.mkdir(parents=True); path.write_bytes(b'tampered archive')
        with self.assertRaises(inventory.InventoryError):
            inventory.Inventory(self.root, npm_cache=cache).read_npm()

    def test_npm_lock_location_escape_is_rejected(self):
        packages, _ = self.npm_fixture()
        packages['node_modules/../../outside'] = {'version': '1.0.0'}
        self.write('apps/rayon_sports/web/package-lock.json', {'name': 'web', 'lockfileVersion': 3, 'packages': packages})
        with self.assertRaises(inventory.InventoryError):
            inventory.Inventory(self.root).read_npm()

    def test_absent_optional_platform_package_is_still_inventoried(self):
        packages, _ = self.npm_fixture()
        packages['node_modules/dep'].update(optional=True, os=['win32'])
        self.write('apps/rayon_sports/web/package-lock.json', {'name': 'web', 'lockfileVersion': 3, 'packages': packages})
        observed = inventory.Inventory(self.root); observed.read_npm()
        dep = next(c for c in observed.components.values() if c['name'] == 'dep')
        self.assertEqual(dep['version'], '1.0.0')
        self.assertEqual(dep['absentInstalledOccurrences'], ['node_modules/dep'])

    def evidence_fixture(self):
        path = self.write('locked.txt', 'exact evidence')
        observed = inventory.Inventory(self.root)
        key = observed.file_evidence(path, 'lockfile')
        component = observed.component('npm', 'dep', '1.0.0', {'kind': 'registry'})
        component['evidence'] = [key]
        value = {'schemaVersion': 1, 'repositoryRoot': str(self.root), 'components': [component], 'edges': [],
                 'evidence': observed.evidence, 'unresolved': [], 'summary': {'components': 1, 'exactInventoryComplete': True},
                 'scope': 'fixture', 'licenseApproval': 'not assessed'}
        return value, path

    def test_evidence_changes_invalidate_report(self):
        value, path = self.evidence_fixture()
        inventory.validate_inventory(value)
        path.write_text('changed evidence')
        with self.assertRaises(inventory.InventoryError):
            inventory.validate_inventory(value)

    def test_forged_component_version_is_rejected(self):
        value, _ = self.evidence_fixture()
        value['components'][0]['version'] = '2.0.0'
        with self.assertRaises(inventory.InventoryError):
            inventory.validate_inventory(value)

    def test_absent_graph_component_is_rejected(self):
        value, _ = self.evidence_fixture()
        value['edges'] = [{'from': value['components'][0]['ref'], 'to': 'absent', 'contexts': []}]
        with self.assertRaises(inventory.InventoryError):
            inventory.validate_inventory(value)

    def test_duplicate_component_reference_is_rejected(self):
        value, _ = self.evidence_fixture()
        value['components'].append(copy.deepcopy(value['components'][0]))
        with self.assertRaises(inventory.InventoryError):
            inventory.validate_inventory(value)

    def test_unresolved_exactness_cannot_be_promoted(self):
        value, _ = self.evidence_fixture()
        value['unresolved'] = [{'kind': 'missing', 'subject': 'dep', 'detail': 'No selected version', 'blocksExact': True}]
        value['summary']['exactInventoryComplete'] = False
        inventory.validate_inventory(value)
        with self.assertRaises(inventory.InventoryError):
            inventory.validate_inventory(value, require_exact=True)

    def test_summary_cannot_hide_unresolved_field(self):
        value, _ = self.evidence_fixture()
        value['unresolved'] = [{'blocksExact': True}]
        with self.assertRaises(inventory.InventoryError):
            inventory.validate_inventory(value)

    def test_scoped_npm_purl_encodes_scope_and_version(self):
        component = {'ecosystem': 'npm', 'name': '@scope/pkg', 'version': '1.0.0+build', 'source': {}}
        self.assertEqual(inventory.component_purl(component), 'pkg:npm/%40scope/pkg@1.0.0%2Bbuild')

    def test_sbom_preserves_integrity_basis_without_binary_hash_claim(self):
        value, _ = self.evidence_fixture()
        value['components'][0]['integrities'] = [{'algorithm': 'sha256', 'value': 'a' * 64, 'basis': 'declared archive'}]
        sbom = inventory.cyclonedx(value)
        self.assertNotIn('hashes', sbom['components'][0])
        properties = {p['name']: p['value'] for p in sbom['components'][0]['properties']}
        self.assertIn('declared archive', properties['africlub:integrity-bases'])


if __name__ == '__main__':
    unittest.main()
