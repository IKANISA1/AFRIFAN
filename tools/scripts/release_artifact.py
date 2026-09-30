#!/usr/bin/env python3
"""Seal/verify a bounded, exact-commit OpenNext artifact. No deploy or network I/O.
A digest proves bytes, not approval. CI dependency and protected-environment gates
remain mandatory. Unknown files, traversal, links and ambiguous JSON are rejected.
"""
from __future__ import annotations
import argparse, hashlib, json, os, re, stat, sys, tempfile, zipfile
from pathlib import Path, PurePosixPath
from typing import Any
MAX_FILES=50000
MAX_FILE=128*1024*1024
MAX_TOTAL=1024*1024*1024
CONTROL=('wrangler.jsonc','package.json','package-lock.json','next.config.ts')
class ArtifactError(ValueError): pass
def need(ok: bool, message: str):
 if not ok: raise ArtifactError(message)
def digest(data: bytes)->str:return hashlib.sha256(data).hexdigest()
def pairs(items):
 value={}
 for key,item in items:
  need(key not in value,'duplicate JSON field');value[key]=item
 return value
def parse(data: bytes):
 try:return json.loads(data,object_pairs_hook=pairs)
 except (UnicodeError,json.JSONDecodeError) as e:raise ArtifactError('invalid JSON') from e
def exact(value: Any, keys: set[str]):
 need(type(value) is dict and set(value)==keys,'invalid object fields')
def safe_path(value: str)->str:
 need(type(value) is str and 0<len(value)<=512 and '\\' not in value and '\x00' not in value,'invalid path')
 need(not any(ord(c)<32 for c in value),'invalid path')
 p=PurePosixPath(value)
 need(not p.is_absolute() and p.as_posix()==value and all(c not in ('','.','..') for c in value.split('/')),'noncanonical path')
 need(value in CONTROL or value.startswith('.open-next/'),'file outside release scope')
 need(not any(part in ('.env','.env.local','.dev.vars','keystore.properties') or part.endswith(('.jks','.p12','.pfx','.pem','.key')) for part in p.parts),'private artifact path')
 return value
def regular(root: Path, name: str)->Path:
 p=root
 for part in PurePosixPath(name).parts:
  p=p/part;need(not p.is_symlink(),'symlink is forbidden')
 need(p.is_file() and stat.S_ISREG(p.stat().st_mode),'regular file required')
 need(p.stat().st_size<=MAX_FILE,'file too large');return p
def sha(value:str):need(type(value) is str and re.fullmatch('[0-9a-f]{40}',value),'exact Git SHA required')
def inventory(root:Path):
 need(root.is_dir() and not root.is_symlink(),'web directory required')
 output=root/'.open-next';need(output.is_dir() and not output.is_symlink(),'OpenNext output required')
 names=list(CONTROL)
 for p in output.rglob('*'):
  need(not p.is_symlink(),'symlink is forbidden')
  if p.is_file():names.append(p.relative_to(root).as_posix())
  else:need(p.is_dir(),'unsupported file type')
 names=sorted(names);need(0<len(names)<=MAX_FILES and '.open-next/worker.js' in names,'invalid release inventory')
 payload={};total=0
 for name in names:
  safe_path(name);data=regular(root,name).read_bytes();total+=len(data)
  need(total<=MAX_TOTAL,'release too large');payload[name]=data
 return payload
def seal(root:Path, out:Path, commit:str, run_id:str):
 sha(commit);need(re.fullmatch('[1-9][0-9]{0,19}',run_id) is not None,'run ID required')
 payload=inventory(root)
 manifest={'schemaVersion':1,'candidateSha':commit,'runId':run_id,'files':[
  {'path':n,'bytes':len(b),'sha256':digest(b)} for n,b in payload.items()]}
 need(not out.exists() and not out.is_symlink(),'refusing to replace artifact')
 out.parent.mkdir(parents=True,exist_ok=True)
 # Exclusive creation; interrupted output is never called a completed artifact.
 with out.open('xb') as raw:
  with zipfile.ZipFile(raw,'w',compression=zipfile.ZIP_DEFLATED) as z:
   z.writestr('release-manifest.json',json.dumps(manifest,sort_keys=True,separators=(',',':'))+'\n')
   for name,data in payload.items():z.writestr(name,data)
  raw.flush();os.fsync(raw.fileno())
 return {'sha256':digest(out.read_bytes()),'bytes':out.stat().st_size,'files':len(payload),'candidateSha':commit,'runId':run_id}
