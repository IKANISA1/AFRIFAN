-- Forward-only source split decommission.
--
-- Historical tables and data are deliberately retained until every deployed
-- environment has completed export, retention, and LET'S PLAY cutover review.
-- This migration only removes client/API/realtime access so the retired
-- runtime cannot be reopened by an old route or direct RPC call.

do $decommission$
declare
  routine record;
  relation record;
begin
  if not exists (
    select 1 from pg_namespace where nspname = 'africlub_game'
  ) then
    return;
  end if;

  revoke usage on schema africlub_game
    from public, anon, authenticated, service_role;
  revoke all privileges on all tables in schema africlub_game
    from public, anon, authenticated, service_role;
  revoke all privileges on all sequences in schema africlub_game
    from public, anon, authenticated, service_role;
  revoke all privileges on all functions in schema africlub_game
    from public, anon, authenticated, service_role;

  alter default privileges in schema africlub_game
    revoke all on tables from public, anon, authenticated, service_role;
  alter default privileges in schema africlub_game
    revoke all on sequences from public, anon, authenticated, service_role;
  alter default privileges in schema africlub_game
    revoke execute on functions from public, anon, authenticated, service_role;

  -- Retire public SECURITY DEFINER wrappers whose implementation reaches the
  -- historical schema. PostgreSQL grants EXECUTE to PUBLIC by default, so this
  -- explicit sweep is required even though the schema itself is no longer
  -- exposed by the application.
  for routine in
    select procedure.oid::regprocedure as signature
      from pg_proc procedure
     join pg_namespace namespace on namespace.oid = procedure.pronamespace
     where namespace.nspname = 'public'
       and procedure.prokind = 'f'
       and pg_get_functiondef(procedure.oid) ilike '%africlub_game%'
  loop
    execute format(
      'revoke execute on function %s from public, anon, authenticated, service_role',
      routine.signature
    );
  end loop;

  -- Realtime is no longer an activation path. Data remains intact but no
  -- retired table emits client change events.
  for relation in
    select format('%I.%I', schemaname, tablename) as qualified_name
      from pg_publication_tables
     where pubname = 'supabase_realtime'
       and schemaname = 'africlub_game'
  loop
    execute format(
      'alter publication supabase_realtime drop table %s',
      relation.qualified_name
    );
  end loop;

  execute $$comment on schema africlub_game is
    'Retired AFRICLUB TV/trivia history. Active ownership moved to LET''S PLAY; client access revoked 2026-08-20.'$$;
end;
$decommission$;
