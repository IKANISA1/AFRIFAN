#!/usr/bin/env python3
"""Prevent retired product routes, APIs and labels from returning to runtime code.
Applied SQL history and explicit negative tests are intentionally outside this
source guard; database contracts separately test the forward migration boundary.
"""
from pathlib import Path
import json
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
paths = subprocess.check_output(['git', 'ls-files', '--cached', '--others', '--exclude-standard', '-z'], cwd=ROOT).decode().split('\0')
retired = re.compile(r'/fanzone(?:[/\s?\'"`]|$)|/challenge(?:[/\s?\'"`]|$)|\b(?:FanzoneModule|FanZoneModule|activate_free_fan_membership(?:_for_club)?|submit_membership_application|(?:admin_)?review_membership_application(?:_if_unchanged)?|membership_qualification_v1)\b', re.I)
label = re.compile(r'''["'](?:[^"'\n]*\s)?Chapters?\b[^"'\n]*["']|>\s*Chapters?\s*<''')
problems = []
count = 0
for name in sorted(set(paths)):
    path = ROOT / name
    if not path.is_file() or path.suffix not in {'.dart', '.ts', '.tsx', '.arb'}:
        continue
    if not (name.startswith('packages/') and '/lib/' in name or name.startswith('apps/') and '/lib/' in name or name.startswith('apps/rayon_sports/web/src/') or name.startswith('supabase/functions/')):
        continue
    if re.search(r'(?:\.test\.|_test\.|/test/|/tests/)', name):
        continue
    count += 1
    source = path.read_text()
    for index, line in enumerate(source.splitlines(), 1):
        if retired.search(line): problems.append(f'{name}:{index}: retired route or membership API')
        if label.search(line): problems.append(f'{name}:{index}: retired display label')
    if path.suffix == '.arb':
        for key, value in json.loads(source).items():
            if isinstance(value, str) and re.search(r'\bchapters?\b|pending verification|free (?:fan |membership )?tier', value, re.I):
                # Ticket lifecycle copy is outside the revised membership scope.
                if not key.startswith('ticket'):
                    problems.append(f'{name}:{key}: retired product copy')
for club in ('rayon_sports', 'vitalo', 'nkana', 'as_vita'):
    if not (ROOT / 'apps' / club / 'pubspec.yaml').is_file():
        problems.append(f'apps/{club}: supported club app missing')
if problems:
    print('\n'.join(problems)); sys.exit(1)
print(f'PASS revised product contract: {count} runtime source files; four club apps; Predict-only routes; paid-membership APIs; FanClubs display copy.')
