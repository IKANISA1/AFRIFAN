"""Exercise original media leases and authority after real vendor row waits."""
import json
import time


def run_media_upload_concurrency(sql, operations_after_lock, root):
    contract = (root / 'supabase/tests/verified_admin_media_upload_contract.sql').read_text()
    seed = 'insert into public.african_football_clubs' + contract.split('insert into public.african_football_clubs', 1)[1].split('create function pg_temp.media_actor', 1)[0]
    service = "set request.jwt.claim.sub=''; set request.jwt.claims='{\"role\":\"service_role\"}'; set role service_role; "
    sql("set request.jwt.claim.sub=''; set request.jwt.claims='{\"role\":\"service_role\"}'; " + seed)

    def identity(n):
        return '99969000-0000-4000-8000-' + str(n).zfill(12)

    def caller(session, ttl=600):
        now = int(time.time())
        claims = {'sub': identity(1), 'role': 'authenticated', 'is_anonymous': False,
                  'aal': 'aal2', 'exp': now + ttl, 'session_id': session,
                  'amr': [{'method': 'totp', 'timestamp': now}]}
        return "set request.jwt.claim.sub='%s'; set request.jwt.claims='%s'; set role authenticated; " % (identity(1), json.dumps(claims))

    def admission(operation, session, ttl=600):
        return caller(session, ttl) + "select public.admit_admin_media_upload('%s',9996901,'shop_product','image/png',9,repeat('a',64));" % operation

    def release(operation, session, ttl=600):
        return caller(session, ttl) + "select public.release_unadmitted_admin_media_upload('%s',9996901);" % operation

    proofs = {}

    def receipt(response):
        return json.loads(response.stdout.strip().splitlines()[-1])

    def admit(operation, session, ttl=600):
        result = receipt(sql(admission(operation, session, ttl)))
        assert result['operation_id'] == operation and result['actor_id'] == identity(1), result
        proofs[operation] = result['dispatch_proof_id']
        return result

    def claim(operation, token, proof=None):
        return service + "select public.claim_admin_media_upload('%s','%s','%s');" % (operation, token, proof or proofs[operation])

    def begin(operation, token):
        result = receipt(sql(service + "select public.begin_admin_media_upload('%s','%s');" % (operation, token)))
        assert result['operation_id'] == operation and result['lease_token'] == token, result
        return result

    def complete(operation, token, outcome, obj=None):
        return service + "select public.complete_admin_media_upload('%s','%s','%s',%s,%s);" % (operation, token, outcome, "'%s'" % obj if obj else 'null', "repeat('a',64)" if outcome == 'stored' else 'null')

    def expire_original(operation, proof):
        return "select pg_sleep(greatest(0,extract(epoch from ((select expires_at from public.admin_media_upload_proofs where operation_id='%s' and proof_id='%s')-clock_timestamp())))+0.2);" % (operation, proof)

    def create_session(n):
        value = identity(n)
        sql("insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values('%s','%s',clock_timestamp(),clock_timestamp(),'aal2',clock_timestamp()+interval '1 hour');" % (value, identity(1)))
        return value

    def insert_object(operation, token, object_id):
        metadata = json.dumps({'mimetype': 'image/png', 'size': 9})
        user_metadata = json.dumps({'operation_id': operation, 'lease_token': token, 'content_sha256': 'a' * 64})
        return service + "insert into storage.objects(id,bucket_id,name,version,metadata,user_metadata) values('%s','africlub-product-images','club-9996901/admin/shop_product/%s.png','%s','%s','%s');" % (
            object_id, operation, identity(980), metadata, user_metadata)

    operation = identity(710)
    admit(operation, identity(951))
    responses = operations_after_lock(
        "select operation_id from public.admin_media_uploads where operation_id='%s' for update;" % operation,
        [claim(operation, identity(910 + n)) for n in range(3)])
    assert all(result.returncode == 0 for result in responses), [result.stderr for result in responses]
    receipts = [json.loads(result.stdout.strip().splitlines()[-1]) for result in responses]
    assert sum(receipt['claimed'] for receipt in receipts) == 1, receipts
    assert all(receipt['operation_id'] == operation and receipt['status'] == 'uploading' for receipt in receipts), receipts
    assert sql("select attempts from public.admin_media_uploads where operation_id='%s';" % operation).stdout.strip() == '1'
    assert sql("select count(*) from storage.objects where name='club-9996901/admin/shop_product/%s.png';" % operation).stdout.strip() == '0'
    print('PASS three independent overlapping media claims: one original lease and no invented Storage effect', flush=True)

    for index, boundary in enumerate(('jwt_expiry', 'session_revocation', 'grant_revocation')):
        operation, session, token, object_id = identity(711 + index), identity(961 + index), identity(921 + index), identity(811 + index)
        sql("insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values('%s','%s',clock_timestamp(),clock_timestamp(),'aal2',clock_timestamp()+interval '1 hour');" % (session, identity(1)))
        admit(operation, session, ttl=3 if boundary == 'jwt_expiry' else 600)
        sql(claim(operation, token))
        assert begin(operation, token)['upload_permitted'] is True
        mutation = {
            'jwt_expiry': 'select pg_sleep(3.2);',
            'session_revocation': "delete from auth.sessions where id='%s';" % session,
            'grant_revocation': "update public.admin_role_assignments set is_active=false,revoked_at=clock_timestamp() where user_id='%s';" % identity(1),
        }[boundary]
        response = operations_after_lock(
            "select operation_id from public.admin_media_uploads where operation_id='%s' for update;" % operation,
            [insert_object(operation, token, object_id)], before_release=mutation)[0]
        expected = {'jwt_expiry': 'MEDIA_ASSURANCE_EXPIRED', 'session_revocation': 'MEDIA_SESSION_REVOKED',
                    'grant_revocation': 'MEDIA_CLUB_AUTHORITY_REQUIRED'}[boundary]
        assert response.returncode != 0 and expected in response.stderr, response.stderr
        assert sql("select count(*) from storage.objects where id='%s';" % object_id).stdout.strip() == '0'
        assert sql("select object_id is null and completed_at is null and status='uploading' from public.admin_media_uploads where operation_id='%s';" % operation).stdout.strip() == 't'
        if boundary == 'grant_revocation':
            sql("update public.admin_role_assignments set is_active=true,revoked_at=null where user_id='%s';" % identity(1))
        print('PASS media Storage %s after independent command lock: no object, completion or false deletion claim' % boundary, flush=True)

    # Match the actual caller order: lifecycle actor, then original operation.
    # Taking the operation alone before executing a caller command would invert
    # its lifecycle lock against an admission that already holds the actor.
    # The second connection still overlaps and must wait for the real winner.
    for index, winner in enumerate(('release', 'admission')):
        operation = identity(714 + index)
        winning = release(operation, identity(951)) if winner == 'release' else admission(operation, identity(951))
        waiting = admission(operation, identity(951)) if winner == 'release' else release(operation, identity(951))
        response = operations_after_lock(
            caller(identity(951)) + "select public.assert_account_active(); "
            "select pg_advisory_xact_lock(hashtextextended('%s',21027));" % operation,
            [waiting], before_commit=winning)[0]
        expected = 'MEDIA_OPERATION_RELEASED' if winner == 'release' else 'MEDIA_RELEASE_UNAVAILABLE'
        assert response.returncode != 0 and expected in response.stderr, response.stderr
        for table, count in (('admin_media_upload_releases', 1 if winner == 'release' else 0),
                             ('admin_media_uploads', 1 if winner == 'admission' else 0)):
            assert sql("select count(*) from public.%s where operation_id='%s';" % (table, operation)).stdout.strip() == str(count)
        assert sql("select count(*) from storage.objects where name='club-9996901/admin/shop_product/%s.png';" % operation).stdout.strip() == '0'
        print('PASS independent media %s wins against overlapping original-operation command: no Storage effect' % winner, flush=True)

    # Pause a genuine caller at its lifecycle boundary, before it acquires the
    # operation. A service lease for the same committed original must wait on
    # that actor first; holding the operation while waiting would deadlock the
    # caller's real renewal below. Neither path substitutes a newer proof.
    operation, token = identity(723), identity(943)
    original = admit(operation, identity(951))['dispatch_proof_id']
    response = operations_after_lock(
        caller(identity(951)) + "select public.assert_account_active();",
        [claim(operation, token, original)],
        before_commit=admission(operation, identity(951)))[0]
    assert response.returncode == 0, response.stderr
    assert receipt(response)['claimed'] is True
    assert sql("select lease_proof_id='%s' and lease_token='%s' and attempts=1 "
               "and storage_attempt_reserved_at is null from public.admin_media_uploads "
               "where operation_id='%s';" % (original, token, operation)).stdout.strip() == 't'
    assert sql("select count(*) from storage.objects where name='club-9996901/admin/shop_product/%s.png';" % operation).stdout.strip() == '0'
    print('PASS real caller renewal overlaps service claim in actor-before-operation order: exact original proof, one lease and no Storage effect', flush=True)

    for index, boundary in enumerate(('jwt_expiry', 'session_revocation', 'grant_revocation')):
        operation, session = identity(716 + index), identity(964 + index)
        sql("insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values('%s','%s',clock_timestamp(),clock_timestamp(),'aal2',clock_timestamp()+interval '1 hour');" % (session, identity(1)))
        mutation = {
            'jwt_expiry': 'select pg_sleep(3.2);',
            'session_revocation': "delete from auth.sessions where id='%s';" % session,
            'grant_revocation': "update public.admin_role_assignments set is_active=false,revoked_at=clock_timestamp() where user_id='%s';" % identity(1),
        }[boundary]
        response = operations_after_lock(
            "select pg_advisory_xact_lock(hashtextextended('%s',21027));" % operation,
            [release(operation, session, ttl=3 if boundary == 'jwt_expiry' else 600)], before_release=mutation)[0]
        expected = {'jwt_expiry': 'STAFF_STEP_UP_REQUIRED', 'session_revocation': 'MEDIA_SESSION_REVOKED',
                    'grant_revocation': 'MEDIA_CLUB_AUTHORITY_REQUIRED'}[boundary]
        assert response.returncode != 0 and expected in response.stderr, response.stderr
        assert sql("select count(*) from public.admin_media_upload_releases where operation_id='%s';" % operation).stdout.strip() == '0'
        assert sql("select count(*) from public.admin_media_uploads where operation_id='%s';" % operation).stdout.strip() == '0'
        if boundary == 'grant_revocation':
            sql("update public.admin_role_assignments set is_active=true,revoked_at=null where user_id='%s';" % identity(1))
        print('PASS unused media release %s after independent original-operation lock: no tombstone or admission' % boundary, flush=True)

    operation = identity(719)
    original = admit(operation, identity(951), ttl=4)['dispatch_proof_id']
    renewed = admit(operation, identity(951))['dispatch_proof_id']
    assert renewed != original
    response = operations_after_lock(
        "select operation_id from public.admin_media_uploads where operation_id='%s' for update;" % operation,
        [claim(operation, identity(939), original)], before_release=expire_original(operation, original))[0]
    assert response.returncode != 0 and 'MEDIA_ASSURANCE_EXPIRED' in response.stderr, response.stderr
    assert sql("select current_proof_id='%s' and lease_token is null and storage_attempt_reserved_at is null from public.admin_media_uploads where operation_id='%s';" % (renewed, operation)).stdout.strip() == 't'
    print('PASS delayed manual dispatch after independent wait cannot borrow renewed current proof', flush=True)

    operation, token, obj = identity(720), identity(940), identity(820)
    old_session, new_session = create_session(971), create_session(972)
    original = admit(operation, old_session)['dispatch_proof_id']
    sql(claim(operation, token))
    assert begin(operation, token)['upload_permitted'] is True
    renewed = admit(operation, new_session)['dispatch_proof_id']
    assert renewed != original
    response = operations_after_lock(
        "select operation_id from public.admin_media_uploads where operation_id='%s' for update;" % operation,
        [insert_object(operation, token, obj)], before_release="delete from auth.sessions where id='%s';" % old_session)[0]
    assert response.returncode != 0 and 'MEDIA_SESSION_REVOKED' in response.stderr, response.stderr
    assert sql("select current_proof_id='%s' and lease_proof_id='%s' and completed_at is null from public.admin_media_uploads where operation_id='%s';" % (renewed, original, operation)).stdout.strip() == 't'
    assert sql("select count(*) from storage.objects where id='%s';" % obj).stdout.strip() == '0'
    assert receipt(sql(complete(operation, token, 'unknown')))['status'] == 'unknown'
    replacement = identity(950)
    assert receipt(sql(claim(operation, replacement)))['claimed'] is True
    assert begin(operation, replacement)['upload_permitted'] is False
    print('PASS independent original-session deletion despite renewed manual review: no publication and no second attempt', flush=True)

    operation, token = identity(721), identity(941)
    admit(operation, identity(951))
    sql(claim(operation, token))
    assert begin(operation, token)['upload_permitted'] is True
    assert receipt(sql(complete(operation, token, 'unknown')))['status'] == 'unknown'
    admit(operation, identity(951))
    replacement = identity(951)
    assert receipt(sql(claim(operation, replacement)))['claimed'] is True
    responses = operations_after_lock(
        "select operation_id from public.admin_media_uploads where operation_id='%s' for update;" % operation,
        [service + "select public.begin_admin_media_upload('%s','%s');" % (operation, replacement)] * 2)
    assert all(response.returncode == 0 for response in responses), [response.stderr for response in responses]
    assert not any(receipt(response)['upload_permitted'] for response in responses)
    denied = sql(insert_object(operation, replacement, identity(821)), check=False)
    assert denied.returncode != 0 and 'MEDIA_STORAGE_ATTEMPT_REQUIRED' in denied.stderr, denied.stderr
    assert sql("select storage_attempt_lease_token='%s' and object_id is null from public.admin_media_uploads where operation_id='%s';" % (token, operation)).stdout.strip() == 't'
    print('PASS two independent unknown recovery attempts retain one original Storage barrier and no invented object', flush=True)

    operation, token, obj = identity(722), identity(942), identity(822)
    original = admit(operation, identity(951), ttl=8)['dispatch_proof_id']
    sql(claim(operation, token))
    assert begin(operation, token)['upload_permitted'] is True
    sql(insert_object(operation, token, obj))
    renewed = admit(operation, identity(951))['dispatch_proof_id']
    assert renewed != original
    response = operations_after_lock(
        "select operation_id from public.admin_media_uploads where operation_id='%s' for update;" % operation,
        [complete(operation, token, 'stored', obj)], before_release=expire_original(operation, original))[0]
    assert response.returncode == 0, response.stderr
    assert receipt(response)['status'] == 'staged'
    assert sql("select current_proof_id='%s' and completed_at is null and object_id='%s' from public.admin_media_uploads where operation_id='%s';" % (renewed, obj, operation)).stdout.strip() == 't'
    replacement = identity(952)
    assert receipt(sql(claim(operation, replacement)))['claimed'] is True
    assert begin(operation, replacement)['upload_permitted'] is False
    assert receipt(sql(complete(operation, replacement, 'stored', obj)))['status'] == 'completed'
    assert sql("select count(*) from storage.objects where name='club-9996901/admin/shop_product/%s.png';" % operation).stdout.strip() == '1'
    print('PASS stored manual completion after independent expiry wait stays staged; fresh original proof reconciles one existing object', flush=True)
