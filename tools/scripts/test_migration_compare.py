import copy
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from migration_compare import compare, read_snapshot, InvalidSnapshot, canonical


def sample():
    return {'schemaVersion': 1, 'dataset': 'payment_claims', 'normalizationVersion': 'v1',
            'cutoff': '2026-09-28T00:00:00Z', 'scopeSha256': 'a'*64,
            'completeDeclared': True, 'expectedRows': 2,
            'fields': {'provider': {'type': 'string', 'nullable': False},
                       'reference': {'type': 'string', 'nullable': False},
                       'club_id': {'type': 'integer', 'nullable': False},
                       'currency': {'type': 'string', 'nullable': False},
                       'amount': {'type': 'decimal', 'nullable': False, 'scale': 2},
                       'observed_at': {'type': 'timestamp', 'nullable': False},
                       'metadata': {'type': 'json', 'nullable': True}},
            'keyFields': ['provider', 'reference'],
            'money': [{'field': 'amount', 'currencyField': 'currency'}],
            'rows': [{'provider': 'synthetic', 'reference': 'private-record-a', 'club_id': '24',
                      'currency': 'RWF', 'amount': '9007199254740993.21', 'observed_at': '2026-09-28T00:00:00Z', 'metadata': {'order': None}},
                     {'provider': 'synthetic', 'reference': 'private-record-b', 'club_id': '26',
                      'currency': 'ZMW', 'amount': '1.01', 'observed_at': '2026-09-28T00:00:00Z', 'metadata': None}]}


