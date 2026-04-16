-- ============================================================================
-- PREDICTION CHALLENGES
-- Stake-based exact-score prediction pools.
-- ============================================================================

-- 1. Tables

create table if not exists football.prediction_challenges (
  id uuid primary key default gen_random_uuid(),
  club_id bigint not null references public.african_football_clubs(id) on delete cascade,
  match_id uuid not null references football.fixtures(id) on delete cascade,
  creator_user_id uuid not null references public.users(id) on delete cascade,
  stake_fet bigint not null,
  currency_code text not null default 'FET',
  status text not null default 'open',
  lock_at timestamptz not null,
  settled_at timestamptz,
  cancelled_at timestamptz,
  void_reason text,
  total_participants integer not null default 1,
  total_pool_fet bigint not null default 0,
  winner_count integer not null default 0,
  loser_count integer not null default 0,
  payout_per_winner_fet bigint not null default 0,
  official_home_score integer,
  official_away_score integer,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint prediction_challenges_status_check
    check (status in ('open', 'locked', 'settled', 'void', 'cancelled')),
  constraint prediction_challenges_stake_check
    check (stake_fet > 0)
);

create index if not exists idx_prediction_challenges_match
  on football.prediction_challenges (match_id, status);

create index if not exists idx_prediction_challenges_club
  on football.prediction_challenges (club_id, status, created_at desc);

