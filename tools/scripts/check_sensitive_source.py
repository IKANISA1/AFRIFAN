#!/usr/bin/env python3
"""Read-only Git source guard. Reports paths/categories, NEVER matched values.
Ignored workstation files are NOT inspected unless already tracked by Git. This
cannot certify Google Drive sharing or revoke a credential; do those separately.
"""
from __future__ import annotations
import argparse,base64,json,re,stat,subprocess,sys
from pathlib import Path,PurePosixPath
MAX_TEXT=8*1024*1024
PEM=re.compile(r'-----BEGIN (?P<kind>(?:RSA |EC |OPENSSH |DSA )?PRIVATE KEY)-----\s*[A-Za-z0-9+/=\s]{32,}-----END (?P=kind)-----')
JWT=re.compile(r'eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}')
def path_issue(name:str):
 p=PurePosixPath(name);base=p.name.lower()
 if p.is_absolute() or '\\' in name or any(x in ('','.','..') for x in name.split('/')):return 'unsafe_source_path'
 if base in ('.env','.env.local','.dev.vars','keystore.properties','service-account.json') or base.endswith(('.jks','.keystore','.p12','.pfx')):return 'private_configuration_or_signing_artifact'
 if (base.startswith('.env.') or base.startswith('.dev.vars.')) and not base.endswith(('.example','.template')):return 'private_environment_configuration'
 return None
def inspect(root:Path,names:list[str]):
 issues=[];read_count=0;excluded_archives=0
 for name in sorted(set(names)):
  # Only these retained evidence namespaces are excluded. Invalid paths and
  # similarly named active source still pass through the strict path guard.
  parts=name.split('/')
  canonical=not PurePosixPath(name).is_absolute() and '\\' not in name and all(p not in ('','.','..') for p in parts)
  if canonical and (name.startswith('docs/drive-import/') or name.startswith('.recovery/')):
   excluded_archives+=1;continue
  problem=path_issue(name)
  if problem:issues.append({'path':name,'category':problem});continue
  full=root
  bad=False
  for part in PurePosixPath(name).parts:
   full=full/part
   if full.is_symlink():issues.append({'path':name,'category':'source_symlink_requires_review'});bad=True;break
  if bad or not full.exists():continue # Deleted worktree path; Git diff is reviewed separately.
  if not full.is_file():issues.append({'path':name,'category':'non_regular_source'});continue
  if full.stat().st_size>MAX_TEXT:
   # Do not silently certify an arbitrarily large source or data dump.
   issues.append({'path':name,'category':'oversized_source_requires_review'});continue
  data=full.read_bytes();read_count+=1
  if b'\x00' in data:continue
  text=data.decode('utf-8',errors='replace')
  pem_text=text.replace('\\\\n','\n').replace('\\n','\n').replace('\\r','\r')
  if PEM.search(pem_text):issues.append({'path':name,'category':'private_key_material'})
  # Public client tokens are not automatically secret. Classify service-role JWTs
  # from their local payload only; there is no token validation/network request.
  for token in JWT.findall(text):
   try:
    payload=token.split('.')[1];decoded=json.loads(base64.urlsafe_b64decode(payload+'='*((-len(payload))%4)))
    if type(decoded) is dict and decoded.get('role')=='service_role':
     issues.append({'path':name,'category':'privileged_backend_token'});break
   except (ValueError,UnicodeError,TypeError):pass
  if '"type"' in text and '"service_account"' in text:
   try:
    v=json.loads(text)
    if type(v) is dict and v.get('type')=='service_account' and v.get('private_key'):issues.append({'path':name,'category':'service_account_private_key'})
   except ValueError:pass
 return {'schemaVersion':1,'sourceFilesRead':read_count,'excludedArchiveFiles':excluded_archives,
  'archiveScope':'Retained docs/drive-import and .recovery evidence requires its separate inventory/privacy review; excluded from active source acceptance.',
  'issues':issues,'passed':not issues,'matchedValuesIncluded':False,'drivePermissionsVerified':False}
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--root',type=Path,default=Path.cwd());p.add_argument('--report',type=Path);a=p.parse_args()
 try:
  names=subprocess.check_output(['git','ls-files','--cached','--others','--exclude-standard','-z'],cwd=a.root).decode().split('\0')
  r=inspect(a.root,[x for x in names if x])
 except (OSError,subprocess.CalledProcessError,UnicodeError):r={'passed':False,'error':'source_inventory_unavailable','issues':[]}
 text=json.dumps(r,indent=2)+'\n'
 if a.report:a.report.parent.mkdir(parents=True,exist_ok=True);a.report.write_text(text)
 print(text);return 0 if r['passed'] else 1
if __name__=='__main__':sys.exit(main())
