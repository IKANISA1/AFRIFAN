-- ============================================================================
-- Prediction challenge runtime hardening
-- Repairs the stake-based challenge feature with:
-- - club-scoped read models
-- - wallet-safe and idempotent mutations
-- - kickoff locking + due settlement automation
-- - refund/void settlement records
-- - lightweight admin inspection + retry support
-- ============================================================================

alter table football.prediction_challenge_settlements
  alter column official_home_score drop not null,
  alter column official_away_score drop not null;

create index if not exists idx_prediction_challenges_due_lock
  on football.prediction_challenges (status, lock_at, created_at desc)
  where status = 'open';

create index if not exists idx_prediction_challenges_due_settle
  on football.prediction_challenges (status, lock_at, created_at desc)
  where status = 'locked';

create index if not exists idx_prediction_challenge_entries_challenge_status_joined
  on football.prediction_challenge_entries (challenge_id, status, joined_at asc);

drop policy if exists prediction_challenges_read on football.prediction_challenges;
drop policy if exists prediction_challenge_entries_owner_read on football.prediction_challenge_entries;
drop policy if exists prediction_challenge_settlements_read on football.prediction_challenge_settlements;

create policy prediction_challenges_scoped_read
on football.prediction_challenges
for select
to authenticated
using (
  club_id::text = public.requesting_club_id()
  and (
    status in ('open', 'locked', 'settled', 'void')
    or creator_user_id = auth.uid()
    or exists (
      select 1
        from football.prediction_challenge_entries entry
       where entry.challenge_id = prediction_challenges.id
         and entry.user_id = auth.uid()
    )
    or public.is_super_admin()
    or public.is_admin_user()
    or public.is_club_admin(club_id)
  )
);

create policy prediction_challenge_entries_scoped_read
on football.prediction_challenge_entries
for select
to authenticated
using (
  exists (
    select 1
      from football.prediction_challenges challenge
     where challenge.id = prediction_challenge_entries.challenge_id
       and challenge.club_id::text = public.requesting_club_id()
       and (
         prediction_challenge_entries.user_id = auth.uid()
         or challenge.status in ('open', 'locked', 'settled', 'void')
         or public.is_super_admin()
         or public.is_admin_user()
         or public.is_club_admin(challenge.club_id)
       )
  )
);

create policy prediction_challenge_settlements_scoped_read
on football.prediction_challenge_settlements
for select
to authenticated
using (
  exists (
    select 1
      from football.prediction_challenges challenge
     where challenge.id = prediction_challenge_settlements.challenge_id
       and challenge.club_id::text = public.requesting_club_id()
       and (
         challenge.creator_user_id = auth.uid()
         or exists (
           select 1
             from football.prediction_challenge_entries entry
            where entry.challenge_id = challenge.id
              and entry.user_id = auth.uid()
         )
         or public.is_super_admin()
         or public.is_admin_user()
         or public.is_club_admin(challenge.club_id)
       )
  )
);

create or replace function public.prediction_challenge_user_json(
  p_user_id uuid,
  p_club_id bigint default null
) returns jsonb
language sql
security definer
stable
set search_path = public
as $$
  select jsonb_build_object(
    'id', p_user_id,
    'display_name', coalesce(
      nullif(btrim((
        select profile.display_name
          from public.profiles profile
         where profile.id = p_user_id
         limit 1
      )), ''),
      nullif(btrim((
        select profile.full_name
          from public.profiles profile
         where profile.id = p_user_id
         limit 1
      )), ''),
      nullif(btrim((
        select membership.display_name
          from public.fan_memberships membership
         where membership.user_id = p_user_id
           and (p_club_id is null or membership.club_id = p_club_id)
         order by membership.updated_at desc nulls last, membership.created_at desc nulls last
         limit 1
      )), ''),
      'Supporter'
    ),
    'avatar_url', (
      select profile.avatar_url
        from public.profiles profile
       where profile.id = p_user_id
       limit 1
    )
  );
$$;

create or replace function public.prediction_challenge_fixture_json(
  p_match_id uuid
) returns jsonb
language sql
security definer
stable
set search_path = public, football
as $$
  select coalesce(
    (
      select jsonb_build_object(
        'id', fixture.id,
        'competition_slug', fixture.competition_slug,
        'competition_name', fixture.competition_name,
        'season_label', fixture.season_label,
        'matchday', fixture.matchday,
        'home_team_slug', fixture.home_team_slug,
        'home_team_name', fixture.home_team_name,
        'home_team_short_name', fixture.home_team_short_name,
        'away_team_slug', fixture.away_team_slug,
        'away_team_name', fixture.away_team_name,
        'away_team_short_name', fixture.away_team_short_name,
        'kickoff_at', fixture.kickoff_at,
        'venue_name', fixture.venue_name,
        'status', fixture.status,
        'home_score', fixture.home_score,
        'away_score', fixture.away_score,
        'home_team_logo_url', coalesce(fixture.home_team_logo, fixture.home_team_logo_url),
        'away_team_logo_url', coalesce(fixture.away_team_logo, fixture.away_team_logo_url),
        'competition_logo_url', coalesce(fixture.competition_logo, fixture.competition_logo_url)
      )
        from public.football_fixtures_catalog fixture
       where fixture.id = p_match_id
       limit 1
    ),
    '{}'::jsonb
  );
$$;

create or replace function public.prediction_challenge_adjust_wallet(
  p_club_id bigint,
  p_user_id uuid,
  p_amount_fet bigint,
  p_direction text,
  p_reference_type text,
  p_reference_id text,
  p_idempotency_key text default null,
  p_note text default null,
  p_metadata jsonb default '{}'::jsonb
) returns bigint
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_membership public.fan_memberships;
  v_existing public.fet_wallet_ledger_entries;
  v_direction text := lower(btrim(coalesce(p_direction, '')));
  v_idempotency_key text := nullif(btrim(coalesce(p_idempotency_key, '')), '');
  v_reference_type text := nullif(btrim(coalesce(p_reference_type, '')), '');
  v_reference_id text := nullif(btrim(coalesce(p_reference_id, '')), '');
  v_amount integer := greatest(coalesce(p_amount_fet, 0), 0)::integer;
  v_entry_type text;
  v_new_balance integer;
