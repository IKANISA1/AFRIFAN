-- Restore the one dependency required by Supabase Auth's custom access-token
-- hook after the SECURITY DEFINER execution allowlist was tightened.

begin;

alter function public.normalize_club_id(text)
  set search_path = public, pg_temp;

revoke execute on function public.normalize_club_id(text)
  from public, anon, authenticated;
grant execute on function public.normalize_club_id(text)
  to service_role, supabase_auth_admin;

revoke execute on function public.custom_access_token_hook(jsonb)
  from public, anon, authenticated, service_role;
grant execute on function public.custom_access_token_hook(jsonb)
  to supabase_auth_admin;

commit;