def verify(archive:Path, expected_hash:str, commit:str, run_id:str, destination:Path|None=None):
 sha(commit);need(re.fullmatch('[0-9a-f]{64}',expected_hash or '') is not None,'expected artifact SHA-256 required')
 need(archive.is_file() and not archive.is_symlink() and archive.stat().st_size<=MAX_TOTAL,'invalid archive')
 need(digest(archive.read_bytes())==expected_hash,'artifact digest mismatch')
 payload={}
 with zipfile.ZipFile(archive) as z:
  entries=z.infolist();names=[e.filename for e in entries]
  need(len(entries)<=MAX_FILES+1 and len(set(names))==len(names),'duplicate or excessive ZIP members')
  need('release-manifest.json' in names,'manifest missing')
  need(sum(e.file_size for e in entries)<=MAX_TOTAL and all(e.file_size<=MAX_FILE for e in entries),'expanded archive too large')
  for e in entries:
   need(not e.is_dir() and not e.flag_bits & 1 and stat.S_IFMT(e.external_attr>>16) in (0,stat.S_IFREG),'unsupported ZIP member')
  manifest=parse(z.read('release-manifest.json'))
  exact(manifest,{'schemaVersion','candidateSha','runId','files'})
  need(type(manifest['schemaVersion']) is int and manifest['schemaVersion']==1 and manifest['candidateSha']==commit and manifest['runId']==run_id,'candidate/run mismatch')
  need(type(manifest['files']) is list and 0<len(manifest['files'])<=MAX_FILES,'invalid inventory')
  recorded=set()
  for entry in manifest['files']:
   exact(entry,{'path','bytes','sha256'});name=safe_path(entry['path'])
   need(name not in recorded and type(entry['bytes']) is int and 0<=entry['bytes']<=MAX_FILE,'duplicate/invalid record')
   need(type(entry['sha256']) is str and re.fullmatch('[0-9a-f]{64}',entry['sha256']),'invalid digest')
   recorded.add(name);need(name in names,'recorded file missing');data=z.read(name)
   need(len(data)==entry['bytes'] and digest(data)==entry['sha256'],'file digest mismatch');payload[name]=data
  need(set(names)==recorded|{'release-manifest.json'},'unrecorded file')
  need(set(CONTROL)<=recorded and '.open-next/worker.js' in recorded,'control files missing')
 if destination is not None:
  need(destination.is_dir() and not destination.is_symlink(),'destination checkout required')
  # Never replace a reviewed control file. Verify checkout context before extraction.
  for name in CONTROL:need(regular(destination,name).read_bytes()==payload[name],'checkout control differs')
  need(not (destination/'.open-next').exists() and not (destination/'.open-next').is_symlink(),'OpenNext destination already exists')
  with tempfile.TemporaryDirectory(prefix='.verified-release-',dir=destination) as temp:
   staging=Path(temp)
   for name,data in payload.items():
    if name.startswith('.open-next/'):
     target=staging/name;target.parent.mkdir(parents=True,exist_ok=True)
     with target.open('xb') as f:f.write(data)
   os.replace(staging/'.open-next',destination/'.open-next')
 return {'verified':True,'candidateSha':commit,'runId':run_id,'files':len(payload),'extracted':destination is not None}
def main():
 parser=argparse.ArgumentParser(description=__doc__);sub=parser.add_subparsers(dest='command',required=True)
 s=sub.add_parser('seal');s.add_argument('--web',type=Path,required=True);s.add_argument('--output',type=Path,required=True)
 v=sub.add_parser('verify');v.add_argument('--archive',type=Path,required=True);v.add_argument('--sha256',required=True);v.add_argument('--extract-to',type=Path)
 for p in (s,v):p.add_argument('--candidate',required=True);p.add_argument('--run-id',required=True)
 args=parser.parse_args()
 try:
  result=seal(args.web,args.output,args.candidate,args.run_id) if args.command=='seal' else verify(args.archive,args.sha256,args.candidate,args.run_id,args.extract_to)
  print(json.dumps(result,sort_keys=True));return 0
 except (ArtifactError,OSError,zipfile.BadZipFile,KeyError) as e:
  print(json.dumps({'error':str(e),'verified':False}),file=sys.stderr);return 1
if __name__=='__main__':sys.exit(main())
