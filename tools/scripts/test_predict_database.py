#!/usr/bin/env python3
"""Replay migrations and verify concurrent operations in a portless Postgres.
Requires Docker and the pinned Postgres, GoTrue and Storage images below.
Uses synthetic data only; no published ports, mounts or external network.
"""
import argparse
import concurrent.futures
from contextlib import contextmanager
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time
import uuid

ROOT = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--contract', action='append', choices=sorted(p.name for p in (ROOT / 'supabase/tests').glob('*.sql')),
                    help='Run a selected contract on the complete migration chain; omit for all contracts and concurrency probes')
parser.add_argument('--through-migration', choices=sorted(p.name for p in (ROOT / 'supabase/migrations').glob('*.sql')),
                    help='Diagnostic migration prefix while a later forward migration is being authored; omit for the complete current chain')
arguments = parser.parse_args()
DOCKER = os.environ.get('DOCKER', 'docker')
NAME = 'africlub-predict-contract-' + uuid.uuid4().hex[:8]
IMAGE = 'public.ecr.aws/supabase/postgres:17.6.1.158'
PASSWORD = 'isolated-predict-contract'
ACTIVE_DATABASE = 'postgres'


@contextmanager
def using_database(name):
    global ACTIVE_DATABASE
    previous = ACTIVE_DATABASE
    ACTIVE_DATABASE = name
    try:
        yield
    finally:
        ACTIVE_DATABASE = previous


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
             'supabase_admin' if admin else 'postgres', '-d', ACTIVE_DATABASE]
    if admin:
        args += ['-h', '127.0.0.1']
    result = subprocess.run(args, input=query, text=True, capture_output=True, timeout=120)
    if check and (result.returncode or re.search(r'^not ok ', result.stdout, re.M)):
        raise RuntimeError(result.stdout[-4000:] + result.stderr[-4000:])
    return result


def actor(n):
    user = '99460000-0000-4000-8000-' + str(n).zfill(12)
    claims = {'sub': user, 'role': 'authenticated', 'is_anonymous': False}
    if n == 5:
        # This fixture is the actual currently assigned staff actor. Supporter
        # callers retain aal1; negative expiry probes override these claims.
        now = int(time.time())
        claims.update(aal='aal2', exp=now + 600, amr=[{'method': 'totp', 'timestamp': now}])
    return "set request.jwt.claim.sub='%s'; set request.jwt.claims='%s'; set role authenticated;\n" % (user, json.dumps(claims))


def fixture(n):
    return '99460000-0000-4000-8000-' + str(n).zfill(12)


def staff_command_actor(user, session, *, expires_in=600, mfa_age=0):
    """Actual authenticated test caller tied to a vendor Auth session row."""
    now = int(time.time())
    claims = {'sub': user, 'role': 'authenticated', 'is_anonymous': False,
              'aal': 'aal2', 'exp': now + expires_in, 'session_id': session,
              'amr': [{'method': 'totp', 'timestamp': now - mfa_age}]}
    return "set request.jwt.claim.sub='%s'; set request.jwt.claims='%s'; set role authenticated;\n" % (user, json.dumps(claims))


def historical_predict_snapshot():
    """Compare every old financial field, excluding only added version/score fields."""
    tables = {
        'pools': ('football.predict_pools', 'club_id=9968001'),
        'entries': ('football.predict_entries', 'club_id=9968001'),
        'memberships': ('public.fan_memberships', 'club_id=9968001'),
        'ledger': ('public.fet_wallet_ledger_entries', "user_id::text like '99680000-%'"),
    }
    return {name: json.loads(sql("select coalesce(jsonb_agg(to_jsonb(t)-'economics_version'-'score_points' order by t.id),'[]'::jsonb) from %s t where %s;" % (table, predicate)).stdout.strip())
            for name, (table, predicate) in tables.items()}


def place(user, match, selection='home'):
    return sql(actor(user) + "select public.predict_place(9946001,'%s','%s');" % (fixture(match), selection), check=False)


