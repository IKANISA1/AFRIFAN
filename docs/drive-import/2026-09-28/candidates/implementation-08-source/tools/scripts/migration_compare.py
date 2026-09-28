#!/usr/bin/env python3
"""Compare two bounded, explicitly normalized export snapshots without mutating either.

Input is NOT a live database export or a proof that extraction was complete. Use an
approved normalizer, consistent cutoff and independently reviewed coverage manifest.
No source record values, keys, balances or filesystem paths are emitted on failure.
Exit 0: supplied snapshots match, 1: drift/invalid data, 2: unproven coverage/context.
"""
from __future__ import annotations
import argparse
import datetime as dt
import hashlib
import json
import re
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any

MAX_BYTES = 32 * 1024 * 1024
MAX_ROWS = 100_000
MAX_ISSUES = 50
NAME = re.compile(r'[a-z][a-z0-9_]{0,63}\Z')
SHA = re.compile(r'[a-f0-9]{64}\Z')
INT = re.compile(r'(?:0|-[1-9][0-9]{0,119}|[1-9][0-9]{0,119})\Z')
STAMP = re.compile(r'\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{3})?Z\Z')
KINDS = {'string', 'integer', 'decimal', 'boolean', 'timestamp', 'json'}

class InvalidSnapshot(ValueError):
    """Intentionally carries a fixed diagnostic, never an input value."""


def _require(ok: bool, code: str) -> None:
    if not ok:
        raise InvalidSnapshot(code)


def _pairs(pairs):
    result = {}
    for key, value in pairs:
        _require(key not in result, 'duplicate_json_key')
        result[key] = value
    return result


def canonical(value: Any) -> bytes:
    return json.dumps(value, ensure_ascii=True, sort_keys=True, separators=(',', ':'), allow_nan=False).encode()


def _json_value(value: Any, depth: int = 0) -> None:
    _require(depth <= 32, 'json_depth')
    if value is None or type(value) is bool:
        return
    if type(value) is int:
        _require(len(str(value)) <= 120, 'json_integer_range')
        return
    if type(value) is str:
        _require(len(value) <= 16384, 'string_length')
        return
    if type(value) is list:
        _require(len(value) <= 1024, 'json_list_length')
        for item in value:
            _json_value(item, depth + 1)
        return
    if type(value) is dict:
        _require(len(value) <= 256 and all(type(k) is str and len(k) <= 128 for k in value), 'json_keys')
        for item in value.values():
            _json_value(item, depth + 1)
        return
    raise InvalidSnapshot('unsupported_value_type')


def _timestamp(value: Any) -> None:
    _require(type(value) is str and bool(STAMP.fullmatch(value)), 'timestamp_format')
    try:
        dt.datetime.fromisoformat(value.replace('Z', '+00:00'))
    except ValueError:
        raise InvalidSnapshot('timestamp_value') from None


def _value(value: Any, spec: dict) -> Any:
    if value is None:
        _require(spec['nullable'], 'null_not_allowed')
        return None
    kind = spec['type']
    if kind == 'string':
        _require(type(value) is str and len(value) <= 16384, 'string_type_or_length')
    elif kind == 'integer':
        # Decimal strings are deliberate: JSON/JavaScript numeric coercion is forbidden.
        _require(type(value) is str and bool(INT.fullmatch(value)), 'integer_format')
    elif kind == 'decimal':
        scale = spec['scale']
        _require(type(value) is str and len(value) <= 140, 'decimal_format')
        pattern = r'-?(?:0|[1-9][0-9]{0,119})' + (rf'\.[0-9]{{{scale}}}' if scale else '') + r'\Z'
        _require(bool(re.fullmatch(pattern, value)), 'decimal_format')
        _require(not (value.startswith('-') and int(value.replace('.', '')) == 0), 'negative_zero')
    elif kind == 'boolean':
        _require(type(value) is bool, 'boolean_format')
    elif kind == 'timestamp':
        _timestamp(value)
    else:
        _json_value(value)
    return value