begin
  if p_club_id is null then
    raise exception 'Club scope is required.';
  end if;

  if p_user_id is null then
    raise exception 'Target user is required.';
  end if;

  if v_amount <= 0 then
    return coalesce((
      select membership.points::bigint
        from public.fan_memberships membership
       where membership.user_id = p_user_id
         and membership.club_id = p_club_id
       limit 1
    ), 0);
  end if;

  if v_direction not in ('debit', 'credit') then
    raise exception 'Invalid wallet direction: %.', p_direction;
  end if;

  if v_idempotency_key is not null then
    select *
      into v_existing
      from public.fet_wallet_ledger_entries ledger
     where ledger.club_id = p_club_id
       and ledger.user_id = p_user_id
       and ledger.idempotency_key = v_idempotency_key
     order by ledger.created_at desc, ledger.id desc
     limit 1;

    if v_existing.id is not null then
      return coalesce(v_existing.balance_after, 0);
    end if;
  end if;

  perform public.fet_wallet_ensure_membership(p_user_id, p_club_id);

  select *
    into v_membership
    from public.fan_memberships membership
   where membership.user_id = p_user_id
     and membership.club_id = p_club_id
   for update;

  if v_membership.id is null then
    raise exception 'Wallet membership not found.';
  end if;

  if v_direction = 'debit' then
    if coalesce(v_membership.points, 0) < v_amount then
      raise exception 'Insufficient FET balance.';
    end if;
    v_new_balance := coalesce(v_membership.points, 0) - v_amount;
    v_entry_type := 'redeem';
  else
    v_new_balance := coalesce(v_membership.points, 0) + v_amount;
    v_entry_type := 'earn';
  end if;

  update public.fan_memberships
     set points = v_new_balance,
         tier = public.resolve_fan_tier(v_new_balance),
         updated_at = timezone('utc', now())
   where id = v_membership.id
  returning * into v_membership;

  perform public.fet_wallet_append_entry(
    p_club_id := p_club_id,
    p_user_id := p_user_id,
    p_membership_id := v_membership.id,
    p_entry_type := v_entry_type,
    p_direction := v_direction,
    p_amount := v_amount,
    p_balance_after := v_membership.points,
    p_counterparty_user_id := null,
    p_reference_type := v_reference_type,
    p_reference_id := v_reference_id,
    p_idempotency_key := v_idempotency_key,
    p_note := p_note,
    p_metadata := coalesce(p_metadata, '{}'::jsonb),
    p_created_by := auth.uid()
  );

  return v_membership.points;
end;
$$;

create or replace function public.prediction_challenge_queue_notification(
  p_user_id uuid,
  p_notification_type text,
  p_title text,
  p_body text,
  p_payload jsonb default '{}'::jsonb
) returns void
language plpgsql
security definer
set search_path = public, football
as $$
begin
  if p_user_id is null then
    return;
  end if;

  insert into football.prediction_notifications (
    user_id,
    notification_type,
    title,
    body,
    payload
  )
  values (
    p_user_id,
    coalesce(nullif(btrim(p_notification_type), ''), 'challenge'),
    coalesce(nullif(btrim(p_title), ''), 'Challenge update'),
    coalesce(nullif(btrim(p_body), ''), 'Your challenge has been updated.'),
    coalesce(p_payload, '{}'::jsonb)
  );
end;
$$;

create or replace function public.prediction_challenge_summary_json(
  p_challenge_id uuid,
  p_viewer_user_id uuid default auth.uid()
) returns jsonb
language plpgsql
security definer
stable
set search_path = public, football, auth
as $$
declare
  v_payload jsonb;
begin
  select
    jsonb_build_object(
      'id', challenge.id,
      'club_id', challenge.club_id,
      'match_id', challenge.match_id,
      'creator_user_id', challenge.creator_user_id,
      'stake_fet', challenge.stake_fet,
      'currency_code', challenge.currency_code,
      'status', challenge.status,
      'lock_at', challenge.lock_at,
      'settled_at', challenge.settled_at,
      'cancelled_at', challenge.cancelled_at,
      'void_reason', challenge.void_reason,
      'total_participants', challenge.total_participants,
      'total_pool_fet', challenge.total_pool_fet,
      'winner_count', challenge.winner_count,
      'loser_count', challenge.loser_count,
      'payout_per_winner_fet', challenge.payout_per_winner_fet,
      'official_home_score', challenge.official_home_score,
      'official_away_score', challenge.official_away_score,
      'created_at', challenge.created_at,
      'updated_at', challenge.updated_at,
      'fixture', fixture_data.fixture_json,
      'creator', creator_data.creator_json,
      'creator_name', creator_data.creator_json ->> 'display_name',
      'creator_avatar', creator_data.creator_json ->> 'avatar_url',
      'creator_prediction',
        case
          when creator_entry.id is null then null
          else jsonb_build_object(
            'home_score', creator_entry.predicted_home_score,
            'away_score', creator_entry.predicted_away_score,
            'joined_at', creator_entry.joined_at
          )
        end,
      'my_entry',
        case
          when viewer_entry.id is null then null
          else jsonb_build_object(
            'id', viewer_entry.id,
            'challenge_id', viewer_entry.challenge_id,
            'user_id', viewer_entry.user_id,
            'predicted_home_score', viewer_entry.predicted_home_score,
            'predicted_away_score', viewer_entry.predicted_away_score,
            'stake_fet', viewer_entry.stake_fet,
            'status', viewer_entry.status,
            'payout_fet', viewer_entry.payout_fet,
            'joined_at', viewer_entry.joined_at,
            'settled_at', viewer_entry.settled_at,
            'user_name', viewer_data.viewer_json ->> 'display_name',
            'user_avatar', viewer_data.viewer_json ->> 'avatar_url',
            'user', viewer_data.viewer_json
          )
        end,
      'permissions', jsonb_build_object(
        'has_joined', viewer_entry.id is not null,
        'is_creator', coalesce(p_viewer_user_id = challenge.creator_user_id, false),
        'can_join',
          coalesce(p_viewer_user_id is not null, false)
          and challenge.status = 'open'
          and challenge.lock_at > timezone('utc', now())
          and viewer_entry.id is null,
        'can_cancel',
          coalesce(p_viewer_user_id = challenge.creator_user_id, false)
          and challenge.status = 'open'
          and challenge.total_participants = 1
          and challenge.lock_at > timezone('utc', now()),
        'can_retry_settlement',
          challenge.status = 'locked'
          and (public.is_super_admin() or public.is_admin_user() or public.is_club_admin(challenge.club_id))
      ),
      'settlement',
        case
          when settlement.challenge_id is null then null
          else jsonb_build_object(
            'challenge_id', settlement.challenge_id,
            'match_id', settlement.match_id,
            'official_home_score', settlement.official_home_score,
            'official_away_score', settlement.official_away_score,
            'winners_count', settlement.winners_count,
            'losers_count', settlement.losers_count,
            'total_pool_fet', settlement.total_pool_fet,
            'losers_pool_fet', settlement.losers_pool_fet,
            'payout_per_winner_fet', settlement.payout_per_winner_fet,
            'settlement_mode', settlement.settlement_mode,
            'executed_at', settlement.executed_at,
            'metadata', coalesce(settlement.metadata, '{}'::jsonb)
          )
        end
    )
    into v_payload
    from football.prediction_challenges challenge
    cross join lateral (
      select public.prediction_challenge_fixture_json(challenge.match_id) as fixture_json
    ) fixture_data
    cross join lateral (
      select public.prediction_challenge_user_json(challenge.creator_user_id, challenge.club_id) as creator_json
    ) creator_data
    left join lateral (
      select entry.*
        from football.prediction_challenge_entries entry
       where entry.challenge_id = challenge.id
         and entry.user_id = challenge.creator_user_id
       order by entry.joined_at asc
       limit 1
    ) creator_entry on true
    left join lateral (
      select entry.*
        from football.prediction_challenge_entries entry
       where entry.challenge_id = challenge.id
         and entry.user_id = p_viewer_user_id
       order by entry.joined_at asc
       limit 1
    ) viewer_entry on true
    cross join lateral (
      select case
        when viewer_entry.id is null then null::jsonb
        else public.prediction_challenge_user_json(viewer_entry.user_id, challenge.club_id)
      end as viewer_json
    ) viewer_data
    left join football.prediction_challenge_settlements settlement
      on settlement.challenge_id = challenge.id
   where challenge.id = p_challenge_id
   limit 1;

  return v_payload;
