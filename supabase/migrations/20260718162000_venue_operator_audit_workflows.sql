-- Audited venue-operator mutations. Every action derives scope from auth.uid()
-- and an active membership; client-supplied club/venue scope is never trusted.

create table if not exists public.venue_staff_audit_events (
  id uuid primary key default gen_random_uuid(),
  club_id bigint not null references public.african_football_clubs(id) on delete cascade,
  venue_id uuid not null references public.venues(id) on delete cascade,
  actor_id uuid not null,
  event_type text not null,
  entity_type text not null,
  entity_id text not null,
  reason text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamp with time zone not null default timezone('utc', now())
);

create index if not exists idx_venue_staff_audit_scope_created
  on public.venue_staff_audit_events (club_id, venue_id, created_at desc);

alter table public.venue_staff_audit_events enable row level security;

drop policy if exists venue_staff_audit_read on public.venue_staff_audit_events;
create policy venue_staff_audit_read
on public.venue_staff_audit_events for select
to authenticated
using (
  public.is_club_admin(club_id) or public.is_super_admin() or
  public.venue_staff_can_access(venue_id)
);

create or replace function public.venue_menu_upsert(
  p_venue_id uuid,
  p_item_id uuid,
  p_name text,
  p_description text,
  p_price_amount integer,
  p_currency_code text,
  p_is_alcohol boolean,
  p_is_active boolean,
  p_sort_order integer
) returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_actor uuid := auth.uid();
  v_membership public.venue_staff_memberships;
  v_item public.venue_drink_items;
  v_event_type text;
begin
  if v_actor is null then
    return jsonb_build_object('status', 'error', 'code', 'auth_required');
  end if;

  select * into v_membership
  from public.venue_staff_memberships
  where user_id = v_actor
    and venue_id = p_venue_id
    and is_active
    and role = any (array['owner', 'manager'])
  order by granted_at asc
  limit 1;

  if v_membership.id is null then
    return jsonb_build_object('status', 'error', 'code', 'permission_denied');
  end if;

  if length(btrim(coalesce(p_name, ''))) < 2 or length(btrim(p_name)) > 80 then
    return jsonb_build_object('status', 'error', 'code', 'invalid_name');
  end if;
  if p_price_amount is null or p_price_amount < 0 or p_price_amount > 10000000 then
    return jsonb_build_object('status', 'error', 'code', 'invalid_price');
  end if;
  if upper(btrim(coalesce(p_currency_code, ''))) !~ '^[A-Z]{3}$' then
    return jsonb_build_object('status', 'error', 'code', 'invalid_currency');
  end if;

  if p_item_id is null then
    insert into public.venue_drink_items (
      club_id, venue_id, item_name, description, price_amount, currency_code,
      is_active, is_alcohol, sort_order, created_by
    ) values (
      v_membership.club_id, v_membership.venue_id, btrim(p_name),
      nullif(btrim(coalesce(p_description, '')), ''), p_price_amount,
      upper(btrim(p_currency_code)), coalesce(p_is_active, false),
      coalesce(p_is_alcohol, false), coalesce(p_sort_order, 0), v_actor
    ) returning * into v_item;
    v_event_type := 'menu_item_created';
  else
    update public.venue_drink_items
    set item_name = btrim(p_name),
        description = nullif(btrim(coalesce(p_description, '')), ''),
        price_amount = p_price_amount,
        currency_code = upper(btrim(p_currency_code)),
        is_active = coalesce(p_is_active, false),
        is_alcohol = coalesce(p_is_alcohol, false),
        sort_order = coalesce(p_sort_order, 0)
    where id = p_item_id
      and club_id = v_membership.club_id
      and venue_id = v_membership.venue_id
    returning * into v_item;
    if v_item.id is null then
      return jsonb_build_object('status', 'error', 'code', 'item_not_found');
    end if;
    v_event_type := 'menu_item_updated';
  end if;

  insert into public.venue_staff_audit_events (
    club_id, venue_id, actor_id, event_type, entity_type, entity_id, metadata
  ) values (
    v_membership.club_id, v_membership.venue_id, v_actor, v_event_type,
    'venue_drink_item', v_item.id::text,
    jsonb_build_object('is_active', v_item.is_active, 'is_alcohol', v_item.is_alcohol)
  );

  return jsonb_build_object('status', 'success', 'code', 'ok', 'item_id', v_item.id);
