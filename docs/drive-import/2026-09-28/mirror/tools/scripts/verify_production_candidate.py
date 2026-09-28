#!/usr/bin/env python3
"""Offline integration runner. A passing contract suite is NOT a release approval.
No SDK download, provider call, remote SQL, resource provisioning or deployment.
"""
from __future__ import annotations
import argparse,hashlib,json,os,re,shutil,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
GROUPS={
 'public-and-operator':['cloudflare/rayon-public/tests/*.test.mjs','cloudflare/operator-api/tests/*.test.mjs'],
 'identity':['cloudflare/supporter-auth/tests/*.test.mjs'],
 'payments':['cloudflare/payment-allocation/tests/*.test.mjs'],
 'membership-gateway':['cloudflare/supporter-membership-api/tests/*.test.mjs'],
 'release-integrity':['tools/tests/*.test.mjs'],
 'repository-boundary':['tools/scripts/validate_repository_boundary.test.mjs'],
}

def check_lock(root:Path,manifest:dict)->list[str]:
 if not isinstance(manifest,dict) or manifest.get('schemaVersion')!=1 or not isinstance(manifest.get('files'),list):return ['source_lock_invalid']
 failures=[];seen=set();root=root.resolve()
 for row in manifest['files']:
  if not isinstance(row,dict) or set(row)!={'path','sha256'} or not isinstance(row.get('path'),str):failures.append('source_lock_invalid');continue
  rel=row['path'];p=root/rel;parts=rel.split('/')
  if rel.lower() in seen or any(part in ('','.','..') for part in parts) or '\\' in rel or any(ord(c)<32 or ord(c)==127 for c in rel) or not re.fullmatch('[a-f0-9]{64}',str(row['sha256'])):failures.append('source_lock_invalid');continue
  seen.add(rel.lower())
  if any((root.joinpath(*parts[:n])).is_symlink() for n in range(1,len(parts)+1)) or not p.is_file() or root not in p.resolve().parents:failures.append(rel+':missing_or_unsafe');continue
  if hashlib.sha256(p.read_bytes()).hexdigest()!=row['sha256']:failures.append(rel+':hash_mismatch')
 if not seen:failures.append('source_lock_empty')
 return failures

def run(args)->int:
 root=args.root.resolve();out=args.results.resolve();out.mkdir(parents=True,exist_ok=True)
 report={'schemaVersion':1,'scope':'selected integration contracts and exact changed-source hashes','productionReady':False,'wholeRepositoryVerified':False,'deployments':0,'groups':[],'blocked':[]}
 def save(code):
  report['exitCode']=code;(out/'integration-summary.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report));return code
 if not shutil.which('node'):report['blocked'].append('node_missing');return save(2)
 version=subprocess.check_output(['node','--version'],text=True).strip();report['nodeVersion']=version
 match=re.fullmatch(r'v(\d+)\.(\d+)\.(\d+)',version)
 if args.ci and (not match or not (22,22,2)<=tuple(map(int,match.groups()))<(23,0,0)):
  report['blocked'].append('pinned_web_node_required');return save(2)
 lock=root/'docs/governance/production-source-lock.json'
 if not lock.is_file():report['blocked'].append('source_lock_missing');return save(2)
 report['sourceFailures']=check_lock(root,json.loads(lock.read_text()))
 if report['sourceFailures']:return save(1)
 for name,patterns in GROUPS.items():
  files=sorted({str(p.relative_to(root)) for pat in patterns for p in root.glob(pat) if p.is_file() and not p.is_symlink()})
  if not files:report['blocked'].append(name+':tests_missing');continue
  completed=subprocess.run(['node','--test',*files],cwd=root,capture_output=True,text=True,timeout=180)
  text=completed.stdout+completed.stderr;(out/(name+'.tap')).write_text(text)
  def count(field):
   m=re.search(r'^# '+field+r' (\d+)\s*$',text,re.M);return int(m[1]) if m else None
  checks={k:count(k) for k in ['tests','pass','fail','cancelled','skipped','todo']}
  passed=completed.returncode==0 and checks['tests'] is not None and checks['tests']>0 and checks['tests']==checks['pass'] and all(checks[k]==0 for k in ['fail','cancelled','skipped','todo'])
  report['groups'].append({'name':name,'testFiles':len(files),'exitCode':completed.returncode,'passed':passed,**checks})
 command=['python3','-m','unittest','discover','-s','tools/security','-p','*_test.py','-v']
 completed=subprocess.run(command,cwd=root,capture_output=True,text=True,timeout=60);text=completed.stdout+completed.stderr;(out/'source-safety.log').write_text(text)
 m=re.search(r'Ran (\d+) tests?',text);report['groups'].append({'name':'source-safety','tests':int(m[1]) if m else 0,'passed':completed.returncode==0 and m is not None,'exitCode':completed.returncode})
 report['totalTestsPassed']=sum(g.get('pass',g.get('tests',0)) for g in report['groups'] if g['passed'])
 report['remainingAcceptance']=['full Flutter and Next builds','real Cloudflare service bindings and D1','signed devices and native storage','provider and legal/privacy approval','restricted sharing and credential exposure response','complete financial and source-history cutover']
 return save(2 if report['blocked'] else 1 if any(not g['passed'] for g in report['groups']) else 0)
if __name__=='__main__':
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--root',type=Path,default=ROOT);parser.add_argument('--results',type=Path,required=True);parser.add_argument('--ci',action='store_true');args=parser.parse_args()
 try:sys.exit(run(args))
 except (OSError,ValueError,subprocess.SubprocessError):print('Verification did not complete; no passing status.',file=sys.stderr);sys.exit(2)
