#!/usr/bin/env python3
"""Read-only, dependency-aware closure planner. Never executes task text or grants approval.

Dependencies mean closure prerequisites, not a prohibition on parallel source work.
Reported approvals are declarations only: validate candidate-bound evidence separately
with release_evidence.py and obtain actual accountable human/environment acceptance.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import re
from collections import Counter
from pathlib import Path
from migration_compare import read_snapshot, canonical

ID = re.compile(r'[A-Z]{3}-[0-9]{2}\Z')
PRIORITY = {'P0': 0, 'P1': 1, 'P2': 2}
STATUS = {'Open', 'In progress', 'Closed'}
MAX_TASKS = 1000

class InvalidRegister(ValueError):
    pass


def plan(register: dict) -> dict:
    tasks = register.get('tasks') if type(register) is dict else None
    if type(tasks) is not list or not 1 <= len(tasks) <= MAX_TASKS:
        raise InvalidRegister('invalid_task_list')
    by_id = {}
    dependencies = {}
    issues = []
    for item in tasks:
        if type(item) is not dict:
            raise InvalidRegister('invalid_task')
        key = item.get('id')
        if type(key) is not str or not ID.fullmatch(key) or key in by_id:
            raise InvalidRegister('invalid_or_duplicate_id')
        if type(item.get('priority')) is not str or type(item.get('status')) is not str or item['priority'] not in PRIORITY or item['status'] not in STATUS:
            raise InvalidRegister('invalid_priority_or_status')
        for field in ('task', 'workstream', 'owner_role', 'acceptance_evidence'):
            if type(item.get(field)) is not str or not item[field].strip():
                raise InvalidRegister('missing_required_text')
        if type(item.get('release_accepted')) is not bool:
            raise InvalidRegister('invalid_acceptance_flag')
        for field in ('assigned_owner', 'closure_link'):
            if type(item.get(field, '')) is not str:
                raise InvalidRegister('invalid_assignment_or_closure')
        raw = item.get('dependencies')
        if type(raw) is not str:
            raise InvalidRegister('invalid_dependencies')
        parts = [] if not raw.strip() else [part.strip() for part in raw.split(';')]
        if any(not ID.fullmatch(part) for part in parts) or len(set(parts)) != len(parts):
            raise InvalidRegister('malformed_dependencies')
        by_id[key] = item
        dependencies[key] = parts
    for key, deps in dependencies.items():
        for dep in deps:
            if dep not in by_id:
                issues.append({'taskId': key, 'code': 'missing_dependency', 'dependencyId': dep})
    # Deterministic Kahn layers preserve priority within each layer.
    def order(key):
        return PRIORITY[by_id[key]['priority']], key
    pending = set(by_id)
    visited = set()
    layers = []
    while pending:
        ready = sorted((key for key in pending if all(dep in visited for dep in dependencies[key])), key=order)
        if not ready:
            break
        layers.append(ready)
        visited.update(ready)
        pending.difference_update(ready)
    # Distinguish a real cycle from downstream blockage and missing-input blockage.
    reach = {k: set(d for d in dependencies[k] if d in by_id) for k in by_id}
    for middle in by_id:
        for key in by_id:
            if middle in reach[key]:
                reach[key] |= reach[middle]
    cyclic = sorted(k for k in by_id if k in reach[k])
    for key in cyclic:
        issues.append({'taskId': key, 'code': 'dependency_cycle'})
    accepted = set()
    for key, item in by_id.items():
        if item['status'] == 'Closed' or item['release_accepted']:
            fields_present = all(type(item.get(f)) is str and item[f].strip() for f in ('assigned_owner', 'closure_link'))
            if item['status'] != 'Closed' or not item['release_accepted'] or not fields_present:
                issues.append({'taskId': key, 'code': 'unsubstantiated_closure_declaration'})
            else:
                accepted.add(key)
    for key in accepted:
        if any(dep not in accepted for dep in dependencies[key]):
            issues.append({'taskId': key, 'code': 'accepted_with_unaccepted_dependencies'})
    rows = []
    for key in sorted(by_id, key=order):
        item = by_id[key]
        rows.append({'id': key, 'task': item['task'], 'priority': item['priority'],
                     'workstream': item['workstream'], 'status': item['status'], 'ownerRole': item['owner_role'],
                     'namedOwnerAssigned': bool(item.get('assigned_owner', '').strip()),
                     'dependencies': dependencies[key],
                     'unacceptedDependencies': [d for d in dependencies[key] if d not in accepted],
                     'closureEvidenceRequired': item['acceptance_evidence'],
                     'dependencyLayer': next((i for i, layer in enumerate(layers) if key in layer), None),
                     'releaseAcceptedDeclared': item['release_accepted']})
    return {'schemaVersion': 1, 'sourceRegisterSha256': hashlib.sha256(canonical(register)).hexdigest(),
            'scope': 'closure_prerequisites_not_an_implementation_or_approval_engine',
            'tasks': rows, 'counts': {'tasks': len(tasks), 'priorities': dict(Counter(t['priority'] for t in tasks)),
            'statuses': dict(Counter(t['status'] for t in tasks)), 'namedOwnersMissing': sum(not r['namedOwnerAssigned'] for r in rows)},
            'dependencyLayers': layers, 'cyclicTaskIds': cyclic,
            'unscheduledTaskIds': sorted(pending), 'issues': issues,
            'sourceWorkMayProceedBeforeClosure': True, 'approvalEvidenceVerified': False,
            'releaseAuthorized': False, 'remoteChanges': 0}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--register', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    try:
        if args.output.exists() or args.output.is_symlink() or args.output.resolve() == args.register.resolve():
            raise InvalidRegister('output_exists')
        result = plan(read_snapshot(args.register))
        import os
        fd = os.open(args.output, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(fd, 'w') as stream:
            stream.write(json.dumps(result, indent=2) + '\n')
        print(json.dumps({'tasks': result['counts']['tasks'], 'issues': len(result['issues']), 'releaseAuthorized': False}))
        return 1 if result['issues'] else 0
    except (ValueError, OSError, TypeError, AttributeError):
        print(json.dumps({'status': 'invalid_register_or_output', 'releaseAuthorized': False}))
        return 1

if __name__ == '__main__':
    raise SystemExit(main())
