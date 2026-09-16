#!/usr/bin/env python3
"""Replay migrations and verify concurrent operations in a portless Postgres.
Requires Docker and the Supabase Postgres image. Uses synthetic data only.
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


def sql(query, *, admin=False, check=True):
    args = [DOCKER, 'exec', '-i']
    if admin:
        args += ['-e', 'PGPASSWORD=' + PASSWORD]
    args += [NAME, 'psql', '-X', '-At', '-v', 'ON_ERROR_STOP=1', '-U',
             'supabase_admin' if admin else 'postgres', '-d', 'postgres']
    if admin:
        args += ['-h', '127.0.0.1']
    result = subprocess.run(args, input=query, text=True, capture_output=True)
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


def ticket_scans_after_lock(lock_query, scan_queries, before_release=None):
    """Run scans only after an independent transaction holds the chosen row."""
    held = subprocess.Popen([DOCKER, 'exec', '-i', NAME, 'psql', '-X', '-qAt',
                             '-v', 'ON_ERROR_STOP=1', '-U', 'postgres', '-d', 'postgres'],
                            stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE, text=True)
    try:
        held.stdin.write("set application_name='ticket_scan_hold'; begin; set local idle_in_transaction_session_timeout='15s'; " + lock_query + '\n')
        held.stdin.flush()
        for _ in range(100):
            if sql("select count(*) from pg_stat_activity where application_name='ticket_scan_hold' and state='idle in transaction';").stdout.strip() == '1':
                break
            time.sleep(.05)
        else:
            raise RuntimeError('Ticket test did not acquire its row lock')
        with concurrent.futures.ThreadPoolExecutor(max_workers=len(scan_queries)) as executor:
            futures = [executor.submit(sql, "set application_name='ticket_scan_waiting'; set statement_timeout='10s'; " + query, check=False) for query in scan_queries]
            try:
                for _ in range(100):
                    waiting = sql("select count(*) from pg_stat_activity where application_name='ticket_scan_waiting' and wait_event_type='Lock';").stdout.strip()
                    if waiting == str(len(scan_queries)):
                        break
                    time.sleep(.05)
                else:
                    raise RuntimeError('Every ticket scan must be blocked before release')
                if before_release:
                    sql("set statement_timeout='8s'; " + before_release)
            finally:
                held.stdin.write('commit;\n')
                held.stdin.flush()
            return [future.result() for future in futures]
    finally:
        if held.poll() is None:
            held.communicate('rollback;\n', timeout=20)


try:
    started = subprocess.run([DOCKER, 'run', '-d', '--pull=never', '--name', NAME,
                    '--label', 'africlub.test=database-concurrency', '--network=none',
                    '--cpus=2', '--memory=2g', '--tmpfs', '/var/lib/postgresql/data',
                    '-e', 'POSTGRES_PASSWORD=' + PASSWORD, IMAGE,
                    'postgres', '-D', '/etc/postgresql', '-c', 'cron.launch_active_jobs=off'],
                   capture_output=True, text=True)
    if started.returncode:
        raise RuntimeError('Isolated Postgres startup failed: ' + started.stderr.strip())
    for _ in range(60):
        if sql('select 1;', admin=True, check=False).returncode == 0:
            break
        time.sleep(.5)
    else:
        raise RuntimeError('Isolated Postgres did not start')
    # The database-only image has an old auth scaffold, not the current GoTrue
    # schema. Provide only the current fields/functions the application uses.
    sql("""drop schema public cascade; create schema public authorization postgres;
      create or replace function auth.jwt() returns jsonb language sql stable as $$
      select coalesce(nullif(current_setting('request.jwt.claims',true),''),'{}')::jsonb $$;
      alter table auth.users add column if not exists phone_confirmed_at timestamptz;
      alter table auth.users add column if not exists is_anonymous boolean default false;
      alter table auth.users add column if not exists phone text;
      create table if not exists auth.identities(id uuid primary key default gen_random_uuid(),
        user_id uuid references auth.users(id), provider text, identity_data jsonb, updated_at timestamptz default now());
      grant usage on schema auth to postgres;
      grant select,insert,update,delete on auth.users to postgres;
      grant select on auth.identities to postgres;""", admin=True)
    for migration in sorted((ROOT / 'supabase/migrations').glob('*.sql')):
        if 'gikundiro_club_identity' in migration.name:
            # Owned ephemeral fixture establishes the source registry before the data migration.
            sql("insert into public.african_football_clubs(id,club_name,country_name,club_slug) overriding system value values (24,'Rayon Sports FC','Rwanda','rayon_sports_rw') on conflict do nothing;")
            sql("insert into public.ai_content(club_id,content_type,title,body,status) select 24,'club_history',title,'Superseded application copy','approved' from unnest(array['The beloved identity','Matchday at scale','One supporter account']) title cross join generate_series(1,2);")
        sql(migration.read_text())
        print('Applied', migration.name, flush=True)
    sql('create extension if not exists pgtap with schema extensions;')
    for name in ['club_identity_contract', 'predict_contract', 'runtime_function_volatility_contract',
                 'security_definer_execution_contract', 'store_release_security_boundary_contract',
                 'english_public_membership_contract', 'venue_access_acl_contract']:
        result = sql('set search_path=public,extensions;\n' + (ROOT / 'supabase/tests' / (name + '.sql')).read_text())
        count = len(re.findall(r'^ok \d+', result.stdout, re.M))
        print('PASS', name, count, 'checks', flush=True)

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

    # Reuse the synthetic club and actors in this disposable database. These
    # are confirmed admission fixtures, not a provider payment simulation.
    sql((ROOT / 'tools/scripts/fixtures/ticket_redemption_concurrency.sql').read_text())
    prepared = sql(actor(1) + "select public.prepare_google_wallet_ticket('%s');" % fixture(713))
    credential = json.loads(prepared.stdout.strip().splitlines()[-1])
    credential_id = str(uuid.UUID(credential['credential_id']))
    operation_id = str(uuid.uuid4())
    redeem = "select public.redeem_ticket_for_verifier('%s','%s',%d,'%s','NORTH');" % (
        fixture(5), credential_id, credential['credential_version'], operation_id)
    responses = ticket_scans_after_lock(
        "select id from public.ticket_wallet_credentials where id='%s' for update;" % credential_id,
        [redeem, redeem])
    assert all(r.returncode == 0 for r in responses), [r.stderr for r in responses]
    decisions = [json.loads(r.stdout.strip().splitlines()[-1]) for r in responses]
    assert all(d['code'] == 'admitted' for d in decisions), decisions
    assert sorted(d['replayed'] for d in decisions) == [False, True], decisions
    assert decisions[0]['scanned_at'] == decisions[1]['scanned_at'], decisions
    assert sql("select count(*) from public.ticket_redemption_events where verifier_user_id='%s' and operation_id='%s';" % (fixture(5), operation_id)).stdout.strip() == '1'
    assert sql("select status from public.tickets where id='%s';" % fixture(713)).stdout.strip() == 'used'
    print('PASS overlapping ticket retries return the same admission and one immutable audit event', flush=True)

    deadline_failures = []
    for number, deadline_table, deadline_column, held_table, expected in [
        (715, 'ticket_events', 'entry_closes_at', 'ticket_wallet_credentials', 'expired'),
        (716, 'ticket_verifier_assignments', 'ends_at', 'ticket_wallet_credentials', 'permission_denied'),
        (717, 'ticket_verifier_assignments', 'ends_at', 'ticket_verifier_assignments', 'permission_denied'),
    ]:
        sql("update public.ticket_events set entry_closes_at=clock_timestamp()+interval '1 hour' where id='%s';" % fixture(714))
        sql("update public.ticket_verifier_assignments set ends_at=clock_timestamp()+interval '30 minutes' where ticket_event_id='%s';" % fixture(714))
        sql("insert into public.tickets(id,match_id,user_id,club_id,seat_type,amount_paid,status,confirmed_at) select '%s',match_id,user_id,club_id,seat_type,amount_paid,'valid',clock_timestamp() from public.tickets where id='%s';" % (fixture(number), fixture(713)))
        prepared = json.loads(sql(actor(1) + "select public.prepare_google_wallet_ticket('%s');" % fixture(number)).stdout.strip().splitlines()[-1])
        credential_id = str(uuid.UUID(prepared['credential_id']))
        deadline_filter = "id='%s'" % fixture(714) if deadline_table == 'ticket_events' else "ticket_event_id='%s'" % fixture(714)
        lock_filter = "id='%s'" % credential_id if held_table == 'ticket_wallet_credentials' else "ticket_event_id='%s'" % fixture(714)
        sql("update public.%s set %s=clock_timestamp()+interval '1 second' where %s;" % (deadline_table, deadline_column, deadline_filter))
        query = "select public.redeem_ticket_for_verifier('%s','%s',%d,'%s','NORTH');" % (fixture(5), credential_id, prepared['credential_version'], str(uuid.uuid4()))
        responses = ticket_scans_after_lock(
            'select id from public.%s where %s for update;' % (held_table, lock_filter), [query],
            "select pg_sleep(greatest(0,extract(epoch from (%s-clock_timestamp())))+.1) from public.%s where %s;" % (deadline_column, deadline_table, deadline_filter))
        response = responses[0]
        assert response.returncode == 0, response.stderr
        decision = json.loads(response.stdout.strip().splitlines()[-1])
        state = sql("select jsonb_build_object('ticket_status',status,'admissions',(select count(*) from public.ticket_redemption_events where ticket_id=t.id and decision='admitted')) from public.tickets t where id='%s';" % fixture(number)).stdout.strip()
        state = json.loads(state)
        passed = decision['code'] == expected and state == {'ticket_status': 'valid', 'admissions': 0}
        print(('PASS' if passed else 'FAIL'), 'ticket deadline after lock', json.dumps({'deadline': deadline_table + '.' + deadline_column, 'held': held_table, 'expected': expected, 'actual': decision['code'], **state}), flush=True)
        if not passed:
            deadline_failures.append(number)
    assert not deadline_failures, 'Expired ticket scans admitted after waiting: ' + str(deadline_failures)

    # Request identity binds immutable replay to the same credential, version
    # and normalized gate. A different request must never replay a green result.
    sql("update public.ticket_events set entry_closes_at=clock_timestamp()+interval '1 hour' where id='%s';" % fixture(714))
    sql("update public.ticket_verifier_assignments set ends_at=clock_timestamp()+interval '30 minutes' where ticket_event_id='%s';" % fixture(714))
    sql("insert into public.tickets(id,match_id,user_id,club_id,seat_type,amount_paid,status,confirmed_at) select '%s',match_id,user_id,club_id,seat_type,amount_paid,'valid',clock_timestamp() from public.tickets where id='%s';" % (fixture(718), fixture(713)))
    other_credential = json.loads(sql(actor(1) + "select public.prepare_google_wallet_ticket('%s');" % fixture(718)).stdout.strip().splitlines()[-1])
    original_credential_id = str(uuid.UUID(credential['credential_id']))
    other_credential_id = str(uuid.UUID(other_credential['credential_id']))
    original_audit = sql("select to_jsonb(e) from public.ticket_redemption_events e where verifier_user_id='%s' and operation_id='%s';" % (fixture(5), operation_id)).stdout.strip()
    replay_failures = []
    for changed, scan_credential, version, gate in [
        ('credential', other_credential_id, other_credential['credential_version'], 'NORTH'),
        ('version', original_credential_id, credential['credential_version'] + 1, 'NORTH'),
        ('gate', original_credential_id, credential['credential_version'], 'SOUTH'),
    ]:
        response = sql("select public.redeem_ticket_for_verifier('%s','%s',%d,'%s','%s');" % (fixture(5), scan_credential, version, operation_id, gate))
        decision = json.loads(response.stdout.strip().splitlines()[-1])
        passed = decision.get('status') == 'rejected' and decision.get('code') == 'operation_conflict' and not decision.get('replayed') and 'ticket_id' not in decision
        print(('PASS' if passed else 'FAIL'), 'ticket operation payload binding', json.dumps({'changed': changed, 'expected': 'operation_conflict', 'actual': decision.get('code'), 'replayed': decision.get('replayed')}), flush=True)
        if not passed:
            replay_failures.append(changed)
    assert sql("select to_jsonb(e) from public.ticket_redemption_events e where verifier_user_id='%s' and operation_id='%s';" % (fixture(5), operation_id)).stdout.strip() == original_audit
    assert sql("select status from public.tickets where id='%s';" % fixture(718)).stdout.strip() == 'valid'
    unchanged = json.loads(sql(redeem).stdout.strip().splitlines()[-1])
    assert unchanged['code'] == 'admitted' and unchanged['replayed']

    # Historical rows have no recorded request version. Preserve the audit,
    # but do not guess a binding and return an admission for an unknown request.
    legacy_operation = str(uuid.uuid4())
    sql("""insert into public.ticket_redemption_events(
        club_id,organization_id,ticket_event_id,venue_id,ticket_id,credential_id,
        verifier_assignment_id,verifier_user_id,operation_id,gate_code,decision,result,scanned_at)
        select club_id,organization_id,ticket_event_id,venue_id,ticket_id,credential_id,
        verifier_assignment_id,verifier_user_id,'%s',gate_code,decision,result,scanned_at
        from public.ticket_redemption_events where verifier_user_id='%s' and operation_id='%s';""" % (legacy_operation, fixture(5), operation_id))
    legacy_audit = sql("select to_jsonb(e) from public.ticket_redemption_events e where operation_id='%s';" % legacy_operation).stdout.strip()
    response = sql("select public.redeem_ticket_for_verifier('%s','%s',%d,'%s','NORTH');" % (fixture(5), original_credential_id, credential['credential_version'], legacy_operation))
    legacy = json.loads(response.stdout.strip().splitlines()[-1])
    passed = legacy.get('code') == 'operation_conflict' and legacy.get('status') == 'rejected' and 'ticket_id' not in legacy
    print(('PASS' if passed else 'FAIL'), 'legacy operation with unknown request version', json.dumps({'expected': 'operation_conflict', 'actual': legacy.get('code')}), flush=True)
    if not passed:
        replay_failures.append('legacy_unknown_version')
    assert sql("select to_jsonb(e) from public.ticket_redemption_events e where operation_id='%s';" % legacy_operation).stdout.strip() == legacy_audit

    revocation_failures = []
    for number, held_table, change, expected in [
        (719, 'ticket_wallet_credentials', 'event', 'permission_denied'),
        (720, 'ticket_verifier_assignments', 'event', 'permission_denied'),
        (721, 'ticket_wallet_credentials', 'assignment', 'permission_denied'),
        (722, 'ticket_wallet_credentials', 'credential', 'credential_inactive'),
        (723, 'ticket_verifier_assignments', 'assignment', 'permission_denied'),
    ]:
        sql("update public.ticket_events set status='active',verification_enabled=true,entry_closes_at=clock_timestamp()+interval '1 hour' where id='%s';" % fixture(714))
        sql("update public.ticket_verifier_assignments set is_active=true,revoked_at=null,revoked_by=null,ends_at=clock_timestamp()+interval '30 minutes' where ticket_event_id='%s';" % fixture(714))
        sql("insert into public.tickets(id,match_id,user_id,club_id,seat_type,amount_paid,status,confirmed_at) select '%s',match_id,user_id,club_id,seat_type,amount_paid,'valid',clock_timestamp() from public.tickets where id='%s';" % (fixture(number), fixture(713)))
        prepared = json.loads(sql(actor(1) + "select public.prepare_google_wallet_ticket('%s');" % fixture(number)).stdout.strip().splitlines()[-1])
        scan_credential = str(uuid.UUID(prepared['credential_id']))
        lock_filter = "id='%s'" % scan_credential if held_table == 'ticket_wallet_credentials' else "ticket_event_id='%s'" % fixture(714)
        held_query = 'select id from public.%s where %s for update;' % (held_table, lock_filter)
        before_release = None
        if change == 'event':
            before_release = "update public.ticket_events set verification_enabled=false where id='%s';" % fixture(714)
        elif change == 'assignment':
            revoke = "select public.revoke_ticket_verifier_assignment('%s',9946001,id,updated_at) from public.ticket_verifier_assignments where ticket_event_id='%s';" % (fixture(5), fixture(714))
            if held_table == 'ticket_verifier_assignments':
                held_query += revoke
            else:
                before_release = revoke
        else:
            held_query += "update public.ticket_wallet_credentials set status='revoked',revoked_at=clock_timestamp() where id='%s';" % scan_credential
        query = "select public.redeem_ticket_for_verifier('%s','%s',%d,'%s','NORTH');" % (fixture(5), scan_credential, prepared['credential_version'], str(uuid.uuid4()))
        response = ticket_scans_after_lock(held_query, [query], before_release)[0]
        assert response.returncode == 0, response.stderr
        decision = json.loads(response.stdout.strip().splitlines()[-1])
        state = json.loads(sql("select jsonb_build_object('ticket_status',status,'admissions',(select count(*) from public.ticket_redemption_events where ticket_id=t.id and decision='admitted')) from public.tickets t where id='%s';" % fixture(number)).stdout.strip())
        passed = decision['code'] == expected and state == {'ticket_status': 'valid', 'admissions': 0}
        print(('PASS' if passed else 'FAIL'), 'ticket access revoked during lock wait', json.dumps({'revoked': change, 'held': held_table, 'expected': expected, 'actual': decision['code'], **state}), flush=True)
        if not passed:
            revocation_failures.append(number)
    sql("update public.ticket_events set verification_enabled=true where id='%s';" % fixture(714))
    sql("update public.ticket_verifier_assignments set is_active=true,revoked_at=null,revoked_by=null where ticket_event_id='%s';" % fixture(714))
    competing_credentials = []
    for number in [724, 725]:
        sql("insert into public.tickets(id,match_id,user_id,club_id,seat_type,amount_paid,status,confirmed_at) select '%s',match_id,user_id,club_id,seat_type,amount_paid,'valid',clock_timestamp() from public.tickets where id='%s';" % (fixture(number), fixture(713)))
        competing_credentials.append(json.loads(sql(actor(1) + "select public.prepare_google_wallet_ticket('%s');" % fixture(number)).stdout.strip().splitlines()[-1]))
    shared_operation = str(uuid.uuid4())
    queries = ["select public.redeem_ticket_for_verifier('%s','%s',%d,'%s','NORTH');" % (fixture(5), c['credential_id'], c['credential_version'], shared_operation) for c in competing_credentials]
    responses = ticket_scans_after_lock("select id from public.ticket_wallet_credentials where id in ('%s','%s') for update;" % tuple(c['credential_id'] for c in competing_credentials), queries)
    assert all(r.returncode == 0 for r in responses), [r.stderr for r in responses]
    results = [json.loads(r.stdout.strip().splitlines()[-1]) for r in responses]
    passed = sorted(r['code'] for r in results) == ['admitted', 'operation_conflict'] and all(not r['replayed'] for r in results)
    print(('PASS' if passed else 'FAIL'), 'concurrent different tickets with one operation', json.dumps({'expected': ['admitted', 'operation_conflict'], 'actual': [r['code'] for r in results]}), flush=True)
    if not passed:
        replay_failures.append('concurrent_different_tickets')
    assert sql("select count(*) from public.ticket_redemption_events where verifier_user_id='%s' and operation_id='%s';" % (fixture(5), shared_operation)).stdout.strip() == '1'
    assert sql("select count(*) from public.tickets where id in ('%s','%s') and status='used';" % (fixture(724), fixture(725))).stdout.strip() == '1'
    assert not replay_failures and not revocation_failures, 'Unsafe operation replay or revoked admission: ' + str({'payload': replay_failures, 'revocation': revocation_failures})
finally:
    subprocess.run([DOCKER, 'rm', '-f', NAME], capture_output=True)
