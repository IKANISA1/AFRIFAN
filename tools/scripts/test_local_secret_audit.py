import base64
import gzip
import io
import json
from pathlib import Path
import stat
import subprocess
import sys
import tarfile
import tempfile
import unittest
import zipfile

from local_secret_audit import Audit, Limits, classify, digest, run, source_open, report_destination


def token():
    return 'sk_'+'live_'+'SyntheticLocalAuditOnly1234567890'


def pem():
    return '-----BEGIN '+'PRIVATE KEY-----\n'+'A'*128+'\n-----END '+'PRIVATE KEY-----'


def jwt(role):
    encode = lambda obj: base64.urlsafe_b64encode(json.dumps(obj).encode()).decode().rstrip('=')
    return encode({'alg': 'HS256'})+'.'+encode({'role': role, 'testOnly': True})+'.'+'synthetic_not_signed_value'


def zip_data(entries):
    out = io.BytesIO()
    with zipfile.ZipFile(out, 'w', compression=zipfile.ZIP_DEFLATED) as archive:
        for name, data in entries:
            archive.writestr(name, data)
    return out.getvalue()


class LocalSecretAuditTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name).resolve()

    def audit(self, data, name='source.txt', limits=None):
        audit = Audit(limits)
        audit.content(data if isinstance(data, bytes) else data.encode(), name)
        return audit.report()

    def assert_private_absent(self, report, *values):
        raw = json.dumps(report)
        for value in values:
            self.assertNotIn(value, raw)
        self.assertFalse(report['matchedValuesIncluded'])

    def test_normal_source(self):
        result = self.audit('export const safe = 1;')
        self.assertTrue(result['passed'])
        self.assertTrue(result['coverageComplete'])

    def test_private_key_values_never_reported(self):
        result = self.audit(pem())
        self.assertFalse(result['passed'])
        self.assertEqual(result['contentFindings'][0]['category'], 'private_key_material')
        self.assert_private_absent(result, pem(), 'A'*128)

    def test_escaped_private_key(self):
        result = self.audit(json.dumps({'private_key': pem()}))
        self.assertFalse(result['passed'])
        self.assert_private_absent(result, 'A'*128)

    def test_parser_markers_without_material_pass(self):
        markers = '"-----BEGIN '+'PRIVATE KEY-----";"-----END '+'PRIVATE KEY-----"'
        self.assertTrue(self.audit(markers)['passed'])

    def test_high_confidence_token(self):
        result = self.audit('const value = "'+token()+'";')
        self.assertFalse(result['passed'])
        self.assert_private_absent(result, token())

    def test_binary_embedded_text_is_not_skipped(self):
        result = self.audit(b'\x00\xff\x80'+token().encode()+b'\x00')
        self.assertFalse(result['passed'])
        self.assertEqual(result['contents'][0]['type'], 'binary')
        self.assert_private_absent(result, token())

    def test_both_utf16_orders_and_offsets(self):
        for encoding in ('utf-16-le', 'utf-16-be'):
            for prefix in (b'\x00\x01', b'\x00\x01\x02'):
                with self.subTest(encoding=encoding, prefix_bytes=len(prefix)):
                    result = self.audit(prefix+token().encode(encoding))
                    self.assertFalse(result['passed'])
                    self.assert_private_absent(result, token())

    def test_privileged_jwt_is_not_exempt_by_testonly_claim(self):
        value = jwt('service_role')
        result = self.audit(value, 'test/synthetic_fixture.txt')
        self.assertFalse(result['passed'])
        self.assertIn('privileged_backend_token', [r['category'] for r in result['contentFindings']])
        self.assert_private_absent(result, value)

    def test_public_anonymous_jwt_classified(self):
        value = jwt('anon')
        result = self.audit(value)
        self.assertTrue(result['passed'])
        self.assertEqual(result['contents'][0]['classifications'], ['public_anonymous_client_token'])
        self.assert_private_absent(result, value)

    def test_other_bearer_jwt_requires_review(self):
        self.assertFalse(self.audit(jwt('authenticated'))['passed'])

    def test_google_client_key_is_separate_classification(self):
        value = 'AIza'+'B'*35
        result = self.audit(value)
        self.assertTrue(result['passed'])
        self.assertEqual(result['contents'][0]['classifications'], ['public_google_client_key_requires_provider_restrictions'])
        self.assert_private_absent(result, value)

    def test_unprefixed_private_assignment(self):
        value = '0123456789abcdef'*4
        self.assertFalse(self.audit('AUTH_HMAC_KEY="'+value+'"')['passed'])

    def test_configuration_placeholder_not_secret(self):
        self.assertTrue(self.audit('client_secret="REPLACE_WITH_REVIEWED_SECRET_MATERIAL"')['passed'])

    def test_service_account_private_key(self):
        result = self.audit(json.dumps({'type': 'service_account', 'private_key': 'synthetic'}))
        self.assertFalse(result['passed'])

    def test_zip_contents_and_nested_gzip_scanned(self):
        result = self.audit(zip_data([('nested.gz', gzip.compress(token().encode()))]), 'artifact.zip')
        self.assertFalse(result['passed'])
        self.assertTrue(result['coverageComplete'])
        self.assertEqual(result['summary']['archiveMembers'], 2)
        self.assert_private_absent(result, token())

    def test_member_traversal_never_extracted(self):
        for name in ('../outside.txt', '/outside', 'C:/outside', 'x\\outside', './outside', 'x/../outside'):
            with self.subTest(name=name):
                result = self.audit(zip_data([(name, token())]), 'artifact.zip')
                self.assertFalse(result['coverageComplete'])
                self.assertFalse((self.root/'outside.txt').exists())
                self.assert_private_absent(result, token())

    def test_secret_in_member_name_is_redacted(self):
        result = self.audit(zip_data([(token()+'.txt', 'normal')]), 'artifact.zip')
        self.assert_private_absent(result, token())
        self.assertIn('[redacted]', result['archiveMembers'][0]['path'])

    def test_private_key_in_member_name_is_redacted(self):
        result = self.audit(zip_data([(pem(), 'normal')]), 'artifact.zip')
        self.assert_private_absent(result, pem(), 'A'*128)

    def test_duplicate_archive_paths_fail_coverage(self):
        import warnings
        with warnings.catch_warnings():
            warnings.simplefilter('ignore')
            data = zip_data([('same.txt', 'first'), ('same.txt', 'second')])
        self.assertFalse(self.audit(data, 'artifact.zip')['coverageComplete'])

    def test_zip_symlink_fails_without_reading_target(self):
        out = io.BytesIO()
        with zipfile.ZipFile(out, 'w') as archive:
            info = zipfile.ZipInfo('link'); info.create_system = 3
            info.external_attr = (stat.S_IFLNK | 0o777) << 16
            archive.writestr(info, '../private')
        result = self.audit(out.getvalue(), 'artifact.zip')
        self.assertFalse(result['coverageComplete'])

    def test_tar_link_and_embedded_file(self):
        out = io.BytesIO()
        with tarfile.open(fileobj=out, mode='w') as archive:
            info = tarfile.TarInfo('file.txt'); data = token().encode(); info.size = len(data)
            archive.addfile(info, io.BytesIO(data))
            link = tarfile.TarInfo('link'); link.type = tarfile.SYMTYPE; link.linkname = '../outside'
            archive.addfile(link)
        result = self.audit(out.getvalue(), 'source.tar')
        self.assertFalse(result['passed'])
        self.assertFalse(result['coverageComplete'])
        self.assert_private_absent(result, token())

    def test_unsupported_extension_cannot_hide_in_content_cache(self):
        audit = Audit(); audit.content(b'normal', 'normal.txt'); audit.content(b'normal', 'archive.7z')
        self.assertFalse(audit.report()['coverageComplete'])

    def test_unsupported_magic_cannot_hide_behind_extension(self):
        self.assertFalse(self.audit(b'7z\xbc\xaf\x27\x1cembedded', 'source.bin')['coverageComplete'])

    def test_encrypted_zip_member_fails_coverage(self):
        data = bytearray(zip_data([('member', 'private')]))
        local = data.index(b'PK\x03\x04'); central = data.index(b'PK\x01\x02')
        data[local+6] |= 1; data[central+8] |= 1
        self.assertFalse(self.audit(bytes(data), 'artifact.zip')['coverageComplete'])

    def test_source_changes_after_read_fail_coverage(self):
        (self.root/'source').write_text('before')
        audit = Audit(); audit.source(self.root, ['source'])
        (self.root/'source').write_text('after')
        audit.verify_source_states(self.root)
        self.assertFalse(audit.report()['coverageComplete'])

    def test_corrupt_archive_fails_coverage(self):
        self.assertFalse(self.audit(b'PK\x03\x04corrupt', 'artifact.zip')['coverageComplete'])

    def test_member_bomb_and_budget_fail_closed(self):
        limits = Limits(max_member_bytes=16)
        result = self.audit(zip_data([('large', b'A'*10000)]), 'artifact.zip', limits)
        self.assertFalse(result['coverageComplete'])
        limits = Limits(max_expanded_bytes=16)
        self.assertFalse(self.audit(zip_data([('a', b'A'*10), ('b', b'B'*10)]), 'artifact.zip', limits)['coverageComplete'])

    def test_member_count_and_depth_bounds(self):
        self.assertFalse(self.audit(zip_data([('a', 'a'), ('b', 'b')]), 'artifact.zip', Limits(max_members=1))['coverageComplete'])
        inner = zip_data([('private', token())]); outer = zip_data([('inner.zip', inner)])
        self.assertFalse(self.audit(outer, 'outer.zip', Limits(max_depth=1))['coverageComplete'])

    def test_source_and_parent_symlink_rejected(self):
        (self.root/'target').mkdir(); (self.root/'target/source.txt').write_text(token())
        (self.root/'linked').symlink_to(self.root/'target', target_is_directory=True)
        audit = Audit(); audit.source(self.root, ['linked/source.txt'])
        self.assertFalse(audit.report()['coverageComplete'])
        with self.assertRaises(OSError):
            source_open(self.root, 'linked/source.txt')

    def test_private_path_oversize_deleted_states(self):
        (self.root/'.env').write_text('not-secret')
        (self.root/'oversize').write_bytes(b'A'*100)
        audit = Audit(Limits(max_blob_bytes=16)); audit.source(self.root, ['.env', 'oversize', 'deleted'])
        result = audit.report(); self.assertFalse(result['passed']); self.assertFalse(result['coverageComplete'])
        self.assertIn('deleted_worktree_path', [r['type'] for r in result['occurrences']])

    def test_sealed_expected_hash_required_and_verified(self):
        path = self.root/'candidate.zip'; data = zip_data([('normal', 'safe')]); path.write_bytes(data)
        audit = Audit(); audit.sealed(path, digest(data)); self.assertTrue(audit.report()['passed'])
        audit = Audit(); audit.sealed(path, '0'*64); self.assertFalse(audit.report()['coverageComplete'])

    def git(self, *args):
        return subprocess.run(['git', *args], cwd=self.root, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True).stdout

    def test_actual_git_history_untracked_and_ignored_scope(self):
        self.git('init', '-q'); self.git('config', 'user.name', 'Synthetic Test'); self.git('config', 'user.email', 'test@example.invalid')
        (self.root/'old.txt').write_text(token()); self.git('add', 'old.txt'); self.git('commit', '-qm', 'synthetic initial')
        self.git('rm', '-q', 'old.txt'); (self.root/'.gitignore').write_text('ignored.txt\n')
        self.git('add', '.gitignore'); self.git('commit', '-qm', 'synthetic removal')
        (self.root/'untracked.txt').write_text(pem()); (self.root/'ignored.txt').write_text('ignored workstation content')
        archive = self.root/'candidate.zip'; archive.write_bytes(zip_data([('member', 'normal')]))
        result = run(self.root, [(archive, digest(archive.read_bytes()))])
        self.assertTrue(result['coverageComplete']); self.assertFalse(result['passed'])
        self.assertGreaterEqual(result['summary']['reachableGitBlobs'], 2)
        self.assertIn('untracked.txt', [r['path'] for r in result['occurrences'] if r['scope']=='active_source'])
        self.assertNotIn('ignored.txt', [r['path'] for r in result['occurrences']])
        self.assert_private_absent(result, token(), pem())

    def test_cli_invalid_argument_redacted(self):
        script = Path(__file__).with_name('local_secret_audit.py')
        result = subprocess.run([sys.executable, str(script), '--max-members', token()], capture_output=True)
        self.assertEqual(result.returncode, 2)
        self.assertNotIn(token().encode(), result.stdout+result.stderr)

    def test_report_cannot_overwrite_source_or_candidate(self):
        self.git('init', '-q')
        (self.root/'source.txt').write_text('preserve')
        (self.root/'.gitignore').write_text('output/\n')
        candidate = self.root/'output/candidate.zip'
        with self.assertRaises(ValueError):
            report_destination(self.root, self.root/'source.txt', [])
        with self.assertRaises(ValueError):
            report_destination(self.root, candidate, [(candidate, 'a'*64)])
        with self.assertRaises(ValueError):
            report_destination(self.root, self.root/'.git/report.json', [])
        self.assertEqual(report_destination(self.root, self.root/'output/report.json', []), self.root/'output/report.json')
        self.assertEqual((self.root/'source.txt').read_text(), 'preserve')

    def test_report_symlink_and_unbounded_limits_rejected(self):
        (self.root/'target').write_text('preserve')
        (self.root/'report').symlink_to(self.root/'target')
        with self.assertRaises(ValueError):
            report_destination(self.root, self.root/'report', [])
        with self.assertRaises(ValueError):
            Audit(Limits(max_members=1000001))

    def test_scanner_source_is_not_a_secret_fixture(self):
        data = Path(__file__).with_name('local_secret_audit.py').read_bytes()
        self.assertTrue(self.audit(data, 'local_secret_audit.py')['passed'])

    def test_long_repeated_jwt_prefix_is_bounded(self):
        import time
        started = time.monotonic()
        self.assertTrue(self.audit('eyJ'*100000)['passed'])
        self.assertLess(time.monotonic()-started, 3)

    def test_oversized_bearer_encoding_does_not_pass(self):
        value = 'eyJ'+'A'*12+'.'+'B'*70000+'.'+'C'*20
        result = self.audit(value)
        self.assertFalse(result['passed'])
        self.assert_private_absent(result, value)


if __name__ == '__main__':
    unittest.main()
