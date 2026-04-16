-- ============================================================================
-- FANZONE reward redemption tracking + reward slugs
-- - Adds stable reward item slugs for downstream gameplay integrations
-- - Persists supporter reward redemption requests and fulfillment status
-- - Exposes reward-specific redemption/history/admin RPCs
-- ============================================================================

alter table public.fet_reward_store_items
  add column if not exists slug text;

update public.fet_reward_store_items
set slug = case lower(btrim(reward))
  when 'mobile airtime' then 'mobile-airtime'
  when 'fanzone premium badge' then 'fanzone-premium-badge'
  when 'jackpot extra entry' then 'jackpot-extra-entry'
  when 'custom avatar frame' then 'custom-avatar-frame'
  when 'club fan kit digital item' then 'club-fan-kit-digital-item'
  when 'partner voucher' then 'partner-voucher'
  else lower(regexp_replace(coalesce(reward, ''), '[^a-zA-Z0-9]+', '-', 'g'))
end
where slug is null
   or nullif(btrim(slug), '') is null;

alter table public.fet_reward_store_items
  alter column slug set not null;

create unique index if not exists idx_fet_reward_store_items_club_slug
  on public.fet_reward_store_items (coalesce(club_id, -1), slug);

drop trigger if exists fet_reward_store_items_set_updated_at on public.fet_reward_store_items;
create trigger fet_reward_store_items_set_updated_at
before update on public.fet_reward_store_items
for each row execute function public.set_updated_at();

