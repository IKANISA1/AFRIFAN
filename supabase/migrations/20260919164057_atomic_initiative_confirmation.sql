-- Service-only state transition. SMS/provider evidence selection remains the
-- caller's responsibility; this function does not attest external settlement.
create or replace function public.confirm_club_initiative_contribution(
  p_contribution_id uuid,
  p_user_id uuid,
  p_reference text,
  p_amount integer
) returns jsonb
language plpgsql security invoker
set search_path = ''
as $$
declare
  v_contribution public.initiative_contributions;
  v_initiative public.initiatives;
  v_points integer := 0;
  v_referral boolean := false;
begin
  if p_user_id is null or p_amount is null or p_amount <= 0
     or nullif(pg_catalog.btrim(p_reference), '') is null then
    return jsonb_build_object('status', 'manual_review', 'reason', 'invalid_payment_binding');
  end if;

  -- Always re-read and validate after a competing transition releases its lock.
  select * into v_contribution
    from public.initiative_contributions
   where id = p_contribution_id and user_id = p_user_id
   for update;
  if not found or v_contribution.momo_reference is distinct from p_reference
     or v_contribution.amount is distinct from p_amount
     or v_contribution.status not in ('pending', 'confirmed') then
    return jsonb_build_object('status', 'manual_review', 'reason', 'contribution_payment_binding_mismatch');
  end if;
  if (select count(*) from public.initiative_contributions
       where user_id = p_user_id and momo_reference = p_reference) <> 1 then
    return jsonb_build_object('status', 'manual_review', 'reason', 'ambiguous_contribution_reference');
  end if;
  if v_contribution.status = 'confirmed' then
    return jsonb_build_object('status', 'confirmed', 'newly_confirmed', false,
      'contribution_id', v_contribution.id, 'points_awarded', 0, 'referral_activated', false);
  end if;

  select * into v_initiative from public.initiatives
   where id = v_contribution.initiative_id for update;
  if not found or v_initiative.club_id is distinct from v_contribution.club_id then
    return jsonb_build_object('status', 'manual_review', 'reason', 'contribution_campaign_mismatch');
  end if;

  update public.initiative_contributions
     set status = 'confirmed', confirmed_at = pg_catalog.now(), updated_at = pg_catalog.now()
   where id = v_contribution.id;
  -- Arithmetic is performed while holding the campaign lock, never from a
  -- stale HTTP snapshot. Any later error rolls back every preceding write.
  update public.initiatives
     set raised_amount = raised_amount + p_amount,
         supporter_count = supporter_count + 1,
         updated_at = pg_catalog.now()
   where id = v_initiative.id;
  v_points := (p_amount / 100) * 2;
  if v_points > 0 then
    perform public.rs_apply_membership_points(p_user_id, v_initiative.partner_id, v_points);
  end if;
  if v_contribution.referral_invite_id is not null then
    v_referral := public.activate_referral_invite_for_user(
      v_contribution.referral_invite_id, p_user_id, 'rayon_support_confirmed',
      v_contribution.id::text, 130, 50
    );
  end if;
  return jsonb_build_object('status', 'confirmed', 'newly_confirmed', true,
    'contribution_id', v_contribution.id, 'points_awarded', v_points,
    'referral_activated', coalesce(v_referral, false));
end;
$$;
revoke all on function public.confirm_club_initiative_contribution(uuid,uuid,text,integer) from public, anon, authenticated;
grant execute on function public.confirm_club_initiative_contribution(uuid,uuid,text,integer) to service_role;
comment on function public.confirm_club_initiative_contribution(uuid,uuid,text,integer) is
  'Service-only atomic contribution status, timestamp, campaign totals and rewards; exact owner/reference/amount, locked state validation and idempotent retries. Not provider settlement attestation.';
