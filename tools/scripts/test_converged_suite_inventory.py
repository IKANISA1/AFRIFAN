import ast
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
class ConvergedInventoryTests(unittest.TestCase):
    def setUp(self): self.text = (ROOT/'tools/scripts/verify_converged_source.py').read_text()
    def test_allocation_delivery_tests_are_registered(self):
        self.assertIn("'cloudflare/allocation-delivery/tests'", self.text)
    def test_shared_telemetry_contract_and_recovery_configuration_are_registered(self):
        self.assertIn("'cloudflare/shared-telemetry/tests'", self.text)
        for path in ['cloudflare/shared-telemetry/scripts/check-deployment.mjs',
                     'cloudflare/auth-code-delivery/scripts/check-review-deployment.mjs',
                     'cloudflare/allocation-delivery/scripts/check-recovery-deployment.mjs']:
            self.assertIn(path, self.text)
        self.assertIn("'test_local_native_ci'", self.text)
    def test_allocation_delivery_templates_checked(self):
        self.assertIn('cloudflare/allocation-delivery/scripts/check-deployment.mjs', self.text)
    def test_private_web_observations_are_in_the_converged_gate(self):
        self.assertIn("'cloudflare/web-observations/tests'", self.text)
        self.assertIn('cloudflare/web-observations/scripts/check-deployment.mjs', self.text)
    def test_case_backend_is_in_pinned_gate(self):
        self.assertIn("'cloudflare/payment-exceptions/tests'", self.text)
    def test_browser_backend_is_in_pinned_gate(self):
        self.assertIn("'cloudflare/supporter-browser-api/tests'", self.text)
    def test_browser_config_is_checked(self):
        self.assertIn("cloudflare/supporter-browser-api/scripts/check-deployment.mjs", self.text)
    def test_router_tests_are_registered(self):
        self.assertIn("'cloudflare/supporter-web-router/tests'", self.text)
    def test_router_configuration_is_checked(self):
        self.assertIn('cloudflare/supporter-web-router/scripts/validate-config.mjs', self.text)
    def test_history_suites_are_registered_by_directory(self):
        for name in ['cloudflare/payment-allocation/tests/membership-history.test.mjs',
                     'cloudflare/supporter-browser-api/tests/history.test.mjs',
                     'cloudflare/supporter-membership-api/tests/history.test.mjs',
                     'cloudflare/supporter-web-router/tests/notifications.test.mjs']:
            path = ROOT/name
            self.assertTrue(path.is_file(), name)
            self.assertIn(repr(str(path.parent.relative_to(ROOT))), self.text)
    def test_history_harness_is_present_and_in_dart_gate(self):
        gate = (ROOT/'tools/scripts/verify_native_membership.py').read_text()
        self.assertIn("('membership-history'", gate)
        self.assertTrue((ROOT/'packages/features/feat_membership/test/native_checkout/history_harness.dart').is_file())
    def test_history_migration_is_only_additive_index(self):
        import sqlite3
        migration = (ROOT/'cloudflare/payment-allocation/migrations/0005_membership_history_read_index.sql').read_text()
        with sqlite3.connect(':memory:') as db:
            db.execute('CREATE TABLE pa_ledger(club_id INTEGER,user_id TEXT,recorded_at_ms INTEGER,allocation_id TEXT,ledger_scope TEXT)')
            db.execute("INSERT INTO pa_ledger VALUES(24,'synthetic',100,'opaque','subscription')")
            before = db.execute('SELECT * FROM pa_ledger').fetchall()
            db.executescript(migration)
            self.assertEqual(before, db.execute('SELECT * FROM pa_ledger').fetchall())
            self.assertEqual(db.execute("SELECT type FROM sqlite_master WHERE name='pa_membership_history_owner'").fetchone(), ('index',))
            self.assertEqual(db.execute("SELECT name FROM sqlite_master WHERE type='table'").fetchall(), [('pa_ledger',)])
    def test_all_named_python_modules_exist(self):
        constants = [n.value for n in ast.walk(ast.parse(self.text)) if isinstance(n, ast.Constant) and isinstance(n.value, str)]
        for name in (s for s in constants if s.startswith('test_')):
            self.assertTrue((ROOT/'tools/scripts'/f'{name}.py').is_file(), name)
    def test_all_deployment_scripts_exist(self):
        constants = [n.value for n in ast.walk(ast.parse(self.text)) if isinstance(n, ast.Constant) and isinstance(n.value, str)]
        for name in (s for s in constants if s.startswith('cloudflare/') and s.endswith('.mjs')):
            self.assertTrue((ROOT/name).is_file(), name)
    def test_pin_is_not_downgraded_or_bypassed(self):
        self.assertEqual((ROOT/'.nvmrc').read_text().strip(), '22.23.2')
        self.assertIn('if actual!=expected:', self.text); self.assertNotIn('--ignore-pin', self.text)
    def test_scoped_success_is_not_production_acceptance(self):
        self.assertIn("'productionReady':False", self.text); self.assertIn("'fullApplicationBuildVerified':False", self.text)

if __name__ == '__main__': unittest.main()
