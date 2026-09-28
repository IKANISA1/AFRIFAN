from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[2]
class CIContractTests(unittest.TestCase):
 def setUp(self):
  self.ci=(ROOT/'.github/workflows/ci.yaml').read_text();self.deploy=(ROOT/'.github/workflows/deploy-gikundiro-web.yml').read_text()
 def test_no_independent_trigger(self):
  self.assertIn('workflow_call:',self.deploy)
  for bad in ['\n  push:','\n  workflow_dispatch:','\n  workflow_run:','pull_request_target:']:self.assertNotIn(bad,self.deploy)
 def test_all_required_jobs_precede_promotion(self):
  line=next(x for x in self.ci.splitlines() if 'needs: [paid-membership-ci' in x)
  for job in ['paid-membership-ci','database-ci','flutter-ci','web-ci','web-e2e','android-build','ios-build','cloudflare-source-ci']:self.assertIn(job,line)
 def test_explicit_disabled_default(self):self.assertIn("vars.AFRICLUB_RELEASE_PROMOTION_ENABLED == 'true'",self.ci);self.assertIn("vars.AFRICLUB_RELEASE_PROMOTION_ENABLED == 'true'",self.deploy)
 def test_main_only(self):self.assertIn("github.ref == 'refs/heads/main'",self.deploy)
 def test_protected_environment(self):self.assertIn('environment: africlub-production',self.deploy)
 def test_seal_after_typecheck(self):self.assertLess(self.ci.index('run: corepack npm run typecheck'),self.ci.index('id: seal'))
 def test_seal_after_tests(self):self.assertLess(self.ci.index('run: corepack npm test'),self.ci.index('id: seal'))
 def test_verifier_before_deploy(self):self.assertLess(self.deploy.index('release_artifact.py verify'),self.deploy.index('opennextjs-cloudflare deploy'))
 def test_acceptance_before_deploy(self):self.assertLess(self.deploy.index('release_evidence.py'),self.deploy.index('opennextjs-cloudflare deploy'))
 def test_no_deployment_rebuild(self):self.assertNotIn('npm run build',self.deploy);self.assertNotIn('opennextjs-cloudflare build',self.deploy)
 def test_no_build_secrets_in_promotion_workflow(self):self.assertGreater(self.deploy.index('secrets.CLOUDFLARE_API_TOKEN'),self.deploy.index('name: Deploy prebuilt output only'))
 def test_sha_and_run_binding(self):
  for name in ['--sha256 "$EXPECTED_ARTIFACT"','--candidate "$EXPECTED_SHA"','--run-id "$RUN_ID"']:self.assertIn(name,self.deploy)
 def test_readonly_permissions(self):self.assertIn('contents: read',self.deploy);self.assertNotIn('write-all',self.deploy)
 def test_no_persisted_git_token(self):self.assertIn('persist-credentials: false',self.deploy)
 def test_strict_next_errors(self):self.assertIn('ignoreBuildErrors: false',(ROOT/'apps/rayon_sports/web/next.config.ts').read_text())
 def test_all_backend_modules_registered(self):
  text=(ROOT/'tools/scripts/verify_converged_source.py').read_text()
  for module in ['rayon-public','operator-api','supporter-auth','auth-code-delivery','payment-allocation','supporter-membership-api']:self.assertIn(module,text)
 def test_pin_preserved(self):self.assertEqual((ROOT/'.nvmrc').read_text().strip(),'22.23.2')
if __name__=='__main__':unittest.main()