exception
  when check_violation then
    return jsonb_build_object('status', 'error', 'code', 'active_item_limit');
end;
$$;

create or replace function public.venue_promotion_launch(
  p_venue_id uuid,
  p_campaign_id uuid,
  p_idempotency_key text
) returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_actor uuid := auth.uid();
  v_membership public.venue_staff_memberships;
  v_campaign public.venue_checkin_campaigns;
  v_key text := nullif(btrim(coalesce(p_idempotency_key, '')), '');
  v_event public.venue_promotion_events;
  v_is_replay boolean := false;
begin
  if v_actor is null then
    return jsonb_build_object('status', 'error', 'code', 'auth_required');
  end if;
  if v_key is null then
    return jsonb_build_object('status', 'error', 'code', 'idempotency_required');
  end if;

  select * into v_membership
  from public.venue_staff_memberships
  where user_id = v_actor
    and venue_id = p_venue_id
    and is_active
    and role = any (array['owner', 'manager'])
  order by granted_at asc limit 1;
  if v_membership.id is null then
    return jsonb_build_object('status', 'error', 'code', 'permission_denied');
  end if;

  select * into v_campaign
  from public.venue_checkin_campaigns
  where id = p_campaign_id
    and club_id = v_membership.club_id
    and venue_id = v_membership.venue_id
  limit 1;
  if v_campaign.id is null then
    return jsonb_build_object('status', 'error', 'code', 'campaign_not_found');
  end if;
  if v_campaign.status <> 'approved' then
    return jsonb_build_object('status', 'error', 'code', 'campaign_not_approved');
  end if;
  if timezone('utc', now()) < v_campaign.starts_at or timezone('utc', now()) >= v_campaign.ends_at then
    return jsonb_build_object('status', 'error', 'code', 'campaign_outside_window');
  end if;
  if v_campaign.fet_budget > 0 and v_campaign.awarded_fet >= v_campaign.fet_budget then
    return jsonb_build_object('status', 'error', 'code', 'campaign_budget_exhausted');
  end if;

  select * into v_event
  from public.venue_promotion_events
  where club_id = v_membership.club_id
    and venue_id = v_membership.venue_id
    and idempotency_key = v_key
  limit 1;

  if v_event.id is not null then
    v_is_replay := true;
  else
    insert into public.venue_promotion_events (
      club_id, venue_id, campaign_id, event_type, fet_amount,
      idempotency_key, metadata
    ) values (
      v_membership.club_id, v_membership.venue_id, v_campaign.id,
      'campaign_launched_by_venue', 0, v_key,
      jsonb_build_object('actor_id', v_actor)
    )
    on conflict (club_id, venue_id, idempotency_key) where idempotency_key is not null
    do nothing
    returning * into v_event;

    if v_event.id is null then
      select * into v_event
      from public.venue_promotion_events
      where club_id = v_membership.club_id
        and venue_id = v_membership.venue_id
        and idempotency_key = v_key
      limit 1;
      v_is_replay := true;
    end if;
  end if;

  if not v_is_replay then
    insert into public.venue_staff_audit_events (
      club_id, venue_id, actor_id, event_type, entity_type, entity_id, metadata
    ) values (
      v_membership.club_id, v_membership.venue_id, v_actor,
      'promotion_launched', 'venue_checkin_campaign', v_campaign.id::text,
      jsonb_build_object('promotion_event_id', v_event.id, 'idempotency_key', v_key)
    );
  end if;

  return jsonb_build_object(
    'status', 'success',
    'code', case when v_is_replay then 'idempotent_replay' else 'ok' end,
    'event_id', v_event.id
  );
end;
$$;

revoke all on function public.venue_menu_upsert(uuid, uuid, text, text, integer, text, boolean, boolean, integer) from public;
grant execute on function public.venue_menu_upsert(uuid, uuid, text, text, integer, text, boolean, boolean, integer) to authenticated;
revoke all on function public.venue_promotion_launch(uuid, uuid, text) from public;
grant execute on function public.venue_promotion_launch(uuid, uuid, text) to authenticated;

comment on table public.venue_staff_audit_events is 'Immutable audit trail for authenticated venue-operator mutations.';