end;
$$;

create or replace function public.prediction_get_challenge_feed(
  p_club_id bigint default null,
  p_statuses text[] default null,
  p_sort text default 'ending_soon',
  p_limit integer default 20,
  p_offset integer default 0,
  p_only_joined boolean default false
) returns jsonb
language plpgsql
security definer
set search_path = public, football, auth
as $$
declare
  v_user_id uuid := auth.uid();
  v_club_id bigint;
  v_sort text := lower(nullif(btrim(coalesce(p_sort, '')), ''));
  v_payload jsonb;
begin
  if v_user_id is null then
    raise exception 'Auth required.';
  end if;

  v_club_id := public.fet_require_club_context(p_club_id);
  v_sort := coalesce(v_sort, 'ending_soon');

  select coalesce(
    jsonb_agg(
      ranked.payload
      order by
        ranked.sort_lock_at asc nulls last,
        ranked.sort_pool desc nulls last,
        ranked.sort_participants desc nulls last,
        ranked.sort_settled desc nulls last,
        ranked.sort_created desc nulls last,
        ranked.created_at desc
    ),
    '[]'::jsonb
  )
    into v_payload
    from (
      select
        public.prediction_challenge_summary_json(challenge.id, v_user_id) as payload,
        challenge.created_at,
        case when v_sort = 'ending_soon' then challenge.lock_at end as sort_lock_at,
        case when v_sort = 'high_pool' then challenge.total_pool_fet end as sort_pool,
        case when v_sort = 'most_participants' then challenge.total_participants end as sort_participants,
        case when v_sort = 'settled' then coalesce(challenge.settled_at, challenge.updated_at, challenge.created_at) end as sort_settled,
        case when v_sort in ('newest', 'open', 'my_joined') then challenge.created_at end as sort_created
      from football.prediction_challenges challenge
      left join football.prediction_challenge_entries viewer_entry
        on viewer_entry.challenge_id = challenge.id
       and viewer_entry.user_id = v_user_id
      where challenge.club_id = v_club_id
        and (
          p_statuses is null
          or array_length(p_statuses, 1) is null
          or challenge.status = any(p_statuses)
        )
        and (not p_only_joined or viewer_entry.id is not null)
      order by
        case when v_sort = 'ending_soon' then challenge.lock_at end asc nulls last,
        case when v_sort = 'high_pool' then challenge.total_pool_fet end desc nulls last,
        case when v_sort = 'most_participants' then challenge.total_participants end desc nulls last,
        case when v_sort = 'settled' then coalesce(challenge.settled_at, challenge.updated_at, challenge.created_at) end desc nulls last,
        challenge.created_at desc
      limit greatest(coalesce(p_limit, 20), 1)
      offset greatest(coalesce(p_offset, 0), 0)
    ) ranked;

  return coalesce(v_payload, '[]'::jsonb);
end;
$$;

create or replace function public.prediction_get_my_challenges(
  p_club_id bigint default null,
  p_statuses text[] default null,
  p_sort text default 'ending_soon',
  p_limit integer default 20,
  p_offset integer default 0
) returns jsonb
language plpgsql
security definer
set search_path = public, football, auth
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'Auth required.';
  end if;

  return public.prediction_get_challenge_feed(
    p_club_id := p_club_id,
    p_statuses := p_statuses,
    p_sort := p_sort,
    p_limit := p_limit,
    p_offset := p_offset,
    p_only_joined := true
  );
end;
$$;

create or replace function public.prediction_get_challenge_detail(
  p_challenge_id uuid,
  p_club_id bigint default null
) returns jsonb
language plpgsql
security definer
set search_path = public, football, auth
as $$
declare
  v_user_id uuid := auth.uid();
  v_club_id bigint;
  v_challenge_club_id bigint;
  v_summary jsonb;
  v_entries jsonb;
begin
  if v_user_id is null then
    raise exception 'Auth required.';
  end if;

  v_club_id := public.fet_require_club_context(p_club_id);

  select challenge.club_id
    into v_challenge_club_id
    from football.prediction_challenges challenge
   where challenge.id = p_challenge_id
   limit 1;

  if v_challenge_club_id is null or v_challenge_club_id != v_club_id then
    raise exception 'Challenge not found.';
  end if;

  v_summary := public.prediction_challenge_summary_json(p_challenge_id, v_user_id);

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', entry.id,
        'challenge_id', entry.challenge_id,
        'user_id', entry.user_id,
        'predicted_home_score', entry.predicted_home_score,
        'predicted_away_score', entry.predicted_away_score,
        'stake_fet', entry.stake_fet,
        'status', entry.status,
        'payout_fet', entry.payout_fet,
        'joined_at', entry.joined_at,
        'settled_at', entry.settled_at,
        'user_name', user_data.user_json ->> 'display_name',
        'user_avatar', user_data.user_json ->> 'avatar_url',
        'user', user_data.user_json
      )
      order by entry.joined_at asc
    ),
    '[]'::jsonb
  )
    into v_entries
    from football.prediction_challenge_entries entry
    cross join lateral (
      select public.prediction_challenge_user_json(entry.user_id, v_club_id) as user_json
    ) user_data
   where entry.challenge_id = p_challenge_id;

  return jsonb_build_object(
    'challenge', v_summary,
    'entries', coalesce(v_entries, '[]'::jsonb),
    'user_entry', v_summary -> 'my_entry',
    'settlement', v_summary -> 'settlement'
  );
end;
$$;

create or replace function public.prediction_admin_get_challenges(
  p_club_id bigint default null,
  p_statuses text[] default null,
  p_limit integer default 50,
  p_offset integer default 0
) returns jsonb
language plpgsql
security definer
set search_path = public, football, auth
as $$
declare
  v_user_id uuid := auth.uid();
  v_club_id bigint;
  v_payload jsonb;
