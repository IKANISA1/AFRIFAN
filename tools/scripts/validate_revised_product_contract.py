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
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
paths = subprocess.check_output(['git', 'ls-files', '--cached', '--others', '--exclude-standard', '-z'], cwd=ROOT).decode().split('\0')
retired = re.compile(r'/fanzone(?:[/\s?\'"`]|$)|/challenge(?:[/\s?\'"`]|$)|\b(?:FanzoneModule|FanZoneModule|activate_free_fan_membership(?:_for_club)?|submit_membership_application|(?:admin_)?review_membership_application(?:_if_unchanged)?|membership_qualification_v1)\b', re.I)
label = re.compile(r'''["'](?:[^"'\n]*\s)?Chapters?\b[^"'\n]*["']|>\s*Chapters?\s*<''')
problems = []
count = 0
mobile_collection = re.compile(
    r'\bsms\b|sms_|_sms|(?-i:[a-z]Sms|Sms[A-Z])|another_telephony|'
    r'telephony\.dart|SmsReceiver|READ_SMS|RECEIVE_SMS|SEND_SMS', re.I
)
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
    native = name.startswith('packages/') or (
        name.startswith('apps/') and '/web/' not in name
    )
    for index, line in enumerate(source.splitlines(), 1):
        if retired.search(line): problems.append(f'{name}:{index}: retired route or membership API')
        if label.search(line): problems.append(f'{name}:{index}: retired display label')
        # This SDK protocol name verifies phone codes delivered through WhatsApp;
        # it neither reads messages nor selects carrier delivery.
        phone_verification = (
            name == 'packages/core/core_auth/lib/src/auth_repository.dart'
            and 'type: OtpType.sms)' in line
        )
        if native and mobile_collection.search(line) and not phone_verification:
            problems.append(f'{name}:{index}: message collection belongs to the management gateway')
    if path.suffix == '.arb':
        for key, value in json.loads(source).items():
            if isinstance(value, str) and re.search(r'\bchapters?\b|pending verification|free (?:fan |membership )?tier', value, re.I):
                # Ticket lifecycle copy is outside the revised membership scope.
                if not key.startswith('ticket'):
                    problems.append(f'{name}:{key}: retired product copy')
for club in ('rayon_sports', 'vitalo', 'nkana', 'as_vita', 'costa_do_sol'):
    if not (ROOT / 'apps' / club / 'pubspec.yaml').is_file():
        problems.append(f'apps/{club}: supported club app missing')
    for manifest in (ROOT / 'apps' / club / 'android' / 'app' / 'src').glob('*/AndroidManifest.xml'):
        tree = ET.parse(manifest)
        for element in tree.iter():
            value = element.get('{http://schemas.android.com/apk/res/android}name', '')
            if re.search(r'(?:READ|RECEIVE|SEND|WRITE)_SMS|RECEIVE_(?:MMS|WAP_PUSH)|SMS_(?:RECEIVED|DELIVER)|(?:Sms|Mms)Receiver', value):
                problems.append(f'{manifest.relative_to(ROOT)}: forbidden message permission or receiver: {value}')

for name in paths:
    path = ROOT / name
    if path.is_file() and (name.endswith('/pubspec.yaml') or name in {'pubspec.yaml', 'pubspec.lock'}):
        if re.search(r'feat_sms_ledger|another_telephony|\bsms_autofill\b|\btelephony\b', path.read_text()):
            problems.append(f'{name}: forbidden mobile collector dependency')
if (ROOT / 'packages/features/feat_sms_ledger').exists():
    problems.append('Retired mobile collector package still exists')
if problems:
    print('\n'.join(problems)); sys.exit(1)
print(f'PASS revised product contract: {count} runtime source files; five club apps without message collection; Predict-only routes; paid-membership APIs; FanClubs display copy.')
