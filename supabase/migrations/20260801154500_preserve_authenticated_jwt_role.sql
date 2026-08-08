-- PostgreSQL/PostgREST authorization depends on the JWT `role` claim being a
-- real database role such as `authenticated`. Product roles such as `fan` or
-- `club_admin` belong in a separate claim and in the governed assignment
-- tables; replacing `role` with `fan` makes every authenticated API request
-- fail before RLS can run.

begin;

create or replace function public.custom_access_token_hook(event jsonb)
returns jsonb
language plpgsql
stable
set search_path = public
as $$
declare
  claims                jsonb;
  app_meta              jsonb;
  user_meta             jsonb;
  v_raw_club_id         text;
  v_normalized_club_id  text;
  v_user_role           text;
begin
  claims := event -> 'claims';
  app_meta := claims -> 'app_metadata';
  user_meta := claims -> 'user_metadata';

  v_raw_club_id := coalesce(
    app_meta ->> 'club_id',
    user_meta ->> 'club_id',
    ''
  );
  v_normalized_club_id := coalesce(
    public.normalize_club_id(nullif(v_raw_club_id, ''))::text,
    v_raw_club_id
  );
  v_user_role := coalesce(
    app_meta ->> 'role',
    user_meta ->> 'role',
    'fan'
  );

  claims := jsonb_set(claims, '{club_id}', to_jsonb(v_normalized_club_id));
  claims := jsonb_set(claims, '{user_role}', to_jsonb(v_user_role));
  event := jsonb_set(event, '{claims}', claims);
  return event;
end;
$$;

comment on function public.custom_access_token_hook(jsonb) is
  'Adds club_id and user_role while preserving the authenticated PostgreSQL JWT role required by PostgREST and RLS.';

commit;