begin
  if v_user_id is null then
    raise exception 'Auth required.';
  end if;

  v_club_id := public.fet_require_club_context(p_club_id);

  if not (public.is_super_admin() or public.is_admin_user() or public.is_club_admin(v_club_id)) then
    raise exception 'Admin access required.';
  end if;

  select coalesce(
    jsonb_agg(
      ranked.payload
      order by ranked.sort_updated desc nulls last, ranked.created_at desc
    ),
    '[]'::jsonb
  )
    into v_payload
    from (
      select
        (public.prediction_challenge_summary_json(challenge.id, v_user_id)
          || jsonb_build_object(
            'admin', jsonb_build_object(
              'audit_status', challenge.status,
              'settlement_state', case
                when settlement.challenge_id is not null then 'recorded'
                when challenge.status in ('settled', 'void', 'cancelled') then 'missing_record'
                else 'pending'
              end,
              'settlement_mode', settlement.settlement_mode,
              'executed_at', settlement.executed_at,
              'metadata', coalesce(settlement.metadata, '{}'::jsonb)
            )
          )) as payload,
        coalesce(challenge.updated_at, challenge.created_at) as sort_updated,
        challenge.created_at
      from football.prediction_challenges challenge
      left join football.prediction_challenge_settlements settlement
        on settlement.challenge_id = challenge.id
      where challenge.club_id = v_club_id
        and (
          p_statuses is null
          or array_length(p_statuses, 1) is null
          or challenge.status = any(p_statuses)
        )
      order by coalesce(challenge.updated_at, challenge.created_at) desc
      limit greatest(coalesce(p_limit, 50), 1)
      offset greatest(coalesce(p_offset, 0), 0)
    ) ranked;

  return coalesce(v_payload, '[]'::jsonb);
end;
$$;

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
  v_fixture record;
  v_challenge_id uuid;
  v_existing_challenge_id uuid;
begin
  if v_user_id is null then
    raise exception 'Auth required.';
  end if;

  if p_home_score is null or p_away_score is null or p_home_score < 0 or p_away_score < 0 or p_home_score > 20 or p_away_score > 20 then
    raise exception 'Invalid score prediction.';
  end if;

  if p_stake_fet < 100 or p_stake_fet > 100000 then
    raise exception 'Stake must be between 100 and 100000 FET.';
  end if;

  v_club_id := public.fet_require_club_context(p_club_id);

  select fixture.id, fixture.kickoff_at, fixture.status
    into v_fixture
    from football.fixtures fixture
   where fixture.id = p_match_id
   limit 1;

  if v_fixture.id is null then
    raise exception 'Match not found.';
  end if;

  if v_fixture.kickoff_at is null or v_fixture.kickoff_at <= timezone('utc', now()) then
    raise exception 'Match has already started.';
  end if;

  if coalesce(v_fixture.status::text, 'scheduled') not in ('scheduled', 'pending') then
    raise exception 'Challenge creation is only available for upcoming matches.';
  end if;

  select challenge.id
    into v_existing_challenge_id
    from football.prediction_challenges challenge
    join football.prediction_challenge_entries creator_entry
      on creator_entry.challenge_id = challenge.id
     and creator_entry.user_id = challenge.creator_user_id
   where challenge.club_id = v_club_id
     and challenge.creator_user_id = v_user_id
     and challenge.match_id = p_match_id
     and challenge.stake_fet = p_stake_fet
     and challenge.status in ('open', 'locked')
     and creator_entry.predicted_home_score = p_home_score
     and creator_entry.predicted_away_score = p_away_score
   order by challenge.created_at desc
   limit 1;

  if v_existing_challenge_id is not null then
    return jsonb_build_object(
      'status', 'already_processed',
      'challenge', public.prediction_challenge_summary_json(v_existing_challenge_id, v_user_id)
    );
  end if;

  insert into football.prediction_challenges (
    club_id,
    match_id,
    creator_user_id,
    stake_fet,
    currency_code,
    status,
    lock_at,
    total_participants,
    total_pool_fet
  )
  values (
    v_club_id,
    p_match_id,
    v_user_id,
    p_stake_fet,
    'FET',
    'open',
    v_fixture.kickoff_at,
    1,
    p_stake_fet
  )
  returning id into v_challenge_id;

  insert into football.prediction_challenge_entries (
    challenge_id,
    user_id,
    predicted_home_score,
    predicted_away_score,
    stake_fet,
    status
  )
  values (
    v_challenge_id,
    v_user_id,
    p_home_score,
    p_away_score,
    p_stake_fet,
    'active'
  );

  perform public.prediction_challenge_adjust_wallet(
    p_club_id := v_club_id,
    p_user_id := v_user_id,
    p_amount_fet := p_stake_fet,
    p_direction := 'debit',
    p_reference_type := 'challenge_create',
    p_reference_id := v_challenge_id::text,
    p_idempotency_key := 'challenge-create-stake:' || v_challenge_id::text,
    p_note := 'Stake locked for challenge creation',
    p_metadata := jsonb_build_object(
      'challenge_id', v_challenge_id,
      'match_id', p_match_id,
      'kind', 'challenge_stake'
    )
  );

  perform public.prediction_challenge_queue_notification(
    p_user_id := v_user_id,
    p_notification_type := 'challenge_created',
    p_title := 'Challenge created',
    p_body := format(
      'Your %s-%s challenge is live with %s FET at stake.',
      p_home_score,
      p_away_score,
      p_stake_fet
    ),
    p_payload := jsonb_build_object(
      'challenge_id', v_challenge_id,
      'fixture_id', p_match_id,
      'route', '/challenge/' || v_challenge_id::text
    )
  );

  return jsonb_build_object(
    'status', 'created',
    'challenge', public.prediction_challenge_summary_json(v_challenge_id, v_user_id)
  );
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
  v_challenge football.prediction_challenges;
