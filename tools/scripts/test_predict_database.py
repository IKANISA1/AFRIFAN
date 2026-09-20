#!/usr/bin/env python3
"""Replay migrations and verify concurrent operations in a portless Postgres.
Requires Docker and the pinned Postgres, GoTrue and Storage images below.
Uses synthetic data only; no published ports, mounts or external network.
"""
import concurrent.futures
import json
import os
from pathlib import Path
import re
import subprocess
import time
import uuid

ROOT = Path(__file__).resolve().parents[2]
DOCKER = os.environ.get('DOCKER', 'docker')
NAME = 'africlub-predict-contract-' + uuid.uuid4().hex[:8]
IMAGE = 'public.ecr.aws/supabase/postgres:17.6.1.158'
PASSWORD = 'isolated-predict-contract'


def start_owned_container(name):
    try:
        subprocess.run([DOCKER, 'start', name], capture_output=True, text=True, check=True, timeout=15)
    except subprocess.TimeoutExpired:
        # Some Docker Desktop engines start the process but lose the start
        # acknowledgement. Recover only this run's labelled container and
        # still require the database/migrator health or exit checks below.
        meta = json.loads(subprocess.check_output([DOCKER, 'inspect', name], timeout=15))[0]
        if meta['Config']['Labels'].get('africlub.test') != 'database-concurrency' or meta['State']['Status'] not in ('running', 'exited'):
            raise
        print('Start acknowledgement timed out; verified owned container state:', name, meta['State']['Status'], flush=True)


def sql(query, *, admin=False, check=True):
    args = [DOCKER, 'exec', '-i']
    if admin:
        args += ['-e', 'PGPASSWORD=' + PASSWORD]
    args += [NAME, 'psql', '-X', '-At', '-v', 'ON_ERROR_STOP=1', '-U',
             'supabase_admin' if admin else 'postgres', '-d', 'postgres']
    if admin:
        args += ['-h', '127.0.0.1']
    result = subprocess.run(args, input=query, text=True, capture_output=True, timeout=120)
    if check and (result.returncode or re.search(r'^not ok ', result.stdout, re.M)):
        raise RuntimeError(result.stdout[-4000:] + result.stderr[-4000:])
    return result


def actor(n):
    user = '99460000-0000-4000-8000-' + str(n).zfill(12)
    return "set request.jwt.claim.sub='%s'; set request.jwt.claims='{\"sub\":\"%s\",\"role\":\"authenticated\"}';\n" % (user, user)


def fixture(n):
    return '99460000-0000-4000-8000-' + str(n).zfill(12)


def place(user, match, selection='home'):
    return sql(actor(user) + "select public.predict_place(9946001,'%s','%s');" % (fixture(match), selection), check=False)


def operations_after_lock(lock_query, operation_queries, before_release=None, before_commit=None):
    """Run operations only after an independent transaction holds the chosen row."""
    held = subprocess.Popen([DOCKER, 'exec', '-i', NAME, 'psql', '-X', '-qAt',
                             '-v', 'ON_ERROR_STOP=1', '-U', 'postgres', '-d', 'postgres'],
                            stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE, text=True)
    try:
        held.stdin.write("set application_name='qa_operation_hold'; begin; set local idle_in_transaction_session_timeout='15s'; " + lock_query + '\n')
        held.stdin.flush()
        for _ in range(100):
            if sql("select count(*) from pg_stat_activity where application_name='qa_operation_hold' and state='idle in transaction';").stdout.strip() == '1':
                break
            time.sleep(.05)
        else:
            raise RuntimeError('Operation test did not acquire its row lock')
        with concurrent.futures.ThreadPoolExecutor(max_workers=len(operation_queries)) as executor:
            futures = [executor.submit(sql, "set application_name='qa_operation_waiting'; set statement_timeout='10s'; " + query, check=False) for query in operation_queries]
            try:
                for _ in range(100):
                    waiting = sql("select count(*) from pg_stat_activity where application_name='qa_operation_waiting' and wait_event_type='Lock';").stdout.strip()
                    if waiting == str(len(operation_queries)):
                        break
                    time.sleep(.05)
                else:
                    raise RuntimeError('Every operation must be blocked before release')
                if before_release:
                    sql("set statement_timeout='8s'; " + before_release)
            finally:
                held.stdin.write((before_commit or '') + '\ncommit;\n')
                held.stdin.flush()
            responses = [future.result() for future in futures]
            held_out, held_error = held.communicate(timeout=20)
            if held.returncode:
                raise RuntimeError('Held transaction failed: ' + held_out[-2000:] + held_error[-4000:])
            return responses
    finally:
        if held.poll() is None:
            held.communicate('rollback;\n', timeout=20)


