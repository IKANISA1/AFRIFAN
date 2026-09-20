"""Parser ownership cases using the existing lock-observed SQL test runner."""
import json


def run_parser_concurrency(sql, operations_after_lock, root):
    actor = '99690000-0000-4000-8000-000000000001'

    def rid(n): return '99690000-0000-4000-8000-' + str(n).zfill(12)

    def claim(n):
        return "set role service_role; select public.claim_momo_sms_parse(id,user_id,updated_at,false) from public.momo_sms_raw where id='%s';" % rid(n)

    payload = json.dumps({'parser_provider': 'contract', 'parser_model': 'v1',
                         'parse_status': 'needs_review', 'tx_direction': 'unknown',
                         'tx_type': 'unknown', 'tx_category': 'uncategorized',
                         'cashflow_bucket': 'unknown', 'amount': 1000, 'currency': 'RWF'})

    def persist(n, token):
        return "set role service_role; select public.persist_momo_sms_parse('%s','%s','%s','%s'::jsonb);" % (rid(n), actor, token, payload)

    def value(result):
        assert result.returncode == 0, result.stderr
        return json.loads(result.stdout.strip().splitlines()[-1])

    rows = []
    seed = (root / 'supabase/tests/momo_parser_claim_contract.sql').read_text().split('-- Reused by the existing')[0]
    assert sql("select count(*) from public.momo_sms_raw where id::text like '99690000-%%';").stdout.strip() == '0'
    sql(seed + '\ncommit;')

    results = operations_after_lock("select id from public.momo_sms_raw where id='%s' for update;" % rid(101), [claim(101)] * 5)
    claims = [value(r) for r in results]
    assert sum(r['status'] == 'claimed' for r in claims) == 1, claims
    first = next(r['token'] for r in claims if r['status'] == 'claimed')
    assert all(r['status'] in ('claimed', 'changed', 'busy') for r in claims), claims
    rows.append('five overlapping claims produce exactly one owner')

    results = operations_after_lock("select id from public.momo_sms_raw where id='%s' for update;" % rid(101),
                                    [persist(101, first), claim(101)],
                                    before_commit="update public.momo_parse_leases set expires_at=clock_timestamp()-interval '1 second' where raw_sms_id='%s';" % rid(101))
    assert results[0].returncode != 0 and 'MOMO_PARSE_LEASE_LOST' in results[0].stderr, results[0]
    replacement = value(results[1])
    assert replacement['status'] == 'claimed' and replacement['token'] != first, replacement
    assert sql("select count(*) from public.momo_sms_parsed where raw_sms_id='%s';" % rid(101)).stdout.strip() == '0'
    rows.append('expired publisher loses to takeover after both wait on the raw row')

    token = replacement['token']
    saved = value(sql(persist(101, token)))
    assert saved['id']
    results = operations_after_lock("select id from public.momo_sms_raw where id='%s' for update;" % rid(101), [claim(101)],
                                    before_commit="update public.momo_parse_leases set expires_at=clock_timestamp()-interval '1 second' where raw_sms_id='%s'; update public.momo_sms_raw set parse_status='failed' where id='%s';" % (rid(101), rid(101)))
    assert value(results[0])['status'] == 'changed', 'The waiting caller still carries the old raw version'
    assert value(sql(claim(101)))['status'] == 'review_required', 'A refreshed caller still cannot bypass the saved interpretation'
    assert sql("select token from public.momo_parse_leases where raw_sms_id='%s';" % rid(101)).stdout.strip() == token
    rows.append('a persisted interpretation cannot be taken over after a lock wait and raw status reset')
    # Restore the source through the fixture owner for the completion-race case.
    sql("update public.momo_sms_raw set parse_status='processing' where id='%s'; update public.momo_parse_leases set raw_version=(select updated_at from public.momo_sms_raw where id='%s') where raw_sms_id='%s';" % (rid(101), rid(101), rid(101)))

    changed = value(sql(claim(103)))['token']
    results = operations_after_lock("select id from public.momo_sms_raw where id='%s' for update;" % rid(103), [persist(103, changed)],
                                    before_commit="update public.momo_sms_raw set sms_body='Changed during blocked publish' where id='%s';" % rid(103))
    assert results[0].returncode != 0 and 'MOMO_PARSE_LEASE_LOST' in results[0].stderr, results[0]
    rows.append('source mutation while publication waits invalidates the interpretation')

    attempt = rid(201)
    sql("insert into public.momo_parse_attempts(id,raw_sms_id,user_id,provider,model,attempt_number,status) values('%s','%s','%s','openai','test',1,'pending');" % (attempt, rid(101), actor))
    complete = "set role service_role; select public.finish_momo_sms_parse('%s','%s','%s',true,'%s','{}','{}');" % (rid(101), actor, token, attempt)
    old_failure = "set role service_role; select public.finish_momo_sms_parse('%s','%s','%s',false);" % (rid(101), actor, first)
    results = operations_after_lock("select id from public.momo_sms_raw where id='%s' for update;" % rid(101), [complete, old_failure])
    assert all(r.returncode == 0 for r in results), [r.stderr for r in results]
    assert results[0].stdout.strip().splitlines()[-1] == 't' and results[1].stdout.strip().splitlines()[-1] == 'f'
    assert sql("select parse_status from public.momo_sms_raw where id='%s';" % rid(101)).stdout.strip() == 'parsed'
    assert sql("select status from public.momo_parse_attempts where id='%s';" % attempt).stdout.strip() == 'success'
    rows.append('late failure cannot undo replacement completion under concurrency')
    for row in rows:
        print('PASS parser', row, flush=True)
    return rows