begin
  if v_user_id is null then
    raise exception 'Auth required.';
  end if;

  if p_home_score is null or p_away_score is null or p_home_score < 0 or p_away_score < 0 or p_home_score > 20 or p_away_score > 20 then
    raise exception 'Invalid score prediction.';
  end if;

  select *
    into v_challenge
    from football.prediction_challenges challenge
   where challenge.id = p_challenge_id
   for update;

  if v_challenge.id is null then
    raise exception 'Challenge not found.';
  end if;

  if v_challenge.status != 'open' or v_challenge.lock_at <= timezone('utc', now()) then
    raise exception 'Challenge is closed.';
  end if;

  if exists (
    select 1
      from football.prediction_challenge_entries entry
     where entry.challenge_id = p_challenge_id
       and entry.user_id = v_user_id
  ) then
    return jsonb_build_object(
      'status', 'already_joined',
      'challenge', public.prediction_challenge_summary_json(p_challenge_id, v_user_id)
    );
  end if;

  insert into football.prediction_challenge_entries (
    challenge_id,
    user_id,
    predicted_home_score,
    predicted_away_score,
    stake_fet,
    status
  )
  values (
    p_challenge_id,
    v_user_id,
    p_home_score,
    p_away_score,
    v_challenge.stake_fet,
    'active'
  );

  update football.prediction_challenges
     set total_participants = total_participants + 1,
         total_pool_fet = total_pool_fet + v_challenge.stake_fet,
         updated_at = timezone('utc', now())
   where id = p_challenge_id;

  perform public.prediction_challenge_adjust_wallet(
    p_club_id := v_challenge.club_id,
    p_user_id := v_user_id,
    p_amount_fet := v_challenge.stake_fet,
    p_direction := 'debit',
    p_reference_type := 'challenge_join',
    p_reference_id := p_challenge_id::text,
    p_idempotency_key := 'challenge-join-stake:' || p_challenge_id::text || ':' || v_user_id::text,
    p_note := 'Stake locked for challenge join',
    p_metadata := jsonb_build_object(
      'challenge_id', p_challenge_id,
      'match_id', v_challenge.match_id,
      'kind', 'challenge_stake'
    )
  );

  perform public.prediction_challenge_queue_notification(
    p_user_id := v_user_id,
    p_notification_type := 'challenge_joined',
    p_title := 'Challenge joined',
    p_body := format(
      'You joined the challenge with %s-%s for %s FET.',
      p_home_score,
      p_away_score,
      v_challenge.stake_fet
    ),
    p_payload := jsonb_build_object(
      'challenge_id', p_challenge_id,
      'fixture_id', v_challenge.match_id,
      'route', '/challenge/' || p_challenge_id::text
    )
  );

  if v_challenge.creator_user_id <> v_user_id then
    perform public.prediction_challenge_queue_notification(
      p_user_id := v_challenge.creator_user_id,
      p_notification_type := 'challenge_participant_joined',
      p_title := 'A supporter joined your challenge',
      p_body := format('Your %s FET pool just picked up another participant.', v_challenge.stake_fet),
      p_payload := jsonb_build_object(
        'challenge_id', p_challenge_id,
        'fixture_id', v_challenge.match_id,
        'route', '/challenge/' || p_challenge_id::text
      )
    );
  end if;

  return jsonb_build_object(
    'status', 'joined',
    'challenge', public.prediction_challenge_summary_json(p_challenge_id, v_user_id)
  );
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
  v_challenge football.prediction_challenges;
begin
  if v_user_id is null then
    raise exception 'Auth required.';
  end if;

  select *
    into v_challenge
    from football.prediction_challenges challenge
   where challenge.id = p_challenge_id
   for update;

  if v_challenge.id is null then
    raise exception 'Challenge not found.';
  end if;

  if v_challenge.creator_user_id <> v_user_id then
    raise exception 'Only the creator can cancel this challenge.';
  end if;

  if v_challenge.status = 'cancelled' then
    return jsonb_build_object(
      'status', 'cancelled',
      'challenge', public.prediction_challenge_summary_json(p_challenge_id, v_user_id)
    );
  end if;

  if v_challenge.status != 'open' or v_challenge.lock_at <= timezone('utc', now()) then
    raise exception 'Challenge can no longer be cancelled.';
  end if;

  if v_challenge.total_participants > 1 then
    raise exception 'Challenge cannot be cancelled after another participant joins.';
  end if;

  update football.prediction_challenges
     set status = 'cancelled',
         cancelled_at = timezone('utc', now()),
         updated_at = timezone('utc', now())
   where id = p_challenge_id;

  update football.prediction_challenge_entries
     set status = 'cancelled',
         settled_at = timezone('utc', now())
   where challenge_id = p_challenge_id;

  perform public.prediction_challenge_adjust_wallet(
    p_club_id := v_challenge.club_id,
    p_user_id := v_user_id,
    p_amount_fet := v_challenge.stake_fet,
    p_direction := 'credit',
    p_reference_type := 'challenge_cancel',
    p_reference_id := p_challenge_id::text,
    p_idempotency_key := 'challenge-cancel-refund:' || p_challenge_id::text || ':' || v_user_id::text,
    p_note := 'Refund for cancelled challenge',
    p_metadata := jsonb_build_object(
      'challenge_id', p_challenge_id,
      'match_id', v_challenge.match_id,
      'kind', 'challenge_refund'
    )
  );

  insert into football.prediction_challenge_settlements (
    challenge_id,
    match_id,
    official_home_score,
    official_away_score,
    winners_count,
    losers_count,
    total_pool_fet,
    losers_pool_fet,
    payout_per_winner_fet,
    settlement_mode,
    executed_at,
    metadata
  )
  values (
    p_challenge_id,
    v_challenge.match_id,
    null,
    null,
    0,
    0,
    v_challenge.total_pool_fet,
    0,
    0,
    'cancelled',
    timezone('utc', now()),
    jsonb_build_object('reason', 'creator_cancelled')
  )
  on conflict (challenge_id) do update
    set settlement_mode = excluded.settlement_mode,
        executed_at = excluded.executed_at,
        metadata = excluded.metadata;

  perform public.prediction_challenge_queue_notification(
    p_user_id := v_user_id,
    p_notification_type := 'challenge_cancelled',
    p_title := 'Challenge cancelled',
    p_body := format('Your %s FET stake was refunded.', v_challenge.stake_fet),
    p_payload := jsonb_build_object(
      'challenge_id', p_challenge_id,
      'fixture_id', v_challenge.match_id,
      'earned', v_challenge.stake_fet,
      'route', '/challenge/' || p_challenge_id::text
    )
  );

  return jsonb_build_object(
    'status', 'cancelled',
    'challenge', public.prediction_challenge_summary_json(p_challenge_id, v_user_id)
  );
end;
$$;

create or replace function public.prediction_challenge_refund_all(
  p_challenge_id uuid,
  p_void_reason text,
  p_settlement_mode text,
  p_notification_title text,
  p_notification_body text,
  p_official_home_score integer default null,
  p_official_away_score integer default null,
  p_metadata jsonb default '{}'::jsonb
) returns jsonb
language plpgsql
security definer
set search_path = public, football, auth
as $$
declare
  v_challenge football.prediction_challenges;
  v_entry football.prediction_challenge_entries;
  v_metadata jsonb := coalesce(p_metadata, '{}'::jsonb) || jsonb_build_object(
    'void_reason', coalesce(p_void_reason, 'unknown')
  );
