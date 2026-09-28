#!/usr/bin/env python3
"""Read-only source hygiene check. Reports paths/rule names, never secret values.

Default input is Git's tracked and non-ignored source set. Ignored local secrets are
not thereby declared safe: Drive sharing and credential exposure require separate
containment. This is a deterministic guard, not a complete secret-scanning service.
"""
from __future__ import annotations
import argparse,hashlib,json,os,re,subprocess,sys
from pathlib import Path,PurePosixPath

FORBIDDEN_NAMES={'.env.local','.env.production','.dev.vars','keystore.properties','credentials.json','id_rsa','id_ed25519'}
FORBIDDEN_DIRS={'.git','.dart_tool','.next','.open-next','.gradle','node_modules','build','coverage','output','Conversation_Files_2026-09-27'}
SECRET_RULES={
 'private-key-block':re.compile(rb'-----BEGIN (?:[A-Z0-9 ]+ )?PRIVATE KEY-----'),
 'github-token':re.compile(rb'\bgh[pousr]_[A-Za-z0-9]{30,}\b'),
 'aws-access-key':re.compile(rb'\bAKIA[A-Z0-9]{16}\b'),
}

def check_paths(root:Path,paths:list[str])->list[dict]:
 root=root.resolve();failures=[];seen={}
 for rel in sorted(set(paths)):
  pp=PurePosixPath(rel)
  if not rel or pp.is_absolute() or '..' in pp.parts or '\\' in rel or any(ord(c)<32 for c in rel):
   failures.append({'path':'[invalid path]','rule':'unsafe-path'});continue
  p=root.joinpath(*pp.parts);normalized=rel.casefold()
  if normalized in seen and seen[normalized]!=rel:failures.append({'path':rel,'rule':'case-collision'})
  seen[normalized]=rel
  if p.is_symlink() or any(q.is_symlink() for q in p.parents if q!=root and root in q.parents):
   failures.append({'path':rel,'rule':'symlink'});continue
  if not p.exists():continue # A tracked deletion is not an existing source file.
  if not p.is_file():failures.append({'path':rel,'rule':'non-regular-source'});continue
  if any(part in FORBIDDEN_DIRS for part in pp.parts[:-1]):failures.append({'path':rel,'rule':'generated-or-archive-source'})
  if pp.name in FORBIDDEN_NAMES or pp.suffix.lower() in {'.jks','.p12','.pfx','.keystore'}:
   failures.append({'path':rel,'rule':'sensitive-file-name'});continue
  if p.stat().st_size>8*1024*1024:continue # Binary/media policy is checked separately.
  data=p.read_bytes()
  if b'\x00' in data:continue
  for name,pattern in SECRET_RULES.items():
   if pattern.search(data):failures.append({'path':rel,'rule':name})
 return failures

def main():
 a=argparse.ArgumentParser(description=__doc__);a.add_argument('--root',type=Path,default=Path.cwd());a.add_argument('--report',type=Path,required=True);args=a.parse_args()
 result=subprocess.run(['git','ls-files','--cached','--others','--exclude-standard','-z'],cwd=args.root,capture_output=True,check=True)
 paths=result.stdout.decode('utf-8',errors='strict').split('\0');paths=[p for p in paths if p]
 failures=check_paths(args.root,paths)
 report={'schemaVersion':1,'scope':'Git tracked and non-ignored source; not ignored working secrets','pathsChecked':len(set(paths)),'failures':failures,'passed':not failures,'credentialRevocationPerformed':False,'publicSharingRemediated':False}
 args.report.parent.mkdir(parents=True,exist_ok=True);args.report.write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({'passed':not failures,'findings':len(failures)}));return int(bool(failures))
if __name__=='__main__':
 try:sys.exit(main())
 except (OSError,ValueError,subprocess.SubprocessError):print('Source scan could not complete; gate failed.',file=sys.stderr);sys.exit(2)
