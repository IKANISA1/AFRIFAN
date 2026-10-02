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

    def admit(operation, session, ttl=600):
        sql(admission(operation, session, ttl))

    def insert_object(operation, token, object_id):
        metadata = json.dumps({'mimetype': 'image/png', 'size': 9})
        user_metadata = json.dumps({'operation_id': operation, 'lease_token': token, 'content_sha256': 'a' * 64})
        return service + "insert into storage.objects(id,bucket_id,name,version,metadata,user_metadata) values('%s','africlub-product-images','club-9996901/admin/shop_product/%s.png','%s','%s','%s');" % (
            object_id, operation, identity(980), metadata, user_metadata)

    operation = identity(710)
    admit(operation, identity(951))
    responses = operations_after_lock(
        "select operation_id from public.admin_media_uploads where operation_id='%s' for update;" % operation,
        [service + "select public.claim_admin_media_upload('%s','%s');" % (operation, identity(910 + n)) for n in range(3)])
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
        sql(service + "select public.claim_admin_media_upload('%s','%s');" % (operation, token))
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

    # The holder wins by executing its real authenticated command inside the
    # transaction that already owns the admission/release advisory lock. A
    # second connection must wait until that winner commits its durable result.
    for index, winner in enumerate(('release', 'admission')):
        operation = identity(714 + index)
        winning = release(operation, identity(951)) if winner == 'release' else admission(operation, identity(951))
        waiting = admission(operation, identity(951)) if winner == 'release' else release(operation, identity(951))
        response = operations_after_lock(
            "select pg_advisory_xact_lock(hashtextextended('%s',21027));" % operation,
            [waiting], before_commit=winning)[0]
        expected = 'MEDIA_OPERATION_RELEASED' if winner == 'release' else 'MEDIA_RELEASE_UNAVAILABLE'
        assert response.returncode != 0 and expected in response.stderr, response.stderr
        for table, count in (('admin_media_upload_releases', 1 if winner == 'release' else 0),
                             ('admin_media_uploads', 1 if winner == 'admission' else 0)):
            assert sql("select count(*) from public.%s where operation_id='%s';" % (table, operation)).stdout.strip() == str(count)
        assert sql("select count(*) from storage.objects where name='club-9996901/admin/shop_product/%s.png';" % operation).stdout.strip() == '0'
        print('PASS independent media %s wins against overlapping original-operation command: no Storage effect' % winner, flush=True)

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
