"""Original notification proofs and device barriers after independent row waits.

The parent harness owns the portless database and verifies every operation is
blocked on a real Lock wait before releasing its independent holder. These
probes call the actual authenticated/service RPCs and vendor Auth session rows;
they never invoke FCM, mint a replacement proof, or rewrite a stored deadline.
"""
import json
import time


def run_notification_command_concurrency(sql, operations_after_lock, root):
    def identity(n):
        return '99969400-0000-4000-8000-' + str(n).zfill(12)

    actor = identity(1)
    service_claims = "set request.jwt.claim.sub=''; set request.jwt.claim.role='service_role'; set request.jwt.claims='{\"role\":\"service_role\"}'; "
    service = service_claims + 'set role service_role; '
    owner = service_claims + 'reset role; '
    assert sql('select count(*) from public.african_football_clubs where id=9996941;').stdout.strip() == '0'
    sql((root / 'tools/scripts/fixtures/notification_command_concurrency.sql').read_text())

    def value(result):
        assert result.returncode == 0, result.stderr
        return json.loads(result.stdout.strip().splitlines()[-1])

    def caller(session, ttl=600, *, user=None):
        user = user or actor
        now = int(time.time())
        claims = {'sub': user, 'role': 'authenticated', 'is_anonymous': False,
                  'aal': 'aal2', 'exp': now + ttl, 'session_id': session,
                  'amr': [{'method': 'totp', 'timestamp': now}]}
        return "set request.jwt.claim.sub='%s'; set request.jwt.claim.role='authenticated'; set request.jwt.claims='%s'; set role authenticated; " % (user, json.dumps(claims))

    def new_session(n, *, user=None):
        session = identity(n)
        sql(owner + "insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values('%s','%s',clock_timestamp(),clock_timestamp(),'aal2',clock_timestamp()+interval '1 hour');" % (session, user or actor))
        return session

    def admission(n, session, *, ttl=600, schedule=False, user=None, club=9996941):
        arguments = {'title': 'Synthetic race command', 'body': 'No provider invocation.',
                     'audience': 'all_fans', 'tier': None, 'group_id': None, 'group_name': None,
                     'delivery_mode': 'schedule' if schedule else 'send_now',
                     'scheduled_at': '2026-01-01T00:00:00.000Z' if schedule else None,
                     'image_url': None}
        return caller(session, ttl, user=user) + "select public.admit_admin_notification('%s',%s,'%s'::jsonb);" % (identity(n), club, json.dumps(arguments))

    def admit(n, *, ttl=600, schedule=False, session=None, user=None, club=9996941):
        session = session or new_session(n + 200, user=user)
        receipt = value(sql(admission(n, session, ttl=ttl, schedule=schedule, user=user, club=club)))
        assert receipt['command']['operation_id'] == identity(n)
        return session, receipt

    def claim(n, lease, proof=None):
        return service + "select public.claim_admin_notification_command('%s','%s',%s);" % (
            identity(n), identity(lease), "'%s'::uuid" % proof if proof else 'null')

    def device(n, lease):
        return service + "select coalesce(public.claim_admin_notification_device('%s','%s'),'null'::jsonb);" % (identity(n), identity(lease))

    def command_lock(n):
        return "select operation_id from public.admin_notification_commands where operation_id='%s' for update;" % identity(n)

    def expire_original(n, proof):
        # Sleep only after the harness has proved a real Lock wait, and derive
        # its duration from the actual immutable proof, never a guessed TTL.
        return "select pg_sleep(greatest(0,extract(epoch from ((select (proof->>'expires_at')::timestamptz from public.admin_notification_proofs where operation_id='%s' and proof_id='%s')-clock_timestamp())))+0.2);" % (identity(n), proof)

    def no_starts(n):
        assert sql("select count(*) from public.admin_notification_devices where operation_id='%s' and state='started';" % identity(n)).stdout.strip() == '0'

    def denied(result, expected):
        assert result.returncode != 0 and expected in result.stderr, result.stderr

    # Two actual service workers are first forced to overlap behind one holder.
    _, receipt = admit(701)
    proof = receipt['dispatch_proof_id']
    responses = operations_after_lock(command_lock(701), [claim(701, n, proof) for n in (801, 802)])
    claims = [value(result) for result in responses]
    assert sum(result['claimed'] for result in claims) == 1, claims
    winner = next(result for result in claims if result['claimed'])
    assert sql("select count(*) from public.notifications where id='%s';" % receipt['command']['notification_id']).stdout.strip() == '1'
    assert sql("select count(*) from public.admin_notification_devices where operation_id='%s';" % identity(701)).stdout.strip() == '2'
    loser = 802 if winner['lease_token'] == identity(801) else 801
    denied(sql(device(701, loser), check=False), 'NOTIFICATION_LEASE_LOST')
    no_starts(701)
    print('PASS independent notification workers: one lease, one original notification, exact two targets, foreign worker cannot start a device', flush=True)

    # Hold precisely the UPDATE that follows the early claim proof check.
    _, receipt = admit(702, ttl=5)
    response = operations_after_lock(
        "select id from public.notifications where id='%s' for update;" % receipt['command']['notification_id'],
        [claim(702, 803, receipt['dispatch_proof_id'])], before_release=expire_original(702, receipt['dispatch_proof_id']))[0]
    denied(response, 'PROVIDER_ASSURANCE_EXPIRED')
    assert sql("select state='admitted' and lease_token is null from public.admin_notification_commands where operation_id='%s';" % identity(702)).stdout.strip() == 't'
    assert sql("select count(*) from public.admin_notification_devices where operation_id='%s';" % identity(702)).stdout.strip() == '0'
    print('PASS actual notification-row wait past original expiry: no successful claim, committed lease or device barrier', flush=True)

    # Assignment and Auth session reads wait on the actual authoritative rows.
    for n, boundary in ((703, 'role_expiry'), (704, 'role_revocation'), (705, 'session_revocation')):
        session, receipt = admit(n, ttl=5 if boundary == 'role_expiry' else 600)
        lock = ("select id from auth.sessions where id='%s' for update;" % session if boundary == 'session_revocation'
                else "select id from public.admin_role_assignments where user_id='%s' and club_id is null for update;" % actor)
        mutation = {'role_revocation': owner + "update public.admin_role_assignments set is_active=false,revoked_at=clock_timestamp() where user_id='%s';" % actor,
                    'session_revocation': owner + "delete from auth.sessions where id='%s';" % session}.get(boundary)
        response = operations_after_lock(lock, [claim(n, n + 101, receipt['dispatch_proof_id'])],
                                         before_release=expire_original(n, receipt['dispatch_proof_id']) if boundary == 'role_expiry' else None,
                                         before_commit=mutation)[0]
        denied(response, {'role_expiry': 'PROVIDER_ASSURANCE_EXPIRED', 'role_revocation': 'PROVIDER_STAFF_AUTHORITY_REQUIRED',
                          'session_revocation': 'PROVIDER_SESSION_REVOKED'}[boundary])
        no_starts(n)
        assert sql("select lease_token is null from public.admin_notification_commands where operation_id='%s';" % identity(n)).stdout.strip() == 't'
        if boundary == 'role_revocation':
            sql(owner + "update public.admin_role_assignments set is_active=true,revoked_at=null where user_id='%s';" % actor)
        print('PASS original notification %s after real authority-row wait: no lease or device start' % boundary, flush=True)

    # The provider device claim must recheck after the actual recipient token wait.
    _, receipt = admit(706, ttl=5)
    value(sql(claim(706, 807, receipt['dispatch_proof_id'])))
    response = operations_after_lock(
        "select id from public.user_fcm_tokens where user_id='%s' for update;" % identity(2),
        [device(706, 807)], before_release=expire_original(706, receipt['dispatch_proof_id']))[0]
    denied(response, 'PROVIDER_ASSURANCE_EXPIRED')
    no_starts(706)
    assert sql("select count(*) from public.admin_notification_devices where operation_id='%s' and state='ready';" % identity(706)).stdout.strip() == '2'
    print('PASS recipient-token wait past original proof expiry: both never-started barriers remain ready, no FCM admission', flush=True)

    # A renewed human admission cannot replace an older worker's immutable proof.
    old_session, receipt = admit(707, ttl=8)
    old_proof = receipt['dispatch_proof_id']
    value(sql(claim(707, 808, old_proof)))
    started = value(sql(device(707, 808)))
    sql(owner + "delete from auth.sessions where id='%s';" % old_session)
    new = new_session(999)
    _, renewed = admit(707, session=new)
    new_proof = renewed['dispatch_proof_id']
    assert new_proof != old_proof
    assert sql("select current_proof_id<>lease_proof_id from public.admin_notification_commands where operation_id='%s';" % identity(707)).stdout.strip() == 't'
    completion = service + "select public.complete_admin_notification_device('%s','%s','%s','unknown',null,'UNKNOWN');" % (identity(707), identity(808), started['delivery_id'])
    response = operations_after_lock(command_lock(707), [completion])[0]
    denied(response, 'PROVIDER_SESSION_REVOKED')
    assert sql("select state from public.admin_notification_devices where delivery_id='%s';" % started['delivery_id']).stdout.strip() == 'started'
    response = operations_after_lock(command_lock(707), [claim(707, 809, old_proof)], before_release=expire_original(707, old_proof))[0]
    denied(response, 'PROVIDER_SESSION_REVOKED')
    assert value(sql(claim(707, 810, new_proof)))['claimed']
    assert sql("select state from public.admin_notification_devices where delivery_id='%s';" % started['delivery_id']).stdout.strip() == 'unknown'
    remaining = value(sql(device(707, 810)))
    assert remaining['delivery_id'] != started['delivery_id']
    assert value(sql(device(707, 810))) is None
    value(sql(service + "select public.complete_admin_notification_device('%s','%s','%s','unknown',null,'UNKNOWN');" % (identity(707), identity(810), remaining['delivery_id'])))
    finished = value(sql(service + "select public.finish_admin_notification_command('%s','%s');" % (identity(707), identity(810))))
    assert finished['delivery']['unknown_count'] == 2 and finished['delivery']['pending_count'] == 0
    assert not value(sql(claim(707, 811, new_proof)))['claimed']
    print('PASS logout/reauthentication with independent waits: old lease cannot borrow new proof, started unknown device never reoffered', flush=True)

    # A real fresh-session caller pauses at its lifecycle guard. The old service
    # dispatch must wait there before taking the operation, allowing the genuine
    # saved-command renewal to complete without an actor/operation cycle.
    _, original = admit(709)
    renewed_session = new_session(1009)
    response = operations_after_lock(
        caller(renewed_session) + 'select public.assert_account_active();',
        [claim(709, 813, original['dispatch_proof_id'])],
        before_commit=admission(709, renewed_session))[0]
    assert value(response)['claimed']
    assert sql("select current_proof_id<>lease_proof_id and lease_proof_id='%s' "
               "from public.admin_notification_commands where operation_id='%s';" %
               (original['dispatch_proof_id'], identity(709))).stdout.strip() == 't'
    no_starts(709)
    print('PASS genuine fresh-session human submit overlaps original worker: no actor/operation inversion or borrowed renewal proof', flush=True)

    # Each GLOBAL creator is the sole eligible recipient of the other's club.
    # Holding the smallest actual lifecycle key forces both independent claims
    # to overlap. Creator-first followed by a late recipient lock would cycle
    # after release; the shared ordered set admits both exact original devices.
    _, cross_a = admit(750, club=9996942)
    _, cross_b = admit(751, user=identity(3), club=9996943)
    value(sql(claim(750, 850, cross_a['dispatch_proof_id'])))
    value(sql(claim(751, 851, cross_b['dispatch_proof_id'])))
    responses = operations_after_lock(
        "select pg_advisory_xact_lock(least(hashtextextended('%s',21000),hashtextextended('%s',21000)));" % (actor, identity(3)),
        [device(750, 850), device(751, 851)])
    devices = [value(response) for response in responses]
    assert devices[0]['target_user_id'] == identity(3) and devices[1]['target_user_id'] == actor, devices
    for n in (750, 751):
        assert sql("select count(*) from public.admin_notification_devices where operation_id='%s' and state='started';" % identity(n)).stdout.strip() == '1'
        assert sql("select count(*) from public.admin_notification_devices where operation_id='%s' and state in('accepted','unknown');" % identity(n)).stdout.strip() == '0'
    print('PASS crossed human creators/recipients after independent lifecycle wait: both original started barriers, no deadlock or fabricated FCM outcome', flush=True)

    # Serialize closure through its real RPC after committing a never-started
    # target. Its removed token/pending account can never start an FCM device.
    _, closing = admit(752, club=9996942)
    value(sql(claim(752, 852, closing['dispatch_proof_id'])))
    sql(service + "select public.request_account_erasure('%s','%s');" % (identity(3), identity(1752)))
    assert value(sql(device(752, 852))) is None
    no_starts(752)
    assert sql("select count(*) from public.admin_notification_devices where operation_id='%s' and state='skipped';" % identity(752)).stdout.strip() == '1'
    assert sql("select count(*) from public.account_erasure_jobs where user_id='%s';" % identity(3)).stdout.strip() == '1'
    print('PASS actual recipient closure after original target snapshot: no device start or FCM authority, original skipped barrier retained', flush=True)

    # The previously committed schedule is cron authority, separate from its
    # creator's expired/revoked human proof, while its exact command stays fixed.
    session, receipt = admit(708, schedule=True)
    assert receipt['command']['state'] == 'scheduled'
    mutation = owner + "delete from auth.sessions where id='%s'; update public.admin_role_assignments set is_active=false,revoked_at=clock_timestamp() where user_id='%s';" % (session, actor)
    response = operations_after_lock(command_lock(708), [claim(708, 812)], before_commit=mutation)[0]
    claimed = value(response)
    assert claimed['claimed'] and claimed['authority_kind'] == 'scheduled' and claimed['lease_proof_id'] is None
    assert sql("select count(*) from public.admin_notification_proofs where operation_id='%s';" % identity(708)).stdout.strip() == '1'
    cron_device = value(sql(device(708, 812)))
    assert cron_device['operation_id'] == identity(708)
    assert sql("select count(*) from public.admin_notification_devices where operation_id='%s' and state='started';" % identity(708)).stdout.strip() == '1'
    print('PASS independent scheduled service lease after creator session/grant revocation: original receipt retained, no fabricated human proof or provider call', flush=True)
