import ast
from pathlib import Path
import sys
import tempfile
import unittest
from verify_converged_source import node_version_output,run_logged_step

ROOT = Path(__file__).resolve().parents[2]
class ConvergedInventoryTests(unittest.TestCase):
    def test_timed_out_step_preserves_streamed_text_and_is_failed(self):
        with tempfile.TemporaryDirectory() as directory:
            log=Path(directory)/'step.log'
            code,timed_out=run_logged_step([sys.executable,'-u','-c',
                'import time; print("streamed evidence"); time.sleep(30)'],log,timeout_seconds=0.2)
            self.assertEqual(code,1);self.assertTrue(timed_out)
            self.assertIn('streamed evidence\n',log.read_text())
            self.assertIn('Required step timed out\n',log.read_text())
    def test_completed_step_streams_stdout_and_stderr_without_changing_result(self):
        with tempfile.TemporaryDirectory() as directory:
            log=Path(directory)/'step.log'
            code,timed_out=run_logged_step([sys.executable,'-u','-c',
                'import sys; print("stdout evidence"); print("stderr evidence",file=sys.stderr); sys.exit(7)'],log)
            self.assertEqual(code,7);self.assertFalse(timed_out)
            self.assertEqual(log.read_text(),'stdout evidence\nstderr evidence\n')
    def test_preload_evidence_cannot_corrupt_or_bypass_the_actual_node_version(self):
        record='{"localValidationNetworkGuard":true,"outboundNetworkAttemptsBlocked":0}'
        for output in ['22.23.2',record+'\n22.23.2','22.23.2\n'+record]:
            self.assertEqual(node_version_output(output),'22.23.2')
        for output in ['untrusted\n22.23.2','22.23.2\n22.23.2',record,'{"localValidationNetworkGuard":false}\n22.23.2']:
            self.assertIsNone(node_version_output(output))
    def test_artifact_environment_and_node_network_guards_are_in_the_converged_gate(self):
        for script in ['tools/scripts/local_validation_network_guard.node-test.mjs',
                       'apps/rayon_sports/web/scripts/artifact-public-environment.node-test.mjs',
                       'apps/rayon_sports/web/scripts/artifact-installed-inputs.node-test.mjs',
                       'apps/rayon_sports/web/scripts/web-build-provenance.node-test.mjs',
                       'apps/rayon_sports/web/scripts/sync-cloudflare-dev-vars.node-test.mjs']:
            self.assertIn(script,self.text)
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