create table if not exists public.fet_reward_redemptions (
  id uuid primary key default gen_random_uuid(),
  club_id bigint not null references public.african_football_clubs(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  reward_item_id uuid not null references public.fet_reward_store_items(id) on delete restrict,
  reward_slug text not null,
  reward_title text not null,
  cost_fet integer not null,
  wallet_reference_id text,
  status text not null default 'pending',
  fulfillment_channel text,
  fulfillment_reference text,
  supporter_note text,
  admin_note text,
  consumed_at timestamptz,
  fulfilled_at timestamptz,
  idempotency_key text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint fet_reward_redemptions_status_check
    check (status in ('pending', 'processing', 'fulfilled', 'cancelled', 'failed')),
  constraint fet_reward_redemptions_cost_positive_check
    check (cost_fet >= 0)
);

create index if not exists idx_fet_reward_redemptions_user_created
  on public.fet_reward_redemptions (club_id, user_id, created_at desc);

create index if not exists idx_fet_reward_redemptions_status
  on public.fet_reward_redemptions (club_id, status, created_at desc);

create unique index if not exists idx_fet_reward_redemptions_idempotency
  on public.fet_reward_redemptions (club_id, user_id, idempotency_key)
  where idempotency_key is not null;

drop trigger if exists fet_reward_redemptions_set_updated_at on public.fet_reward_redemptions;
create trigger fet_reward_redemptions_set_updated_at
before update on public.fet_reward_redemptions
for each row execute function public.set_updated_at();

alter table public.fet_reward_redemptions enable row level security;

drop policy if exists fet_reward_redemptions_owner_read on public.fet_reward_redemptions;
create policy fet_reward_redemptions_owner_read
on public.fet_reward_redemptions
for select
to authenticated
using (
  auth.uid() = user_id
  and club_id::text = public.requesting_club_id()
);

drop policy if exists fet_reward_redemptions_admin_manage on public.fet_reward_redemptions;
create policy fet_reward_redemptions_admin_manage
on public.fet_reward_redemptions
for all
to authenticated
using (public.is_club_admin(club_id) or public.is_super_admin() or public.is_admin_user())
with check (public.is_club_admin(club_id) or public.is_super_admin() or public.is_admin_user());

create or replace function public.fet_redeem_reward(
  p_reward_item_id uuid,
  p_note text default null,
  p_idempotency_key text default null,
  p_club_id bigint default null
) returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_user_id uuid := auth.uid();
  v_club_id bigint;
  v_idempotency_key text := nullif(btrim(coalesce(p_idempotency_key, '')), '');
  v_note text := nullif(btrim(coalesce(p_note, '')), '');
  v_item public.fet_reward_store_items;
  v_existing public.fet_reward_redemptions;
  v_redeem_result jsonb;
  v_redemption public.fet_reward_redemptions;
begin
  if v_user_id is null then
    raise exception 'Authentication is required.';
  end if;

  if p_reward_item_id is null then
    raise exception 'Reward item is required.';
  end if;

  v_club_id := public.fet_require_club_context(p_club_id);

  select *
    into v_item
  from public.fet_reward_store_items item
  where item.id = p_reward_item_id
    and item.is_active = true
    and (item.club_id is null or item.club_id = v_club_id)
  limit 1;

  if v_item.id is null then
    raise exception 'Reward item not found.';
  end if;

  if v_item.cost_fet <= 0 then
    raise exception 'Reward item is not redeemable.';
  end if;

  if v_idempotency_key is not null then
    select *
      into v_existing
    from public.fet_reward_redemptions redemption
    where redemption.club_id = v_club_id
      and redemption.user_id = v_user_id
      and redemption.idempotency_key = v_idempotency_key
    order by redemption.created_at desc, redemption.id desc
    limit 1;

    if v_existing.id is not null then
      return jsonb_build_object(
        'status', 'submitted',
        'already_processed', true,
        'redemption_id', v_existing.id,
        'reward_item_id', v_existing.reward_item_id,
        'reward_slug', v_existing.reward_slug,
        'reward_title', v_existing.reward_title,
        'balance', null,
        'reference_id', v_existing.wallet_reference_id,
        'message', 'Reward redemption already recorded.'
      );
    end if;
  end if;

  v_redeem_result := public.fet_redeem(
    p_amount := v_item.cost_fet,
    p_note := coalesce(v_note, format('FANZONE reward: %s', v_item.reward)),
    p_idempotency_key := v_idempotency_key,
    p_club_id := v_club_id
  );

  insert into public.fet_reward_redemptions (
    club_id,
    user_id,
    reward_item_id,
    reward_slug,
    reward_title,
    cost_fet,
    wallet_reference_id,
    status,
    supporter_note,
    idempotency_key,
    metadata
  )
  values (
    v_club_id,
    v_user_id,
    v_item.id,
    v_item.slug,
    v_item.reward,
    v_item.cost_fet,
    nullif(v_redeem_result ->> 'reference_id', ''),
    'pending',
    v_note,
    v_idempotency_key,
    jsonb_build_object(
      'cost_label', v_item.cost_label,
      'category', v_item.category,
      'emoji', v_item.emoji,
      'wallet_status', v_redeem_result ->> 'status'
    )
  )
  returning * into v_redemption;

  return jsonb_build_object(
    'status', 'submitted',
    'already_processed', false,
    'redemption_id', v_redemption.id,
    'reward_item_id', v_redemption.reward_item_id,
    'reward_slug', v_redemption.reward_slug,
    'reward_title', v_redemption.reward_title,
    'balance', (v_redeem_result ->> 'balance')::integer,
    'reference_id', v_redemption.wallet_reference_id,
    'message', format('Redeemed %s.', v_redemption.reward_title)
  );
exception
  when unique_violation then
    if v_idempotency_key is null then
      raise;
    end if;

    select *
      into v_existing
    from public.fet_reward_redemptions redemption
    where redemption.club_id = v_club_id
      and redemption.user_id = v_user_id
      and redemption.idempotency_key = v_idempotency_key
    order by redemption.created_at desc, redemption.id desc
    limit 1;

    if v_existing.id is null then
      raise;
    end if;

    return jsonb_build_object(
      'status', 'submitted',
      'already_processed', true,
      'redemption_id', v_existing.id,
      'reward_item_id', v_existing.reward_item_id,
      'reward_slug', v_existing.reward_slug,
      'reward_title', v_existing.reward_title,
      'balance', null,
      'reference_id', v_existing.wallet_reference_id,
      'message', 'Reward redemption already recorded.'
    );
end;
$$;

create or replace function public.fet_get_reward_redemptions(
  p_limit integer default 20,
  p_offset integer default 0,
  p_club_id bigint default null
) returns table(
  id uuid,
  reward_item_id uuid,
  reward_slug text,
  reward_title text,
  cost_fet integer,
  wallet_reference_id text,
  status text,
  fulfillment_channel text,
  fulfillment_reference text,
  supporter_note text,
  admin_note text,
  consumed_at timestamptz,
  fulfilled_at timestamptz,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path to 'public'
as $$
declare
  v_user_id uuid := auth.uid();
  v_club_id bigint;
begin
  if v_user_id is null then
    raise exception 'Authentication is required.';
  end if;

  v_club_id := public.fet_require_club_context(p_club_id);

  return query
  select
    redemption.id,
    redemption.reward_item_id,
    redemption.reward_slug,
    redemption.reward_title,
    redemption.cost_fet,
    redemption.wallet_reference_id,
    redemption.status,
    redemption.fulfillment_channel,
    redemption.fulfillment_reference,
    redemption.supporter_note,
    redemption.admin_note,
    redemption.consumed_at,
    redemption.fulfilled_at,
    redemption.created_at
  from public.fet_reward_redemptions redemption
  where redemption.user_id = v_user_id
    and redemption.club_id = v_club_id
  order by redemption.created_at desc
  limit greatest(coalesce(p_limit, 20), 1)
  offset greatest(coalesce(p_offset, 0), 0);
end;
$$;

create or replace function public.fet_admin_update_reward_redemption(
  p_redemption_id uuid,
  p_status text,
  p_fulfillment_channel text default null,
  p_fulfillment_reference text default null,
  p_admin_note text default null
) returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_status text := lower(nullif(btrim(coalesce(p_status, '')), ''));
  v_redemption public.fet_reward_redemptions;
begin
  if auth.uid() is null then
    raise exception 'Authentication is required.';
  end if;

  if v_status not in ('pending', 'processing', 'fulfilled', 'cancelled', 'failed') then
    raise exception 'Unsupported redemption status.';
  end if;

  select *
    into v_redemption
  from public.fet_reward_redemptions redemption
  where redemption.id = p_redemption_id
  for update;

  if v_redemption.id is null then
    raise exception 'Reward redemption not found.';
  end if;

  if not (public.is_club_admin(v_redemption.club_id) or public.is_super_admin() or public.is_admin_user()) then
    raise exception 'Club admin access is required.';
  end if;

  update public.fet_reward_redemptions
  set status = v_status,
      fulfillment_channel = nullif(btrim(coalesce(p_fulfillment_channel, '')), ''),
      fulfillment_reference = nullif(btrim(coalesce(p_fulfillment_reference, '')), ''),
      admin_note = nullif(btrim(coalesce(p_admin_note, '')), ''),
      fulfilled_at = case
        when v_status = 'fulfilled' then timezone('utc', now())
        else fulfilled_at
      end,
      updated_at = timezone('utc', now())
  where id = v_redemption.id
  returning * into v_redemption;

  return jsonb_build_object(
    'status', v_redemption.status,
    'redemption_id', v_redemption.id,
    'message', format('Reward redemption marked %s.', v_redemption.status)
  );
end;
$$;

grant execute on function public.fet_redeem_reward(uuid, text, text, bigint) to authenticated;
grant execute on function public.fet_redeem_reward(uuid, text, text, bigint) to service_role;
grant execute on function public.fet_get_reward_redemptions(integer, integer, bigint) to authenticated;
grant execute on function public.fet_get_reward_redemptions(integer, integer, bigint) to service_role;
grant execute on function public.fet_admin_update_reward_redemption(uuid, text, text, text, text) to authenticated;
grant execute on function public.fet_admin_update_reward_redemption(uuid, text, text, text, text) to service_role;