try:
    print('Creating fresh isolated container', NAME, flush=True)
    started = subprocess.run([DOCKER, 'create', '--pull=never', '--name', NAME,
                    '--label', 'africlub.test=database-concurrency', '--network=none',
                    '--cpus=2', '--memory=2g', '--tmpfs', '/var/lib/postgresql/data',
                    '-e', 'POSTGRES_PASSWORD=' + PASSWORD, IMAGE,
                    'postgres', '-D', '/etc/postgresql', '-c', 'cron.launch_active_jobs=off'],
                   capture_output=True, text=True, timeout=180)
    if started.returncode:
        raise RuntimeError('Isolated Postgres startup failed: ' + started.stderr.strip())
    print('Starting fresh isolated container', NAME, flush=True)
    start_owned_container(NAME)
    for _ in range(60):
        if sql('select 1;', admin=True, check=False).returncode == 0:
            break
        time.sleep(.5)
    else:
        raise RuntimeError('Isolated Postgres did not start')
    # Apply the real vendor schemas inside the portless database namespace.
    # network=container:<name> retains network=none isolation and only allows
    # the migrators to reach this test database over shared loopback.
    sql("alter role supabase_auth_admin password 'isolated-predict-contract'; alter role supabase_storage_admin password 'isolated-predict-contract';", admin=True)
    vendor_migrations = [
        ('auth', 'public.ecr.aws/supabase/gotrue:v2.195.0', 'auth', ['migrate'], {
            'GOTRUE_DB_DRIVER': 'postgres',
            'GOTRUE_DB_DATABASE_URL': 'postgres://supabase_auth_admin:' + PASSWORD + '@127.0.0.1:5432/postgres',
            'GOTRUE_JWT_SECRET': 'isolated-contract-jwt-not-a-real-secret-32',
            'GOTRUE_SITE_URL': 'http://127.0.0.1:3200',
            'API_EXTERNAL_URL': 'http://127.0.0.1:9999',
            'GOTRUE_LOG_LEVEL': 'warn',
        }),
        ('storage', 'public.ecr.aws/supabase/storage-api:v1.68.10', 'node', ['dist/scripts/migrate-call.js'], {
            'DATABASE_URL': 'postgres://supabase_storage_admin:' + PASSWORD + '@127.0.0.1:5432/postgres',
            'AUTH_JWT_SECRET': 'isolated-contract-jwt-not-a-real-secret-32',
            'STORAGE_BACKEND': 'file',
            'FILE_STORAGE_BACKEND_PATH': '/tmp/storage',
        }),
    ]
    for vendor, image, entrypoint, command, environment in vendor_migrations:
        args = [DOCKER, 'create', '--pull=never', '--name', NAME + '-' + vendor,
                '--label', 'africlub.test=database-concurrency',
                '--network=container:' + NAME, '--memory=256m']
        for key, value in environment.items():
            args += ['-e', key + '=' + value]
        args += ['--entrypoint', entrypoint, image] + command
        created = subprocess.run(args, capture_output=True, text=True, timeout=90)
        if created.returncode:
            raise RuntimeError(vendor + ' migrator creation failed: ' + created.stderr[-4000:])
        start_owned_container(NAME + '-' + vendor)
        deadline = time.monotonic() + 180
        while True:
            state = json.loads(subprocess.check_output([DOCKER, 'inspect', '--format', '{{json .State}}', NAME + '-' + vendor], timeout=15))
            if state['Status'] == 'exited':
                if state['ExitCode'] != 0 or state['OOMKilled']:
                    detail = subprocess.run([DOCKER, 'logs', '--tail=50', NAME + '-' + vendor], capture_output=True, text=True, timeout=15)
                    raise RuntimeError(vendor + ' migration failed: ' + detail.stdout[-4000:] + detail.stderr[-4000:])
                break
            if state['Status'] not in ('running', 'created') or time.monotonic() >= deadline:
                raise RuntimeError(vendor + ' migrator did not finish successfully')
            time.sleep(.25)
        print('Migrated real vendor schema:', vendor, image, flush=True)
    # Keep vendor-created public schema and its trusted service default ACLs.
    # This owned fresh database has no application tables to reset.
    for migration in sorted((ROOT / 'supabase/migrations').glob('*.sql')):
        if 'gikundiro_club_identity' in migration.name:
            # Owned ephemeral fixture establishes the source registry before the data migration.
            sql("insert into public.african_football_clubs(id,club_name,country_name,club_slug,currency_code,currency_symbol) overriding system value values (24,'Rayon Sports FC','Rwanda','rayon_sports_rw','RWF','RWF') on conflict do nothing;")
            sql("insert into public.ai_content(club_id,content_type,title,body,status) select 24,'club_history',title,'Superseded application copy','approved' from unnest(array['The beloved identity','Matchday at scale','One supporter account']) title cross join generate_series(1,2);")
        sql(migration.read_text())
        print('Applied', migration.name, flush=True)
    sql('create extension if not exists pgtap with schema extensions;')
    # Exercise the entire declared database contract suite on this fresh
    # replay. New SQL contracts must not silently remain outside the CI gate.
    for seed_path in (ROOT / 'supabase/seed.sql', ROOT / 'supabase/seed-clubs.sql'):
        sql(seed_path.read_text())
        print('Seeded', seed_path.name, flush=True)
    contracts = sorted((ROOT / 'supabase/tests').glob('*.sql'))
    if not contracts:
        raise RuntimeError('No database contracts were discovered')
    total_assertions = 0
    for contract in contracts:
        result = sql('set search_path=public,extensions;\n' + contract.read_text())
        count = len(re.findall(r'^ok \d+', result.stdout, re.M))
        plans = re.findall(r'^1\.\.(\d+)\s*$', result.stdout, re.M)
        if len(plans) != 1 or count != int(plans[0]) or count == 0:
            raise RuntimeError('Incomplete pgTAP plan: ' + contract.name + '\n' + result.stdout[-4000:])
        if re.search(r'^(?:not )?ok \d+.*#\s*(?:SKIP|TODO)\b', result.stdout, re.M | re.I):
            raise RuntimeError('Skipped or TODO database assertion: ' + contract.name)
        total_assertions += count
        print('PASS', contract.stem, count, 'checks', flush=True)
    print('PASS', len(contracts), 'SQL contracts;', total_assertions, 'assertions; no skips', flush=True)

    seed = (ROOT / 'supabase/tests/predict_contract.sql').read_text().split('-- Helper')[0]
    sql(seed + '\ncommit;')
    sql(actor(5) + "select public.predict_admin_settings(9946001,true,100); select public.predict_admin_prepare(9946001,'%s','https://example.com/fixture');" % fixture(301))
    with concurrent.futures.ThreadPoolExecutor(max_workers=5) as executor:
        responses = list(executor.map(lambda _: place(1,301), range(5)))
    assert all(r.returncode == 0 for r in responses)
    assert sql("select count(*) from football.predict_entries where user_id='%s';" % fixture(1)).stdout.strip() == '1'
    assert sql("select points from public.fan_memberships where user_id='%s';" % fixture(1)).stdout.strip() == '400'
    assert sql("select count(*) from public.fet_wallet_ledger_entries where user_id='%s';" % fixture(1)).stdout.strip() == '2'
    print('PASS five concurrent retries: one entry, one welcome, one debit', flush=True)

    sql(actor(5) + "select public.predict_admin_settings(9946001,true,300);" + ''.join(
        "select public.predict_admin_prepare(9946001,'%s','https://example.com/fixture');" % fixture(n) for n in [302,303]))
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as executor:
        responses = list(executor.map(lambda n: place(2,n), [302,303]))
    assert sum(r.returncode == 0 for r in responses) == 1
    assert any('PREDICT_INSUFFICIENT_FET' in r.stderr for r in responses), [r.stderr for r in responses]
    assert sql("select points from public.fan_memberships where user_id='%s';" % fixture(2)).stdout.strip() == '200'
    print('PASS simultaneous different fixtures cannot overspend a wallet', flush=True)

    sql("update football.fixtures set kickoff_at=clock_timestamp()+interval '3 seconds' where id='%s';" % fixture(304))
    sql(actor(5) + "select public.predict_admin_settings(9946001,true,100); select public.predict_admin_prepare(9946001,'%s','https://example.com/fixture');" % fixture(304))
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as executor:
        held = executor.submit(sql, "set application_name='predict_boundary_hold'; begin; select id from football.predict_pools where fixture_id='%s' for update; select pg_sleep(4); commit;" % fixture(304))
        for _ in range(30):
            if sql("select count(*) from pg_stat_activity where application_name='predict_boundary_hold' and wait_event='PgSleep';").stdout.strip() == '1':
                break
            time.sleep(.05)
        else:
            raise RuntimeError('Boundary test did not acquire its lock')
        response = place(3,304)
        held.result()
    assert response.returncode != 0 and 'PREDICT_POOL_CLOSED' in response.stderr
    assert sql("select count(*) from football.predict_entries where user_id='%s';" % fixture(3)).stdout.strip() == '0'
    print('PASS request waiting across kickoff is rejected after lock acquisition', flush=True)

    sql((ROOT / 'tools/scripts/fixtures/initiative_confirmation_concurrency.sql').read_text())

    def confirm_contribution(number):
        return "set role service_role; select public.confirm_club_initiative_contribution('%s','%s','RS-SUPPORT-CONCURRENT-%d',1000);" % (fixture(number), fixture(5), number)

    def contribution_state():
        return json.loads(sql("""select jsonb_build_object(
          'amount',raised_amount,'count',supporter_count,
          'points',(select points from public.fan_memberships where user_id='%s' and partner_id='%s'))
          from public.initiatives where id='%s';""" % (fixture(5), fixture(800), fixture(801))).stdout.strip())

    responses = operations_after_lock(
        "select id from public.initiative_contributions where id='%s' for update;" % fixture(802),
        [confirm_contribution(802)] * 5)
    assert all(r.returncode == 0 for r in responses), [r.stderr for r in responses]
    decisions = [json.loads(r.stdout.strip().splitlines()[-1]) for r in responses]
    assert all(d['status'] == 'confirmed' for d in decisions), decisions
    assert sum(d['newly_confirmed'] for d in decisions) == 1, decisions
    assert contribution_state() == {'amount': 1000, 'count': 1, 'points': 20}, contribution_state()
    print('PASS five overlapping contribution confirmations commit one amount, count and reward', flush=True)

    responses = operations_after_lock(
        "select id from public.initiatives where id='%s' for update;" % fixture(801),
        [confirm_contribution(n) for n in (803, 804)])
    assert all(r.returncode == 0 for r in responses), [r.stderr for r in responses]
    decisions = [json.loads(r.stdout.strip().splitlines()[-1]) for r in responses]
    assert all(d['newly_confirmed'] for d in decisions), decisions
    assert contribution_state() == {'amount': 3000, 'count': 3, 'points': 60}, contribution_state()
    print('PASS overlapping distinct contributions preserve both campaign increments and rewards', flush=True)

    for number, mutation in [(805, "status='cancelled'"), (806, 'amount=2000'), (807, "user_id='%s'" % fixture(4))]:
        responses = operations_after_lock(
            "select id from public.initiative_contributions where id='%s' for update;" % fixture(number),
            [confirm_contribution(number)],
            before_commit="update public.initiative_contributions set %s where id='%s';" % (mutation, fixture(number)))
        assert responses[0].returncode == 0, responses[0].stderr
        decision = json.loads(responses[0].stdout.strip().splitlines()[-1])
        assert decision['status'] == 'manual_review', decision
        assert contribution_state() == {'amount': 3000, 'count': 3, 'points': 60}, contribution_state()
        assert sql("select confirmed_at is null from public.initiative_contributions where id='%s';" % fixture(number)).stdout.strip() == 't'
        print('PASS contribution binding revalidated after lock', mutation, flush=True)

    allocation_seed = (ROOT / 'supabase/tests/manual_sms_allocation_contract.sql').read_text().split('-- Helper functions and assertions')[0]
    sql(allocation_seed + '\ncommit;')

    def allocation_id(number):
        return '99510000-0000-4000-8000-' + str(number).zfill(12)

    def allocate(number, actor_number=3):
        return ("set request.jwt.claim.sub='%s'; set role authenticated; "
                "select * from public.allocate_momo_manual_review('%s','%s','Concurrent contract');"
                % (allocation_id(actor_number), allocation_id(400 + number), allocation_id(500 + number)))

    responses = operations_after_lock(
        "select id from public.momo_reconciliations where id='%s' for update;" % allocation_id(401),
        [allocate(1)] * 5)
    assert all(r.returncode == 0 for r in responses), [r.stderr for r in responses]
    assert sql("select count(*) from public.admin_audit_log where action='momo_manual_allocation' and target_id='%s';" % allocation_id(401)).stdout.strip() == '1'
    assert sql("select count(*) from public.momo_ledger_entries where parsed_sms_id='%s' and ledger_status='posted';" % allocation_id(301)).stdout.strip() == '1'
    print('PASS five overlapping manual allocation retries post and audit exactly once', flush=True)

    for number, mutation, expected in [
        (2, "status='cancelled'", 'MANUAL_ALLOCATION_STATE_CONFLICT'),
        (3, "receiving_account_id='%s'" % allocation_id(103), 'MANUAL_ALLOCATION_RECEIVER_MISMATCH'),
        (4, 'expected_amount=2000', 'MANUAL_ALLOCATION_AMOUNT_MISMATCH'),
    ]:
        responses = operations_after_lock(
            "select id from public.payment_intents where id='%s' for update;" % allocation_id(500 + number),
            [allocate(number)],
            before_commit="update public.payment_intents set %s where id='%s';" % (mutation, allocation_id(500 + number)))
        assert responses[0].returncode != 0 and expected in responses[0].stderr, responses[0].stderr
        assert sql("select count(*) from public.momo_ledger_entries where parsed_sms_id='%s';" % allocation_id(300 + number)).stdout.strip() == '0'
        print('PASS manual allocation revalidates changed intent after lock', mutation, flush=True)

    responses = operations_after_lock(
        "select id from public.payment_receiver_accounts where id='%s' for update;" % allocation_id(100),
        [allocate(5)],
        before_commit="update public.payment_receiver_accounts set is_active=false where id='%s';" % allocation_id(100))
    assert responses[0].returncode != 0 and 'MANUAL_ALLOCATION_RECEIVER_MISMATCH' in responses[0].stderr, responses[0].stderr
    sql("update public.payment_receiver_accounts set is_active=true where id='%s';" % allocation_id(100))
    print('PASS manual allocation rechecks receiver activation after lock', flush=True)

    sql("update public.payment_intents set expires_at=clock_timestamp()+interval '2 seconds' where id='%s';" % allocation_id(506))
    responses = operations_after_lock(
        "select id from public.payment_receiver_accounts where id='%s' for update;" % allocation_id(100),
        [allocate(6)], before_commit='select pg_sleep(2.1);')
    assert responses[0].returncode != 0 and 'MANUAL_ALLOCATION_EXPIRED' in responses[0].stderr, responses[0].stderr
    print('PASS manual allocation cannot cross its expiry while waiting for a receiver', flush=True)

    responses = operations_after_lock(
        "select id from public.payment_intents where id='%s' for update;" % allocation_id(507),
        [allocate(7, 5)],
        before_commit="update public.admin_role_assignments set is_active=false where user_id='%s';" % allocation_id(5))
    assert responses[0].returncode != 0 and 'MANUAL_ALLOCATION_FORBIDDEN' in responses[0].stderr, responses[0].stderr
    print('PASS revoked operator cannot allocate after a lock wait', flush=True)

    for table, identifier in [('momo_sms_raw', 231), ('momo_sms_parsed', 331),
                              ('momo_reconciliations', 431), ('payment_intents', 531)]:
        sql("update public.%s set user_id='%s' where id='%s';" % (table, allocation_id(2), allocation_id(identifier)))
    sql("update public.momo_sms_parsed set momo_tx_id='ALLOCATION-TX-30' where id='%s';" % allocation_id(331))
    responses = operations_after_lock(
        "select id from public.payment_receiver_accounts where id='%s' for update;" % allocation_id(100),
        [allocate(30), allocate(31)])
    assert sum(r.returncode == 0 for r in responses) == 1, [r.stderr for r in responses]
    assert any('MANUAL_ALLOCATION_TRANSACTION_USED' in r.stderr for r in responses), [r.stderr for r in responses]
    assert sql("select count(*) from public.momo_ledger_entries where external_reference='ALLOCATION-TX-30' and ledger_status='posted';").stdout.strip() == '1'
    print('PASS concurrent imports by different accounts cannot manually allocate the same provider transaction twice', flush=True)
    intent_seed = (ROOT / 'supabase/tests/payment_intent_atomic_contract.sql').read_text().split('create function pg_temp.intent_call')[0]
    sql(intent_seed + '\ncommit;')

    def intent_id(number):
        return '99520000-0000-4000-8000-' + str(number).zfill(12)

    def auto_allocate(number):
        return "set role service_role; select public.allocate_momo_payment_intent('%s','%s');" % (intent_id(300 + number), intent_id(500 + number))

    responses = operations_after_lock(
        "select id from public.momo_reconciliations where id='%s' for update;" % intent_id(401),
        [auto_allocate(1)] * 5)
    assert all(r.returncode == 0 for r in responses), [r.stderr for r in responses]
    decisions = [json.loads(r.stdout.strip().splitlines()[-1]) for r in responses]
    assert sum(d['newly_allocated'] for d in decisions) == 1, decisions
    assert sql("select count(*) from public.momo_ledger_entries where parsed_sms_id='%s' and ledger_status='posted';" % intent_id(301)).stdout.strip() == '1'
    print('PASS five overlapping automatic intent allocations commit one debit and recover the same decision', flush=True)

    for number, mutation, expected in [
        (2, "status='cancelled'", 'INTENT_ALLOCATION_STATE_CONFLICT'),
        (3, "receiving_account_id='%s'" % intent_id(103), 'INTENT_ALLOCATION_RECEIVER_MISMATCH'),
        (4, 'expected_amount=2000', 'INTENT_ALLOCATION_AMOUNT_MISMATCH'),
    ]:
        responses = operations_after_lock(
            "select id from public.payment_intents where id='%s' for update;" % intent_id(500 + number),
            [auto_allocate(number)],
            before_commit="update public.payment_intents set %s where id='%s';" % (mutation, intent_id(500 + number)))
        assert responses[0].returncode != 0 and expected in responses[0].stderr, responses[0].stderr
        assert sql("select count(*) from public.momo_ledger_entries where parsed_sms_id='%s';" % intent_id(300 + number)).stdout.strip() == '0'
        print('PASS automatic allocation revalidates changed intent after lock', mutation, flush=True)

    for number, mutation in [(5, 'is_active=false'), (6, "payee_number_or_code='changed-receiver'")]:
        responses = operations_after_lock(
            "select id from public.payment_receiver_accounts where id='%s' for update;" % intent_id(100),
            [auto_allocate(number)],
            before_commit="update public.payment_receiver_accounts set %s where id='%s';" % (mutation, intent_id(100)))
        assert responses[0].returncode != 0 and 'INTENT_ALLOCATION_RECEIVER_MISMATCH' in responses[0].stderr, responses[0].stderr
        sql("update public.payment_receiver_accounts set is_active=true,payee_number_or_code='995200100' where id='%s';" % intent_id(100))
        assert sql("select status from public.payment_intents where id='%s';" % intent_id(500 + number)).stdout.strip() == 'pending'
        print('PASS automatic allocation revalidates receiver after lock', mutation, flush=True)

    sql("update public.payment_intents set expires_at=clock_timestamp()+interval '2 seconds' where id='%s';" % intent_id(507))
    responses = operations_after_lock(
        "select id from public.payment_receiver_accounts where id='%s' for update;" % intent_id(100),
        [auto_allocate(7)], before_commit='select pg_sleep(2.1);')
    assert responses[0].returncode != 0 and 'INTENT_ALLOCATION_EXPIRED' in responses[0].stderr, responses[0].stderr
    print('PASS automatic allocation rechecks wall-clock expiry after lock waits', flush=True)

    for first, second, manual in [(30, 31, False), (32, 33, True)]:
        for table, offset in [('momo_sms_raw', 200), ('momo_sms_parsed', 300), ('momo_reconciliations', 400), ('payment_intents', 500)]:
            sql("update public.%s set user_id='%s' where id='%s';" % (table, intent_id(2), intent_id(offset + second)))
        reference = 'INTENT-TX-' + str(first)
        sql("update public.momo_sms_parsed set momo_tx_id='%s' where id='%s';" % (reference, intent_id(300 + second)))
        second_call = ("set request.jwt.claim.sub='%s'; set role authenticated; select * from public.allocate_momo_manual_review('%s','%s','Concurrent automatic/manual evidence');"
                       % (intent_id(3), intent_id(400 + second), intent_id(500 + second))) if manual else auto_allocate(second)
        responses = operations_after_lock(
            "select id from public.payment_receiver_accounts where id='%s' for update;" % intent_id(100),
            [auto_allocate(first), second_call])
        assert sum(r.returncode == 0 for r in responses) == 1, [r.stderr for r in responses]
        assert any('ALLOCATION_TRANSACTION_USED' in r.stderr for r in responses), [r.stderr for r in responses]
        assert sql("select count(*) from public.momo_ledger_entries where external_reference='%s' and ledger_status='posted';" % reference).stdout.strip() == '1'
        print('PASS automatic/manual' if manual else 'PASS automatic/automatic', 'cross-account allocation cannot reuse one provider transaction', flush=True)
    from commerce_confirmation_concurrency import run_commerce_concurrency
    run_commerce_concurrency(sql, operations_after_lock, ROOT)
finally:
    subprocess.run([DOCKER, 'rm', '-f', NAME + '-auth', NAME + '-storage', NAME], capture_output=True, timeout=60)