begin
  select *
    into v_challenge
    from football.prediction_challenges challenge
   where challenge.id = p_challenge_id
   for update;

  if v_challenge.id is null then
    return jsonb_build_object('status', 'missing');
  end if;

  if v_challenge.status = 'void' then
    return jsonb_build_object('status', 'void', 'already_processed', true);
  end if;

  for v_entry in
    select entry.*
      from football.prediction_challenge_entries entry
     where entry.challenge_id = p_challenge_id
       and entry.status = 'active'
     order by entry.joined_at asc
  loop
    perform public.prediction_challenge_adjust_wallet(
      p_club_id := v_challenge.club_id,
      p_user_id := v_entry.user_id,
      p_amount_fet := v_entry.stake_fet,
      p_direction := 'credit',
      p_reference_type := 'challenge_refund',
      p_reference_id := p_challenge_id::text,
      p_idempotency_key := 'challenge-refund:' || p_challenge_id::text || ':' || v_entry.id::text || ':' || coalesce(p_void_reason, 'void'),
      p_note := 'Challenge stake refunded',
      p_metadata := jsonb_build_object(
        'challenge_id', p_challenge_id,
        'entry_id', v_entry.id,
        'match_id', v_challenge.match_id,
        'void_reason', p_void_reason,
        'kind', 'challenge_refund'
      )
    );

    update football.prediction_challenge_entries
       set status = 'refunded',
           payout_fet = stake_fet,
           settled_at = timezone('utc', now())
     where id = v_entry.id;

    perform public.prediction_challenge_queue_notification(
      p_user_id := v_entry.user_id,
      p_notification_type := 'challenge_refunded',
      p_title := p_notification_title,
      p_body := p_notification_body,
      p_payload := jsonb_build_object(
        'challenge_id', p_challenge_id,
        'fixture_id', v_challenge.match_id,
        'earned', v_entry.stake_fet,
        'void_reason', p_void_reason,
        'route', '/challenge/' || p_challenge_id::text
      )
    );
  end loop;

  insert into football.prediction_challenge_settlements (
    challenge_id,
    match_id,
    official_home_score,
    official_away_score,
    winners_count,
    losers_count,
    total_pool_fet,
    losers_pool_fet,
    payout_per_winner_fet,
    settlement_mode,
    executed_at,
    metadata
  )
  values (
    p_challenge_id,
    v_challenge.match_id,
    p_official_home_score,
    p_official_away_score,
    0,
    0,
    v_challenge.total_pool_fet,
    0,
    0,
    coalesce(nullif(btrim(p_settlement_mode), ''), 'void'),
    timezone('utc', now()),
    v_metadata
  )
  on conflict (challenge_id) do update
    set official_home_score = excluded.official_home_score,
        official_away_score = excluded.official_away_score,
        winners_count = excluded.winners_count,
        losers_count = excluded.losers_count,
        total_pool_fet = excluded.total_pool_fet,
        losers_pool_fet = excluded.losers_pool_fet,
        payout_per_winner_fet = excluded.payout_per_winner_fet,
        settlement_mode = excluded.settlement_mode,
        executed_at = excluded.executed_at,
        metadata = excluded.metadata;

  update football.prediction_challenges
     set status = 'void',
         settled_at = timezone('utc', now()),
         void_reason = coalesce(nullif(btrim(p_void_reason), ''), 'void'),
         winner_count = 0,
         loser_count = 0,
         payout_per_winner_fet = 0,
         official_home_score = p_official_home_score,
         official_away_score = p_official_away_score,
         updated_at = timezone('utc', now())
   where id = p_challenge_id;

  return jsonb_build_object(
    'status', 'void',
    'void_reason', p_void_reason,
    'challenge', public.prediction_challenge_summary_json(p_challenge_id, auth.uid())
  );
end;
$$;

create or replace function public.prediction_challenge_lock_due()
returns jsonb
language plpgsql
security definer
set search_path = public, football, auth
as $$
declare
  v_challenge record;
  v_entry record;
  v_locked_count integer := 0;
  v_voided_count integer := 0;
begin
  if auth.role() != 'service_role' then
    raise exception 'Service role required.';
  end if;

  for v_challenge in
    select challenge.id, challenge.club_id, challenge.match_id, challenge.total_participants
      from football.prediction_challenges challenge
     where challenge.status = 'open'
       and challenge.lock_at <= timezone('utc', now())
     order by challenge.lock_at asc, challenge.created_at asc
     for update skip locked
  loop
    if coalesce(v_challenge.total_participants, 0) <= 1 then
      perform public.prediction_challenge_refund_all(
        p_challenge_id := v_challenge.id,
        p_void_reason := 'no_opponents',
        p_settlement_mode := 'no_opponents',
        p_notification_title := 'Challenge voided',
        p_notification_body := 'No one joined before kickoff. Your stake has been refunded.',
        p_metadata := jsonb_build_object('locked_at', timezone('utc', now()))
      );
      v_voided_count := v_voided_count + 1;
      continue;
    end if;

    update football.prediction_challenges
       set status = 'locked',
           updated_at = timezone('utc', now())
     where id = v_challenge.id
       and status = 'open';

    for v_entry in
      select entry.user_id
        from football.prediction_challenge_entries entry
       where entry.challenge_id = v_challenge.id
    loop
      perform public.prediction_challenge_queue_notification(
        p_user_id := v_entry.user_id,
        p_notification_type := 'challenge_locked',
        p_title := 'Challenge locked',
        p_body := 'Kickoff has passed. The pool is now locked for settlement.',
        p_payload := jsonb_build_object(
          'challenge_id', v_challenge.id,
          'fixture_id', v_challenge.match_id,
          'route', '/challenge/' || v_challenge.id::text
        )
      );
    end loop;

    v_locked_count := v_locked_count + 1;
  end loop;

  return jsonb_build_object(
    'status', 'ok',
    'locked', v_locked_count,
    'voided_no_opponents', v_voided_count
  );
end;
$$;

create or replace function public.prediction_challenge_settle_internal(
  p_challenge_id uuid,
  p_force boolean default false
) returns jsonb
language plpgsql
security definer
set search_path = public, football, auth
as $$
declare
  v_challenge football.prediction_challenges;
  v_fixture record;
  v_total_active integer := 0;
  v_winners_count integer := 0;
  v_losers_count integer := 0;
  v_losers_pool_fet bigint := 0;
  v_base_payout_per_winner_fet bigint := 0;
  v_remainder_fet bigint := 0;
  v_entry football.prediction_challenge_entries;
  v_actual_payout bigint;
  v_winner_payouts jsonb := '[]'::jsonb;
