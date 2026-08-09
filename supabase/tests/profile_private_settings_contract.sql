-- Profile bootstrap, private contacts, preferences, and push-token boundary.

create extension if not exists pgtap with schema extensions;

begin;

select plan(11);

select ok(
  has_function_privilege(
    'authenticated',
    'public.bootstrap_supporter_profile(bigint,text,text,text,text)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'anon',
    'public.bootstrap_supporter_profile(bigint,text,text,text,text)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'service_role',
    'public.bootstrap_supporter_profile(bigint,text,text,text,text)',
    'EXECUTE'
  )
  and exists (
    select 1
    from pg_proc as procedure
    where procedure.oid =
      'public.bootstrap_supporter_profile(bigint,text,text,text,text)'::regprocedure
      and procedure.prosecdef
      and procedure.proconfig = array['search_path=""']::text[]
      and procedure.prosrc ~ 'already bound to another club'
  ),
  'profile bootstrap is authenticated-only, fixed-path, and tenant-immutable'
);

select ok(
  exists (
    select 1
    from pg_proc as procedure
    where procedure.oid = 'public.handle_new_user()'::regprocedure
      and procedure.prosecdef
      and procedure.proconfig = array['search_path=""']::text[]
      and procedure.prosrc ~ 'raw_app_meta_data'
      and procedure.prosrc !~ 'raw_user_meta_data ->> ''club_id'''
  )
  and not has_function_privilege(
    'authenticated',
    'public.handle_new_user()',
    'EXECUTE'
  ),
  'Auth trigger never treats user metadata as tenant authority'
);

select ok(
  not has_table_privilege('anon', 'public.profiles', 'SELECT')
  and not has_table_privilege('authenticated', 'public.profiles', 'INSERT')
  and not has_table_privilege('authenticated', 'public.profiles', 'DELETE')
  and has_column_privilege(
    'authenticated',
    'public.profiles',
    'display_name',
    'SELECT'
  )
  and not has_column_privilege(
    'authenticated',
    'public.profiles',
    'phone',
    'SELECT'
  )
  and has_column_privilege(
    'authenticated',
    'public.profiles',
    'display_name',
    'UPDATE'
  )
  and not has_column_privilege(
    'authenticated',
    'public.profiles',
    'club_id',
    'UPDATE'
  )
  and (
    select count(*) = 2
    from pg_policies
    where schemaname = 'public'
      and tablename = 'profiles'
  ),
  'profile ACL exposes one safe own-row projection and bounded edits'
);

select ok(
  has_table_privilege(
    'authenticated',
    'public.user_notification_settings',
    'SELECT'
  )
  and has_table_privilege(
    'authenticated',
    'public.user_privacy_settings',
    'UPDATE'
  )
  and has_table_privilege(
    'authenticated',
    'public.user_private_contacts',
    'INSERT'
  )
  and has_table_privilege(
    'authenticated',
    'public.user_fcm_tokens',
    'DELETE'
  )
  and not has_table_privilege(
    'anon',
    'public.user_private_contacts',
    'SELECT'
  )
  and (
    select count(*) = 4
    from pg_trigger
    where tgname like 'enforce_user_%_scope'
      and not tgisinternal
  ),
  'private settings and tokens have owner operations plus four scope triggers'
);

insert into public.african_football_clubs (
  id,
  club_name,
  country_name,
  club_slug,
  is_active
) overriding system value values
  (9951001, 'Profile Contract Club', 'Rwanda', 'profile-contract-club', true),
  (9951002, 'Foreign Profile Contract Club', 'Rwanda', 'foreign-profile-contract-club', true);

insert into auth.users (
  id,
  aud,
  role,
  raw_user_meta_data,
  raw_app_meta_data
) values (
  '99510000-0000-4000-8000-000000000001',
  'authenticated',
  'authenticated',
  '{"club_id":"9951002","display_name":"Profile Owner"}'::jsonb,
  '{}'::jsonb
);

select is(
  (
    select profile.club_id
    from public.profiles as profile
    where profile.id = '99510000-0000-4000-8000-000000000001'
  ),
  null::bigint,
  'a user-metadata club is ignored during Auth-trigger bootstrap'
);

