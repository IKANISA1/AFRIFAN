"""Admission regressions for publisher evidence and compiled output closure."""
import copy
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import dependency_gap_closure as c
import local_dependency_inventory as d

ROOT = Path(__file__).resolve().parents[2]

class ClosureTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.inventory = d.load_report(ROOT / (d.DEFAULT_PREFIX + '.json'))
        cls.manifest = d.load_json(ROOT / c.DEFAULT_MANIFEST)
        cls.components = {x['ref']: x for x in cls.inventory['components']}

    def test_all_22_publisher_relationships_admitted(self):
        self.assertEqual(len(self.manifest['licenses']), 22)
        for row in self.manifest['licenses']:
            with self.subTest(component=row['ref']):
                c.verify_license(row, self.components[row['ref']], ROOT, self.inventory['evidence'])

    def test_wrong_selected_version_rejected(self):
        row = copy.deepcopy(self.manifest['licenses'][0]); row['version'] = '999.0.0'
        with self.assertRaisesRegex(d.InventoryError, 'identity differs'):
            c.verify_license(row, self.components[row['ref']], ROOT, self.inventory['evidence'])

    def test_changed_publisher_file_rejected(self):
        row = copy.deepcopy(self.manifest['licenses'][0]); row['files'][0]['sha256'] = '0' * 64
        with self.assertRaisesRegex(d.InventoryError, 'hash differs'):
            c.verify_license(row, self.components[row['ref']], ROOT, self.inventory['evidence'])

    def test_exact_release_commit_inference_rejected(self):
        row = copy.deepcopy(next(x for x in self.manifest['licenses'] if x['method'] == 'publisher-package-source-grant'))
        row['exactReleaseCommitClaimed'] = True
        with self.assertRaisesRegex(d.InventoryError, 'exact release provenance'):
            c.verify_license(row, self.components[row['ref']], ROOT, self.inventory['evidence'])

    def test_incomplete_plugin_output_receipt_rejected(self):
        row = copy.deepcopy(self.manifest)
        with tempfile.TemporaryDirectory(dir=ROOT / 'output') as directory:
            manifest = Path(directory) / 'manifest.json'; manifest.write_text(json.dumps(row))
            outputs = Path(directory) / 'outputs.json'
            outputs.write_text(json.dumps({'passed': True, 'applicationReleaseBuilds': 0, 'results': [], 'outputCount': 282}))
            with self.assertRaisesRegex(d.InventoryError, 'coverage incomplete'):
                c.apply_closure(self.inventory, manifest, outputs)

    def test_source_file_header_is_required(self):
        self.assertFalse(c.apache_grant(b'Copyright, see parent package.'))
        self.assertTrue(c.apache_grant(b'The Netty Project licenses this file to you under the Apache License,\n * version 2.0'))

    def test_truncated_java_class_rejected(self):
        for raw in (b'not-java', b'\xca\xfe\xba\xbe\0\0\0\x34\0\x03\x01\0\x20foo'):
            with self.subTest(raw=raw), self.assertRaises(d.InventoryError):
                c.class_source(raw)

if __name__ == '__main__':
    unittest.main()