begin
  select *
    into v_challenge
    from football.prediction_challenges challenge
   where challenge.id = p_challenge_id
   for update;

  if v_challenge.id is null then
    return jsonb_build_object('status', 'missing');
  end if;

  if not (
    auth.role() = 'service_role'
    or (
      p_force
      and (public.is_super_admin() or public.is_admin_user() or public.is_club_admin(v_challenge.club_id))
    )
  ) then
    raise exception 'Permission denied.';
  end if;

  if v_challenge.status in ('settled', 'void', 'cancelled') then
    return jsonb_build_object(
      'status', v_challenge.status,
      'already_processed', true,
      'challenge', public.prediction_challenge_summary_json(p_challenge_id, auth.uid())
    );
  end if;

  if v_challenge.status = 'open' and v_challenge.lock_at <= timezone('utc', now()) then
    if coalesce(v_challenge.total_participants, 0) <= 1 then
      return public.prediction_challenge_refund_all(
        p_challenge_id := p_challenge_id,
        p_void_reason := 'no_opponents',
        p_settlement_mode := 'no_opponents',
        p_notification_title := 'Challenge voided',
        p_notification_body := 'No one joined before kickoff. Your stake has been refunded.',
        p_metadata := jsonb_build_object('settled_from', 'open')
      );
    end if;

    update football.prediction_challenges
       set status = 'locked',
           updated_at = timezone('utc', now())
     where id = p_challenge_id
       and status = 'open'
    returning * into v_challenge;
  end if;

  if v_challenge.status <> 'locked' then
    return jsonb_build_object('status', 'pending', 'message', 'Challenge is not ready for settlement.');
  end if;

  select fixture.id, fixture.status, fixture.home_score, fixture.away_score
    into v_fixture
    from football.fixtures fixture
   where fixture.id = v_challenge.match_id
   limit 1;

  if v_fixture.id is null then
    return public.prediction_challenge_refund_all(
      p_challenge_id := p_challenge_id,
      p_void_reason := 'match_invalid',
      p_settlement_mode := 'match_invalid',
      p_notification_title := 'Challenge refunded',
      p_notification_body := 'The official result is unavailable. Your stake has been refunded.',
      p_metadata := jsonb_build_object('fixture_missing', true)
    );
  end if;

  if coalesce(v_challenge.total_participants, 0) <= 1 then
    return public.prediction_challenge_refund_all(
      p_challenge_id := p_challenge_id,
      p_void_reason := 'no_opponents',
      p_settlement_mode := 'no_opponents',
      p_notification_title := 'Challenge voided',
      p_notification_body := 'No one joined before kickoff. Your stake has been refunded.',
      p_metadata := jsonb_build_object('fixture_status', v_fixture.status)
    );
  end if;

  if coalesce(v_fixture.status::text, '') in ('postponed', 'cancelled', 'abandoned') then
    return public.prediction_challenge_refund_all(
      p_challenge_id := p_challenge_id,
      p_void_reason := 'match_invalid',
      p_settlement_mode := 'match_invalid',
      p_notification_title := 'Challenge refunded',
      p_notification_body := 'The fixture did not finish officially. Your stake has been refunded.',
      p_metadata := jsonb_build_object('fixture_status', v_fixture.status)
    );
  end if;

  if coalesce(v_fixture.status::text, '') <> 'finished'
     or v_fixture.home_score is null
     or v_fixture.away_score is null then
    if v_challenge.lock_at <= timezone('utc', now()) - interval '3 days' then
      return public.prediction_challenge_refund_all(
        p_challenge_id := p_challenge_id,
        p_void_reason := 'match_invalid',
        p_settlement_mode := 'match_invalid',
        p_notification_title := 'Challenge refunded',
        p_notification_body := 'The official result was not confirmed in time. Your stake has been refunded.',
        p_metadata := jsonb_build_object('fixture_status', v_fixture.status, 'stale_lock', true)
      );
    end if;

    return jsonb_build_object('status', 'pending', 'message', 'Official result is not available yet.');
  end if;

  select count(*)
    into v_total_active
    from football.prediction_challenge_entries entry
   where entry.challenge_id = p_challenge_id
     and entry.status = 'active';

  if v_total_active <= 1 then
    return public.prediction_challenge_refund_all(
      p_challenge_id := p_challenge_id,
      p_void_reason := 'no_opponents',
      p_settlement_mode := 'no_opponents',
      p_notification_title := 'Challenge voided',
      p_notification_body := 'No valid opponent remained at settlement. Your stake has been refunded.',
      p_official_home_score := v_fixture.home_score,
      p_official_away_score := v_fixture.away_score,
      p_metadata := jsonb_build_object('fixture_status', v_fixture.status)
    );
  end if;

  select count(*)
    into v_winners_count
    from football.prediction_challenge_entries entry
   where entry.challenge_id = p_challenge_id
     and entry.status = 'active'
     and entry.predicted_home_score = v_fixture.home_score
     and entry.predicted_away_score = v_fixture.away_score;

  if v_winners_count = 0 then
    return public.prediction_challenge_refund_all(
      p_challenge_id := p_challenge_id,
      p_void_reason := 'no_exact_winner',
      p_settlement_mode := 'no_exact_winner',
      p_notification_title := 'Challenge refunded',
      p_notification_body := 'No one hit the exact score. All stakes were refunded.',
      p_official_home_score := v_fixture.home_score,
      p_official_away_score := v_fixture.away_score,
      p_metadata := jsonb_build_object('fixture_status', v_fixture.status)
    );
  end if;

  v_losers_count := greatest(v_total_active - v_winners_count, 0);
  v_losers_pool_fet := v_losers_count * v_challenge.stake_fet;
  v_base_payout_per_winner_fet := v_challenge.stake_fet + floor(v_losers_pool_fet / v_winners_count);
  v_remainder_fet := mod(v_losers_pool_fet, v_winners_count);

  for v_entry in
    select entry.*
      from football.prediction_challenge_entries entry
     where entry.challenge_id = p_challenge_id
       and entry.status = 'active'
     order by entry.joined_at asc, entry.id asc
  loop
    if v_entry.predicted_home_score = v_fixture.home_score
       and v_entry.predicted_away_score = v_fixture.away_score then
      v_actual_payout := v_base_payout_per_winner_fet;
      if v_remainder_fet > 0 then
        v_actual_payout := v_actual_payout + 1;
        v_remainder_fet := v_remainder_fet - 1;
      end if;

      perform public.prediction_challenge_adjust_wallet(
        p_club_id := v_challenge.club_id,
        p_user_id := v_entry.user_id,
        p_amount_fet := v_actual_payout,
        p_direction := 'credit',
        p_reference_type := 'challenge_payout',
        p_reference_id := p_challenge_id::text,
        p_idempotency_key := 'challenge-payout:' || p_challenge_id::text || ':' || v_entry.id::text,
        p_note := 'Challenge payout',
        p_metadata := jsonb_build_object(
          'challenge_id', p_challenge_id,
          'entry_id', v_entry.id,
          'match_id', v_challenge.match_id,
          'kind', 'challenge_payout'
        )
      );

      update football.prediction_challenge_entries
         set status = 'winner',
             payout_fet = v_actual_payout,
             settled_at = timezone('utc', now())
       where id = v_entry.id;

      v_winner_payouts := v_winner_payouts || jsonb_build_object(
        'entry_id', v_entry.id,
        'user_id', v_entry.user_id,
        'payout_fet', v_actual_payout
      );

      perform public.prediction_challenge_queue_notification(
        p_user_id := v_entry.user_id,
        p_notification_type := 'challenge_won',
        p_title := 'Challenge won',
        p_body := format('Exact score hit. You earned %s FET.', v_actual_payout),
        p_payload := jsonb_build_object(
          'challenge_id', p_challenge_id,
          'fixture_id', v_challenge.match_id,
          'earned', v_actual_payout,
          'route', '/challenge/' || p_challenge_id::text
        )
      );
    else
      update football.prediction_challenge_entries
         set status = 'loser',
             payout_fet = 0,
             settled_at = timezone('utc', now())
       where id = v_entry.id;

      perform public.prediction_challenge_queue_notification(
        p_user_id := v_entry.user_id,
        p_notification_type := 'challenge_lost',
        p_title := 'Challenge settled',
        p_body := 'The challenge has settled and this pick did not win.',
        p_payload := jsonb_build_object(
          'challenge_id', p_challenge_id,
          'fixture_id', v_challenge.match_id,
          'route', '/challenge/' || p_challenge_id::text
        )
      );
    end if;
  end loop;

  insert into football.prediction_challenge_settlements (
    challenge_id,
    match_id,
    official_home_score,
    official_away_score,
    winners_count,
    losers_count,
    total_pool_fet,
    losers_pool_fet,
    payout_per_winner_fet,
    settlement_mode,
    executed_at,
    metadata
  )
  values (
    p_challenge_id,
    v_challenge.match_id,
    v_fixture.home_score,
    v_fixture.away_score,
    v_winners_count,
    v_losers_count,
    v_challenge.total_pool_fet,
    v_losers_pool_fet,
    v_base_payout_per_winner_fet,
    'standard',
    timezone('utc', now()),
    jsonb_build_object(
      'winner_payouts', v_winner_payouts,
      'remainder_distribution_applied', jsonb_array_length(v_winner_payouts),
      'official_status', v_fixture.status
    )
  )
  on conflict (challenge_id) do update
    set official_home_score = excluded.official_home_score,
        official_away_score = excluded.official_away_score,
        winners_count = excluded.winners_count,
        losers_count = excluded.losers_count,
        total_pool_fet = excluded.total_pool_fet,
        losers_pool_fet = excluded.losers_pool_fet,
        payout_per_winner_fet = excluded.payout_per_winner_fet,
        settlement_mode = excluded.settlement_mode,
        executed_at = excluded.executed_at,
        metadata = excluded.metadata;

  update football.prediction_challenges
     set status = 'settled',
         settled_at = timezone('utc', now()),
         winner_count = v_winners_count,
         loser_count = v_losers_count,
         payout_per_winner_fet = v_base_payout_per_winner_fet,
         official_home_score = v_fixture.home_score,
         official_away_score = v_fixture.away_score,
         updated_at = timezone('utc', now())
   where id = p_challenge_id;

  return jsonb_build_object(
    'status', 'settled',
    'challenge', public.prediction_challenge_summary_json(p_challenge_id, auth.uid())
  );
