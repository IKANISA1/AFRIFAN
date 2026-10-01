"""Actual archive admission and bounded private-asset retrieval regressions."""
import copy
import hashlib
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import tempfile
import unittest
from unittest.mock import patch

import provision_design_authority as authority


class AuthorityProvisionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.root = self.base / 'product'
        self.source = self.base / 'selected'
        (self.root / 'tools/scripts').mkdir(parents=True)
        (self.root / 'docs/governance').mkdir(parents=True)
        shutil.copyfile(authority.ROOT / 'tools/scripts/validate_design_authority.mjs', self.root / 'tools/scripts/validate_design_authority.mjs')
        self.names = json.loads(subprocess.check_output(['node', '--input-type=module', '-e',
            "import {requiredAuthorityFiles} from './tools/scripts/validate_design_authority.mjs'; console.log(JSON.stringify(requiredAuthorityFiles));"], cwd=self.root))
        for name in self.names:
            file = self.source / name
            file.parent.mkdir(parents=True, exist_ok=True)
            file.write_text('Synthetic selected reference ' + name)
        adapter = self.root / 'DESIGN.md'
        adapter.write_text('Synthetic product adapter')
        bound = [{'path': name, 'sha256': hashlib.sha256((self.source / name).read_bytes()).hexdigest()} for name in self.names]
        self.document = {'design_authority': {'skill': 'revolut-design', 'path': 'SKILL.md', 'bound_files': bound,
                                             'sha256': next(x['sha256'] for x in bound if x['path'] == 'SKILL.md')},
                         'product_adapter': {'path': 'DESIGN.md', 'sha256': hashlib.sha256(adapter.read_bytes()).hexdigest()}}
        self.register = self.root / 'docs/governance/design-exceptions.json'
        self.register.write_text(json.dumps(self.document))
        self.archive = self.base / 'authority.tar.gz'
        self.digest = authority.pack(self.root, self.source, self.archive)
        self.destination = self.base / 'fresh-runner' / 'authority'

    def altered_archive(self, change):
        stream = io.BytesIO()
        with tarfile.open(self.archive, 'r:gz') as source, tarfile.open(fileobj=stream, mode='w:gz') as target:
            for original in source:
                entry = copy.copy(original)
                data = source.extractfile(original).read()
                if original.name == 'SKILL.md' and change == 'changed':
                    data += b'unapproved revision'
                    entry.size = len(data)
                if original.name == 'SKILL.md' and change == 'link':
                    entry.type, entry.linkname, entry.size = tarfile.SYMTYPE, '../outside', 0
                if original.name == 'SKILL.md' and change == 'omitted':
                    continue
                if original.name == 'SKILL.md' and change == 'oversized':
                    entry.size = authority.LIMIT + 1
                    target.addfile(entry, io.BytesIO(b'x' * entry.size))
                    continue
                target.addfile(entry, io.BytesIO(data) if entry.isfile() else None)
            if change in ('duplicate', 'escape', 'image'):
                name = {'duplicate': 'SKILL.md', 'escape': '../outside', 'image': 'account-screenshot.png'}[change]
                entry = tarfile.TarInfo(name)
                entry.size = 4
                target.addfile(entry, io.BytesIO(b'fake'))
        self.archive.write_bytes(stream.getvalue())
        return hashlib.sha256(stream.getvalue()).hexdigest()

    def test_deterministic_archive_provisions_without_original_source_on_fresh_runner(self):
        other = self.base / 'second.tar.gz'
        self.assertEqual(authority.pack(self.root, self.source, other), self.digest)
        self.assertEqual(other.read_bytes(), self.archive.read_bytes())
        shutil.rmtree(self.source)
        self.assertEqual(authority.provision(self.root, self.archive, self.digest, self.destination), len(self.names))
        self.assertEqual(sorted(str(p.relative_to(self.destination)) for p in self.destination.rglob('*') if p.is_file()), sorted(self.names))
        authority.validate_source(self.root, self.destination)

    def test_wrong_digest_never_creates_destination(self):
        with self.assertRaisesRegex(ValueError, 'digest differs'):
            authority.provision(self.root, self.archive, '0' * 64, self.destination)
        self.assertFalse(self.destination.exists())

    def test_unsafe_or_unapproved_archive_is_rejected_before_materialization(self):
        original = self.archive.read_bytes()
        for change in ('changed', 'link', 'omitted', 'oversized', 'duplicate', 'escape', 'image'):
            with self.subTest(change=change):
                self.archive.write_bytes(original)
                digest = self.altered_archive(change)
                with self.assertRaises(ValueError):
                    authority.provision(self.root, self.archive, digest, self.destination)
                self.assertFalse(self.destination.exists())
                self.assertFalse((self.base / 'outside').exists())

    def test_existing_destination_and_source_links_are_preserved_and_rejected(self):
        self.destination.mkdir(parents=True)
        marker = self.destination / 'keep'
        marker.write_text('Existing source')
        with self.assertRaises(ValueError):
            authority.provision(self.root, self.archive, self.digest, self.destination)
        self.assertEqual(marker.read_text(), 'Existing source')
        (self.source / 'SKILL.md').unlink()
        (self.source / 'SKILL.md').symlink_to(marker)
        with self.assertRaises(ValueError):
            authority.pack(self.root, self.source, self.base / 'linked.tar.gz')

    def test_adapter_revision_and_selected_authority_cannot_be_substituted(self):
        (self.root / 'DESIGN.md').write_text('Changed adapter')
        with self.assertRaises(ValueError):
            authority.provision(self.root, self.archive, self.digest, self.destination)
        self.assertFalse(self.destination.exists())
        self.document['design_authority']['skill'] = 'competing-design'
        self.register.write_text(json.dumps(self.document))
        with self.assertRaises(ValueError):
            authority.pack(self.root, self.source, self.base / 'replacement.tar.gz')

    def fake_gh(self, private=True, body=None, reported_size=None, slow=False):
        binary = self.base / 'bin'
        binary.mkdir(exist_ok=True)
        file = binary / 'gh'
        data = self.archive.read_bytes() if body is None else body
        payload = self.base / 'download.bin'
        payload.write_bytes(data)
        meta = {'state': 'uploaded', 'size': len(data) if reported_size is None else reported_size}
        file.write_text(f'#!{sys.executable}\nimport sys,time\nfrom pathlib import Path\n'
                        f'if "--jq" in sys.argv: print({str(private).lower()!r})\n'
                        f'elif "-H" in sys.argv:\n time.sleep({60 if slow else 0}); sys.stdout.buffer.write(Path({str(payload)!r}).read_bytes())\n'
                        f'else: print({json.dumps(meta)!r})\n')
        file.chmod(0o755)
        return {'PATH': str(binary) + os.pathsep + os.environ['PATH']}

    def test_pinned_private_asset_retrieval_uses_real_stream_and_provisions(self):
        with patch.dict(os.environ, self.fake_gh()):
            self.assertEqual(authority.download(self.root, 'owner/private-repo', '123', self.digest, self.destination), len(self.names))

    def test_public_repository_and_oversized_asset_are_rejected(self):
        for options in ({'private': False}, {'reported_size': authority.LIMIT + 1}):
            with self.subTest(options=options), patch.dict(os.environ, self.fake_gh(**options)):
                with self.assertRaises(ValueError):
                    authority.download(self.root, 'owner/repo', '123', self.digest, self.destination)
                self.assertFalse(self.destination.exists())

    def test_chunked_asset_overrun_and_slow_response_are_bounded(self):
        cases = ({'body': b'x' * (authority.LIMIT + 1), 'reported_size': 10}, {'slow': True})
        for options in cases:
            with self.subTest(options=options), patch.dict(os.environ, self.fake_gh(**options)):
                with self.assertRaises(ValueError):
                    authority.download(self.root, 'owner/repo', '123', self.digest, self.destination, timeout=0.2)
                self.assertFalse(self.destination.exists())


if __name__ == '__main__':
    unittest.main()
