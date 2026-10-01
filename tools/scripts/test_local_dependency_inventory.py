"""Regressions for actual lock/evidence boundaries, without registry or SDK access."""
import base64
import copy
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
import zipfile

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

    def test_esm_build_target_query_is_preserved_but_token_is_rejected(self):
        value = 'https://esm.sh/pkg@1.0.0?target=denonext'
        self.assertEqual(inventory.safe_url(value), value)
        with self.assertRaises(inventory.InventoryError):
            inventory.safe_url(value + '&token=secret')

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

    def local_dart_fixture(self):
        upstream = self.root / 'pub-cache/hosted/pub.dev/dep-1.2.3'
        vendor = self.root / 'vendor/dep'
        for directory in (upstream, vendor):
            if directory.exists(): shutil.rmtree(directory)
        published = {'name': 'dep', 'version': '1.2.3', 'resolution': 'workspace',
                     'repository': 'https://example.test/dep', 'dependencies': {}}
        self.write('pub-cache/hosted/pub.dev/dep-1.2.3/pubspec.yaml', published)
        self.write('pub-cache/hosted/pub.dev/dep-1.2.3/LICENSE', 'Original package license text')
        self.write('pub-cache/hosted/pub.dev/dep-1.2.3/lib/client.dart', 'void applyReply() {}\n')
        shutil.copytree(upstream, vendor)
        self.write('vendor/dep/UPSTREAM_PUBSPEC.yaml', (upstream / 'pubspec.yaml').read_text())
        self.write('vendor/dep/pubspec.yaml', {k: v for k, v in published.items() if k != 'resolution'})
        self.write('vendor/dep/lib/client.dart', 'void applyReply() { checkGeneration(); }\n')
        originals = inventory.regular_package_manifest(upstream)
        self.write('vendor/dep/UPSTREAM_PROVENANCE.json', {
            'schemaVersion': 1, 'upstreamPackage': 'dep', 'upstreamVersion': '1.2.3',
            'upstreamRepository': published['repository'], 'sourceAbsolutePath': str(upstream),
            'files': originals, 'fileCount': len(originals), 'copyHashCoverage': len(originals),
            'localPatchFiles': ['lib/client.dart', 'pubspec.yaml'], 'license': 'declared original text',
        })
        self.write('pubspec.yaml', {'name': 'app', 'version': '0.1.0', 'workspace': [],
                                   'dependencies': {'dep': '^1.2.3'}, 'dependency_overrides': {'dep': {'path': 'vendor/dep'}}})
        self.write('pubspec.lock', {'packages': {'dep': {'version': '1.2.3', 'source': 'path',
            'description': {'path': 'vendor/dep', 'relative': True}, 'dependency': 'direct overridden'}}})
        sdk = self.root / 'sdk'
        self.write('sdk/bin/cache/flutter.version.json', {'frameworkVersion': '3.44.9', 'frameworkRevision': 'a' * 40, 'engineRevision': 'b' * 40})
        self.write('sdk/LICENSE', 'Flutter-only SDK license')
        self.write('.fvmrc', {'flutter': '3.44.9'})
        self.write('.dart_tool/package_config.json', {'flutterRoot': sdk.as_uri(), 'packages': [
            {'name': 'app', 'rootUri': '../', 'packageUri': 'lib/'},
            {'name': 'dep', 'rootUri': '../vendor/dep', 'packageUri': 'lib/'},
        ]})
        self.refresh_local_dart_manifest()
        return vendor, upstream

    def refresh_local_dart_manifest(self):
        vendor = self.root / 'vendor/dep'
        upstream = inventory.load_json(vendor / 'UPSTREAM_PROVENANCE.json')
        old_files = {f['path']: f for f in upstream['files']}
        files = inventory.regular_package_manifest(vendor, ('LOCAL_PATCH_MANIFEST.json',))
        for record in files:
            original = old_files.get('pubspec.yaml' if record['path'] == 'UPSTREAM_PUBSPEC.yaml' else record['path'])
            record['upstreamSha256'] = original['sha256'] if original else None
            record['matchesUpstream'] = record['sha256'] == original['sha256'] if original else None
        self.write('vendor/dep/LOCAL_PATCH_MANIFEST.json', {
            'schemaVersion': 1, 'sourceType': 'local_path_patch', 'package': 'dep', 'version': '1.2.3',
            'vendorPath': 'vendor/dep', 'fileCount': len(files), 'files': files,
            'upstreamProvenance': {'path': 'UPSTREAM_PROVENANCE.json', 'sha256': inventory.digest_file(vendor / 'UPSTREAM_PROVENANCE.json')},
            'upstreamPubspec': {'path': 'UPSTREAM_PUBSPEC.yaml', 'sha256': inventory.digest_file(vendor / 'UPSTREAM_PUBSPEC.yaml')},
            'license': {'path': 'LICENSE', 'sha256': inventory.digest_file(vendor / 'LICENSE')},
            'rootOverride': {'path': 'pubspec.yaml', 'sha256': inventory.digest_file(self.root / 'pubspec.yaml'),
                             'package': 'dep', 'declaredPath': 'vendor/dep'},
            'packageConfig': {'path': '.dart_tool/package_config.json', 'sha256': inventory.digest_file(self.root / '.dart_tool/package_config.json'),
                              'name': 'dep', 'canonicalSelection': 'vendor/dep'},
        })

    def read_local_dart(self):
        observed = inventory.Inventory(self.root, pub_cache=self.root / 'pub-cache')
        observed.read_dart()
        return observed, observed.dart_by_name['dep']

    def test_local_dart_patch_has_complete_content_identity_and_own_license(self):
        vendor, _ = self.local_dart_fixture()
        observed, package = self.read_local_dart()
        self.assertEqual(package['source']['kind'], 'path')
        self.assertEqual(package['source']['path'], 'vendor/dep')
        self.assertEqual(package['licenseEvidence'], ['vendor/dep/LICENSE'])
        self.assertNotIn('sdk/LICENSE', package['licenseEvidence'])
        self.assertTrue(all(record['algorithm'] == 'sha256' for record in package['integrities']))
        self.assertIn('not upstream hosted archive', package['integrities'][0]['basis'])
        self.assertFalse(package['localSourceProvenance']['upstreamArchiveByteEqualityClaimed'])
        self.assertEqual(package['localSourceProvenance']['changedUpstreamFiles'], ['lib/client.dart', 'pubspec.yaml'])
        self.assertEqual(package['localSourceProvenance']['regularFileCount'], 5)
        self.assertEqual(package['source']['patchManifestSha256'], inventory.digest_file(vendor / 'LOCAL_PATCH_MANIFEST.json'))
        self.assertIn(('vendor/dep/lib/client.dart'), package['evidence'])
        self.assertIsNone(inventory.component_purl(package))
        exported = inventory.cyclonedx({'components': [package], 'edges': [], 'summary': {'exactInventoryComplete': True}, 'scope': 'fixture', 'unresolved': [], 'licenseApproval': 'not assessed'})
        self.assertNotIn('purl', exported['components'][0])
        self.assertTrue(any(p['name'] == 'africlub:local-source-provenance' for p in exported['components'][0]['properties']))
        self.assertFalse(any(g['blocksExact'] for g in observed.gaps.values()))

    def test_local_dart_path_escape_noncanonical_and_directory_links_rejected(self):
        for declared, relative in [('../outside', True), ('vendor//dep', True), ('vendor/./dep', True), (str(self.root.parent / 'outside'), False), ('vendor/dep', False), ('vendor/dep', 1)]:
            with self.subTest(path=declared, relative=relative):
                self.local_dart_fixture()
                lock = inventory.load_yaml(self.root / 'pubspec.lock')
                lock['packages']['dep']['description'] = {'path': declared, 'relative': relative}
                self.write('pubspec.lock', lock)
                with self.assertRaises(inventory.InventoryError): self.read_local_dart()
        vendor, _ = self.local_dart_fixture()
        moved = self.root / 'elsewhere'; vendor.rename(moved); vendor.symlink_to(moved, target_is_directory=True)
        with self.assertRaises(inventory.InventoryError): self.read_local_dart()

    def test_local_dart_override_and_active_config_must_select_exact_source(self):
        for change in ('override', 'config', 'config-query', 'config-link'):
            with self.subTest(change=change):
                self.local_dart_fixture()
                if change == 'override':
                    self.write('pubspec.yaml', {'name': 'app', 'version': '0.1.0', 'workspace': []})
                else:
                    config = inventory.load_json(self.root / '.dart_tool/package_config.json')
                    config['packages'][1]['rootUri'] = {'config': '../other', 'config-query': '../vendor/dep?token=hidden', 'config-link': '../alias'}[change]
                    if change == 'config-link': (self.root / 'alias').symlink_to(self.root / 'vendor/dep', target_is_directory=True)
                    self.write('.dart_tool/package_config.json', config)
                with self.assertRaises(inventory.InventoryError): self.read_local_dart()

    def test_local_dart_changed_file_unrecorded_file_link_and_special_rejected(self):
        for change in ('changed', 'extra', 'link', 'special'):
            with self.subTest(change=change):
                vendor, _ = self.local_dart_fixture()
                if change == 'changed': (vendor / 'lib/client.dart').write_text('unrecorded patch')
                elif change == 'extra': (vendor / 'extra.dart').write_text('unrecorded source')
                elif change == 'link': (vendor / 'link.dart').symlink_to(vendor / 'lib/client.dart')
                else: os.mkfifo(vendor / 'special')
                with self.assertRaises(inventory.InventoryError): self.read_local_dart()

    def test_local_dart_manifest_duplicate_omitted_unsafe_and_false_original_rejected(self):
        for change in ('duplicate', 'omitted', 'unsafe', 'false-original', 'wrong-binding'):
            with self.subTest(change=change):
                vendor, _ = self.local_dart_fixture()
                manifest = inventory.load_json(vendor / 'LOCAL_PATCH_MANIFEST.json')
                if change == 'duplicate': manifest['files'].append(manifest['files'][0]); manifest['fileCount'] += 1
                elif change == 'omitted': manifest['files'].pop(); manifest['fileCount'] -= 1
                elif change == 'unsafe': manifest['files'][0]['path'] = '../outside'
                elif change == 'false-original': next(f for f in manifest['files'] if f['path'] == 'lib/client.dart')['matchesUpstream'] = True
                else: manifest['rootOverride']['sha256'] = '0' * 64
                self.write('vendor/dep/LOCAL_PATCH_MANIFEST.json', manifest)
                with self.assertRaises(inventory.InventoryError): self.read_local_dart()

    def test_local_dart_version_runtime_dependencies_license_and_original_bytes_rejected(self):
        for change in ('version', 'dependencies', 'license', 'upstream', 'upstream-pubspec'):
            with self.subTest(change=change):
                vendor, upstream = self.local_dart_fixture()
                if change in ('version', 'dependencies'):
                    pub = inventory.load_yaml(vendor / 'pubspec.yaml')
                    if change == 'version': pub['version'] = '1.2.4'
                    else: pub['dependencies'] = {'new_runtime_package': '^1.0.0'}
                    self.write('vendor/dep/pubspec.yaml', pub)
                elif change == 'license': (vendor / 'LICENSE').write_text('replaced license')
                elif change == 'upstream': (upstream / 'lib/client.dart').write_text('changed original cache')
                else: (vendor / 'UPSTREAM_PUBSPEC.yaml').write_text('name: forged\n')
                self.refresh_local_dart_manifest()
                with self.assertRaises(inventory.InventoryError): self.read_local_dart()

    def test_local_dart_upstream_patch_declaration_and_repository_rejected(self):
        for change in ('undeclared-patch', 'forged-upstream', 'credential-url', 'missing-provenance'):
            with self.subTest(change=change):
                vendor, _ = self.local_dart_fixture()
                path = vendor / 'UPSTREAM_PROVENANCE.json'
                upstream = inventory.load_json(path)
                if change == 'undeclared-patch': upstream['localPatchFiles'] = ['pubspec.yaml']
                elif change == 'forged-upstream': upstream['files'][0]['sha256'] = '0' * 64
                elif change == 'credential-url': upstream['upstreamRepository'] = 'https://user:hidden@example.test/dep'
                else:
                    path.unlink()
                    with self.assertRaises(inventory.InventoryError): self.read_local_dart()
                    continue
                self.write('vendor/dep/UPSTREAM_PROVENANCE.json', upstream)
                self.refresh_local_dart_manifest()
                with self.assertRaises(inventory.InventoryError) as context: self.read_local_dart()
                self.assertNotIn('hidden', str(context.exception))

    def test_local_dart_absolute_locked_selection_keeps_portable_source_identity(self):
        vendor, _ = self.local_dart_fixture()
        lock = inventory.load_yaml(self.root / 'pubspec.lock')
        lock['packages']['dep']['description'] = {'path': str(vendor), 'relative': False}
        self.write('pubspec.lock', lock)
        _, package = self.read_local_dart()
        self.assertEqual(package['source']['path'], 'vendor/dep')

    def test_local_dart_resealed_patch_changes_source_identity_without_version_change(self):
        vendor, _ = self.local_dart_fixture()
        _, before = self.read_local_dart()
        (vendor / 'lib/client.dart').write_text('void applyReply() { checkNewGeneration(); }\n')
        self.refresh_local_dart_manifest()
        _, after = self.read_local_dart()
        self.assertEqual(before['version'], after['version'])
        self.assertEqual(before['licenseEvidence'], after['licenseEvidence'])
        self.assertNotEqual(before['source']['contentSha256'], after['source']['contentSha256'])
        self.assertNotEqual(before['ref'], after['ref'])

    def test_local_dart_full_validation_rejects_post_inventory_vendor_drift(self):
        vendor, _ = self.local_dart_fixture()
        observed, _ = self.read_local_dart()
        value = {'schemaVersion': 1, 'repositoryRoot': str(self.root),
                 'components': list(observed.components.values()), 'edges': [],
                 'evidence': observed.evidence, 'unresolved': [],
                 'summary': {'components': len(observed.components), 'exactInventoryComplete': True}}
        inventory.validate_inventory(value)
        (vendor / 'lib/client.dart').write_text('reply guard removed after inventory')
        with self.assertRaises(inventory.InventoryError): inventory.validate_inventory(value)

    def test_local_dart_change_during_file_attribution_rejects_observation(self):
        vendor, _ = self.local_dart_fixture()

        class ConcurrentSourceChange(inventory.Inventory):
            def file_evidence(self, path, role):
                if Path(path) == vendor / 'lib/client.dart':
                    Path(path).write_text('changed while observing the source')
                return super().file_evidence(path, role)

        with self.assertRaises(inventory.InventoryError):
            ConcurrentSourceChange(self.root, pub_cache=self.root / 'pub-cache').read_dart()

    def test_portable_skips_only_confirmed_ignored_generated_pub_and_plugin_inputs(self):
        value, _ = self.evidence_fixture()
        subprocess.run(['git', 'init', '--quiet', str(self.root)], check=True)
        self.write('.gitignore', '.dart_tool/package_config.json\napps/*/.flutter-plugins-dependencies\n')
        observer = inventory.Inventory(self.root)
        for path, role in [('.dart_tool/package_config.json', 'dart-active-resolution'),
                           ('apps/rayon_sports/.flutter-plugins-dependencies', 'native-resolution-source-input')]:
            source = self.write(path, 'generated machine paths')
            key = observer.file_evidence(source, role)
            value['evidence'].update(observer.evidence)
            source.unlink()
        inventory.validate_inventory(value, repository_only=True)
        with self.assertRaises((inventory.InventoryError, OSError)): inventory.validate_inventory(value)
        for path in ('.dart_tool/package_config.json', 'apps/rayon_sports/.flutter-plugins-dependencies'):
            self.write(path, 'different machine paths')
        inventory.validate_inventory(value, repository_only=True)
        with self.assertRaises(inventory.InventoryError): inventory.validate_inventory(value)

    def test_portable_does_not_skip_tracked_config_or_arbitrary_dart_tool_source(self):
        for path, role, tracked in [('.dart_tool/package_config.json', 'dart-active-resolution', True),
                                    ('vendor/dep/.dart_tool/source.dart', 'local-dart-patched-source', False),
                                    ('.dart_tool/package_config.json', 'local-dart-patched-source', False)]:
            with self.subTest(path=path, tracked=tracked):
                value, _ = self.evidence_fixture()
                subprocess.run(['git', 'init', '--quiet', str(self.root)], check=True)
                self.write('.gitignore', '.dart_tool/\nvendor/dep/.dart_tool/\n')
                source = self.write(path, 'bound source')
                if tracked: subprocess.run(['git', '-C', str(self.root), 'add', '--force', '--', path], check=True)
                observer = inventory.Inventory(self.root)
                observer.file_evidence(source, role)
                value['evidence'].update(observer.evidence)
                source.write_text('changed source')
                for portable in (False, True):
                    with self.assertRaises(inventory.InventoryError): inventory.validate_inventory(value, repository_only=portable)

    def test_portable_and_full_reject_tracked_override_and_vendor_source_drift(self):
        vendor, _ = self.local_dart_fixture()
        subprocess.run(['git', 'init', '--quiet', str(self.root)], check=True)
        self.write('.gitignore', '.dart_tool/\n')
        observed, _ = self.read_local_dart()
        value = {'schemaVersion': 1, 'repositoryRoot': str(self.root),
                 'components': list(observed.components.values()), 'edges': [],
                 'evidence': observed.evidence, 'unresolved': [],
                 'summary': {'components': len(observed.components), 'exactInventoryComplete': True}}
        for source in (self.root / 'pubspec.yaml', vendor / 'lib/client.dart', vendor / 'UPSTREAM_PROVENANCE.json', vendor / 'LICENSE'):
            saved = source.read_bytes()
            source.write_bytes(b'changed source')
            for portable in (False, True):
                with self.assertRaises(inventory.InventoryError): inventory.validate_inventory(value, repository_only=portable)
            source.write_bytes(saved)

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

    def test_summary_cannot_forge_license_edge_or_evidence_coverage(self):
        for key in ('componentsWithLicenseText', 'dependencyEdges', 'evidenceItems', 'unresolvedFields'):
            value, _ = self.evidence_fixture()
            value['summary'][key] = 99
            with self.subTest(key=key), self.assertRaises(inventory.InventoryError):
                inventory.validate_inventory(value)

    def test_repository_only_validation_relocates_committed_inputs(self):
        value, _ = self.evidence_fixture()
        value['repositoryRoot'] = '/different/author/machine'
        inventory.validate_inventory(value, root_override=self.root, repository_only=True)

    def test_repository_only_validation_does_not_claim_cache_verification(self):
        value, _ = self.evidence_fixture()
        value['evidence']['outside'] = {'kind': 'file', 'path': '/not/on/this/machine', 'bytes': 1, 'sha256': 'a' * 64, 'roles': ['cache']}
        inventory.validate_inventory(value, repository_only=True)
        with self.assertRaises(OSError):
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

    def bounded_fixture(self):
        value = {'schemaVersion': 1, 'components': [{'name': 'pkg\tnewline\n', 'id': i} for i in range(8)],
                 'evidence': {'source-' + str(i): {'sha256': str(i)} for i in range(8)}}
        path = self.root / 'report.json'
        inventory.write_bounded_report(value, path, [['components'], ['evidence']], max_bytes=150)
        return value, path, inventory.load_json(path)

    def test_bounded_tables_preserve_all_rows_and_escaped_values(self):
        value, path, index = self.bounded_fixture()
        self.assertEqual(inventory.load_report(path), value)
        self.assertGreater(len(index['payloadTables']['tables'][0]['shards']), 1)
        self.assertTrue(all(s['bytes'] <= 150 for t in index['payloadTables']['tables'] for s in t['shards']))

    def test_bounded_shard_corruption_is_rejected(self):
        _, path, index = self.bounded_fixture()
        shard = self.root / index['payloadTables']['tables'][0]['shards'][0]['path']
        shard.write_bytes(shard.read_bytes().replace(b'pkg', b'BAD'))
        with self.assertRaises(inventory.InventoryError):
            inventory.load_report(path)

    def test_bounded_missing_row_shard_or_table_is_rejected(self):
        for mutation in ('rows', 'missing', 'table-hash', 'repeated-shard'):
            _, path, index = self.bounded_fixture()
            table = index['payloadTables']['tables'][0]
            if mutation == 'rows':
                table['rows'] -= 1
            elif mutation == 'missing':
                table['shards'].pop()
            elif mutation == 'table-hash':
                table['sha256'] = '0' * 64
            else:
                table['shards'].append(table['shards'][0])
            path.write_text(json.dumps(index))
            with self.subTest(mutation=mutation), self.assertRaises(inventory.InventoryError):
                inventory.load_report(path)

    def test_bounded_shard_escape_and_symlink_are_rejected(self):
        _, path, index = self.bounded_fixture()
        shard = index['payloadTables']['tables'][0]['shards'][0]
        original = shard['path']; shard['path'] = '../outside.tsv'
        path.write_text(json.dumps(index))
        with self.assertRaises(inventory.InventoryError):
            inventory.load_report(path)
        shard['path'] = original; path.write_text(json.dumps(index))
        target = self.root / original
        outside = self.write('outside.tsv', target.read_text())
        target.unlink(); target.symlink_to(outside)
        with self.assertRaises(inventory.InventoryError):
            inventory.load_report(path)

    def test_bounded_nested_android_target_tables_roundtrip(self):
        value = {'targets': {'app': {'offline': True, 'configurations': [{'name': 'debug', 'components': []}]}}}
        path = self.root / 'android.json'
        inventory.write_bounded_report(value, path, [['targets', 'app', 'configurations']])
        self.assertEqual(inventory.load_report(path), value)

    def test_report_export_binds_android_snapshot_to_inventory_coverage(self):
        value, _ = self.evidence_fixture()
        value['components'][0]['occurrences'] = []
        value['summary'].update(byEcosystem={'npm': 1}, evidenceItems=1, dependencyEdges=0,
                                componentsWithLicenseText=0, componentsWithLicenseDeclaration=0)
        value['unresolved'] = []
        snapshot = {'offline': True, 'configurations': [{'configuration': 'debug', 'components': []}]}
        path = self.write('resolution.json', snapshot)
        value['coverage'] = {'android': {'app': {'resolution': path.name}}}
        inventory.write_reports(value, self.root / 'export')
        self.assertEqual(inventory.load_report(self.root / 'export.android.json')['targets']['app'], snapshot)

    def test_bounded_duplicate_table_and_inline_collision_are_rejected(self):
        _, path, index = self.bounded_fixture()
        index['payloadTables']['tables'].append(index['payloadTables']['tables'][0])
        path.write_text(json.dumps(index))
        with self.assertRaises(inventory.InventoryError):
            inventory.load_report(path)
        _, path, index = self.bounded_fixture()
        index['components'] = []
        path.write_text(json.dumps(index))
        with self.assertRaises(inventory.InventoryError):
            inventory.load_report(path)

    def test_bounded_oversize_row_is_rejected(self):
        with self.assertRaises(inventory.InventoryError):
            inventory.write_bounded_report({'items': ['x' * 200]}, self.root / 'report.json', [['items']], max_bytes=100)

    def license_fixture(self, ecosystem, name, version, source):
        value, _ = self.evidence_fixture()
        observed = inventory.Inventory(self.root)
        c = observed.component(ecosystem, name, version, source)
        c['evidence'] = list(value['evidence'])
        value['components'] = [c]
        value['unresolved'] = [{'kind': 'license-evidence-unavailable', 'subject': c['ref'], 'detail': 'Missing license', 'blocksExact': False}]
        return value, c

    def recover(self, value):
        return inventory.recover_local_license_evidence(value, self.root / 'npm', self.root / 'deno', self.root / 'maven')

    def test_cdn_license_recovery_binds_exact_upstream_version_and_keeps_transform_boundary(self):
        value, c = self.license_fixture('deno-remote', 'https://esm.sh/whatwg-url@5.0.0', '5.0.0', {'kind': 'http', 'url': 'https://esm.sh/whatwg-url@5.0.0'})
        self.write('deno/npm/registry.npmjs.org/whatwg-url/5.0.0/package.json', {'name': 'whatwg-url', 'version': '5.0.0', 'license': 'MIT'})
        self.write('deno/npm/registry.npmjs.org/whatwg-url/5.0.0/LICENSE.txt', 'Package license text')
        result = self.recover(value); observed = result['components'][0]
        self.assertEqual(observed['ref'], c['ref']); self.assertEqual(observed['version'], '5.0.0')
        self.assertEqual(result['licenseRecovery']['remainingGapCount'], 0)
        self.assertIn('not asserted identical', observed['licenseAssociations'][0]['basis'])
        self.assertEqual(len(observed['licenseEvidence']), 1)
        properties = inventory.cyclonedx(result)['components'][0]['properties']
        self.assertTrue(any(p['name'] == 'africlub:license-associations' for p in properties))

    def test_cdn_license_recovery_rejects_nearby_installed_versions(self):
        value, _ = self.license_fixture('deno-remote', 'https://esm.sh/whatwg-url@5.0.0', '5.0.0', {'kind': 'http', 'url': 'https://esm.sh/whatwg-url@5.0.0'})
        self.write('apps/rayon_sports/web/node_modules/whatwg-url/package.json', {'name': 'whatwg-url', 'version': '5.0.1', 'license': 'MIT'})
        result = self.recover(value)
        self.assertEqual(result['licenseRecovery']['remainingGapCount'], 1)

    def maven_license_fixture(self):
        value, c = self.license_fixture('maven', 'com.android:signflinger', '8.13.2', {'kind': 'gradle-module-cache'})
        jar = self.root / 'current.jar'
        with zipfile.ZipFile(jar, 'w') as archive: archive.writestr('Example.class', b'class body')
        observer = inventory.Inventory(self.root); key = observer.file_evidence(jar, 'selected-artifact')
        value['evidence'].update(observer.evidence); c['evidence'].append(key)
        self.write('maven/com.android/signflinger/8.5.2/content/signflinger-8.5.2.pom', '<project><groupId>com.android</groupId><artifactId>signflinger</artifactId><version>8.5.2</version><licenses><license><name>Apache-2.0</name></license></licenses></project>')
        sibling = self.root / 'maven/com.android/signflinger/8.5.2/content/signflinger-8.5.2.jar'; sibling.write_bytes(jar.read_bytes())
        return value, c, sibling

    def test_maven_license_recovery_requires_identical_actual_jar_bytes(self):
        value, c, sibling = self.maven_license_fixture()
        result = self.recover(value); association = result['components'][0]['licenseAssociations'][0]
        self.assertEqual(association['jarSha256'], inventory.digest_file(sibling))
        self.assertEqual(result['components'][0]['version'], c['version'])
        self.assertEqual(result['licenseRecovery']['remainingGapCount'], 0)
        with zipfile.ZipFile(sibling, 'w') as archive: archive.writestr('Example.class', b'different class body')
        result = self.recover(value)
        self.assertEqual(result['licenseRecovery']['remainingGapCount'], 1)

    def test_maven_license_recovery_rejects_corrupt_content_addressed_pom(self):
        value, _, sibling = self.maven_license_fixture()
        pom = sibling.with_suffix('.pom')
        bound = pom.parent.parent / hashlib.sha1(pom.read_bytes()).hexdigest() / pom.name
        bound.parent.mkdir(); bound.write_bytes(pom.read_bytes()); pom.unlink()
        bound.write_bytes(bound.read_bytes().replace(b'Apache-2.0', b'forged-license'))
        with self.assertRaises(inventory.InventoryError): self.recover(value)

    def test_embedded_pom_file_license_does_not_clear_whole_package_gap(self):
        value, c = self.license_fixture('maven', 'io.netty:classes', '1.0.0', {'kind': 'gradle-module-cache'})
        jar = self.root / 'current.jar'
        with zipfile.ZipFile(jar, 'w') as archive: archive.writestr('META-INF/maven/io.netty/classes/pom.xml', '<!-- licenses this file to you under the Apache License -->')
        observer = inventory.Inventory(self.root); key = observer.file_evidence(jar, 'selected-artifact')
        value['evidence'].update(observer.evidence); c['evidence'].append(key)
        result = self.recover(value)
        self.assertEqual(result['licenseRecovery']['remainingGapCount'], 1)
        self.assertFalse(result['components'][0]['licenseDeclarations'])
        self.assertIn('POM file only', result['licenseRecovery']['findings'][0]['partialEvidence'][0]['scope'])

    def test_registry_license_cache_integrity_and_exact_release_are_verified(self):
        value, _ = self.license_fixture('deno-remote', 'https://esm.sh/bufferutil@4.1.0', '4.1.0', {'kind': 'http', 'url': 'https://esm.sh/bufferutil@4.1.0'})
        body = json.dumps({'name': 'bufferutil', 'versions': {'4.1.0': {'name': 'bufferutil', 'version': '4.1.0', 'license': 'MIT'}}}).encode()
        digest = hashlib.sha512(body).hexdigest()
        file = self.root / 'npm/_cacache/content-v2/sha512' / digest[:2] / digest[2:4] / digest[4:]
        file.parent.mkdir(parents=True); file.write_bytes(body)
        sri = 'sha512-' + base64.b64encode(hashlib.sha512(body).digest()).decode()
        self.write('npm/_cacache/index-v5/a/b/index', 'index-hash\t' + json.dumps({'key': 'make-fetch-happen:request-cache:https://registry.npmjs.org/bufferutil', 'integrity': sri}) + '\n')
        result = self.recover(value)
        self.assertEqual(result['licenseRecovery']['remainingGapCount'], 0)
        self.assertEqual(result['licenseRecovery']['networkRequests'], 0)
        file.write_bytes(b'corrupt registry body')
        with self.assertRaises(inventory.InventoryError): self.recover(value)


if __name__ == '__main__':
    unittest.main()