end;
$$;

create or replace function public.prediction_challenge_settle_due()
returns jsonb
language plpgsql
security definer
set search_path = public, football, auth
as $$
declare
  v_challenge record;
  v_result jsonb;
  v_settled_count integer := 0;
  v_voided_count integer := 0;
  v_pending_count integer := 0;
begin
  if auth.role() != 'service_role' then
    raise exception 'Service role required.';
  end if;

  for v_challenge in
    select challenge.id
      from football.prediction_challenges challenge
      join football.fixtures fixture on fixture.id = challenge.match_id
     where challenge.status = 'locked'
       and (
         fixture.status::text in ('finished', 'postponed', 'cancelled', 'abandoned')
         or challenge.lock_at <= timezone('utc', now()) - interval '3 days'
       )
     order by challenge.lock_at asc, challenge.created_at asc
     for update skip locked
  loop
    v_result := public.prediction_challenge_settle(v_challenge.id);

    case coalesce(v_result ->> 'status', '')
      when 'settled' then
        v_settled_count := v_settled_count + 1;
      when 'void' then
        v_voided_count := v_voided_count + 1;
      else
        v_pending_count := v_pending_count + 1;
    end case;
  end loop;

  return jsonb_build_object(
    'status', 'ok',
    'settled', v_settled_count,
    'voided', v_voided_count,
    'pending', v_pending_count
  );
end;
$$;

create or replace function public.prediction_challenge_admin_retry_settlement(
  p_challenge_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = public, football, auth
as $$
declare
  v_club_id bigint;
begin
  select challenge.club_id
    into v_club_id
    from football.prediction_challenges challenge
   where challenge.id = p_challenge_id
   limit 1;

  if v_club_id is null then
    raise exception 'Challenge not found.';
  end if;

  if not (public.is_super_admin() or public.is_admin_user() or public.is_club_admin(v_club_id)) then
    raise exception 'Admin access required.';
  end if;

  return public.prediction_challenge_settle_internal(
    p_challenge_id := p_challenge_id,
    p_force := true
  );
end;
$$;

create or replace function public.prediction_challenge_settle(
  p_challenge_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = public, football, auth
as $$
begin
  return public.prediction_challenge_settle_internal(
    p_challenge_id := p_challenge_id,
    p_force := false
  );
end;
$$;

grant execute on function public.prediction_challenge_user_json(uuid, bigint) to authenticated, service_role;
grant execute on function public.prediction_challenge_fixture_json(uuid) to authenticated, service_role;
grant execute on function public.prediction_challenge_adjust_wallet(bigint, uuid, bigint, text, text, text, text, text, jsonb) to service_role;
grant execute on function public.prediction_challenge_queue_notification(uuid, text, text, text, jsonb) to service_role;
grant execute on function public.prediction_challenge_summary_json(uuid, uuid) to authenticated, service_role;
grant execute on function public.prediction_get_challenge_feed(bigint, text[], text, integer, integer, boolean) to authenticated;
grant execute on function public.prediction_get_my_challenges(bigint, text[], text, integer, integer) to authenticated;
grant execute on function public.prediction_get_challenge_detail(uuid, bigint) to authenticated;
grant execute on function public.prediction_admin_get_challenges(bigint, text[], integer, integer) to authenticated;
grant execute on function public.prediction_challenge_create(uuid, integer, integer, bigint, bigint) to authenticated;
grant execute on function public.prediction_challenge_join(uuid, integer, integer) to authenticated;
grant execute on function public.prediction_challenge_cancel(uuid) to authenticated;
grant execute on function public.prediction_challenge_refund_all(uuid, text, text, text, text, integer, integer, jsonb) to service_role;
grant execute on function public.prediction_challenge_lock_due() to service_role;
grant execute on function public.prediction_challenge_settle_internal(uuid, boolean) to service_role;
grant execute on function public.prediction_challenge_settle(uuid) to service_role;
grant execute on function public.prediction_challenge_settle_due() to service_role;
grant execute on function public.prediction_challenge_admin_retry_settlement(uuid) to authenticated;
