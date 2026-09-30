#!/usr/bin/env python3
"""Run the reconciled backend/native source gates. Does not install or deploy.
--profile backend excludes platform gates intentionally; release requires backend,
pure-Dart, platform builds, devices and approved real-environment evidence.
"""
from __future__ import annotations
import argparse,json,os,re,shutil,subprocess,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--results',type=Path,required=True);p.add_argument('--profile',choices=['backend','portable-native','complete'],default='complete');a=p.parse_args()
 a.results.mkdir(parents=True,exist_ok=True);steps=[]
 def run(name,command,cwd=ROOT):
  start=time.monotonic()
  try:
   result=subprocess.run(command,cwd=cwd,capture_output=True,text=True,timeout=300)
   (a.results/(name+'.log')).write_text(result.stdout+result.stderr)
   code=result.returncode
  except FileNotFoundError:code=2;(a.results/(name+'.log')).write_text('Required executable not installed\n')
  except subprocess.TimeoutExpired as e:
   code=1;(a.results/(name+'.log')).write_text('Required step timed out\n'+str(e.stdout or '')+str(e.stderr or ''))
  steps.append({'name':name,'command':command,'exitCode':code,'elapsedSeconds':round(time.monotonic()-start,2)});return code
 blocked=False
 if a.profile in ('backend','complete'):
  # Preserve actual repository version, not a lower ad-hoc CI requirement.
  expected=(ROOT/'.nvmrc').read_text().strip()
  try:actual=subprocess.check_output(['node','-p','process.versions.node'],text=True).strip()
  except (FileNotFoundError,subprocess.CalledProcessError):actual=None
  if actual!=expected:
   blocked=True;steps.append({'name':'node-runtime-pin','exitCode':2,'expected':expected,'actual':actual})
  else:
   node_tests=sorted(str(x.relative_to(ROOT)) for base in ['cloudflare/rayon-public/tests','cloudflare/operator-api/tests','cloudflare/supporter-auth/tests','cloudflare/auth-code-delivery/tests','cloudflare/payment-allocation/tests','cloudflare/supporter-membership-api/tests','cloudflare/payment-exceptions/tests','cloudflare/supporter-browser-api/tests','cloudflare/supporter-web-router/tests','cloudflare/allocation-delivery/tests'] for x in (ROOT/base).glob('*.test.mjs'))
   node_tests+=['tools/scripts/validate_repository_boundary.test.mjs','tools/scripts/validate_predict_economics_contract.test.mjs']
   run('backend-contracts',['node','--test',*node_tests])
   for name,script in [('operator-assets','cloudflare/operator-api/scripts/build-ui.mjs'),('operator-config','cloudflare/operator-api/scripts/check-deployment.mjs'),('public-config','cloudflare/rayon-public/scripts/check-deployment.mjs'),('case-config','cloudflare/payment-exceptions/scripts/check-deployment.mjs'),('browser-config','cloudflare/supporter-browser-api/scripts/check-deployment.mjs'),('web-router-config','cloudflare/supporter-web-router/scripts/validate-config.mjs'),('delivery-outbox-config','cloudflare/allocation-delivery/scripts/check-deployment.mjs'),('allocation-config','cloudflare/payment-allocation/scripts/check-deployment.mjs'),('checkout-config','cloudflare/payment-allocation/scripts/check-checkout-deployment.mjs'),('gateway-config','cloudflare/supporter-membership-api/scripts/check-deployment.mjs'),('identity-config','cloudflare/supporter-auth/scripts/check-deployment.mjs'),('queue-health-config','cloudflare/supporter-auth/scripts/check-reliable-delivery.mjs'),('delivery-config','cloudflare/auth-code-delivery/scripts/check-deployment.mjs'),('receipt-config','cloudflare/auth-code-delivery/scripts/check-receipts-deployment.mjs')]:
    run(name,['node',script]+(['--check'] if name=='operator-assets' else []))
  run('python-source-gates',[sys.executable,'-m','unittest','-v','test_supporter_sms_boundary','test_public_snapshot_import','test_migration_release','test_release_artifact','test_release_evidence','test_ci_contract','test_sensitive_source','test_migration_lineage','test_migration_compare','test_task_execution_plan','test_converged_suite_inventory'],ROOT/'tools/scripts')
  # Exercise the credential-bearing capture transport boundary itself. Its
  # fixture intercepts both HTTP and HTTPS and rejects redirects before any
  # second request; the aggregate gate must preserve this separate suite.
  run('public-source-capture',[sys.executable,'-m','unittest','discover','-s','cloudflare/rayon-public/tests','-p','source_capture_test.py','-v'])
 if a.profile in ('portable-native','complete'):
  for name,script in [('portable-kotlin','verify_android_recovery.py'),('portable-swift','verify_ios_recovery.py')]:
   code=run(name,[sys.executable,str(ROOT/'tools/scripts'/script),'--results',str(a.results/name)])
   if code==2:blocked=True
 if a.profile=='complete':
  code=run('native-dart',[sys.executable,str(ROOT/'tools/scripts/verify_native_membership.py'),'--results',str(a.results/'dart')])
  if code==2:blocked=True
 failed=any(s['exitCode'] not in (0,2) for s in steps);blocked|=any(s['exitCode']==2 for s in steps)
 result={'schemaVersion':1,'profile':a.profile,'status':'failed' if failed else 'blocked' if blocked else 'passed_scoped_checks','steps':steps,'fullApplicationBuildVerified':False,'productionReady':False,'deploymentActions':0}
 (a.results/'verification.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
 return 1 if failed else 2 if blocked else 0
if __name__=='__main__':sys.exit(main())
