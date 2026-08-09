-- PostgreSQL grants EXECUTE on new functions to PUBLIC by default.  Remove
-- that inherited capability from every security-definer function in the
-- exposed application schemas.  Explicit anon/authenticated/service_role
-- grants remain unchanged and are governed by the RPC contract tests.
do $migration$
declare
  function_signature text;
begin
  for function_signature in
    select p.oid::regprocedure::text
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where p.prosecdef
      and n.nspname in ('public', 'football', 'africlub_game')
  loop
    execute format(
      'revoke execute on function %s from public',
      function_signature
    );
  end loop;
end
$migration$;

-- RLS expressions execute as the calling client role.  These two helpers are
-- not public RPC capabilities: they expose only a derived tenant/admin boolean,
-- but their explicit grants are required for governed policies to evaluate.
grant execute on function public.requesting_club_id() to anon, authenticated;
grant execute on function africlub_game.is_game_admin(bigint) to authenticated;

-- Boolean RLS helpers are safe to expose: they derive a true/false decision
-- from the caller JWT and do not return protected rows.  Policies created
-- without a TO clause apply to both client roles, so both roles need explicit
-- EXECUTE in order for policy evaluation to fail closed instead of erroring.
grant execute on function africlub_game.can_assign_display_to_session(uuid, uuid)
  to authenticated;
grant execute on function africlub_game.can_manage_display(uuid)
  to authenticated;
grant execute on function africlub_game.can_organize_session(uuid)
  to authenticated;
grant execute on function africlub_game.is_game_admin(bigint)
  to authenticated;
grant execute on function africlub_game.is_session_participant(uuid)
  to authenticated;
grant execute on function africlub_game.is_tv_session_subscriber(uuid)
  to authenticated;
grant execute on function public.is_admin() to anon, authenticated;
grant execute on function public.is_admin_user() to authenticated;
grant execute on function public.is_club_admin(bigint) to anon, authenticated;
grant execute on function public.is_group_member(uuid, uuid)
  to authenticated;
grant execute on function public.is_partner_admin(uuid) to authenticated;
grant execute on function public.is_super_admin() to authenticated;
grant execute on function public.rs_is_partner_admin(uuid)
  to authenticated;
grant execute on function public.venue_staff_can_access(uuid, text[])
  to authenticated;