class MigrationCompareTests(unittest.TestCase):
    def check_bad(self, mutate):
        a = sample(); mutate(a)
        self.assertEqual(compare(a, sample())['exitCode'], 1)
    def test_equal_data_never_authorizes_release(self):
        r = compare(sample(), sample()); self.assertEqual(r['exitCode'], 0)
        self.assertFalse(r['coverageVerified']); self.assertFalse(r['releaseAuthorized'])
    def test_order_independent_rows(self):
        b = sample(); b['rows'].reverse(); self.assertEqual(compare(sample(), b)['exitCode'], 0)
    def test_arbitrary_precision_change_detected(self):
        b = sample(); b['rows'][0]['amount'] = '9007199254740993.22'
        r = compare(sample(), b); self.assertEqual(r['counts']['changedRows'], 1); self.assertEqual(r['counts']['moneyGroupsDifferent'], 1)
    def test_global_key_detects_cross_club_reference_reuse(self):
        a = sample(); row = copy.deepcopy(a['rows'][0]); row['club_id'] = '44'; a['rows'].append(row); a['expectedRows'] = 3
        self.assertEqual(compare(a, a)['counts']['sourceDuplicateKeys'], 1); self.assertEqual(compare(a, a)['status'], 'drift')
    def test_missing_row(self):
        b = sample(); b['rows'].pop(); b['expectedRows'] = 1
        self.assertEqual(compare(sample(), b)['counts']['missingInTarget'], 1)
    def test_extra_row(self):
        b = sample(); row = copy.deepcopy(b['rows'][0]); row['reference'] = 'private-record-c'; b['rows'].append(row); b['expectedRows'] = 3
        self.assertEqual(compare(sample(), b)['counts']['extraInTarget'], 1)
    def test_same_total_but_changed_records_fails(self):
        a = sample(); a['rows'][0]['currency'] = 'ZMW'; b = copy.deepcopy(a)
        b['rows'][0]['amount'] = '9007199254740993.20'; b['rows'][1]['amount'] = '1.02'
        r = compare(a, b); self.assertEqual(r['counts']['moneyGroupsDifferent'], 0); self.assertEqual(r['counts']['changedRows'], 2); self.assertEqual(r['exitCode'], 1)
    def test_report_omits_record_keys_and_amounts(self):
        a = sample(); r = json.dumps(compare(a, a))
        self.assertNotIn('private-record', r); self.assertNotIn('9007199254740993', r)
    def test_cutoff_mismatch_blocks(self):
        b = sample(); b['cutoff'] = '2026-09-27T00:00:00Z'; self.assertEqual(compare(sample(), b)['status'], 'context_mismatch')
    def test_scope_mismatch_blocks(self):
        b = sample(); b['scopeSha256'] = 'b'*64; self.assertEqual(compare(sample(), b)['exitCode'], 2)
    def test_normalization_mismatch_blocks(self):
        b = sample(); b['normalizationVersion'] = 'v2'; self.assertEqual(compare(sample(), b)['exitCode'], 2)
    def test_explicit_partial_data_blocks(self):
        a = sample(); a['completeDeclared'] = False; self.assertEqual(compare(a, a)['status'], 'coverage_unproven')
    def test_incorrect_declared_count_blocks(self):
        a = sample(); a['expectedRows'] = 3; self.assertEqual(compare(a, a)['exitCode'], 2)
    def test_nonboolean_coverage_flag(self): self.check_bad(lambda a: a.update(completeDeclared='true'))
    def test_empty_key_fields(self): self.check_bad(lambda a: a.update(keyFields=[]))
    def test_nullable_key(self): self.check_bad(lambda a: a['fields']['reference'].update(nullable=True))
    def test_duplicate_key_field(self): self.check_bad(lambda a: a.update(keyFields=['provider', 'provider']))
    def test_boolean_not_integer_string(self): self.check_bad(lambda a: a['rows'][0].update(club_id=True))
    def test_numeric_not_integer_string(self): self.check_bad(lambda a: a['rows'][0].update(club_id=24))
    def test_leading_zero_integer_rejected(self): self.check_bad(lambda a: a['rows'][0].update(club_id='024'))
    def test_decimal_float_rejected(self): self.check_bad(lambda a: a['rows'][0].update(amount=1.01))
    def test_decimal_scientific_notation_rejected(self): self.check_bad(lambda a: a['rows'][0].update(amount='1e3'))
    def test_decimal_rounding_not_invented(self): self.check_bad(lambda a: a['rows'][0].update(amount='1.001'))
    def test_negative_zero_rejected(self): self.check_bad(lambda a: a['rows'][0].update(amount='-0.00'))
    def test_naive_timestamp_rejected(self): self.check_bad(lambda a: a['rows'][0].update(observed_at='2026-09-28T00:00:00'))
    def test_invalid_calendar_date_rejected(self): self.check_bad(lambda a: a['rows'][0].update(observed_at='2026-02-30T00:00:00Z'))
    def test_unknown_row_field_rejected(self): self.check_bad(lambda a: a['rows'][0].update(secret='not-emitted'))
    def test_null_required_value_rejected(self): self.check_bad(lambda a: a['rows'][0].update(amount=None))
    def test_currency_group_not_coerced(self): self.check_bad(lambda a: a['rows'][0].update(currency='rwf'))
    def test_nested_float_rejected(self): self.check_bad(lambda a: a['rows'][0].update(metadata={'ratio': 0.1}))
    def test_actual_reader_rejects_duplicate_keys(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d)/'input.json'; p.write_text('{"a":1,"a":2}')
            with self.assertRaises(InvalidSnapshot): read_snapshot(p)
    def test_actual_reader_rejects_symlink(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d)/'input.json'; p.write_bytes(canonical(sample())); q = Path(d)/'link'; q.symlink_to(p)
            with self.assertRaises(InvalidSnapshot): read_snapshot(q)
    def test_cli_readonly_and_private_output(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d); a = root/'a.json'; b = root/'b.json'; out = root/'result.json'
            a.write_bytes(canonical(sample())); b.write_bytes(a.read_bytes()); before = a.read_bytes()
            cmd = [sys.executable, str(Path(__file__).with_name('migration_compare.py')), '--source', str(a), '--target', str(b), '--output', str(out)]
            r = subprocess.run(cmd, capture_output=True, text=True)
            self.assertEqual(r.returncode, 0, r.stderr); self.assertEqual(a.read_bytes(), before); self.assertEqual(b.read_bytes(), before)
            self.assertEqual(out.stat().st_mode & 0o777, 0o600); self.assertEqual(subprocess.run(cmd, capture_output=True).returncode, 1)
    def test_cli_wont_overwrite_source(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d)/'input.json'; p.write_bytes(canonical(sample())); before = p.read_bytes()
            r = subprocess.run([sys.executable, str(Path(__file__).with_name('migration_compare.py')), '--source', str(p), '--target', str(p), '--output', str(p)], capture_output=True)
            self.assertEqual(r.returncode, 1); self.assertEqual(p.read_bytes(), before)

if __name__ == '__main__': unittest.main()
