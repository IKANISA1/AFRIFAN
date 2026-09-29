"""Evidence rejection must never republish the rejected private value."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / 'tools/scripts/validate_evidence_privacy.sh'


class EvidencePrivacyRedactionTest(unittest.TestCase):
    def scan(self, text):
        with tempfile.TemporaryDirectory(prefix='africlub-evidence-redaction-') as directory:
            evidence = Path(directory)
            (evidence / 'captured.log').write_text(text)
            baseline = json.loads((ROOT / 'docs/governance/golden-baselines.json').read_text())
            manifest = evidence / 'fixture-manifest.json'
            manifest.write_text(json.dumps({
                'provenance': {'data_source': 'synthetic_non_production'},
                'privacy': {'data_classification': 'synthetic_non_production',
                            'automated_scan': 'tools/scripts/validate_evidence_privacy.sh',
                            'human_review_status': 'pending'},
                'baselines': [baseline['baselines'][0]],
            }))
            report = evidence / 'evidence-privacy-validation.json'
            result = subprocess.run(
                ['bash', str(SCRIPT)], cwd=ROOT, capture_output=True, text=True,
                env={**os.environ, 'EVIDENCE_ROOT': str(evidence),
                     'GOLDEN_MANIFEST': str(manifest), 'REPORT': str(report)},
            )
            return result, json.loads(report.read_text()) if report.exists() else None

    def test_secret_rejection_exposes_path_but_no_token(self):
        token = 'sb_' + 'secret_' + 'SyntheticCredentialForRedactionTest123456789'
        result, report = self.scan('captured provider response: ' + token + '\n')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('captured.log', result.stderr)
        self.assertIn('values redacted', result.stderr)
        self.assertNotIn(token, result.stdout + result.stderr)
        self.assertIsNone(report)

    def test_private_phone_and_otp_rejection_exposes_no_values(self):
        phone = '+250' + '788123456'
        otp = '739' + '152'
        result, report = self.scan('phone=' + phone + '\nOTP: ' + otp + '\n')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('captured.log', result.stderr)
        for value in (phone, otp):
            self.assertNotIn(value, result.stdout + result.stderr)
        self.assertIsNone(report)

    def test_bearer_rejection_exposes_no_value(self):
        token = 'syntheticBearerCredential1234567890'
        result, report = self.scan('Authorization: Bearer ' + token + '\n')
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn(token, result.stdout + result.stderr)
        self.assertIsNone(report)

    def test_clean_evidence_records_pending_human_review(self):
        result, report = self.scan('688 delivery tests passed; no private payloads recorded.\n')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(report['status'], 'pass')
        self.assertEqual(report['human_review_status'], 'pending')
        self.assertFalse(report['completion_claim'])


if __name__ == '__main__':
    unittest.main()