def operations_after_lock(lock_query, operation_queries, before_release=None, before_commit=None):
    """Run operations only after an independent transaction holds the chosen row."""
    held = subprocess.Popen([DOCKER, 'exec', '-i', NAME, 'psql', '-X', '-qAt',
                             '-v', 'ON_ERROR_STOP=1', '-U', 'postgres', '-d', ACTIVE_DATABASE],
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
    migrations = sorted((ROOT / 'supabase/migrations').glob('*.sql'))
    if arguments.through_migration:
        migrations = [p for p in migrations if p.name <= arguments.through_migration]
        print('Diagnostic migration prefix through', arguments.through_migration, '; complete current chain not admitted', flush=True)
    for migration in migrations:
        if migration.name == '20261001230000_free_prediction_entry_policy.sql':
            # Copy only this run's portless, real pre-forward vendor/schema
            # database. Historical fixtures must not contaminate fresh-catalog
            # contracts, and must remain intact for later real service races.
            # Supabase's image opens background sessions in the default database.
            # Stop connections only in this run's portless, owned test container
            # while making a physical copy, preserving catalog OIDs and ownership.
            with using_database('template1'):
                try:
                    sql('alter database postgres allow_connections false;')
                    sql("select pg_terminate_backend(pid) from pg_stat_activity where datname='postgres' and pid<>pg_backend_pid();", admin=True)
                    sql('create database qa_predict_history template postgres;')
                finally:
                    sql('alter database postgres allow_connections true;')
            with using_database('qa_predict_history'):
                sql((ROOT / 'tools/scripts/fixtures/predict_pre_free_migration.sql').read_text())
                historical = historical_predict_snapshot()
                assert len(historical['pools']) == 3 and len(historical['entries']) == 6
                assert any(row['outcome'] == 'won' for row in historical['entries'])
                assert any(row['payout_fet'] > 0 for row in historical['entries'])
                assert any(row['status'] == 'open' for row in historical['pools'])
                sql(migration.read_text())
                assert historical_predict_snapshot() == historical, 'Free migration changed historical financial rows'
                assert sql("select count(*) from football.predict_pools where club_id=9968001 and economics_version='legacy_paid_v1';").stdout.strip() == '3'
                assert sql("select count(*) from football.predict_entries where club_id=9968001 and economics_version='legacy_paid_v1';").stdout.strip() == '6'
                print('PASS isolated pre-forward paid open/settled/void history: every old pool/entry/wallet/ledger field preserved; all historical versions retained', flush=True)
        if 'gikundiro_club_identity' in migration.name:
            # Owned ephemeral fixture establishes the source registry before the data migration.
            sql("insert into public.african_football_clubs(id,club_name,country_name,club_slug,currency_code,currency_symbol) overriding system value values (24,'Rayon Sports FC','Rwanda','rayon_sports_rw','RWF','RWF') on conflict do nothing;")
            sql("insert into public.ai_content(club_id,content_type,title,body,status) select 24,'club_history',title,'Superseded application copy','approved' from unnest(array['The beloved identity','Matchday at scale','One supporter account']) title cross join generate_series(1,2);")
        sql(migration.read_text())
        if migration.name > '20261001230000_free_prediction_entry_policy.sql':
            with using_database('qa_predict_history'):
                sql(migration.read_text())
                assert historical_predict_snapshot() == historical, 'Forward migration changed preserved historical financial rows: ' + migration.name
        print('Applied', migration.name, flush=True)
    sql('create extension if not exists pgtap with schema extensions;')
    # Exercise the entire declared database contract suite on this fresh
    # replay. New SQL contracts must not silently remain outside the CI gate.
    for seed_path in (ROOT / 'supabase/seed.sql', ROOT / 'supabase/seed-clubs.sql'):
        sql(seed_path.read_text())
        print('Seeded', seed_path.name, flush=True)
    contracts = sorted((ROOT / 'supabase/tests').glob('*.sql'))
    if arguments.contract:
        contracts = [contract for contract in contracts if contract.name in arguments.contract]
    if not contracts:
        raise RuntimeError('No database contracts were discovered')
    total_assertions = 0
    failed_contracts = []
    for contract in contracts:
        try:
            result = sql('set search_path=public,extensions;\n' + contract.read_text())
        except RuntimeError as error:
            # Independent contracts each own their transaction and connection.
            # Report all failures without hiding later checks behind the first.
            failed_contracts.append(contract.name)
            print('FAIL', contract.name, str(error), flush=True)
            continue
        count = len(re.findall(r'^ok \d+', result.stdout, re.M))
        plans = re.findall(r'^1\.\.(\d+)\s*$', result.stdout, re.M)
        if len(plans) != 1 or count != int(plans[0]) or count == 0:
            raise RuntimeError('Incomplete pgTAP plan: ' + contract.name + '\n' + result.stdout[-4000:])
        if re.search(r'^(?:not )?ok \d+.*#\s*(?:SKIP|TODO)\b', result.stdout, re.M | re.I):
            raise RuntimeError('Skipped or TODO database assertion: ' + contract.name)
        total_assertions += count
        print('PASS', contract.stem, count, 'checks', flush=True)
    if failed_contracts:
        raise RuntimeError('Failed SQL contracts: ' + ', '.join(failed_contracts))
    print('PASS', len(contracts), 'SQL contracts;', total_assertions, 'assertions; no skips', flush=True)
    if arguments.contract:
        print('Focused contract replay only; full-suite concurrency probes were not run', flush=True)
        sys.exit(0)

    from admin_media_upload_concurrency import run_media_upload_concurrency
    run_media_upload_concurrency(sql, operations_after_lock, ROOT)

    # Each request actually waits behind an independent transaction. A revoked
    # source or expired signature cannot leave raw evidence or financial effects.
    ingress = json.loads((ROOT / 'tools/scripts/fixtures/trusted_ingress_concurrency.json').read_text())
    sql((ROOT / ingress['fixture']).read_text())
    for name in ('expiry', 'gateway_revocation', 'config_revocation', 'subject_expiry'):
        probe = ingress[name]
        attempts = operations_after_lock(probe['hold'], [probe['operation']],
                                        before_release=probe.get('before_release'), before_commit=probe.get('before_commit'))
        assert attempts[0].returncode != 0 and probe['expected_error'] in attempts[0].stderr, attempts[0].stderr
        state = json.loads(sql(ingress['state']).stdout.strip())
        assert state == ingress['expected_state'], (name, state)
        if name == 'gateway_revocation': sql(ingress['restore_gateway'])
        if name == 'config_revocation': sql(ingress['restore_config'])
        print('PASS trusted ingress real post-lock ' + name + ': denied, no raw evidence/event/ledger, original stock/order preserved', flush=True)

    # Native checkout recovery uses the same original operation after response
    # loss; concurrent retries must recover one frozen financial instruction.
    shop_contract = (ROOT / 'supabase/tests/shop_checkout_receipt_recovery_contract.sql').read_text()
    shop_seed = 'insert into public.african_football_clubs' + shop_contract.split('insert into public.african_football_clubs', 1)[1].split('create temporary table receipts', 1)[0]
    sql(shop_seed)
    shop_subject = '99962000-0000-4000-8000-000000000001'
    shop_reference = 'order-99962000-0000-4000-8000-000000000209'

    def shop_context(subject, club):
        return "set request.jwt.claim.sub='%s'; set request.jwt.claims='%s'; set role authenticated; " % (
            subject, json.dumps({'sub': subject, 'role': 'authenticated', 'club_id': str(club), 'is_anonymous': False}))

    shop_prepare = shop_context(shop_subject, 9996201) + "select public.prepare_shop_checkout_for_club('[{\"product_id\":\"99962000-0000-4000-8000-000000000110\",\"quantity\":2}]','QA Kigali address','%s',9996201);" % shop_reference
    shop_attempts = operations_after_lock(
        "select id from public.shop_products where id='99962000-0000-4000-8000-000000000110' for update;",
        [shop_prepare] * 10)
    assert all(r.returncode == 0 for r in shop_attempts), [r.stderr for r in shop_attempts]
    shop_responses = [json.loads(r.stdout.strip().splitlines()[-1]) for r in shop_attempts]
    assert len({r['order']['id'] for r in shop_responses}) == 1, shop_responses
    assert len({json.dumps(r['receipt'], sort_keys=True) for r in shop_responses}) == 1
    assert all(r['receipt']['total'] == 2500 and r['receipt']['ussd_code'] == '*182*8*1*2500*12345#' and r['can_pay'] for r in shop_responses)
    assert sql("select stock from public.shop_products where id='99962000-0000-4000-8000-000000000110';").stdout.strip() == '18'
    assert sql("select count(*) from public.shop_orders where momo_reference='%s';" % shop_reference).stdout.strip() == '1'
    assert sql("select count(*) from public.pending_transactions where reference='%s';" % shop_reference).stdout.strip() == '1'
    recovered = sql(shop_context(shop_subject, 9996201) + "select public.recover_shop_checkout_for_club('%s',9996201);" % shop_reference)
    assert json.loads(recovered.stdout.strip().splitlines()[-1])['receipt'] == shop_responses[0]['receipt']
    outsider = sql(shop_context('99962000-0000-4000-8000-000000000002', 9996202) + "select coalesce(public.recover_shop_checkout_for_club('%s',9996202),'null'::jsonb);" % shop_reference)
    assert outsider.stdout.strip().splitlines()[-1] == 'null'
    forged_club = sql(shop_context(shop_subject, 9996201) + "select public.recover_shop_checkout_for_club('%s',9996202);" % shop_reference, check=False)
    assert forged_club.returncode != 0 and 'SHOP_AUTH_REQUIRED' in forged_club.stderr
    print('PASS 10 overlapping native checkout retries: one order/reservation/instruction; restart recovers original receipt; foreign user/club cannot read it', flush=True)

    seed = (ROOT / 'supabase/tests/predict_contract.sql').read_text().split('-- Helper')[0]
    sql(seed + '\ncommit;')

    # Exercise the actual service-only admission RPC in independent PostgreSQL
    # transactions. Sequential mocks cannot establish the concurrency bound.
    service_context = "set role service_role; set request.jwt.claims='{\"role\":\"service_role\"}'; "
    admission_query = service_context + "select allowed from public.consume_edge_rate_limit('isolated-concurrency-budget',1,60);"
    with concurrent.futures.ThreadPoolExecutor(max_workers=20) as executor:
        admissions = list(executor.map(lambda _: sql(admission_query), range(20)))
    decisions = [r.stdout.strip().splitlines()[-1] for r in admissions]
    assert decisions.count('t') == 1 and decisions.count('f') == 19, decisions
    assert sql("select cardinality(accepted_at) from public.edge_rate_limit_buckets where bucket_key='isolated-concurrency-budget';").stdout.strip() == '1'
    print('PASS 20 concurrent real admission calls: exactly one admitted, 19 denied', flush=True)

    # An authorization decision must be refreshed after a contended resource
    # lock. Revoke the assignment while settlement waits for the fixture.
    sql("""insert into auth.users(id,aud,role) values ('%s','authenticated','authenticated');
        insert into public.users(id,phone,full_name) values ('%s','+25079946900','Synthetic global settlement actor');
        insert into public.admin_role_assignments(id,user_id,role,is_active)
          values ('%s','%s','admin',true);
        insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after)
          values ('%s','%s',clock_timestamp(),clock_timestamp(),'aal2',clock_timestamp()+interval '1 hour');
        insert into football.fixtures(id,competition_id,season_id,home_team_id,away_team_id,kickoff_at)
          select '%s',competition_id,season_id,home_team_id,away_team_id,clock_timestamp()+interval '30 days'
          from football.fixtures where id='%s';""" % (fixture(900), fixture(900), fixture(901), fixture(900), fixture(903), fixture(900), fixture(399), fixture(301)))
    staff_context = staff_command_actor(fixture(900), fixture(903))
    sql(staff_context + "select public.admit_verified_staff_command('%s','fixture_settle','%s','{\"home_score\":2,\"away_score\":1}');" % (fixture(902), fixture(399)))
    settlement_query = service_context + "select public.prediction_admin_settle_as_actor('%s',2,1,'%s','%s');" % (fixture(399), fixture(900), fixture(902))
    settlements = operations_after_lock(
        "select id from football.fixtures where id='%s' for update;" % fixture(399),
        [settlement_query],
        before_release="update public.admin_role_assignments set is_active=false,revoked_at=clock_timestamp() where id='%s';" % fixture(901))
    assert settlements[0].returncode != 0 and 'SETTLEMENT_GLOBAL_ADMIN_REQUIRED' in settlements[0].stderr, settlements[0].stderr
    assert sql("select status::text from football.fixtures where id='%s';" % fixture(399)).stdout.strip() == 'scheduled'
    assert sql("select count(*) from public.admin_audit_log where action='prediction.global_fixture_settle' and metadata->>'operation_id'='%s';" % fixture(902)).stdout.strip() == '0'
    print('PASS revoked global grant cannot settle after waiting for a fixture lock; no mutation or success audit', flush=True)

    sql("update public.admin_role_assignments set is_active=true,revoked_at=null where id='%s';" % fixture(901))
    # The original provider JWT/MFA deadline and actual vendor session must
    # survive the resource wait; a service-role transport cannot renew them.
    for index, boundary in enumerate(('jwt_expiry', 'mfa_expiry', 'session_revocation')):
        resource, operation, session = fixture(401 + index), fixture(904 + index), fixture(907 + index)
        sql("""insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after)
          values('%s','%s',clock_timestamp(),clock_timestamp(),'aal2',clock_timestamp()+interval '1 hour');
          insert into football.fixtures(id,competition_id,season_id,home_team_id,away_team_id,kickoff_at)
          select '%s',competition_id,season_id,home_team_id,away_team_id,clock_timestamp()+interval '%s days'
          from football.fixtures where id='%s';""" % (session, fixture(900), resource, 31 + index, fixture(301)))
        caller = staff_command_actor(fixture(900), session,
            expires_in=2 if boundary == 'jwt_expiry' else 600,
            mfa_age=298 if boundary == 'mfa_expiry' else 0)
        sql(caller + "select public.admit_verified_staff_command('%s','fixture_settle','%s','{\"home_score\":2,\"away_score\":1}');" % (operation, resource))
        service_query = service_context + "select public.prediction_admin_settle_as_actor('%s',2,1,'%s','%s');" % (resource, fixture(900), operation)
        change = "delete from auth.sessions where id='%s';" % session if boundary == 'session_revocation' else "select pg_sleep(2.2);"
        denied = operations_after_lock("select id from football.fixtures where id='%s' for update;" % resource,
            [service_query], before_release=change)[0]
        expected = 'STAFF_COMMAND_SESSION_REVOKED' if boundary == 'session_revocation' else 'STAFF_COMMAND_ASSURANCE_EXPIRED'
        assert denied.returncode != 0 and expected in denied.stderr, denied.stderr
        assert sql("select status::text from football.fixtures where id='%s';" % resource).stdout.strip() == 'scheduled'
        assert sql("select result is null from public.verified_staff_commands where operation_id='%s';" % operation).stdout.strip() == 't'
        assert sql("select count(*) from public.admin_audit_log where action='prediction.global_fixture_settle' and metadata->>'operation_id'='%s';" % operation).stdout.strip() == '0'
        print('PASS actual service financial %s during independent fixture wait: no settlement, completion or success audit' % boundary, flush=True)

    sql(actor(5) + "select public.predict_admin_settings(9946001,true,0); select public.predict_admin_prepare(9946001,'%s','https://example.com/fixture');" % fixture(301))
    with concurrent.futures.ThreadPoolExecutor(max_workers=5) as executor:
        responses = list(executor.map(lambda _: place(1,301), range(5)))
    assert all(r.returncode == 0 for r in responses)
    assert sql("select count(*) from football.predict_entries where user_id='%s';" % fixture(1)).stdout.strip() == '1'
    assert sql("select count(*) from public.fan_memberships where user_id='%s';" % fixture(1)).stdout.strip() == '0'
    assert sql("select count(*) from public.fet_wallet_ledger_entries where user_id='%s';" % fixture(1)).stdout.strip() == '0'
    print('PASS five concurrent free retries: one entry, no monetary wallet or welcome/debit ledger effects', flush=True)

    # A separate fixture has an existing zero-balance monetary wallet. Free
    # entry must preserve it while never creating one for the preceding caller.
    sql(actor(2) + "reset role; select public.fet_wallet_ensure_membership('%s',9946001);" % fixture(2))
    assert sql("select points from public.fan_memberships where user_id='%s';" % fixture(2)).stdout.strip() == '0'
    sql(actor(5) + "select public.predict_admin_settings(9946001,true,0);" + ''.join(
        "select public.predict_admin_prepare(9946001,'%s','https://example.com/fixture');" % fixture(n) for n in [302,303]))
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as executor:
        responses = list(executor.map(lambda n: place(2,n), [302,303]))
    assert all(r.returncode == 0 for r in responses), [r.stderr for r in responses]
    assert sql("select points from public.fan_memberships where user_id='%s';" % fixture(2)).stdout.strip() == '0'
    assert sql("select count(*) from football.predict_entries where user_id='%s' and stake_fet=0 and economics_version='free_v1';" % fixture(2)).stdout.strip() == '2'
    assert sql("select count(*) from public.fet_wallet_ledger_entries where user_id='%s';" % fixture(2)).stdout.strip() == '0'
    print('PASS simultaneous free fixtures: both zero-balance picks succeed without wallet mutation', flush=True)

    with using_database('qa_predict_history'):
        # The real pre-forward charged open pool remains a liability. Only an
        # attributed current global service command can void it, with one receipt.
        legacy_actor = '99680000-0000-4000-8000-000000000005'
        legacy_fixture = '99680000-0000-4000-8000-000000000301'
        legacy_pool = sql("select id from football.predict_pools where fixture_id='%s' and club_id=9968001;" % legacy_fixture).stdout.strip()
        legacy_operation = '99680000-0000-4000-8000-000000000801'
        legacy_session = '99680000-0000-4000-8000-000000000851'
        sql("insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values('%s','%s',clock_timestamp(),clock_timestamp(),'aal2',clock_timestamp()+interval '1 hour');" % (legacy_session, legacy_actor))
        legacy_admission = staff_command_actor(legacy_actor, legacy_session) + "select public.admit_verified_staff_command('%s','predict_legacy_settle','%s','{\"void_reason\":\"Synthetic concurrent legacy void\"}');" % (legacy_operation, legacy_pool)
        sql(legacy_admission)
        legacy_query = service_context + "select public.predict_admin_settle_for_actor('%s','%s','%s','Synthetic concurrent legacy void');" % (legacy_pool, legacy_actor, legacy_operation)
        before_legacy = historical_predict_snapshot()
        revoked = operations_after_lock(
            "select id from football.fixtures where id='%s' for update;" % legacy_fixture,
            [legacy_query],
            before_release="update public.admin_role_assignments set is_active=false,revoked_at=clock_timestamp() where user_id='%s' and role='admin';" % legacy_actor)
        assert revoked[0].returncode != 0 and 'PREDICT_GLOBAL_ADMIN_REQUIRED' in revoked[0].stderr
        assert historical_predict_snapshot() == before_legacy
        assert sql("select count(*) from football.predict_service_operations where operation_id='%s';" % legacy_operation).stdout.strip() == '0'
        print('PASS historical service actor revoked during fixture wait: no receipt or financial mutation', flush=True)
        sql("update public.admin_role_assignments set is_active=true,revoked_at=null where user_id='%s' and role='admin';" % legacy_actor)
        sql(legacy_admission)
        with concurrent.futures.ThreadPoolExecutor(max_workers=5) as executor:
            legacy_responses = list(executor.map(lambda _: sql(legacy_query, check=False), range(5)))
        assert all(response.returncode == 0 for response in legacy_responses), [r.stderr for r in legacy_responses]
        legacy_receipts = [json.loads(r.stdout.strip().splitlines()[-1]) for r in legacy_responses]
        assert all(receipt == legacy_receipts[0] for receipt in legacy_receipts)
        assert sql("select count(*) from football.predict_service_operations where operation_id='%s' and completed_at is not null;" % legacy_operation).stdout.strip() == '1'
        assert sql("select count(*) from public.fet_wallet_ledger_entries where club_id=9968001 and entry_type='predict_refund' and reference_id in(select id::text from football.predict_entries where pool_id='%s');" % legacy_pool).stdout.strip() == '2'
        after_legacy = historical_predict_snapshot()
        assert sum(row['points'] for row in after_legacy['memberships']) - sum(row['points'] for row in before_legacy['memberships']) == 200
        assert len(after_legacy['ledger']) - len(before_legacy['ledger']) == 2
        reused = sql(service_context + "select public.predict_admin_settle_for_actor('%s','%s','%s','Changed reason');" % (legacy_pool, legacy_actor, legacy_operation), check=False)
        assert reused.returncode != 0 and 'PREDICT_OPERATION_BINDING_MISMATCH' in reused.stderr
        assert historical_predict_snapshot() == after_legacy
        print('PASS five historical service retries: original receipt, one200FET refund, changed operation binding rejected', flush=True)

    sql("update football.fixtures set kickoff_at=clock_timestamp()+interval '3 seconds' where id='%s';" % fixture(304))
    sql(actor(5) + "select public.predict_admin_settings(9946001,true,0); select public.predict_admin_prepare(9946001,'%s','https://example.com/fixture');" % fixture(304))
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

    def allocate_across_new_review(number, second_query, expected_second_error=None):
        """Observe both sides of a review appearing between lock snapshots."""
        sql("delete from public.momo_reconciliations where parsed_sms_id='%s';" % intent_id(300 + number))
        held = subprocess.Popen([DOCKER, 'exec', '-i', NAME, 'psql', '-X', '-qAt',
                                 '-v', 'ON_ERROR_STOP=1', '-U', 'postgres', '-d', 'postgres'],
                                stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        def wait_for(label, predicate):
            for _ in range(100):
                if sql("select count(*) from pg_stat_activity where application_name='%s' and %s;" % (label, predicate)).stdout.strip() == '1':
                    return
                time.sleep(.03)
            raise RuntimeError('Missing observed lock: ' + label)
        try:
            # NO KEY UPDATE allows the review's foreign-key check while both
            # allocators are blocked trying to lock this interpretation.
            held.stdin.write("set application_name='qa_review_creation_hold'; begin; set local idle_in_transaction_session_timeout='20s'; select id from public.momo_sms_parsed where id='%s' for no key update;\n" % intent_id(300 + number))
            held.stdin.flush()
            wait_for('qa_review_creation_hold', "state='idle in transaction'")
            with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
                first = pool.submit(sql, "set application_name='qa_review_absent'; set statement_timeout='12s'; " + auto_allocate(number), check=False)
                second = None
                try:
                    wait_for('qa_review_absent', "wait_event_type='Lock'")
                    sql("insert into public.momo_reconciliations(id,parsed_sms_id,user_id,club_id,country_code,match_status) select '%s',id,user_id,club_id,country_code,'manual_review' from public.momo_sms_parsed where id='%s';" % (intent_id(400 + number), intent_id(300 + number)))
                    second = pool.submit(sql, "set application_name='qa_review_present'; set statement_timeout='12s'; " + second_query, check=False)
                    wait_for('qa_review_present', "wait_event_type='Lock'")
                finally:
                    held.stdin.write('commit;\n')
                    held.stdin.flush()
                responses = [first.result(), second.result()]
            held_out, held_error = held.communicate(timeout=15)
            assert held.returncode == 0, held_error
            assert responses[0].returncode == 0, responses[0].stderr
            if expected_second_error:
                assert responses[1].returncode != 0 and expected_second_error in responses[1].stderr, responses[1].stderr
            else:
                assert responses[1].returncode == 0, responses[1].stderr
            assert sql("select count(*) from public.momo_ledger_entries where parsed_sms_id='%s' and ledger_status='posted';" % intent_id(300 + number)).stdout.strip() == '1'
            return responses
        finally:
            if held.poll() is None:
                held.communicate('rollback;\n', timeout=15)

    allocate_across_new_review(20, auto_allocate(20))
    print('PASS automatic allocation retries span absent and newly inserted review without deadlock', flush=True)
    allocate_across_new_review(21, "set request.jwt.claim.sub='%s'; set role authenticated; select * from public.allocate_momo_manual_review('%s','%s','Concurrent receipt');" % (intent_id(3), intent_id(421), intent_id(521)))
    print('PASS manual allocation shares the same evidence serialization as automatic retry', flush=True)
    allocate_across_new_review(22, "set request.jwt.claim.sub='%s'; set role authenticated; select * from public.admin_reject_momo_sms_manual_review('%s','Concurrent rejection');" % (intent_id(3), intent_id(422)), 'MANUAL_REVIEW_STATE_CONFLICT')
    print('PASS concurrent rejection cannot deadlock or overwrite a committed allocation', flush=True)
    allocate_across_new_review(23, "set role service_role; select public.claim_momo_sms_parse('%s','%s',(select updated_at from public.momo_sms_raw where id='%s'),true);" % (intent_id(223), intent_id(1), intent_id(223)))
    print('PASS parser claim waits for the same evidence and respects the committed receipt', flush=True)
    claim = json.loads(sql("set role service_role; select public.claim_momo_sms_parse('%s','%s',(select updated_at from public.momo_sms_raw where id='%s'),true);" % (intent_id(224), intent_id(1), intent_id(224))).stdout.strip().splitlines()[-1])
    assert claim['status'] == 'claimed', claim
    allocate_across_new_review(24, "set role service_role; select public.persist_momo_sms_parse('%s','%s','%s','{}');" % (intent_id(224), intent_id(1), claim['token']), 'MOMO_PARSE_EVIDENCE_COMMITTED')
    print('PASS parser persistence waits and refuses to reinterpret newly committed evidence', flush=True)
    commerce_receipt = allocate_across_new_review(27, "set role service_role; select public.confirm_club_commerce_payment('shop',array['%s'::uuid],'%s','INTENT-TX-27',1000,9952001,'%s','mtn_rwanda','995200100','RWF','RW','%s');" % (intent_id(627), intent_id(1), intent_id(110), intent_id(327)))
    assert json.loads(commerce_receipt[1].stdout.strip().splitlines()[-1])['status'] == 'manual_review'
    print('PASS commerce confirmation cannot deadlock with or repurpose a generic allocation', flush=True)

    # Existing Edge fallbacks write a review/ledger through REST. Their FK
    # checks must not invert a parsed-row lock held by an allocation RPC.
    sql("delete from public.momo_reconciliations where parsed_sms_id='%s';" % intent_id(325))
    responses = operations_after_lock(
        "select id from public.payment_receiver_accounts where id='%s' for update;" % intent_id(100),
        [auto_allocate(25)],
        before_release="insert into public.momo_reconciliations(id,parsed_sms_id,user_id,club_id,country_code,match_status) select '%s',id,user_id,club_id,country_code,'manual_review' from public.momo_sms_parsed where id='%s';" % (intent_id(425), intent_id(325)))
    assert responses[0].returncode == 0, responses[0].stderr
    assert sql("select match_status from public.momo_reconciliations where parsed_sms_id='%s';" % intent_id(325)).stdout.strip() == 'matched'
    print('PASS direct parser review insertion completes its FK check while allocation waits on receiver', flush=True)
    responses = operations_after_lock(
        "select id from public.payment_receiver_accounts where id='%s' for update;" % intent_id(100),
        [auto_allocate(26)],
        before_release="insert into public.momo_ledger_entries(parsed_sms_id,user_id,club_id,country_code,ledger_scope,ledger_status,entry_type,amount,currency) select id,user_id,club_id,country_code,'wallet','draft','debit',amount,currency from public.momo_sms_parsed where id='%s';" % intent_id(326))
    assert responses[0].returncode == 0, responses[0].stderr
    assert sql("select count(*) from public.momo_ledger_entries where parsed_sms_id='%s' and ledger_status='posted';" % intent_id(326)).stdout.strip() == '1'
    print('PASS direct parser ledger insertion completes its FK check and allocates exactly once', flush=True)

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
    from momo_parser_concurrency import run_parser_concurrency
    run_parser_concurrency(sql, operations_after_lock, ROOT)
finally:
    subprocess.run([DOCKER, 'rm', '-f', NAME + '-auth', NAME + '-storage', NAME], capture_output=True, timeout=60)