create table if not exists football.prediction_challenge_entries (
  id uuid primary key default gen_random_uuid(),
  challenge_id uuid not null references football.prediction_challenges(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  predicted_home_score integer not null,
  predicted_away_score integer not null,
  stake_fet bigint not null,
  status text not null default 'active',
  payout_fet bigint not null default 0,
  joined_at timestamptz not null default timezone('utc', now()),
  settled_at timestamptz,
  unique(challenge_id, user_id),
  constraint prediction_challenge_entries_status_check
    check (status in ('active', 'winner', 'loser', 'refunded', 'cancelled')),
  constraint prediction_challenge_entries_score_check
    check (predicted_home_score >= 0 and predicted_away_score >= 0)
);

create index if not exists idx_prediction_challenge_entries_user
  on football.prediction_challenge_entries (user_id, status, joined_at desc);

create table if not exists football.prediction_challenge_settlements (
  id uuid primary key default gen_random_uuid(),
  challenge_id uuid not null unique references football.prediction_challenges(id) on delete cascade,
  match_id uuid not null references football.fixtures(id) on delete cascade,
  official_home_score integer not null,
  official_away_score integer not null,
  winners_count integer not null,
  losers_count integer not null,
  total_pool_fet bigint not null,
  losers_pool_fet bigint not null,
  payout_per_winner_fet bigint not null,
  settlement_mode text not null,
  executed_at timestamptz not null default timezone('utc', now()),
  metadata jsonb not null default '{}'::jsonb
);

-- 2. Triggers & RLS

drop trigger if exists prediction_challenges_set_updated_at on football.prediction_challenges;
create trigger prediction_challenges_set_updated_at
before update on football.prediction_challenges
for each row execute function public.set_updated_at();

alter table football.prediction_challenges enable row level security;
alter table football.prediction_challenge_entries enable row level security;
alter table football.prediction_challenge_settlements enable row level security;

-- Public can read open/settled challenges
drop policy if exists prediction_challenges_read on football.prediction_challenges;
create policy prediction_challenges_read
on football.prediction_challenges
for select
to authenticated
using (true);

-- Owners can read their entries
drop policy if exists prediction_challenge_entries_owner_read on football.prediction_challenge_entries;
create policy prediction_challenge_entries_owner_read
on football.prediction_challenge_entries
for select
to authenticated
using (auth.uid() = user_id);

-- 3. Core RPC Functions

create or replace function public.prediction_challenge_create(
  p_match_id uuid,
  p_home_score integer,
  p_away_score integer,
  p_stake_fet bigint,
  p_club_id bigint default null
) returns jsonb
language plpgsql
security definer
set search_path = public, football, auth
as $$
declare
  v_user_id uuid := auth.uid();
  v_club_id bigint;
  v_kickoff timestamptz;
  v_challenge_id uuid;
  v_membership public.fan_memberships;
begin
  if v_user_id is null then raise exception 'Auth required.'; end if;
  
  v_club_id := public.fet_require_club_context(p_club_id);

  select kickoff_at into v_kickoff
  from football.fixtures where id = p_match_id;

  if v_kickoff is null or v_kickoff <= now() then
    raise exception 'Match has already started or is invalid.';
  end if;

  if p_stake_fet <= 0 then raise exception 'Invalid stake.'; end if;

  -- Verify balance
  select * into v_membership from public.fan_memberships
  where user_id = v_user_id and club_id = v_club_id for update;

  if v_membership.points < p_stake_fet then
    raise exception 'Insufficient FET balance.';
  end if;

  -- Create challenge
  insert into football.prediction_challenges (
    club_id, match_id, creator_user_id, stake_fet, status, lock_at, total_pool_fet
  ) values (
    v_club_id, p_match_id, v_user_id, p_stake_fet, 'open', v_kickoff, p_stake_fet
  ) returning id into v_challenge_id;

  -- Create creator entry
  insert into football.prediction_challenge_entries (
    challenge_id, user_id, predicted_home_score, predicted_away_score, stake_fet, status
  ) values (
    v_challenge_id, v_user_id, p_home_score, p_away_score, p_stake_fet, 'active'
  );

  -- Debit wallet
  update public.fan_memberships set points = points - p_stake_fet
  where id = v_membership.id;

  perform public.fet_wallet_append_entry(
    p_club_id := v_club_id,
    p_user_id := v_user_id,
    p_membership_id := v_membership.id,
    p_entry_type := 'redeem', -- Or 'stake' if added to types
    p_direction := 'debit',
    p_amount := p_stake_fet::integer,
    p_balance_after := (v_membership.points - p_stake_fet)::integer,
    p_reference_type := 'challenge_create',
    p_reference_id := v_challenge_id::text,
    p_note := 'Stake for challenge creation'
  );

  return jsonb_build_object('id', v_challenge_id, 'status', 'created');
end;
$$;

create or replace function public.prediction_challenge_join(
  p_challenge_id uuid,
  p_home_score integer,
  p_away_score integer
) returns jsonb
language plpgsql
security definer
set search_path = public, football, auth
as $$
declare
  v_user_id uuid := auth.uid();
  v_challenge record;
  v_membership public.fan_memberships;
begin
  if v_user_id is null then raise exception 'Auth required.'; end if;

  select * into v_challenge from football.prediction_challenges
  where id = p_challenge_id for update;

  if v_challenge.id is null then raise exception 'Challenge not found.'; end if;
  if v_challenge.status != 'open' or v_challenge.lock_at <= now() then
    raise exception 'Challenge is closed.';
  end if;

  if exists (
    select 1 from football.prediction_challenge_entries
    where challenge_id = p_challenge_id and user_id = v_user_id
  ) then
    raise exception 'Already joined this challenge.';
  end if;

  -- Verify balance
  select * into v_membership from public.fan_memberships
  where user_id = v_user_id and club_id = v_challenge.club_id for update;

  if v_membership.points < v_challenge.stake_fet then
    raise exception 'Insufficient FET balance.';
  end if;

  -- Create entry
  insert into football.prediction_challenge_entries (
    challenge_id, user_id, predicted_home_score, predicted_away_score, stake_fet, status
  ) values (
    p_challenge_id, v_user_id, p_home_score, p_away_score, v_challenge.stake_fet, 'active'
  );

  -- Update challenge summary
  update football.prediction_challenges set
    total_participants = total_participants + 1,
    total_pool_fet = total_pool_fet + v_challenge.stake_fet
  where id = p_challenge_id;

  -- Debit wallet
  update public.fan_memberships set points = points - v_challenge.stake_fet
  where id = v_membership.id;

  perform public.fet_wallet_append_entry(
    p_club_id := v_challenge.club_id,
    p_user_id := v_user_id,
    p_membership_id := v_membership.id,
    p_entry_type := 'redeem',
    p_direction := 'debit',
    p_amount := v_challenge.stake_fet::integer,
    p_balance_after := (v_membership.points - v_challenge.stake_fet)::integer,
    p_reference_type := 'challenge_join',
    p_reference_id := p_challenge_id::text,
    p_note := 'Stake for joining challenge'
  );

  return jsonb_build_object('id', p_challenge_id, 'status', 'joined');
end;
$$;

create or replace function public.prediction_challenge_cancel(
  p_challenge_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = public, football, auth
as $$
declare
  v_user_id uuid := auth.uid();
  v_challenge record;
  v_membership public.fan_memberships;
begin
  if v_user_id is null then raise exception 'Auth required.'; end if;

  select * into v_challenge from football.prediction_challenges
  where id = p_challenge_id for update;

  if v_challenge.id is null then raise exception 'Challenge not found.'; end if;
  if v_challenge.creator_user_id != v_user_id then raise exception 'Permission denied.'; end if;
  if v_challenge.total_participants > 1 then raise exception 'Cannot cancel after others joined.'; end if;
  if v_challenge.status != 'open' then raise exception 'Invalid status for cancellation.'; end if;

  -- Refund creator
  select * into v_membership from public.fan_memberships
  where user_id = v_user_id and club_id = v_challenge.club_id for update;

  update public.fan_memberships set points = points + v_challenge.stake_fet
  where id = v_membership.id;

  perform public.fet_wallet_append_entry(
    p_club_id := v_challenge.club_id,
    p_user_id := v_user_id,
    p_membership_id := v_membership.id,
    p_entry_type := 'earn',
    p_direction := 'credit',
    p_amount := v_challenge.stake_fet::integer,
    p_balance_after := (v_membership.points + v_challenge.stake_fet)::integer,
    p_reference_type := 'challenge_cancel',
    p_reference_id := p_challenge_id::text,
    p_note := 'Refund for cancelled challenge'
  );

  update football.prediction_challenges set
    status = 'cancelled',
    cancelled_at = now()
  where id = p_challenge_id;

  update football.prediction_challenge_entries set
    status = 'cancelled'
  where challenge_id = p_challenge_id;

  return jsonb_build_object('status', 'cancelled');
end;
$$;

create or replace function public.prediction_challenge_settle(
  p_challenge_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = public, football
as $$
declare
  v_challenge record;
  v_match record;
  v_winners_count integer;
  v_losers_count integer;
  v_losers_pool_fet bigint;
  v_payout_per_winner_fet bigint;
  v_remainder_fet bigint;
  v_winner record;
  v_entry record;
  v_membership public.fan_memberships;
begin
  -- Only allow settlement via service role (automated job)
  if auth.role() != 'service_role' then
    return jsonb_build_object('status', 'error', 'message', 'Unauthorized.');
  end if;

  select * into v_challenge from football.prediction_challenges
  where id = p_challenge_id for update;

  if v_challenge.id is null or v_challenge.status in ('settled', 'void', 'cancelled') then
    return jsonb_build_object('status', 'skipped', 'message', 'Challenge already processed.');
  end if;

  select * into v_match from football.fixtures where id = v_challenge.match_id;

  -- 1. Check for void conditions
  if v_match.status != 'finished' or v_match.home_score is null or v_match.away_score is null then
    -- Refund all and void if match was cancelled/postponed
    if v_match.status in ('cancelled', 'postponed', 'abandoned') or (v_challenge.lock_at < now() - interval '3 days') then
       goto void_refund;
    end if;
    return jsonb_build_object('status', 'pending', 'message', 'Match not finished yet.');
  end if;

  -- 2. Count winners
  select count(*) into v_winners_count
  from football.prediction_challenge_entries
  where challenge_id = p_challenge_id
    and predicted_home_score = v_match.home_score
    and predicted_away_score = v_match.away_score;

  if v_winners_count = 0 then
    goto void_refund;
  end if;

  -- 3. Calculate payouts
  v_losers_count := v_challenge.total_participants - v_winners_count;
  v_losers_pool_fet := v_losers_count * v_challenge.stake_fet;
  v_payout_per_winner_fet := v_challenge.stake_fet + floor(v_losers_pool_fet / v_winners_count);
  v_remainder_fet := v_losers_pool_fet % v_winners_count;

  -- 4. Distribute to winners
  for v_winner in 
    select * from football.prediction_challenge_entries
    where challenge_id = p_challenge_id
      and predicted_home_score = v_match.home_score
      and predicted_away_score = v_match.away_score
    order by joined_at asc
  loop
    declare
      v_actual_payout bigint := v_payout_per_winner_fet;
    begin
      if v_remainder_fet > 0 then
        v_actual_payout := v_actual_payout + 1;
        v_remainder_fet := v_remainder_fet - 1;
      end if;

      update football.prediction_challenge_entries set
        status = 'winner',
        payout_fet = v_actual_payout,
        settled_at = now()
      where id = v_winner.id;

      -- Credit wallet
      select * into v_membership from public.fan_memberships
      where user_id = v_winner.user_id and club_id = v_challenge.club_id for update;

      update public.fan_memberships set points = points + v_actual_payout
      where id = v_membership.id;

      perform public.fet_wallet_append_entry(
        p_club_id := v_challenge.club_id,
        p_user_id := v_winner.user_id,
        p_membership_id := v_membership.id,
        p_entry_type := 'earn',
        p_direction := 'credit',
        p_amount := v_actual_payout::integer,
        p_balance_after := (v_membership.points + v_actual_payout)::integer,
        p_reference_type := 'challenge_payout',
        p_reference_id := p_challenge_id::text,
        p_note := 'Winnings from exact score challenge'
      );
    end;
  end loop;

  -- 5. Mark losers
  update football.prediction_challenge_entries set
    status = 'loser',
    settled_at = now()
  where challenge_id = p_challenge_id
    and (predicted_home_score != v_match.home_score or predicted_away_score != v_match.away_score);

  -- 6. Record settlement
  insert into football.prediction_challenge_settlements (
    challenge_id, match_id, official_home_score, official_away_score,
    winners_count, losers_count, total_pool_fet, losers_pool_fet,
    payout_per_winner_fet, settlement_mode
  ) values (
    p_challenge_id, v_challenge.match_id, v_match.home_score, v_match.away_score,
    v_winners_count, v_losers_count, v_challenge.total_pool_fet, v_losers_pool_fet,
    v_payout_per_winner_fet, 'standard'
  );

  update football.prediction_challenges set
    status = 'settled',
    settled_at = now(),
    winner_count = v_winners_count,
    loser_count = v_losers_count,
    payout_per_winner_fet = v_payout_per_winner_fet,
    official_home_score = v_match.home_score,
    official_away_score = v_match.away_score
  where id = p_challenge_id;

  return jsonb_build_object('status', 'settled', 'winners', v_winners_count);

<<void_refund>>
  for v_entry in select * from football.prediction_challenge_entries where challenge_id = p_challenge_id
  loop
    select * into v_membership from public.fan_memberships
    where user_id = v_entry.user_id and club_id = v_challenge.club_id for update;

    update public.fan_memberships set points = points + v_entry.stake_fet
    where id = v_membership.id;

    perform public.fet_wallet_append_entry(
      p_club_id := v_challenge.club_id,
      p_user_id := v_entry.user_id,
      p_membership_id := v_membership.id,
      p_entry_type := 'earn',
      p_direction := 'credit',
      p_amount := v_entry.stake_fet::integer,
      p_balance_after := (v_membership.points + v_entry.stake_fet)::integer,
      p_reference_type := 'challenge_refund',
      p_reference_id := p_challenge_id::text,
      p_note := 'Stake refund for voided challenge'
    );

    update football.prediction_challenge_entries set
      status = 'refunded',
      payout_fet = stake_fet,
      settled_at = now()
    where id = v_entry.id;
  end loop;

  update football.prediction_challenges set
    status = 'void',
    settled_at = now(),
    void_reason = case when v_winners_count = 0 then 'no_exact_winner' else 'match_invalid' end
  where id = p_challenge_id;

  return jsonb_build_object('status', 'voided', 'reason', 'refunded_all');
end;
$$;

grant execute on function public.prediction_challenge_create(uuid, integer, integer, bigint, bigint) to authenticated;
grant execute on function public.prediction_challenge_join(uuid, integer, integer) to authenticated;
grant execute on function public.prediction_challenge_cancel(uuid) to authenticated;
grant execute on function public.prediction_challenge_settle(uuid) to service_role;
