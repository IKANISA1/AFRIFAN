"""Actual original manual football proof/barrier admission behind independent locks.

The parent harness proves a real Lock wait before releasing every holder. No
provider executes. Stored deadlines and actual vendor Auth session rows are used;
no synthetic stored-proof mutation or newer-session borrowing supplies authority.
"""
import json
import time


def _psql_scalar(result):
    """Read one result row after psql's explicit session command tags.

    The harness deliberately uses -At without -q. Discard only leading SET
    and RESET tags; extra, missing or failed query results remain failures.
    """
    diagnostic = {'returncode': result.returncode, 'stdout': result.stdout,
                  'stderr': result.stderr}
    assert result.returncode == 0, diagnostic
    lines = result.stdout.strip().splitlines()
    while lines and lines[0] in ('SET', 'RESET'):
        lines.pop(0)
    assert len(lines) == 1, diagnostic
    return lines[0]


def run_football_sync_command_concurrency(sql, operations_after_lock, root):
    def ident(n):
        return '99969800-0000-4000-8000-' + str(n).zfill(12)

    actor = ident(1)
    service_claims = "set request.jwt.claim.sub='';set request.jwt.claim.role='service_role';set request.jwt.claims='{\"role\":\"service_role\"}';set request.headers='{}';"
    service = service_claims + 'set role service_role;'
    owner = service_claims + 'reset role;'

    def scalar(query):
        return _psql_scalar(sql(owner + query))

    assert scalar('select count(*) from public.african_football_clubs where id=9996981;') == '0'
    sql((root / 'tools/scripts/fixtures/football_sync_command_concurrency.sql').read_text())

    def val(result):
        return json.loads(_psql_scalar(result))

    def caller(session, ttl=600):
        now = int(time.time())
        claims = {'sub': actor, 'role': 'authenticated', 'is_anonymous': False,
                  'aal': 'aal2', 'exp': now + ttl, 'session_id': session,
                  'amr': [{'method': 'totp', 'timestamp': now}]}
        return "set request.jwt.claim.sub='%s';set request.jwt.claim.role='authenticated';set request.jwt.claims='%s';set request.headers='{}';set role authenticated;" % (actor, json.dumps(claims))

    def session(n):
        result = ident(n + 2000)
        sql(owner + "insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values('%s','%s',clock_timestamp(),clock_timestamp(),'aal2',clock_timestamp()+interval '1 hour');" % (result, actor))
        return result

    def admit(n, *, ttl=600, command='sync-fixtures', session_id=None):
        session_id = session_id or session(n)
        receipt = val(sql(caller(session_id, ttl) + "select public.admit_manual_football_sync('%s','%s');" % (ident(n), json.dumps({'command': command}))))
        assert receipt['command']['scope'] == 'global'
        return session_id, receipt

    def claim(n, lease, proof):
        return service + "select public.claim_manual_football_sync('%s','%s','%s');" % (ident(n), ident(lease), proof)

    def start(n, lease, url=None):
        url = url or 'https://v3.football.api-sports.io/fixtures?league=199698&season=2026'
        return service + "select public.start_manual_football_request('%s','%s','%s');" % (ident(n), ident(lease), url)

    def expire(n, proof):
        return "select pg_sleep(greatest(0,extract(epoch from((select(proof->>'expires_at')::timestamptz from public.manual_football_sync_proofs where operation_id='%s' and proof_id='%s')-clock_timestamp())))+0.2);" % (ident(n), proof)

    def no_starts(n):
        operation = ident(n)
        result = sql(owner + """select jsonb_build_object(
          'operation_id','%s', 'request_count',(select count(*) from public.manual_football_sync_requests where operation_id='%s'),
          'command',(select jsonb_build_object('actor_id',actor_id,'state',state,'lease_token',lease_token,
            'lease_proof_id',lease_proof_id,'current_proof_id',current_proof_id,'lease_until',lease_until)
            from public.manual_football_sync_commands where operation_id='%s'),
          'retained_requests',(select coalesce(jsonb_agg(jsonb_build_object('request_id',request_id,'state',state,
            'attempt',attempt,'url',url,'lease_token',lease_token,'lease_proof_id',lease_proof_id,
            'source_request_id',source_request_id) order by request_id),'[]'::jsonb)
            from public.manual_football_sync_requests where operation_id='%s'),
          'current_user',current_user,'jwt_role',auth.role());""" % ((operation,) * 4))
        observed = val(result)
        print('DIAGNOSTIC football zero-request invariant: ' + json.dumps(observed, sort_keys=True), flush=True)
        if n == 701:
            print('DIAGNOSTIC football psql transcript: ' + json.dumps(result.stdout), flush=True)
        assert observed['operation_id'] == operation and observed['request_count'] == 0 and observed['retained_requests'] == [], {
            'observed': observed, 'stdout': result.stdout, 'stderr': result.stderr}

    def denied(result, *expected):
        assert result.returncode != 0 and any(code in result.stderr for code in expected), result.stderr

    # An existing command or retained request cannot masquerade as a new claim.
    assert scalar("select count(*) from public.manual_football_sync_commands where operation_id::text like '99969800-0000-4000-8000-%';") == '0'
    assert scalar("select count(*) from public.manual_football_sync_requests where operation_id::text like '99969800-0000-4000-8000-%';") == '0'
    no_starts(701)
    _, receipt = admit(701)
    no_starts(701)
    results = operations_after_lock("select operation_id from public.manual_football_sync_commands where operation_id='%s' for update;" % ident(701),
                                    [claim(701, n, receipt['dispatch_proof_id']) for n in (801, 802)])
    claims = [val(result) for result in results]
    assert sum(c['claimed'] for c in claims) == 1, claims
    no_starts(701)
    print('PASS actual overlapping football workers: one original lease, zero provider barriers', flush=True)

    # Pause a genuine authenticated renewal at the actor lifecycle boundary,
    # before its operation lock. Every old worker must wait there rather than
    # hold the operation and deadlock the actual admission in before_commit.
    # A new real Auth session appends a proof; it cannot replace the old lease.
    for n, path in ((720, 'claim'), (721, 'start'), (722, 'complete'), (723, 'assert'), (724, 'finish'), (725, 'publication')):
        _, original = admit(n)
        original_proof = original['dispatch_proof_id']
        lease = n + 100
        request = None
        if path != 'claim':
            val(sql(claim(n, lease, original_proof)))
        if path == 'complete':
            request = val(sql(start(n, lease)))
        if path == 'claim':
            query = claim(n, lease, original_proof)
        elif path == 'start':
            query = start(n, lease)
        elif path == 'complete':
            query = service + "select public.complete_manual_football_request('%s','%s','%s',200,'{\"content-type\":\"application/json\"}',encode(convert_to('{\"response\":[]}', 'UTF8'),'base64'));" % (ident(n), ident(lease), request['request_id'])
        elif path == 'assert':
            query = service + "select public.assert_manual_football_sync('%s','%s');" % (ident(n), ident(lease))
        elif path == 'finish':
            query = service + "select public.finish_manual_football_sync('%s','%s','{\"success\":true,\"synthetic\":true}');" % (ident(n), ident(lease))
        else:
            context = json.dumps({'x-africlub-football-operation': ident(n), 'x-africlub-football-lease': ident(lease),
                                  'x-africlub-football-proof': original_proof})
            query = service + "set request.headers='%s';update public.football_sync_config set last_synced_at=clock_timestamp() where id='%s';" % (context, ident(601))
        renewed_session = session(n + 1000)
        renewal = caller(renewed_session) + "select public.admit_manual_football_sync('%s','{\"command\":\"sync-fixtures\"}');" % ident(n)
        response = operations_after_lock(caller(renewed_session) + 'select public.assert_account_active();',
                                         [query], before_commit=renewal)[0]
        output = val(response) if path != 'publication' else response
        if path == 'publication':
            assert response.returncode == 0, response.stderr
        elif path == 'claim':
            assert output['claimed']
        elif path == 'start':
            assert not output['cached']
        elif path == 'complete':
            assert output['recorded']
        elif path == 'assert':
            assert output['allowed']
        else:
            assert output['command']['state'] == 'completed'
        assert scalar("select lease_proof_id='%s' and lease_token='%s' and current_proof_id<>lease_proof_id from public.manual_football_sync_commands where operation_id='%s';" % (original_proof, ident(lease), ident(n))) == 't'
        assert scalar("select count(*) from public.manual_football_sync_proofs where operation_id='%s';" % ident(n)) == '2'
        expected = 1 if path in ('start', 'complete') else 0
        assert scalar("select count(*) from public.manual_football_sync_requests where operation_id='%s';" % ident(n)) == str(expected)
        if path == 'start':
            # Retain the real known mocked response, so the following independent
            # fixture can test the same URL without an artificial uncertain GET.
            val(sql(service + "select public.complete_manual_football_request('%s','%s','%s',200,'{\"content-type\":\"application/json\"}',encode(convert_to('{\"response\":[]}', 'UTF8'),'base64'));" % (ident(n), ident(lease), output['request_id'])))
        print('PASS genuine caller renewal overlaps football %s: actor before operation, exact original lease proof, no duplicate GET' % path, flush=True)

    # The actual per-league row is read after the original proof check. It must
    # reject a deadline that expires while waiting before any GET can start.
    _, receipt = admit(702, ttl=5)
    val(sql(claim(702, 803, receipt['dispatch_proof_id'])))
    result = operations_after_lock("select id from public.football_sync_config where id='%s' for update;" % ident(601),
                                  [start(702, 803)], before_release=expire(702, receipt['dispatch_proof_id']))[0]
    denied(result, 'FOOTBALL_LEASE_LOST', 'PROVIDER_ASSURANCE_EXPIRED')
    no_starts(702)
    print('PASS original football request/config wait past immutable deadline: no provider barrier committed', flush=True)

    for n, kind in ((703, 'grant'), (704, 'session')):
        sid, receipt = admit(n)
        lock = ("select id from public.admin_role_assignments where user_id='%s' and club_id is null for update;" % actor if kind == 'grant'
                else "select id from auth.sessions where id='%s' for update;" % sid)
        mutation = (owner + "update public.admin_role_assignments set is_active=false,revoked_at=clock_timestamp() where user_id='%s';" % actor if kind == 'grant'
                    else owner + "delete from auth.sessions where id='%s';" % sid)
        result = operations_after_lock(lock, [claim(n, n + 101, receipt['dispatch_proof_id'])], before_commit=mutation)[0]
        denied(result, 'PROVIDER_STAFF_AUTHORITY_REQUIRED' if kind == 'grant' else 'PROVIDER_SESSION_REVOKED')
        no_starts(n)
        if kind == 'grant':
            sql(owner + "update public.admin_role_assignments set is_active=true,revoked_at=null where user_id='%s';" % actor)
        print('PASS actual football %s wait then revocation: no lease or GET barrier' % kind, flush=True)

    # An actual publication statement obtains the operation at statement entry,
    # then waits on the row. Its row trigger must recheck after that row wait.
    _, receipt = admit(705, ttl=5)
    val(sql(claim(705, 806, receipt['dispatch_proof_id'])))
    headers = json.dumps({'x-africlub-football-operation': ident(705), 'x-africlub-football-lease': ident(806),
                          'x-africlub-football-proof': receipt['dispatch_proof_id']})
    publication = service + "set request.headers='%s';update public.football_sync_config set last_synced_at=clock_timestamp() where id='%s';" % (headers, ident(601))
    previous = scalar("select coalesce(last_synced_at::text,'null') from public.football_sync_config where id='%s';" % ident(601))
    result = operations_after_lock("select id from public.football_sync_config where id='%s' for update;" % ident(601),
                                  [publication], before_release=expire(705, receipt['dispatch_proof_id']))[0]
    denied(result, 'FOOTBALL_LEASE_LOST', 'PROVIDER_ASSURANCE_EXPIRED')
    assert scalar("select coalesce(last_synced_at::text,'null') from public.football_sync_config where id='%s';" % ident(601)) == previous
    print('PASS actual football publication row wait past original proof: no stale progress mutation', flush=True)

    _, receipt = admit(706)
    val(sql(claim(706, 807, receipt['dispatch_proof_id'])))
    result = operations_after_lock("select id from public.football_sync_config where id='%s' for update;" % ident(601),
                                  [start(706, 807)], before_commit=owner + "update public.football_sync_config set season_year=2025 where id='%s';" % ident(601))[0]
    denied(result, 'FOOTBALL_TARGET_CHANGED')
    no_starts(706)
    sql(owner + "update public.football_sync_config set season_year=2026 where id='%s';" % ident(601))
    print('PASS actual changed configured season after wait cannot borrow original global snapshot', flush=True)

    original_session, receipt = admit(707, command='status')
    val(sql(claim(707, 808, receipt['dispatch_proof_id'])))
    request = val(sql(start(707, 808, 'https://v3.football.api-sports.io/status')))
    val(sql(service + "select public.complete_manual_football_request('%s','%s','%s',null,'{}',null);" % (ident(707), ident(808), request['request_id'])))
    val(sql(service + "select public.finish_manual_football_sync('%s','%s','{\"success\":false}');" % (ident(707), ident(808))))
    # A real renewed login has a distinct vendor session. Keep the original
    # session/proof and uncertain GET; admission cannot reset that outcome.
    renewed_session = session(1707)
    assert renewed_session != original_session
    _, same = admit(707, command='status', session_id=renewed_session)
    assert same['command']['state'] == 'unknown' and 'dispatch_proof_id' not in same
    assert scalar("select count(*) from auth.sessions where id in('%s','%s') and user_id='%s';" % (original_session, renewed_session, actor)) == '2'
    assert scalar("select proof->>'session_id' from public.manual_football_sync_proofs where operation_id='%s' and proof_id='%s';" % (ident(707), receipt['dispatch_proof_id'])) == original_session
    assert scalar("select count(*) from public.manual_football_sync_requests where operation_id='%s';" % ident(707)) == '1'
    assert scalar("select state from public.manual_football_sync_requests where request_id='%s';" % request['request_id']) == 'unknown'
    _, renewed = admit(708, command='status')
    val(sql(claim(708, 809, renewed['dispatch_proof_id'])))
    denied(sql(start(708, 809, 'https://v3.football.api-sports.io/status'), check=False), 'FOOTBALL_REQUEST_OUTCOME_UNKNOWN')
    no_starts(708)
    print('PASS unknown original GET remains once across renewed proof and new duplicate operation', flush=True)

    old_session, old = admit(709, ttl=3)
    val(sql(claim(709, 810, old['dispatch_proof_id'])))
    sql(expire(709, old['dispatch_proof_id']))
    sql(owner + "delete from auth.sessions where id='%s';" % old_session)
    _, fresh = admit(709, session_id=session(1709))
    denied(sql(claim(709, 810, fresh['dispatch_proof_id']), check=False), 'FOOTBALL_LEASE_REUSE')
    val(sql(claim(709, 811, fresh['dispatch_proof_id'])))
    denied(sql(service + "select public.assert_manual_football_sync('%s','%s');" % (ident(709), ident(810)), check=False), 'FOOTBALL_LEASE_LOST')
    denied(sql(start(709, 810), check=False), 'FOOTBALL_LEASE_LOST')
    print('PASS newly admitted actual session cannot renew an old worker lease or borrow its authority', flush=True)

    def logo_barrier(n, lease, team, *, ttl=600, version='qa-1'):
        _, receipt = admit(n, ttl=ttl, command='download-logos')
        val(sql(claim(n, lease, receipt['dispatch_proof_id'])))
        get = val(sql(start(n, lease, 'https://media.api-sports.io/football/teams/%s.png' % team)))
        val(sql(service + "select public.complete_manual_football_request('%s','%s','%s',200,'{\"content-type\":\"image/png\"}',encode(decode('010203','hex'),'base64'));" % (ident(n), ident(lease), get['request_id'])))
        put = val(sql(start(n, lease, 'storage:football-assets/teams/%s.png' % team)))
        metadata = {'manual_football_operation': ident(n), 'manual_football_lease': ident(lease),
                    'manual_football_proof': receipt['dispatch_proof_id'], 'manual_football_request': put['request_id'],
                    'content_sha256': put['content_sha256']}
        sql(service + "insert into storage.objects(bucket_id,name,version,metadata,user_metadata) values('football-assets','teams/%s.png','%s','{\"size\":3,\"mimetype\":\"image/png\"}','%s');" % (team, version, json.dumps(metadata)))
        return receipt, put

    # Vendor Storage publishes the actual object row, not arbitrary forwarded
    # PostgREST headers. Its stored user_metadata names the immutable original
    # barrier, and the BEFORE/AFTER row guards check that proof after the wait.
    receipt, put = logo_barrier(710, 812, 199698, ttl=5, version='1')
    result = operations_after_lock("select id from storage.objects where bucket_id='football-assets' and name='teams/199698.png' for update;",
                                  [service + "update storage.objects set version='qa-final' where bucket_id='football-assets' and name='teams/199698.png';"],
                                  before_release=expire(710, receipt['dispatch_proof_id']))[0]
    denied(result, 'FOOTBALL_LEASE_LOST', 'PROVIDER_ASSURANCE_EXPIRED')
    assert scalar("select version from storage.objects where bucket_id='football-assets' and name='teams/199698.png';") == '1'
    assert scalar("select state from public.manual_football_sync_requests where request_id='%s';" % put['request_id']) == 'started'
    assert scalar("select count(*) from public.manual_football_sync_requests where operation_id='%s';" % ident(710)) == '2'
    print('PASS actual Storage publication row wait expires original upload proof: no completed object or repeat barrier', flush=True)

    receipt, put = logo_barrier(711, 813, 199699)
    val(sql(service + "select public.complete_manual_football_request('%s','%s','%s',null,'{}',null);" % (ident(711), ident(813), put['request_id'])))
    val(sql(service + "select public.finish_manual_football_sync('%s','%s','{\"success\":false}');" % (ident(711), ident(813))))
    _, review = admit(711, ttl=5, command='download-logos', session_id=session(1711))
    recovery = val(sql(claim(711, 814, review['dispatch_proof_id'])))
    assert recovery['mode'] == 'reconcile_storage'
    complete = service + "select public.complete_manual_football_request('%s','%s','%s',200,'{\"content-type\":\"image/png\"}',encode(decode('010203','hex'),'base64'));" % (ident(711), ident(814), put['request_id'])
    result = operations_after_lock("select id from storage.objects where bucket_id='football-assets' and name='teams/199699.png' for update;",
                                  [complete], before_release=expire(711, review['dispatch_proof_id']))[0]
    denied(result, 'FOOTBALL_LEASE_LOST', 'PROVIDER_ASSURANCE_EXPIRED')
    assert scalar("select state from public.manual_football_sync_requests where request_id='%s';" % put['request_id']) == 'unknown'
    _, fresh = admit(711, command='download-logos', session_id=session(2711))
    assert val(sql(claim(711, 815, fresh['dispatch_proof_id'])))['mode'] == 'reconcile_storage'
    val(sql(service + "select public.complete_manual_football_request('%s','%s','%s',200,'{\"content-type\":\"image/png\"}',encode(decode('010203','hex'),'base64'));" % (ident(711), ident(815), put['request_id'])))
    assert scalar("select count(*) from public.manual_football_sync_requests where operation_id='%s';" % ident(711)) == '2'
    denied(sql(start(711, 815, 'https://media.api-sports.io/football/teams/199699.png'), check=False), 'FOOTBALL_RECONCILIATION_READ_ONLY')
    print('PASS actual original Storage readback row wait expires recovery proof: fresh read-only retry verifies same object without GET/upload', flush=True)

    # xp_events is the existing compatibility view. Its INSTEAD OF writer
    # waits on the real fet_events row, where the original proof is checked.
    _, receipt = admit(712, ttl=5, command='auto-settle')
    val(sql(claim(712, 816, receipt['dispatch_proof_id'])))
    headers = json.dumps({'x-africlub-football-operation': ident(712), 'x-africlub-football-lease': ident(816),
                          'x-africlub-football-proof': receipt['dispatch_proof_id']})
    result = operations_after_lock("select id from public.fet_events where id='%s' for update;" % ident(650),
                                  [service + "set request.headers='%s';update public.xp_events set xp_awarded=9 where id='%s';" % (headers, ident(650))],
                                  before_release=expire(712, receipt['dispatch_proof_id']))[0]
    denied(result, 'FOOTBALL_LEASE_LOST', 'PROVIDER_ASSURANCE_EXPIRED')
    assert scalar("select fet_awarded from public.fet_events where id='%s';" % ident(650)) == '3'
    assert scalar("select xp_awarded from public.xp_events where id='%s';" % ident(650)) == '3'
    no_starts(712)
    print('PASS actual xp_events compatibility writer backing-row wait expires original proof: no stale reward or GET barrier', flush=True)

    # Metadata-only Storage runs after its object tuple lock. It must also
    # share actor-before-operation order with a genuine caller renewal.
    original, put = logo_barrier(726, 826, 199700)
    renewed_session = session(1726)
    renewal = caller(renewed_session) + "select public.admit_manual_football_sync('%s','{\"command\":\"download-logos\"}');" % ident(726)
    update_object = service + "update storage.objects set version='qa-final' where bucket_id='football-assets' and name='teams/199700.png';"
    response = operations_after_lock(caller(renewed_session) + 'select public.assert_account_active();',
                                     [update_object], before_commit=renewal)[0]
    assert response.returncode == 0, response.stderr
    assert scalar("select lease_proof_id='%s' and current_proof_id<>lease_proof_id from public.manual_football_sync_commands where operation_id='%s';" % (original['dispatch_proof_id'], ident(726))) == 't'
    assert scalar("select version from storage.objects where bucket_id='football-assets' and name='teams/199700.png';") == 'qa-final'
    print('PASS genuine caller renewal overlaps metadata-only Storage: exact original upload proof, no operation/actor inversion', flush=True)

    # A delayed original Storage worker owns the object row first. Readback
    # must wait there BEFORE actor/command; otherwise its held command and the
    # old row guard form a real cycle. Catch only the exact authority denial,
    # never 40P01 deadlock, then require successful original-byte reconciliation.
    val(sql(service + "select public.complete_manual_football_request('%s','%s','%s',null,'{}',null);" % (ident(726), ident(826), put['request_id'])))
    val(sql(service + "select public.finish_manual_football_sync('%s','%s','{\"success\":false}');" % (ident(726), ident(826))))
    _, review = admit(726, command='download-logos', session_id=session(2726))
    recovery = val(sql(claim(726, 827, review['dispatch_proof_id'])))
    assert recovery['mode'] == 'reconcile_storage'
    complete = service + "select public.complete_manual_football_request('%s','%s','%s',200,'{\"content-type\":\"image/png\"}',encode(decode('010203','hex'),'base64'));" % (ident(726), ident(827), put['request_id'])
    late_update = service + "do $overlap$ begin update storage.objects set version='qa-late-old-worker' where bucket_id='football-assets' and name='teams/199700.png'; raise exception 'OLD_STORAGE_WORKER_UNEXPECTEDLY_ADMITTED'; exception when insufficient_privilege then if sqlerrm<>'FOOTBALL_ORIGINAL_PROOF_REQUIRED' then raise;end if;end $overlap$;"
    response = operations_after_lock("select id from storage.objects where bucket_id='football-assets' and name='teams/199700.png' for update;",
                                     [complete], before_commit=late_update)[0]
    assert val(response)['recorded']
    assert scalar("select version from storage.objects where bucket_id='football-assets' and name='teams/199700.png';") == 'qa-final'
    assert scalar("select state from public.manual_football_sync_requests where request_id='%s';" % put['request_id']) == 'accepted'
    assert scalar("select count(*) from public.manual_football_sync_requests where operation_id='%s';" % ident(726)) == '2'
    assert scalar("select lease_proof_id='%s' and lease_token='%s' from public.manual_football_sync_commands where operation_id='%s';" % (review['dispatch_proof_id'], ident(827), ident(726))) == 't'
    print('PASS genuine original object UPDATE versus readback: old authority denied, same original bytes reconciled, no swallowed deadlock or repeat GET/upload', flush=True)

    sql(owner + "update public.admin_role_assignments set is_active=false,revoked_at=clock_timestamp() where user_id='%s';" % actor)
    result = sql(service + "update public.football_sync_config set last_synced_at=clock_timestamp() where id='%s';" % ident(601))
    assert result.returncode == 0, result.stderr
    print('PASS independent cron service authority retains normal publication after human grant/session expiry', flush=True)
