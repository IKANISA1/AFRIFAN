#!/usr/bin/env python3
"""Fail-closed evidence-package validator. Never deploys, resets, deletes, or switches writers.

A pass checks candidate identity, completeness, freshness, and artifact hashes.
It does not independently verify the truth of evidence or authenticate reviewers.
Approval remains with accountable owners and the governed deployment process.
"""
from __future__ import annotations
import argparse
import datetime as dt
import hashlib
import json
import pathlib
import re
import sys

CUTOVER_GATES = (
 'consistent_backup_restore','complete_original_media_export','identity_session_migration',
 'tenant_and_role_authorization','transaction_concurrency_failure_tests','ledger_entitlement_ticket_parity',
 'function_behavior_dispositions','scheduled_job_dispositions','queue_retry_and_dead_letter_recovery',
 'public_content_rights_and_refresh','old_client_minimum_version','five_club_device_acceptance',
 'web_member_admin_acceptance','monitoring_and_restore','capacity_locality_cost',
 'prediction_economics_approval','write_freeze_final_delta_reconciliation','accountable_cutover_approval',
)
RETIRE_GATES = CUTOVER_GATES + (
 'observation_window_complete','no_runtime_supabase_dependency','retention_and_export_approved',
 'old_jobs_functions_disabled_keys_revoked',
)
HEX = re.compile(r'^[a-f0-9]{64}$')


def timestamp(value):
    if not isinstance(value,str): raise ValueError('Missing timestamp')
    result = dt.datetime.fromisoformat(value.replace('Z','+00:00'))
    if result.tzinfo is None: raise ValueError('Timezone required')
    return result


def safe_artifact(root: pathlib.Path, item: dict) -> str | None:
    if not isinstance(item,dict) or not isinstance(item.get('path'),str) or not HEX.fullmatch(str(item.get('sha256',''))):
        return 'Malformed evidence artifact reference'
    relative = pathlib.PurePosixPath(item['path'])
    if relative.is_absolute() or relative.as_posix() != item['path'] or any(p in ('','.','..') for p in item['path'].split('/')) or '\\' in item['path'] or not relative.parts:
        return 'Evidence path escapes evidence root'
    target = root.joinpath(*relative.parts)
    cursor = root
    for part in relative.parts:
        cursor = cursor / part
        if cursor.is_symlink(): return 'Evidence symlink is not allowed'
    if not target.is_file(): return f'Missing evidence artifact: {item["path"]}'
    if hashlib.sha256(target.read_bytes()).hexdigest() != item['sha256']:
        return f'Evidence hash mismatch: {item["path"]}'
    return None


def validate(record: dict, root: pathlib.Path, candidate: str, stage: str,
             now: dt.datetime | None = None) -> list[str]:
    now = now or dt.datetime.now(dt.timezone.utc); errors=[]
    if root.is_symlink(): return ['Evidence root symlink is not allowed']
    root=root.resolve()
    if stage not in ('cutover','retire'): return ['Unknown release stage']
    if not isinstance(record,dict) or type(record.get('schemaVersion')) is not int or record.get('schemaVersion') != 1: return ['Invalid release evidence schema']
    if not re.fullmatch(r'(?:[a-f0-9]{40}|[a-f0-9]{64})',candidate) or record.get('candidateId') != candidate:
        errors.append('Candidate identity mismatch or invalid candidate ID')
    if record.get('stage') != stage: errors.append('Evidence stage does not match requested operation')
    if record.get('singleWriter') is not True: errors.append('Exactly one authoritative financial writer is required')
    expected_writer='supabase' if stage=='cutover' else 'cloudflare'
    if record.get('authoritativeWriter') != expected_writer: errors.append('Unexpected authoritative writer for this stage')
    if stage=='cutover' and record.get('cloudflareFinancialWritesStarted') is not False:
        errors.append('A simple pre-write cutover cannot be used after target financial writes; reconcile forward recovery')
    if stage=='retire' and record.get('cloudflareFinancialWritesStarted') is not True:
        errors.append('Cloudflare financial authority has not been evidenced')
    gates=record.get('gates'); required=RETIRE_GATES if stage=='retire' else CUTOVER_GATES
    if not isinstance(gates,list): return errors+['Missing release gates']
    indexed={}
    for gate in gates:
        if not isinstance(gate,dict) or not isinstance(gate.get('id'),str): errors.append('Malformed gate'); continue
        if gate['id'] not in required: errors.append('Unknown release gate'); continue
        if gate['id'] in indexed: errors.append(f'Duplicate gate: {gate["id"]}')
        indexed[gate['id']]=gate
    for name in required:
        gate=indexed.get(name)
        if not gate or gate.get('passed') is not True:
            errors.append(f'Unproven release gate: {name}'); continue
        if gate.get('candidateId') != candidate: errors.append(f'{name}: evidence belongs to another candidate')
        try:
            observed=timestamp(gate.get('observedAt'))
            if not dt.timedelta(minutes=-5) <= now-observed <= dt.timedelta(hours=24):
                errors.append(f'{name}: stale or future evidence')
        except ValueError: errors.append(f'{name}: invalid observation timestamp')
        if not isinstance(gate.get('reviewer'),str) or not gate['reviewer'].strip(): errors.append(f'{name}: reviewer missing')
        artifacts=gate.get('artifacts')
        if not isinstance(artifacts,list) or not artifacts: errors.append(f'{name}: inspectable evidence artifacts required'); continue
        for item in artifacts:
            error=safe_artifact(root,item)
            if error:errors.append(f'{name}: {error}')
    return errors


def template(stage='cutover'):
    return {'schemaVersion':1,'candidateId':None,'stage':stage,'singleWriter':None,
            'authoritativeWriter':None,'cloudflareFinancialWritesStarted':None,
            'gates':[{'id':name,'passed':False,'candidateId':None,'observedAt':None,
                      'reviewer':None,'artifacts':[]} for name in (RETIRE_GATES if stage=='retire' else CUTOVER_GATES)]}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--stage',choices=['cutover','retire'],default='cutover')
    parser.add_argument('--template',action='store_true')
    parser.add_argument('--evidence',type=pathlib.Path)
    parser.add_argument('--evidence-root',type=pathlib.Path)
    parser.add_argument('--candidate')
    args=parser.parse_args()
    if args.template: print(json.dumps(template(args.stage),indent=2));return 0
    if not args.evidence or not args.candidate:parser.error('--evidence and --candidate are required')
    record=json.loads(args.evidence.read_text(encoding='utf-8'))
    errors=validate(record,args.evidence_root or args.evidence.parent,args.candidate,args.stage)
    print(json.dumps({'evidencePackageValid':not errors,'stage':args.stage,'candidateId':args.candidate,
                      'errors':errors,'deploymentPerformed':False,'reviewerIdentityAuthenticated':False},indent=2))
    return 1 if errors else 0

if __name__=='__main__':
    try:sys.exit(main())
    except (ValueError,OSError,TypeError) as error:print(str(error),file=sys.stderr);sys.exit(2)
