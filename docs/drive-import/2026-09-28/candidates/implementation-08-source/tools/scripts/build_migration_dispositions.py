#!/usr/bin/env python3
"""Generate a complete review ledger from the existing read-only inventory files.

No live queries, secret values, record exports, or automatic retirements. A new
or changed object is unresolved. Existing decisions survive only when identity
and source metadata fingerprints still match exactly.
"""
from __future__ import annotations
import argparse
import collections
import hashlib
import json
import pathlib
import sys

SECTIONS = ('relations','functions','policies','triggers','indexes','storage_buckets',
            'cron_jobs','deployed_edge_functions','edge_secret_names','extensions')
DISPOSITIONS = {'unresolved','migrate','replace','retain-temporarily','archive','retire'}


def digest(value):
    return hashlib.sha256(json.dumps(value,sort_keys=True,separators=(',',':'),ensure_ascii=False).encode()).hexdigest()


def build(remote, local, previous=None):
    if not isinstance(remote,dict) or remote.get('query_mode')!='read_only' or remote.get('failures') != {} or not isinstance(remote.get('project_ref'),str) or not remote['project_ref']:
        raise RuntimeError('A successful read-only inventory with no missing sections is required')
    queries=remote.get('queries')
    if not isinstance(queries,dict) or any(not isinstance(queries.get(name),list) for name in SECTIONS):
        raise RuntimeError('Incomplete catalog inventory')
    if not isinstance(local,dict) or not isinstance(local.get('edge_functions'),list):
        raise RuntimeError('Local function inventory required')
    prior={}
    if previous is not None:
        if not isinstance(previous,dict) or previous.get('schemaVersion')!=1:raise RuntimeError('Invalid previous disposition ledger')
        if previous.get('sourceProjectRef') != remote['project_ref']:raise RuntimeError('Previous ledger belongs to another source project')
        for row in previous.get('objects',[]):
            if not isinstance(row,dict) or not isinstance(row.get('key'),str) or row['key'] in prior:
                raise RuntimeError('Malformed or duplicate prior disposition')
            prior[row['key']]=row
    objects=[];seen=set(); live_functions=set()
    for kind in SECTIONS:
        for value in queries[kind]:
            row={'name':value} if kind=='edge_secret_names' else value
            if not isinstance(row,dict):raise RuntimeError(f'Malformed object in {kind}')
            name=row.get('name') or row.get('slug') or row.get('bucket_id')
            if not isinstance(name,str) or not name:raise RuntimeError(f'Missing object identity in {kind}')
            if kind=='deployed_edge_functions':
                name=row.get('slug') or name;live_functions.add(name)
            identity=[remote['project_ref'],kind,row.get('schema'),row.get('table_name'),name,row.get('arguments')]
            key=digest(identity); fingerprint=digest(row)
            if key in seen:raise RuntimeError('Duplicate live catalog identity')
            seen.add(key)
            decision=prior.get(key)
            preserve=decision and decision.get('sourceFingerprint')==fingerprint
            disposition=decision.get('disposition') if preserve else 'unresolved'
            if disposition not in DISPOSITIONS:raise RuntimeError('Invalid prior disposition')
            objects.append({'key':key,'kind':kind,'schema':row.get('schema'),'table':row.get('table_name'),
              'name':name,'arguments':row.get('arguments'),'sourceFingerprint':fingerprint,
              'localEntrypointPresent':name in local['edge_functions'] if kind=='deployed_edge_functions' else None,
              'disposition':disposition,'owner':decision.get('owner') if preserve else None,
              'destination':decision.get('destination') if preserve else None,
              'approvalEvidence':decision.get('approvalEvidence',[]) if preserve else [],
              'contractEvidence':decision.get('contractEvidence',[]) if preserve else [],
              'sourceChangedSinceDecision':bool(decision and not preserve)})
    for name in sorted(set(local['edge_functions'])-live_functions):
        if not isinstance(name,str) or not name:raise RuntimeError('Malformed local entrypoint')
        key=digest([remote['project_ref'],'local-only-edge-function',name]);seen.add(key)
        fingerprint=digest({'name':name,'deployed':False})
        decision=prior.get(key)
        preserve=decision and decision.get('sourceFingerprint')==fingerprint
        disposition=decision.get('disposition') if preserve else 'unresolved'
        if disposition not in DISPOSITIONS:raise RuntimeError('Invalid local-only disposition')
        objects.append({'key':key,'kind':'local-only-edge-function','name':name,'schema':None,'table':None,
          'arguments':None,'sourceFingerprint':fingerprint,
          'localEntrypointPresent':True,'disposition':disposition,'owner':decision.get('owner') if preserve else None,
          'destination':decision.get('destination') if preserve else None,
          'approvalEvidence':decision.get('approvalEvidence',[]) if preserve else [],
          'contractEvidence':decision.get('contractEvidence',[]) if preserve else [],'sourceChangedSinceDecision':bool(decision and not preserve)})
    objects.sort(key=lambda row:(row['kind'],row.get('schema') or '',row.get('table') or '',row['name'],row.get('arguments') or ''))
    disappeared=[key for key in prior if key not in seen]
    # Absence from the newest inventory is not proof of safe retirement.
    return {'schemaVersion':1,'sourceProjectRef':remote['project_ref'],'sourceCapturedAt':remote.get('captured_at_utc'),
      'sourceInventoryDigest':digest(remote),'localInventoryDigest':digest(local),
      'summary':dict(sorted(collections.Counter(row['kind'] for row in objects).items())),
      'objects':objects,'previousObjectsAbsentFromInventory':disappeared,
      'unresolvedObjects':sum(row['disposition']=='unresolved' or not row['owner'] or not row['approvalEvidence'] or not row['contractEvidence'] for row in objects),
      'retirementAuthorized':False,'liveStateRecheckedByThisTool':False}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--remote',type=pathlib.Path,required=True)
    parser.add_argument('--local',type=pathlib.Path,required=True)
    parser.add_argument('--previous',type=pathlib.Path)
    parser.add_argument('--output',type=pathlib.Path,required=True)
    parser.add_argument('--require-resolved',action='store_true')
    args=parser.parse_args()
    read=lambda p:json.loads(p.read_text(encoding='utf-8'))
    result=build(read(args.remote),read(args.local),read(args.previous) if args.previous else None)
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(result,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
    args.output.chmod(0o600)
    print(json.dumps({'objects':len(result['objects']),'unresolved':result['unresolvedObjects'],
                      'sourceCapturedAt':result['sourceCapturedAt'],'summary':result['summary'],
                      'retirementAuthorized':False},indent=2))
    return 1 if args.require_resolved and (result['unresolvedObjects'] or result['previousObjectsAbsentFromInventory']) else 0

if __name__=='__main__':
    try:sys.exit(main())
    except (RuntimeError,OSError,ValueError,TypeError,KeyError) as error:print(str(error),file=sys.stderr);sys.exit(2)
