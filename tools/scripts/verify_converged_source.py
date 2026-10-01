#!/usr/bin/env python3
"""Run the reconciled backend/native source gates. Does not install or deploy.
--profile backend excludes platform gates intentionally; release requires backend,
pure-Dart, platform builds, devices and approved real-environment evidence.
"""
from __future__ import annotations
import argparse,json,os,re,shutil,signal,subprocess,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def run_logged_step(command,log,cwd=ROOT,timeout_seconds=300):
 # Stream directly to disk so a live gate remains observable and a timeout
 # preserves UTF-8 output rather than serializing captured bytes as repr().
 timed_out=False
 with Path(log).open('w',encoding='utf-8') as output:
  try:
   process=subprocess.Popen(command,cwd=cwd,stdout=output,stderr=subprocess.STDOUT,start_new_session=True)
  except FileNotFoundError:
   output.write('Required executable not installed\n');return 2,False
  try:code=process.wait(timeout=timeout_seconds)
  except subprocess.TimeoutExpired:
   timed_out=True;output.write('\nRequired step timed out\n');output.flush()
   # Stop this gate's descendants as well as the parent. An expired aggregate
   # must not leave test children competing with a later invocation.
   try:os.killpg(process.pid,signal.SIGTERM)
   except ProcessLookupError:pass
   try:process.wait(timeout=5)
   except subprocess.TimeoutExpired:
    try:os.killpg(process.pid,signal.SIGKILL)
    except ProcessLookupError:pass
    process.wait()
   code=1
 return code,timed_out
def node_version_output(raw):
 versions=[]
 for line in raw.splitlines():
  if re.fullmatch(r'[0-9]+\.[0-9]+\.[0-9]+',line):versions.append(line);continue
  try:record=json.loads(line)
  except (TypeError,json.JSONDecodeError):return None
  if not (type(record) is dict and set(record)=={'localValidationNetworkGuard','outboundNetworkAttemptsBlocked'} and
   record['localValidationNetworkGuard'] is True and type(record['outboundNetworkAttemptsBlocked']) is int and
   record['outboundNetworkAttemptsBlocked']>=0):return None
 return versions[0] if len(versions)==1 else None
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--results',type=Path,required=True);p.add_argument('--profile',choices=['backend','portable-native','complete'],default='complete');a=p.parse_args()
 a.results.mkdir(parents=True,exist_ok=True);steps=[]
 def run(name,command,cwd=ROOT,timeout_seconds=300):
  start=time.monotonic()
  code,timed_out=run_logged_step(command,a.results/(name+'.log'),cwd,timeout_seconds)
  steps.append({'name':name,'command':command,'exitCode':code,'timedOut':timed_out,'timeoutSeconds':timeout_seconds,'elapsedSeconds':round(time.monotonic()-start,2)});return code
 blocked=False
 if a.profile in ('backend','complete'):
  # Preserve actual repository version, not a lower ad-hoc CI requirement.
  expected=(ROOT/'.nvmrc').read_text().strip()
  try:actual=node_version_output(subprocess.check_output(['node','-p','process.versions.node'],text=True))
  except (FileNotFoundError,subprocess.CalledProcessError):actual=None
  if actual!=expected:
   blocked=True;steps.append({'name':'node-runtime-pin','exitCode':2,'expected':expected,'actual':actual})
  else:
   # Client contracts compile with the repository's locked TypeScript package.
   # Do not depend on a global tsc or the caller's incidental PATH.
   tsc=ROOT/'apps/rayon_sports/web/node_modules/.bin/tsc'
   if not tsc.is_file() or tsc.resolve()!=(ROOT/'apps/rayon_sports/web/node_modules/typescript/bin/tsc').resolve():
    steps.append({'name':'locked-typescript-runtime','exitCode':2});blocked=True
   else:
    os.environ['PATH']=str(tsc.parent)+os.pathsep+os.environ.get('PATH','')
   node_tests=sorted(str(x.relative_to(ROOT)) for base in ['cloudflare/rayon-public/tests','cloudflare/operator-api/tests','cloudflare/supporter-auth/tests','cloudflare/auth-code-delivery/tests','cloudflare/payment-allocation/tests','cloudflare/supporter-membership-api/tests','cloudflare/payment-exceptions/tests','cloudflare/supporter-browser-api/tests','cloudflare/supporter-web-router/tests','cloudflare/allocation-delivery/tests','cloudflare/shared-telemetry/tests','cloudflare/web-observations/tests'] for x in (ROOT/base).glob('*.test.mjs'))
   node_tests+=['tools/scripts/validate_repository_boundary.test.mjs','tools/scripts/validate_predict_economics_contract.test.mjs',
    'tools/scripts/local_validation_network_guard.node-test.mjs',
    'apps/rayon_sports/web/scripts/artifact-public-environment.node-test.mjs',
    'apps/rayon_sports/web/scripts/artifact-installed-inputs.node-test.mjs',
    'apps/rayon_sports/web/scripts/web-build-provenance.node-test.mjs',
    'apps/rayon_sports/web/scripts/sync-cloudflare-dev-vars.node-test.mjs']
   # Individual race suites still create independent writers. Limit competing
   # test files so wall-clock deadline assertions do not measure unrelated jobs.
   run('backend-contracts',['node','--test','--test-concurrency=4',*node_tests],timeout_seconds=1800)
   for name,script in [('operator-assets','cloudflare/operator-api/scripts/build-ui.mjs'),('operator-config','cloudflare/operator-api/scripts/check-deployment.mjs'),('public-config','cloudflare/rayon-public/scripts/check-deployment.mjs'),('case-config','cloudflare/payment-exceptions/scripts/check-deployment.mjs'),('browser-config','cloudflare/supporter-browser-api/scripts/check-deployment.mjs'),('web-router-config','cloudflare/supporter-web-router/scripts/validate-config.mjs'),('delivery-outbox-config','cloudflare/allocation-delivery/scripts/check-deployment.mjs'),('allocation-config','cloudflare/payment-allocation/scripts/check-deployment.mjs'),('checkout-config','cloudflare/payment-allocation/scripts/check-checkout-deployment.mjs'),('gateway-config','cloudflare/supporter-membership-api/scripts/check-deployment.mjs'),('identity-config','cloudflare/supporter-auth/scripts/check-deployment.mjs'),('queue-health-config','cloudflare/supporter-auth/scripts/check-reliable-delivery.mjs'),('delivery-config','cloudflare/auth-code-delivery/scripts/check-deployment.mjs'),('receipt-config','cloudflare/auth-code-delivery/scripts/check-receipts-deployment.mjs'),('delivery-review-config','cloudflare/auth-code-delivery/scripts/check-review-deployment.mjs'),('allocation-recovery-config','cloudflare/allocation-delivery/scripts/check-recovery-deployment.mjs'),('private-metrics-config','cloudflare/shared-telemetry/scripts/check-deployment.mjs'),('private-web-observations-config','cloudflare/web-observations/scripts/check-deployment.mjs')]:
    run(name,['node',script]+(['--check'] if name=='operator-assets' else []))
  run('python-source-gates',[sys.executable,'-m','unittest','-v','test_supporter_sms_boundary','test_public_snapshot_import','test_migration_release','test_release_artifact','test_release_evidence','test_ci_contract','test_sensitive_source','test_migration_lineage','test_migration_compare','test_task_execution_plan','test_converged_suite_inventory','test_local_native_ci'],ROOT/'tools/scripts')
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