select set_config(
  'request.jwt.claim.sub',
  '99510000-0000-4000-8000-000000000001',
  true
);
select set_config(
  'request.jwt.claims',
  '{"sub":"99510000-0000-4000-8000-000000000001","role":"authenticated","is_anonymous":true}',
  true
);
set local role authenticated;
do $$
declare
  bootstrapped public.profiles;
begin
  select * into bootstrapped
  from public.bootstrap_supporter_profile(
    9951001,
    'Profile Owner',
    'RW',
    'rw',
    null
  );

  if bootstrapped.club_id <> 9951001
     or bootstrapped.id <>
       '99510000-0000-4000-8000-000000000001'::uuid then
    raise exception 'unexpected bootstrap result: %', bootstrapped;
  end if;
end $$;
reset role;
select pass('authenticated bootstrap binds the active deployment club');

select is(
  (
    select pg_catalog.count(*)::integer
    from (
      select club_id
      from public.user_privacy_settings
      where user_id = '99510000-0000-4000-8000-000000000001'
      union all
      select club_id
      from public.user_notification_settings
      where user_id = '99510000-0000-4000-8000-000000000001'
    ) as settings
    where settings.club_id = 9951001
  ),
  2,
  'bootstrap synchronizes both preference rows to the trusted club'
);

set local role authenticated;
do $$
declare
  mismatch_denied boolean := false;
begin
  begin
    perform public.bootstrap_supporter_profile(
      9951002,
      'Tenant Switch',
      'RW',
      'rw',
      null
    );
  exception
    when raise_exception then mismatch_denied := true;
  end;

  if not mismatch_denied then
    raise exception 'profile tenant reassignment was accepted';
  end if;
end $$;
reset role;
select pass('a bootstrapped supporter cannot switch tenant');

set local role authenticated;
do $$
declare
  insert_denied boolean := false;
  club_update_denied boolean := false;
  contact_scope_denied boolean := false;
  visible_contacts integer;
begin
  update public.profiles
     set display_name = 'Updated Owner'
   where id = '99510000-0000-4000-8000-000000000001';

  begin
    insert into public.profiles (id, club_id)
    values ('99510000-0000-4000-8000-000000000099', 9951001);
  exception
    when insufficient_privilege then insert_denied := true;
  end;

  begin
    update public.profiles
       set club_id = 9951002
     where id = '99510000-0000-4000-8000-000000000001';
  exception
    when insufficient_privilege then club_update_denied := true;
  end;

  begin
    insert into public.user_private_contacts (
      user_id,
      club_id,
      momo_number,
      country_code
    ) values (
      '99510000-0000-4000-8000-000000000001',
      9951002,
      '+250780000001',
      'RW'
    );
  exception
    when raise_exception then contact_scope_denied := true;
  end;

  insert into public.user_private_contacts (
    user_id,
    club_id,
    momo_number,
    country_code
  ) values (
    '99510000-0000-4000-8000-000000000001',
    null,
    '+250780000001',
    'RW'
  );

  select pg_catalog.count(*)::integer
    into visible_contacts
    from public.user_private_contacts;

  if not insert_denied
     or not club_update_denied
     or not contact_scope_denied
     or visible_contacts <> 1 then
    raise exception
      'owner profile/private contract failed: insert %, club %, contact %, visible %',
      insert_denied,
      club_update_denied,
      contact_scope_denied,
      visible_contacts;
  end if;
end $$;
reset role;
select pass('owner edits are bounded and private-contact tenant scope is derived');

insert into auth.users (
  id,
  aud,
  role,
  raw_user_meta_data,
  raw_app_meta_data
) values (
  '99510000-0000-4000-8000-000000000002',
  'authenticated',
  'authenticated',
  '{}'::jsonb,
  '{"club_id":"9951002"}'::jsonb
);

insert into public.user_private_contacts (
  user_id,
  club_id,
  momo_number,
  country_code
) values (
  '99510000-0000-4000-8000-000000000002',
  9951002,
  '+250780000002',
  'RW'
);

set local role authenticated;
select is(
  (
    select pg_catalog.count(*)::integer
    from public.user_private_contacts
  ),
  1,
  'RLS hides another supporter private contact even when the base table has rows'
);
reset role;

select ok(
  (
    select analytics_enabled is false
    from public.user_privacy_settings
    where user_id = '99510000-0000-4000-8000-000000000001'
  ),
  'new supporter analytics remains explicit opt-in'
);

select * from finish();

rollback;
