begin;

select plan(8);

select ok(
  has_function_privilege(
    'supabase_auth_admin',
    'public.custom_access_token_hook(jsonb)',
    'EXECUTE'
  ),
  'Supabase Auth can execute the custom access-token hook'
);

select ok(
  has_function_privilege(
    'supabase_auth_admin',
    'public.normalize_club_id(text)',
    'EXECUTE'
  ),
  'Supabase Auth can execute the hook club-normalization dependency'
);

select ok(
  not has_function_privilege(
    'anon',
    'public.custom_access_token_hook(jsonb)',
    'EXECUTE'
  ),
  'anonymous clients cannot execute the custom access-token hook'
);

select ok(
  not has_function_privilege(
    'authenticated',
    'public.custom_access_token_hook(jsonb)',
    'EXECUTE'
  ),
  'authenticated clients cannot execute the custom access-token hook directly'
);

select ok(
  not has_function_privilege(
    'anon',
    'public.normalize_club_id(text)',
    'EXECUTE'
  ),
  'anonymous clients cannot execute the hook dependency directly'
);

select ok(
  not has_function_privilege(
    'authenticated',
    'public.normalize_club_id(text)',
    'EXECUTE'
  ),
  'authenticated clients cannot execute the hook dependency directly'
);

select is(
  (
    select array_to_string(proconfig, ',')
    from pg_proc
    where oid = 'public.normalize_club_id(text)'::regprocedure
  ),
  'search_path=public, pg_temp',
  'the SECURITY DEFINER dependency has a fixed search path with pg_temp last'
);

select is(
  public.custom_access_token_hook(
    jsonb_build_object(
      'claims',
      jsonb_build_object(
        'role', 'authenticated',
        'app_metadata', jsonb_build_object('club_id', '24', 'role', 'fan')
      )
    )
  )->'claims'->>'role',
  'authenticated',
  'the hook preserves the PostgreSQL JWT role claim'
);

select * from finish();

rollback;