def read_snapshot(path: Path) -> dict:
    try:
        _require(not path.is_symlink() and path.is_file(), 'not_regular_file')
        with path.open('rb') as stream:
            raw = stream.read(MAX_BYTES + 1)
        _require(len(raw) <= MAX_BYTES, 'snapshot_size')
        def reject(_):
            raise InvalidSnapshot('nonfinite_json')
        result = json.loads(raw, object_pairs_hook=_pairs, parse_constant=reject)
        _require(type(result) is dict, 'snapshot_object')
        return result
    except InvalidSnapshot:
        raise
    except (ValueError, OSError, UnicodeError, RecursionError):
        raise InvalidSnapshot('unreadable_snapshot') from None


def validate(snapshot: dict) -> dict:
    keys = {'schemaVersion', 'dataset', 'normalizationVersion', 'cutoff', 'scopeSha256',
            'completeDeclared', 'expectedRows', 'fields', 'keyFields', 'money', 'rows'}
    _require(type(snapshot) is dict and set(snapshot) == keys, 'snapshot_fields')
    _require(type(snapshot['schemaVersion']) is int and snapshot['schemaVersion'] == 1, 'snapshot_version')
    _require(type(snapshot['dataset']) is str and bool(NAME.fullmatch(snapshot['dataset'])), 'dataset_id')
    _require(type(snapshot['normalizationVersion']) is str and bool(NAME.fullmatch(snapshot['normalizationVersion'])), 'normalization_version')
    _timestamp(snapshot['cutoff'])
    _require(type(snapshot['scopeSha256']) is str and bool(SHA.fullmatch(snapshot['scopeSha256'])), 'scope_digest')
    _require(type(snapshot['completeDeclared']) is bool, 'coverage_flag')
    _require(type(snapshot['expectedRows']) is int and 0 <= snapshot['expectedRows'] <= MAX_ROWS, 'expected_rows')
    fields = snapshot['fields']
    _require(type(fields) is dict and 1 <= len(fields) <= 128, 'field_definitions')
    for name, spec in fields.items():
        _require(type(name) is str and bool(NAME.fullmatch(name)) and type(spec) is dict, 'field_definition')
        _require(spec.get('type') in KINDS and type(spec.get('nullable')) is bool, 'field_type')
        expected = {'type', 'nullable', 'scale'} if spec['type'] == 'decimal' else {'type', 'nullable'}
        _require(set(spec) == expected, 'field_options')
        if spec['type'] == 'decimal':
            _require(type(spec['scale']) is int and 0 <= spec['scale'] <= 12, 'decimal_scale')
    key_fields = snapshot['keyFields']
    _require(type(key_fields) is list and 1 <= len(key_fields) <= 8, 'key_fields')
    _require(all(type(k) is str and k in fields for k in key_fields) and len(set(key_fields)) == len(key_fields), 'key_fields')
    _require(all(not fields[k]['nullable'] and fields[k]['type'] not in ('json',) for k in key_fields), 'key_type')
    money = snapshot['money']
    _require(type(money) is list and len(money) <= 16, 'money_definitions')
    seen_money = set()
    for entry in money:
        _require(type(entry) is dict and set(entry) == {'field', 'currencyField'}, 'money_definition')
        a, b = entry['field'], entry['currencyField']
        _require(type(a) is str and type(b) is str and a in fields and b in fields, 'money_fields')
        _require(fields[a]['type'] in ('integer', 'decimal') and fields[b]['type'] == 'string', 'money_types')
        _require(not fields[a]['nullable'] and not fields[b]['nullable'] and (a, b) not in seen_money, 'money_nullable_or_duplicate')
        seen_money.add((a, b))
    rows = snapshot['rows']
    _require(type(rows) is list and len(rows) <= MAX_ROWS, 'row_limit')
    index = {}
    duplicates = 0
    totals = defaultdict(int)
    for row in rows:
        _require(type(row) is dict and set(row) == set(fields), 'row_fields')
        for name, spec in fields.items():
            _value(row[name], spec)
        key = canonical([row[k] for k in key_fields])
        if key in index:
            duplicates += 1
        index[key] = canonical(row)
        for entry in money:
            currency = row[entry['currencyField']]
            _require(bool(re.fullmatch(r'[A-Z]{3}', currency)), 'currency_format')
            totals[(entry['field'], currency)] += int(row[entry['field']].replace('.', ''))
    return {'index': index, 'duplicates': duplicates, 'totals': dict(totals), 'rowCount': len(rows),
            'countMatchesDeclaration': len(rows) == snapshot['expectedRows']}


