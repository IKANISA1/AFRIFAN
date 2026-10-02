"""Independent vendor-row waits for exact human generation proof/lease binding.

Uses the harness's real connections and installed Auth/Storage schema. Provider
permission and vendor object rows are exercised; no Google request, bytes or
external settlement/approval is fabricated by this SQL-only test.
"""
import json
import time


def run_admin_image_generation_concurrency(sql, operations_after_lock, root):
    sql((root / 'tools/scripts/fixtures/admin_image_generation_concurrency.sql').read_text())
    club = 9996741
    service = "set request.jwt.claim.sub=''; set request.jwt.claims='{\"role\":\"service_role\"}'; set role service_role; "
    context = {'model': 'gemini-2.5-flash-image', 'public_origin': 'https://qa.invalid',
               'prompt_used': 'Synthetic immutable generation race prompt', 'aspect_ratio': '16:9'}
    request = {'kind': 'home_banner', 'prompt': 'Synthetic race', 'subject': None, 'aspectRatio': '16:9'}

    def identity(n):
        return '99967400-0000-4000-8000-' + str(n).zfill(12)

    def literal(value):
        return "'" + str(value).replace("'", "''") + "'"

    def encoded(value):
        return literal(json.dumps(value, separators=(',', ':')))

    def caller(actor, session=None, ttl=600):
        now = int(time.time())
        claims = {'sub': identity(actor), 'role': 'authenticated', 'is_anonymous': False,
                  'aal': 'aal2', 'exp': now + ttl, 'session_id': session or identity(950 + actor),
                  'amr': [{'method': 'totp', 'timestamp': now}]}
        return "set request.jwt.claim.sub=%s; set request.jwt.claims=%s; set role authenticated; " % (literal(identity(actor)), encoded(claims))

    def result(response):
        return json.loads(response.stdout.strip().splitlines()[-1])

    def admit(operation, actor, ttl=600, session=None, target=None):
        arguments = request if target is None else {'productType': 'news', 'productName': None,
                                                    'targetTable': 'news_articles', 'targetId': target}
        domain = 'admin_image' if target is None else 'product_image'
        receipt = result(sql(caller(actor, session, ttl) +
                             'select public.admit_admin_image_generation(%s,%s,%s,%s);' %
                             (literal(operation), club, literal(domain), encoded(arguments))))
        assert receipt['operation_id'] == operation and receipt['actor_id'] == identity(actor), receipt
        assert receipt['club_id'] == club and receipt['domain'] == domain, receipt
        assert receipt.get('dispatch_proof_id'), receipt
        return receipt

    def claim_query(operation, lease, proof):
        return service + 'select public.claim_admin_image_generation(%s,%s,%s,%s);' % (
            literal(operation), literal(lease), literal(proof), encoded(context))

    def record_query(operation, lease, outcome, obj=None):
        return service + "select public.record_admin_image_generation_result(%s,%s,%s,%s,repeat('a',64),'image/png',9);" % (
            literal(operation), literal(lease), literal(outcome), literal(obj) if obj else 'null')

    def record(operation, lease, outcome, obj=None):
        return sql(record_query(operation, lease, outcome, obj))

    def generation(operation):
        return result(sql('select to_jsonb(g) from public.admin_image_generations g where operation_id=%s;' % literal(operation)))

    def expire_proof(operation, proof):
        # The holder releases only after the actual immutable server deadline;
        # a guessed sleep must not stand in for proof of expiry during a wait.
        return "select pg_sleep(greatest(0,extract(epoch from ((select (proof->>'expires_at')::timestamptz from public.admin_image_generation_proofs where operation_id=%s and proof_id=%s)-clock_timestamp())))+0.2);" % (literal(operation), literal(proof))

    def private_insert(operation, lease, obj):
        row = generation(operation)
        metadata = {'mimetype': 'image/png', 'size': 9}
        user_metadata = {'operation_id': operation, 'lease_token': lease, 'content_sha256': 'a' * 64}
        return service + 'insert into storage.objects(id,bucket_id,name,version,metadata,user_metadata) values(%s,%s,%s,%s,%s,%s);' % (
            literal(obj), literal('africlub-generated-image-staging'), literal(row['staging_path']),
            literal(identity(990)), encoded(metadata), encoded(user_metadata))

    def prepare(operation, actor, lease, obj, ttl=600, target=None):
        admission = admit(operation, actor, ttl, target=target)
        claimed = result(sql(claim_query(operation, lease, admission['dispatch_proof_id'])))
        assert claimed['claimed'] is True and claimed['reconcile'] is False, claimed
        record(operation, lease, 'prepared')
        sql(private_insert(operation, lease, obj))
        record(operation, lease, 'stored', obj)
        return admission, generation(operation)

    def public_permission(row, actor, lease, session=None):
        permission = result(sql(caller(actor, session) +
                                "select public.admit_admin_media_upload(%s,%s,%s,'image/png',9,repeat('a',64));" % (
                                    literal(row['public_upload_id']), club, literal(row['kind']))))
        # SQL30 will require the exact original proof/begin barrier; SQL28/29
        # currently preserve the existing two-argument manual identity.
        supports_bound = sql("select to_regprocedure('public.claim_admin_media_upload(uuid,uuid,uuid)') is not null;").stdout.strip() == 't'
        if supports_bound:
            response = sql(service + 'select public.claim_admin_media_upload(%s,%s,%s);' % (
                literal(row['public_upload_id']), literal(lease), literal(permission['dispatch_proof_id'])))
            claimed = result(response)
            assert claimed['claimed'] is True, claimed
            began = result(sql(service + 'select public.begin_admin_media_upload(%s,%s);' % (literal(row['public_upload_id']), literal(lease))))
            assert began['upload_permitted'] is True, began
        else:
            claimed = result(sql(service + 'select public.claim_admin_media_upload(%s,%s);' % (literal(row['public_upload_id']), literal(lease))))
            assert claimed['claimed'] is True, claimed
        return permission

    def public_insert(row, lease, obj):
        metadata = {'mimetype': 'image/png', 'size': 9}
        user_metadata = {'operation_id': row['public_upload_id'], 'lease_token': lease, 'content_sha256': 'a' * 64,
                         'generation_operation_id': row['operation_id'], 'generation_lease_token': row['lease_token'],
                         'generation_proof_id': row['lease_proof_id']}
        return service + 'insert into storage.objects(id,bucket_id,name,version,metadata,user_metadata) values(%s,%s,%s,%s,%s,%s);' % (
            literal(obj), literal('africlub-product-images'),
            literal('club-%s/admin/%s/%s.png' % (club, row['kind'], row['public_upload_id'])),
            literal(identity(991)), encoded(metadata), encoded(user_metadata))

    def assert_denied(response, error, operation, obj=None):
        assert response.returncode != 0 and error in response.stderr, response.stderr
        if obj:
            assert sql('select count(*) from storage.objects where id=%s;' % literal(obj)).stdout.strip() == '0'
        row = generation(operation)
        assert row['completed_at'] is None and row['status'] != 'completed', row

    operation = identity(710)
    admission = admit(operation, 1)
    responses = operations_after_lock('select operation_id from public.admin_image_generations where operation_id=%s for update;' % literal(operation),
                                     [claim_query(operation, identity(910 + n), admission['dispatch_proof_id']) for n in range(3)])
    assert all(response.returncode == 0 for response in responses), [r.stderr for r in responses]
    receipts = [result(response) for response in responses]
    assert sum(r['claimed'] for r in receipts) == 1 and not any(r['reconcile'] for r in receipts), receipts
    row = generation(operation)
    assert row['provider_started_at'] is not None and row['lease_proof_id'] == admission['dispatch_proof_id'], row
    assert sql("select count(*) from storage.objects where bucket_id='africlub-generated-image-staging' and name like 'club-%s/%s%%';" % (club, operation)).stdout.strip() == '0'
    print('PASS three independent generation claims: one original provider permission and no invented result', flush=True)

    # A real caller paused at its lifecycle boundary must be able to renew the
    # original while each worker path waits. Operation-before-actor would hold
    # the caller's next lock and deadlock this genuine admission, rather than
    # merely producing a useful-looking lease denial.
    operation, lease, obj, actor = identity(721), identity(961), identity(861), 11
    original = admit(operation, actor)['dispatch_proof_id']
    renewal = caller(actor) + 'select public.admit_admin_image_generation(%s,%s,%s,%s);' % (
        literal(operation), club, literal('admin_image'), encoded(request))
    for stage in ('claim', 'prepared', 'private_storage', 'stored'):
        query = (claim_query(operation, lease, original) if stage == 'claim' else
                 private_insert(operation, lease, obj) if stage == 'private_storage' else
                 record_query(operation, lease, stage, obj if stage == 'stored' else None))
        response = operations_after_lock(
            caller(actor) + 'select public.assert_account_active();', [query],
            before_commit=renewal)[0]
        assert response.returncode == 0, response.stderr
        if stage == 'claim':
            claimed = result(response)
            assert claimed['claimed'] is True and claimed['reconcile'] is False, claimed
        row = generation(operation)
        assert row['lease_proof_id'] == original and row['lease_token'] == lease, row
        assert row['provider_started_at'] is not None and row['completed_at'] is None, row
        assert sql('select count(*) from storage.objects where id=%s;' % literal(obj)).stdout.strip() == (
            '1' if stage in ('private_storage', 'stored') else '0')
        print('PASS real caller renewal overlaps generation %s: actor before both operation domains, exact original lease and no replay' % stage, flush=True)
    assert generation(operation)['stage_verified'] is True

    operation, lease, obj, actor = identity(722), identity(962), identity(862), 12
    original, row = prepare(operation, actor, lease, obj)
    public_lease, public_obj = identity(972), identity(872)
    public_permission(row, actor, public_lease)
    response = operations_after_lock(
        caller(actor) + 'select public.assert_account_active();',
        [public_insert(row, public_lease, public_obj)],
        before_commit=caller(actor) + 'select public.admit_admin_image_generation(%s,%s,%s,%s);' % (
            literal(operation), club, literal('admin_image'), encoded(request)))[0]
    assert response.returncode == 0, response.stderr
    row = generation(operation)
    assert row['lease_proof_id'] == original['dispatch_proof_id'] and row['lease_token'] == lease, row
    assert row['completed_at'] is None and row['stage_verified'] is True, row
    assert sql('select count(*) from storage.objects where id=%s;' % literal(public_obj)).stdout.strip() == '1'
    print('PASS real caller renewal overlaps generated public Storage: actor then media then generation, exact two original leases and no false completion', flush=True)

    for actor, boundary in ((2, 'jwt_expiry'), (3, 'session_revocation'), (4, 'grant_revocation')):
        operation, session = identity(710 + actor), identity(950 + actor)
        admission = admit(operation, actor, ttl=4 if boundary == 'jwt_expiry' else 600)
        if boundary == 'grant_revocation':
            hold = 'select id from public.admin_role_assignments where user_id=%s for update;' % literal(identity(actor))
            mutation = 'update public.admin_role_assignments set is_active=false,revoked_at=clock_timestamp() where user_id=%s;' % literal(identity(actor))
        else:
            hold = 'select id from auth.sessions where id=%s for update;' % literal(session)
            mutation = 'delete from auth.sessions where id=%s;' % literal(session)
        kwargs = {'before_release': expire_proof(operation, admission['dispatch_proof_id'])} if boundary == 'jwt_expiry' else {'before_commit': mutation}
        response = operations_after_lock(hold, [claim_query(operation, identity(920 + actor), admission['dispatch_proof_id'])], **kwargs)[0]
        expected = {'jwt_expiry': 'PROVIDER_ASSURANCE_EXPIRED', 'session_revocation': 'PROVIDER_SESSION_REVOKED',
                    'grant_revocation': 'PROVIDER_STAFF_AUTHORITY_REQUIRED'}[boundary]
        assert_denied(response, expected, operation)
        assert generation(operation)['provider_started_at'] is None
        print('PASS independent generation claim %s after actual authority row wait: no provider permission' % boundary, flush=True)

    operation = identity(715)
    old = admit(operation, 5, ttl=4)
    renewed = admit(operation, 5)
    assert renewed['dispatch_proof_id'] != old['dispatch_proof_id']
    response = operations_after_lock('select id from auth.sessions where id=%s for update;' % literal(identity(955)),
                                     [claim_query(operation, identity(925), old['dispatch_proof_id'])], before_release=expire_proof(operation, old['dispatch_proof_id']))[0]
    assert_denied(response, 'PROVIDER_ASSURANCE_EXPIRED', operation)
    row = generation(operation)
    assert row['current_proof_id'] == renewed['dispatch_proof_id'] and row['provider_started_at'] is None, row
    print('PASS delayed original generation dispatch cannot borrow renewed current proof', flush=True)

    for actor, boundary in ((6, 'jwt_expiry'), (7, 'session_revocation')):
        operation, lease, obj = identity(710 + actor), identity(930 + actor), identity(810 + actor)
        old, row = prepare(operation, actor, lease, obj, ttl=8 if boundary == 'jwt_expiry' else 600)
        replacement_session = None
        if boundary == 'session_revocation':
            replacement_session = identity(970 + actor)
            sql("insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values(%s,%s,clock_timestamp(),clock_timestamp(),'aal2',clock_timestamp()+interval '1 hour');" % (
                literal(replacement_session), literal(identity(actor))))
        renewed = admit(operation, actor, session=replacement_session)
        assert renewed['dispatch_proof_id'] != old['dispatch_proof_id']
        public_lease, public_obj = identity(940 + actor), identity(820 + actor)
        public_permission(row, actor, public_lease, replacement_session)
        kwargs = {'before_release': expire_proof(operation, old['dispatch_proof_id'])} if boundary == 'jwt_expiry' else {
            'before_release': 'delete from auth.sessions where id=%s;' % literal(identity(950 + actor))}
        response = operations_after_lock('select operation_id from public.admin_image_generations where operation_id=%s for update;' % literal(operation),
                                         [public_insert(row, public_lease, public_obj)], **kwargs)[0]
        expected = 'PROVIDER_ASSURANCE_EXPIRED' if boundary == 'jwt_expiry' else 'PROVIDER_SESSION_REVOKED'
        assert_denied(response, expected, operation, public_obj)
        current = generation(operation)
        assert current['lease_proof_id'] == old['dispatch_proof_id'] and current['current_proof_id'] == renewed['dispatch_proof_id'], current
        assert current['stage_verified'] is True and current['staging_object_id'] == obj, current
        print('PASS public generated Storage %s after SQL27 guard and independent SQL28 wait: original proof only' % boundary, flush=True)

    operation, lease, obj, actor = identity(718), identity(938), identity(818), 8
    admission = admit(operation, actor)
    sql(claim_query(operation, lease, admission['dispatch_proof_id']))
    record(operation, lease, 'prepared')
    response = operations_after_lock('select id from public.admin_role_assignments where user_id=%s for update;' % literal(identity(actor)),
                                     [private_insert(operation, lease, obj)], before_commit=
                                     'update public.admin_role_assignments set is_active=false,revoked_at=clock_timestamp() where user_id=%s;' % literal(identity(actor)))[0]
    assert_denied(response, 'PROVIDER_STAFF_AUTHORITY_REQUIRED', operation, obj)
    assert generation(operation)['staging_object_id'] is None
    print('PASS private generated Storage after actual grant revocation wait: no private or public object', flush=True)

    for actor, boundary in ((9, 'jwt_expiry'), (10, 'target_version')):
        operation, lease, obj, target = identity(710 + actor), identity(930 + actor), identity(810 + actor), identity(501 if actor == 9 else 502)
        _admission, row = prepare(operation, actor, lease, obj, target=target)
        public_lease, public_obj = identity(940 + actor), identity(820 + actor)
        public_permission(row, actor, public_lease)
        sql(public_insert(row, public_lease, public_obj))
        sql(service + "select public.complete_admin_media_upload(%s,%s,'stored',%s,repeat('a',64));" % (
            literal(row['public_upload_id']), literal(public_lease), literal(public_obj)))
        query = caller(actor, ttl=4 if boundary == 'jwt_expiry' else 600) + 'select public.commit_admin_image_generation(%s,%s);' % (literal(operation), club)
        kwargs = {'before_release': 'select pg_sleep(4.2);'} if boundary == 'jwt_expiry' else {
            'before_commit': "set request.jwt.claims='{\"role\":\"service_role\"}'; update public.news_articles set image_prompt='Concurrent retained editor decision',updated_at=clock_timestamp() where id=%s;" % literal(target)}
        response = operations_after_lock('select id from public.news_articles where id=%s for update;' % literal(target), [query], **kwargs)[0]
        if boundary == 'jwt_expiry':
            assert_denied(response, 'PROVIDER_ASSURANCE_EXPIRED', operation)
            assert sql('select image_url is null and image_prompt is null from public.news_articles where id=%s;' % literal(target)).stdout.strip() == 't'
        else:
            assert response.returncode == 0, response.stderr
            receipt = result(response)
            assert receipt['status'] == 'staged' and receipt['target_conflict'] is True, receipt
            assert sql("select image_url is null and image_prompt='Concurrent retained editor decision' from public.news_articles where id=%s;" % literal(target)).stdout.strip() == 't'
        assert generation(operation)['completed_at'] is None
        print('PASS product generation %s after independent target wait: no blind overwrite or false completion' % boundary, flush=True)
