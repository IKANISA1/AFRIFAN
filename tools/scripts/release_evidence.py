#!/usr/bin/env python3
"""Validate exact-candidate release declarations. Does NOT prove their truth or deploy.
Supply via the reviewed protected-environment variable, never from client input.
"""
from __future__ import annotations
import json,os,re,sys,time
from release_artifact import ArtifactError,need,exact,parse
REQUIRED=frozenset({'source_access_restricted','exposed_credentials_resolved','real_runtime_verified',
 'privacy_storage_approved','full_user_journeys_accepted','backup_restore_accepted',
 'payment_history_reconciled','single_writer_plan_approved','rollback_rehearsed',
 'monitoring_and_support_ready','brand_and_content_rights_approved','store_policy_approved'})
def validate(raw:str,commit:str,artifact:str,now_ms:int|None=None):
 need(type(raw) is str and 0<len(raw.encode())<=32768,'release acceptance missing or oversized')
 need(re.fullmatch('[0-9a-f]{40}',commit or '') is not None and re.fullmatch('[0-9a-f]{64}',artifact or '') is not None,'invalid expected candidate')
 value=parse(raw.encode());exact(value,{'schemaVersion','candidateSha','artifactSha256','expiresAtMs','checks'})
 need(type(value['schemaVersion']) is int and value['schemaVersion']==1,'invalid schema')
 need(value['candidateSha']==commit and value['artifactSha256']==artifact,'release approval candidate differs')
 now=int(time.time()*1000) if now_ms is None else now_ms
 need(type(value['expiresAtMs']) is int and now<value['expiresAtMs']<=now+86400000,'acceptance expired or excessive lifetime')
 need(type(value['checks']) is list and len(value['checks'])==len(REQUIRED),'required checks missing')
 seen=set()
 for item in value['checks']:
  exact(item,{'id','status','reviewer','evidenceRef','verifiedAtMs'})
  need(item['id'] in REQUIRED and item['id'] not in seen,'unknown/duplicate check');seen.add(item['id'])
  need(item['status']=='approved','check not approved')
  need(type(item['reviewer']) is str and re.fullmatch('[A-Za-z0-9_.@-]{3,120}',item['reviewer']),'reviewer missing')
  need(type(item['evidenceRef']) is str and re.fullmatch('[A-Za-z0-9_./:#-]{6,240}',item['evidenceRef']),'evidence reference missing')
  need(type(item['verifiedAtMs']) is int and now-86400000<=item['verifiedAtMs']<=now,'verification stale or future')
 need(seen==REQUIRED,'required checks missing')
 return {'validated':True,'candidateSha':commit,'checks':len(seen),'evidenceTruthIndependentlyVerified':False}
if __name__=='__main__':
 try:print(json.dumps(validate(os.environ.get('RELEASE_ACCEPTANCE_JSON',''),os.environ.get('EXPECTED_SHA',''),os.environ.get('EXPECTED_ARTIFACT',''))))
 except (ArtifactError,ValueError,TypeError) as e:print(json.dumps({'validated':False,'error':str(e)}),file=sys.stderr);sys.exit(1)
