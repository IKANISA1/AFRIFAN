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
                 'english_public_membership_contract', 'retired_venue_product_contract',
                 'member_portal_read_contract', 'member_contribution_history_contract',
                 'initiative_confirmation_atomic_contract']:
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
finally:
    subprocess.run([DOCKER, 'rm', '-f', NAME], capture_output=True)
