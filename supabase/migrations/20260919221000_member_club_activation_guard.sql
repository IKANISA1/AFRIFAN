-- Bind a deliberate website activation to the club the supporter is viewing.
-- The existing no-argument RPC remains available to the native clients.
begin;

create function public.activate_free_fan_membership_for_club(p_expected_club_id bigint)
returns public.fan_memberships
language plpgsql security invoker set search_path = '' as $$
declare
  v_club_id bigint;
begin
  if auth.uid() is null then
    raise exception using errcode='42501', message='MEMBER_AUTH_REQUIRED';
  end if;
  begin
    v_club_id := nullif(public.requesting_club_id(), '')::bigint;
  exception when invalid_text_representation then
    raise exception using errcode='42501', message='MEMBER_CLUB_MISMATCH';
  end;
  if p_expected_club_id is null or v_club_id is null
     or v_club_id <> p_expected_club_id then
    raise exception using errcode='42501', message='MEMBER_CLUB_MISMATCH';
  end if;
  return public.activate_free_fan_membership();
end;
$$;
revoke all on function public.activate_free_fan_membership_for_club(bigint)
  from public, anon, authenticated, service_role;
grant execute on function public.activate_free_fan_membership_for_club(bigint) to authenticated;

commit;