def compare(source: dict, target: dict) -> dict:
    """Only compares supplied snapshots; output is deliberately data-minimized."""
    base = {'schemaVersion': 1, 'scope': 'supplied_normalized_snapshots_only',
            'coverageVerified': False, 'releaseAuthorized': False, 'databaseWrites': 0}
    try:
        left, right = validate(source), validate(target)
    except InvalidSnapshot as exc:
        return {**base, 'status': 'invalid_input', 'exitCode': 1, 'reason': str(exc)}
    except (TypeError, ValueError, RecursionError):
        return {**base, 'status': 'invalid_input', 'exitCode': 1, 'reason': 'invalid_snapshot'}
    envelope = ('dataset', 'normalizationVersion', 'cutoff', 'scopeSha256', 'fields', 'keyFields', 'money')
    differences = [k for k in envelope if source[k] != target[k]]
    if differences:
        return {**base, 'status': 'context_mismatch', 'exitCode': 2, 'contextFields': differences}
    a, b = set(left['index']), set(right['index'])
    counts = {'sourceRows': left['rowCount'], 'targetRows': right['rowCount'],
              'sourceDuplicateKeys': left['duplicates'], 'targetDuplicateKeys': right['duplicates'],
              'missingInTarget': len(a - b), 'extraInTarget': len(b - a),
              'changedRows': sum(left['index'][k] != right['index'][k] for k in a & b),
              'matchedRows': sum(left['index'][k] == right['index'][k] for k in a & b),
              'moneyGroupsCompared': len(set(left['totals']) | set(right['totals'])),
              'moneyGroupsDifferent': sum(left['totals'].get(k) != right['totals'].get(k)
                    for k in set(left['totals']) | set(right['totals']))}
    drift = any(counts[k] for k in ('sourceDuplicateKeys', 'targetDuplicateKeys', 'missingInTarget',
                                    'extraInTarget', 'changedRows', 'moneyGroupsDifferent'))
    declared = source['completeDeclared'] and target['completeDeclared'] and left['countMatchesDeclaration'] and right['countMatchesDeclaration']
    status = 'drift' if drift else 'coverage_unproven' if not declared else 'matching_supplied_snapshots'
    # These hashes bind the supplied normalized objects, not a live export signature.
    return {**base, 'status': status, 'exitCode': 1 if drift else 2 if not declared else 0,
            'contextSha256': hashlib.sha256(canonical({k: source[k] for k in envelope})).hexdigest(),
            'sourceNormalizedSha256': hashlib.sha256(canonical(source)).hexdigest(),
            'targetNormalizedSha256': hashlib.sha256(canonical(target)).hexdigest(),
            'coverageDeclarationsConsistent': declared, 'counts': counts}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--target', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    try:
        _require(args.output.resolve() not in (args.source.resolve(), args.target.resolve()), 'output_overwrites_input')
        _require(not args.output.exists() and not args.output.is_symlink(), 'output_exists')
        report = compare(read_snapshot(args.source), read_snapshot(args.target))
        # Exclusive/private creation, never overwrite an existing export or evidence file.
        import os
        fd = os.open(args.output, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(fd, 'w') as output:
            output.write(json.dumps(report, indent=2) + '\n')
        print(json.dumps({'status': report['status'], 'exitCode': report['exitCode']}))
        return report['exitCode']
    except (InvalidSnapshot, OSError):
        print(json.dumps({'status': 'invalid_input_or_output', 'exitCode': 1}))
        return 1

if __name__ == '__main__':
    raise SystemExit(main())
