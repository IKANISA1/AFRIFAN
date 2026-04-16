-- ============================================================================
-- FANZONE social graph + direct friend challenges
-- - Adds friend requests / accepted friendships with presence-aware directory RPCs
-- - Adds direct friend-vs-friend prediction challenges on fixture markets
-- - Hooks challenge settlement into the existing fixture settlement RPC
-- ============================================================================

create table if not exists public.supporter_friendships (
  id uuid primary key default gen_random_uuid(),
  club_id bigint not null references public.african_football_clubs(id) on delete cascade,
  requester_user_id uuid not null references public.users(id) on delete cascade,
  addressee_user_id uuid not null references public.users(id) on delete cascade,
  status text not null default 'pending',
  last_action_by uuid references public.users(id) on delete set null,
  requested_at timestamptz not null default timezone('utc', now()),
  responded_at timestamptz,
  accepted_at timestamptz,
  note text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint supporter_friendships_status_check
    check (status in ('pending', 'accepted', 'declined', 'blocked', 'cancelled')),
  constraint supporter_friendships_distinct_users_check
    check (requester_user_id <> addressee_user_id)
);

create unique index if not exists idx_supporter_friendships_pair
  on public.supporter_friendships (
    club_id,
    least(requester_user_id::text, addressee_user_id::text),
    greatest(requester_user_id::text, addressee_user_id::text)
  );

create index if not exists idx_supporter_friendships_requester
  on public.supporter_friendships (club_id, requester_user_id, status, created_at desc);

create index if not exists idx_supporter_friendships_addressee
  on public.supporter_friendships (club_id, addressee_user_id, status, created_at desc);

drop trigger if exists supporter_friendships_set_updated_at on public.supporter_friendships;
create trigger supporter_friendships_set_updated_at
before update on public.supporter_friendships
for each row execute function public.set_updated_at();

alter table public.supporter_friendships enable row level security;

drop policy if exists supporter_friendships_participant_read on public.supporter_friendships;
create policy supporter_friendships_participant_read
on public.supporter_friendships
for select
to authenticated
using (
  (
    auth.uid() = requester_user_id
    or auth.uid() = addressee_user_id
  )
  and club_id::text = public.requesting_club_id()
);

drop policy if exists supporter_friendships_admin_read on public.supporter_friendships;
create policy supporter_friendships_admin_read
on public.supporter_friendships
for select
to authenticated
using (public.is_club_admin(club_id) or public.is_super_admin());

drop policy if exists supporter_friendships_requester_insert on public.supporter_friendships;
create policy supporter_friendships_requester_insert
on public.supporter_friendships
for insert
to authenticated
with check (
  auth.uid() = requester_user_id
  and club_id::text = public.requesting_club_id()
);

drop policy if exists supporter_friendships_participant_update on public.supporter_friendships;
create policy supporter_friendships_participant_update
on public.supporter_friendships
for update
to authenticated
using (
  (
    auth.uid() = requester_user_id
    or auth.uid() = addressee_user_id
  )
  and club_id::text = public.requesting_club_id()
)
with check (
  (
    auth.uid() = requester_user_id
    or auth.uid() = addressee_user_id
  )
  and club_id::text = public.requesting_club_id()
);

create or replace view public.supporter_presence_catalog
with (security_invoker = true) as
with device_presence as (
  select
    token.user_id,
    token.club_id,
    token.last_seen_at
  from public.user_fcm_tokens token
  where token.user_id is not null
    and token.club_id is not null
  union all
  select
    subscription.user_id,
    nullif(subscription.club_id, '')::bigint as club_id,
    subscription.last_seen_at
  from public.web_push_subscriptions subscription
  where subscription.user_id is not null
    and nullif(subscription.club_id, '') ~ '^[0-9]+$'
)
select
  device_presence.user_id,
  device_presence.club_id,
  max(device_presence.last_seen_at) as last_seen_at,
  max(device_presence.last_seen_at) >= timezone('utc', now()) - interval '10 minutes' as is_online
from device_presence
group by device_presence.user_id, device_presence.club_id;

grant select on public.supporter_presence_catalog to authenticated, service_role;

create or replace function public.fet_get_friendship_row(
  p_self_user_id uuid,
  p_other_user_id uuid,
  p_club_id bigint
) returns public.supporter_friendships
language sql
stable
security definer
set search_path to 'public'
as $$
  select friendship.*
  from public.supporter_friendships friendship
  where friendship.club_id = p_club_id
    and (
      (
        friendship.requester_user_id = p_self_user_id
        and friendship.addressee_user_id = p_other_user_id
      ) or (
        friendship.requester_user_id = p_other_user_id
        and friendship.addressee_user_id = p_self_user_id
      )
    )
  order by friendship.created_at desc, friendship.id desc
  limit 1;
$$;

create or replace function public.fet_get_friends(
  p_club_id bigint default null,
  p_limit integer default 20,
  p_search text default null
) returns table(
  user_id uuid,
  public_user_id text,
  display_name text,
  tier text,
  balance integer,
  friendship_id uuid,
  friendship_status text,
  is_online boolean,
  last_seen_at timestamptz
)
language plpgsql
stable
security definer
set search_path to 'public'
as $$
declare
  v_user_id uuid := auth.uid();
  v_club_id bigint;
  v_search text := nullif(btrim(coalesce(p_search, '')), '');
begin
  if v_user_id is null then
    raise exception 'Authentication is required.';
  end if;

  v_club_id := public.fet_require_club_context(p_club_id);

  return query
  with accepted_friendships as (
    select
      friendship.id,
      friendship.status,
      case
        when friendship.requester_user_id = v_user_id then friendship.addressee_user_id
        else friendship.requester_user_id
      end as friend_user_id
    from public.supporter_friendships friendship
    where friendship.club_id = v_club_id
      and friendship.status = 'accepted'
      and (
        friendship.requester_user_id = v_user_id
        or friendship.addressee_user_id = v_user_id
      )
  )
  select
    profile.id as user_id,
    coalesce(nullif(btrim(profile.public_user_id), ''), user_row.public_user_id) as public_user_id,
    case
      when coalesce(profile.privacy_show_real_name, false)
        and nullif(btrim(profile.full_name), '') is not null
        then profile.full_name
      else coalesce(
        nullif(btrim(profile.display_name), ''),
        nullif(btrim(profile.public_user_id), ''),
        nullif(btrim(user_row.public_user_id), ''),
        'Supporter'
      )
    end as display_name,
    coalesce(membership.tier, public.resolve_fan_tier(coalesce(membership.points, 0))) as tier,
    coalesce(membership.points, 0)::integer as balance,
    friendship.id as friendship_id,
    friendship.status as friendship_status,
    case
      when coalesce(privacy.show_activity_status, true) then coalesce(presence.is_online, false)
      else false
    end as is_online,
    case
      when coalesce(privacy.show_activity_status, true) then presence.last_seen_at
      else null
    end as last_seen_at
  from accepted_friendships friendship
  join public.profiles profile
    on profile.id = friendship.friend_user_id
  left join public.users user_row
    on user_row.id = profile.id
  left join public.fan_memberships membership
    on membership.user_id = profile.id
   and membership.club_id = v_club_id
  left join public.user_privacy_settings privacy
    on privacy.user_id = profile.id
   and coalesce(privacy.club_id, v_club_id) = v_club_id
  left join public.supporter_presence_catalog presence
    on presence.user_id = profile.id
   and presence.club_id = v_club_id
  where profile.club_id = v_club_id
    and (
      v_search is null
      or coalesce(profile.display_name, '') ilike '%' || v_search || '%'
      or coalesce(profile.full_name, '') ilike '%' || v_search || '%'
      or coalesce(profile.public_user_id, '') ilike '%' || v_search || '%'
    )
  order by
    coalesce(
      case
        when coalesce(privacy.show_activity_status, true) then presence.is_online
        else false
      end,
      false
    ) desc,
    coalesce(membership.points, 0) desc,
    coalesce(nullif(btrim(profile.display_name), ''), nullif(btrim(profile.full_name), ''), 'Supporter') asc
  limit greatest(coalesce(p_limit, 20), 1);
end;
$$;

create or replace function public.fet_search_supporters(
  p_query text,
  p_club_id bigint default null,
  p_limit integer default 8
) returns table(
  user_id uuid,
  public_user_id text,
  display_name text,
  tier text,
  balance integer,
  friendship_id uuid,
  friendship_status text,
  is_online boolean,
  last_seen_at timestamptz
)
language plpgsql
stable
security definer
set search_path to 'public'
as $$
declare
  v_user_id uuid := auth.uid();
  v_club_id bigint;
  v_query text := nullif(btrim(coalesce(p_query, '')), '');
begin
  if v_user_id is null then
    raise exception 'Authentication is required.';
  end if;

  if v_query is null then
    return;
  end if;

  v_club_id := public.fet_require_club_context(p_club_id);

  return query
  with scoped as (
    select
      profile.id as user_id,
      coalesce(nullif(btrim(profile.public_user_id), ''), user_row.public_user_id) as public_user_id,
      case
        when coalesce(profile.privacy_show_real_name, false)
          and nullif(btrim(profile.full_name), '') is not null
          then profile.full_name
        else coalesce(
          nullif(btrim(profile.display_name), ''),
          nullif(btrim(profile.public_user_id), ''),
          nullif(btrim(user_row.public_user_id), ''),
          'Supporter'
        )
      end as display_name,
      coalesce(membership.tier, public.resolve_fan_tier(coalesce(membership.points, 0))) as tier,
      coalesce(membership.points, 0)::integer as balance,
      friendship.id as friendship_id,
      case
        when friendship.id is null then 'none'
        when friendship.status = 'pending' and friendship.requester_user_id = v_user_id then 'pending_outgoing'
        when friendship.status = 'pending' and friendship.addressee_user_id = v_user_id then 'pending_incoming'
        else friendship.status
      end as friendship_status,
      case
        when coalesce(privacy.show_activity_status, true) then coalesce(presence.is_online, false)
        else false
      end as is_online,
      case
        when coalesce(privacy.show_activity_status, true) then presence.last_seen_at
        else null
      end as last_seen_at
    from public.profiles profile
    left join public.users user_row
      on user_row.id = profile.id
    left join public.fan_memberships membership
      on membership.user_id = profile.id
     and membership.club_id = v_club_id
    left join lateral (
      select *
      from public.fet_get_friendship_row(v_user_id, profile.id, v_club_id)
    ) friendship on true
    left join public.user_privacy_settings privacy
      on privacy.user_id = profile.id
     and coalesce(privacy.club_id, v_club_id) = v_club_id
    left join public.supporter_presence_catalog presence
      on presence.user_id = profile.id
     and presence.club_id = v_club_id
    where profile.club_id = v_club_id
      and profile.id <> v_user_id
      and (
        coalesce(profile.public_user_id, '') ilike '%' || v_query || '%'
        or coalesce(profile.display_name, '') ilike '%' || v_query || '%'
        or coalesce(profile.full_name, '') ilike '%' || v_query || '%'
        or (
          coalesce(profile.privacy_findable_by_phone, false)
          and coalesce(profile.phone, '') ilike '%' || v_query || '%'
        )
      )
  )
  select
    scoped.user_id,
    scoped.public_user_id,
    scoped.display_name,
    scoped.tier,
    scoped.balance,
    scoped.friendship_id,
    scoped.friendship_status,
    scoped.is_online,
    scoped.last_seen_at
  from scoped
  order by
    case scoped.friendship_status
      when 'accepted' then 0
      when 'pending_incoming' then 1
      when 'pending_outgoing' then 2
      when 'none' then 3
      else 4
    end asc,
    scoped.balance desc,
    scoped.display_name asc
  limit greatest(coalesce(p_limit, 8), 1);
end;
$$;

create or replace function public.fet_request_friend(
  p_target_user_id uuid,
  p_club_id bigint default null,
  p_note text default null
) returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_user_id uuid := auth.uid();
  v_club_id bigint;
  v_existing public.supporter_friendships;
  v_note text := nullif(btrim(coalesce(p_note, '')), '');
begin
  if v_user_id is null then
    raise exception 'Authentication is required.';
  end if;

  if p_target_user_id is null then
    raise exception 'A supporter is required.';
  end if;

  if p_target_user_id = v_user_id then
    raise exception 'You cannot add yourself.';
  end if;

  v_club_id := public.fet_require_club_context(p_club_id);

  if not exists (
    select 1
    from public.profiles profile
    where profile.id = p_target_user_id
      and profile.club_id = v_club_id
  ) then
    raise exception 'Supporter not found in this club context.';
  end if;

  select *
    into v_existing
  from public.fet_get_friendship_row(v_user_id, p_target_user_id, v_club_id);

  if v_existing.id is not null then
    if v_existing.status = 'accepted' then
      return jsonb_build_object(
        'status', 'accepted',
        'friendship_id', v_existing.id,
        'message', 'You are already friends.'
      );
    end if;

    if v_existing.status = 'pending' and v_existing.requester_user_id = v_user_id then
      return jsonb_build_object(
        'status', 'pending_outgoing',
        'friendship_id', v_existing.id,
        'message', 'Friend request already sent.'
      );
    end if;

    if v_existing.status = 'pending' and v_existing.addressee_user_id = v_user_id then
      update public.supporter_friendships
      set status = 'accepted',
          last_action_by = v_user_id,
          responded_at = timezone('utc', now()),
          accepted_at = timezone('utc', now()),
          updated_at = timezone('utc', now())
      where id = v_existing.id;

      return jsonb_build_object(
        'status', 'accepted',
        'friendship_id', v_existing.id,
        'message', 'Friend request accepted.'
      );
    end if;

    if v_existing.status = 'blocked' and coalesce(v_existing.last_action_by, p_target_user_id) <> v_user_id then
      raise exception 'This supporter is not available for friend requests.';
    end if;

    update public.supporter_friendships
    set requester_user_id = v_user_id,
        addressee_user_id = p_target_user_id,
        status = 'pending',
        last_action_by = v_user_id,
        requested_at = timezone('utc', now()),
        responded_at = null,
        accepted_at = null,
        note = v_note,
        metadata = coalesce(metadata, '{}'::jsonb),
        updated_at = timezone('utc', now())
    where id = v_existing.id;

    return jsonb_build_object(
      'status', 'pending_outgoing',
      'friendship_id', v_existing.id,
      'message', 'Friend request sent.'
    );
  end if;

  insert into public.supporter_friendships (
    club_id,
    requester_user_id,
    addressee_user_id,
    status,
    last_action_by,
    note
  )
  values (
    v_club_id,
    v_user_id,
    p_target_user_id,
    'pending',
    v_user_id,
    v_note
  )
  returning * into v_existing;

  return jsonb_build_object(
    'status', 'pending_outgoing',
    'friendship_id', v_existing.id,
    'message', 'Friend request sent.'
  );
end;
$$;

create or replace function public.fet_respond_friend_request(
  p_friendship_id uuid,
  p_action text,
  p_club_id bigint default null
) returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_user_id uuid := auth.uid();
  v_club_id bigint;
  v_action text := lower(nullif(btrim(coalesce(p_action, '')), ''));
  v_friendship public.supporter_friendships;
begin
  if v_user_id is null then
    raise exception 'Authentication is required.';
  end if;

  if p_friendship_id is null then
    raise exception 'Friend request is required.';
  end if;

  if v_action not in ('accepted', 'declined', 'cancelled', 'blocked') then
    raise exception 'Unsupported friend action.';
  end if;

  v_club_id := public.fet_require_club_context(p_club_id);

  select *
    into v_friendship
  from public.supporter_friendships friendship
  where friendship.id = p_friendship_id
    and friendship.club_id = v_club_id
  for update;

  if v_friendship.id is null then
    raise exception 'Friend request not found.';
  end if;

  if v_action in ('accepted', 'declined') and v_friendship.addressee_user_id <> v_user_id then
    raise exception 'Only the invited supporter can accept or decline this request.';
  end if;

  if v_action = 'cancelled' and v_friendship.requester_user_id <> v_user_id then
    raise exception 'Only the requester can cancel this request.';
  end if;

  if v_action = 'blocked'
     and v_user_id not in (v_friendship.requester_user_id, v_friendship.addressee_user_id) then
    raise exception 'Only participants can block a supporter.';
  end if;

  update public.supporter_friendships
  set status = v_action,
      last_action_by = v_user_id,
      responded_at = case
        when v_action in ('accepted', 'declined', 'blocked') then timezone('utc', now())
        else responded_at
      end,
      accepted_at = case
        when v_action = 'accepted' then timezone('utc', now())
        else null
      end,
      updated_at = timezone('utc', now())
  where id = v_friendship.id
  returning * into v_friendship;

  return jsonb_build_object(
    'status', v_friendship.status,
    'friendship_id', v_friendship.id,
    'message', case v_friendship.status
      when 'accepted' then 'Friend request accepted.'
      when 'declined' then 'Friend request declined.'
      when 'cancelled' then 'Friend request cancelled.'
      when 'blocked' then 'Supporter blocked.'
      else 'Friend request updated.'
    end
  );
end;
$$;

grant execute on function public.fet_get_friends(bigint, integer, text) to authenticated;
grant execute on function public.fet_get_friends(bigint, integer, text) to service_role;
grant execute on function public.fet_search_supporters(text, bigint, integer) to authenticated;
grant execute on function public.fet_search_supporters(text, bigint, integer) to service_role;
grant execute on function public.fet_request_friend(uuid, bigint, text) to authenticated;
grant execute on function public.fet_request_friend(uuid, bigint, text) to service_role;
grant execute on function public.fet_respond_friend_request(uuid, text, bigint) to authenticated;
grant execute on function public.fet_respond_friend_request(uuid, text, bigint) to service_role;

create table if not exists football.prediction_friend_challenges (
  id uuid primary key default gen_random_uuid(),
  club_id bigint not null references public.african_football_clubs(id) on delete cascade,
  fixture_id uuid not null references football.fixtures(id) on delete cascade,
  fixture_market_id uuid not null references football.fixture_markets(id) on delete cascade,
  challenger_user_id uuid not null references public.users(id) on delete cascade,
  opponent_user_id uuid not null references public.users(id) on delete cascade,
  challenger_outcome text not null,
  opponent_outcome text,
  status text not null default 'pending',
  winner_user_id uuid references public.users(id) on delete set null,
  challenge_note text,
  expires_at timestamptz,
  responded_at timestamptz,
  settled_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint prediction_friend_challenges_status_check
    check (
      status in (
        'pending',
        'accepted',
        'declined',
        'challenger_won',
        'opponent_won',
        'draw',
        'expired',
        'cancelled'
      )
    ),
  constraint prediction_friend_challenges_distinct_users_check
    check (challenger_user_id <> opponent_user_id)
);

create index if not exists idx_prediction_friend_challenges_fixture
  on football.prediction_friend_challenges (fixture_id, status, created_at desc);

create index if not exists idx_prediction_friend_challenges_opponent
  on football.prediction_friend_challenges (opponent_user_id, status, created_at desc);

create index if not exists idx_prediction_friend_challenges_challenger
  on football.prediction_friend_challenges (challenger_user_id, status, created_at desc);

drop trigger if exists prediction_friend_challenges_set_updated_at on football.prediction_friend_challenges;
create trigger prediction_friend_challenges_set_updated_at
before update on football.prediction_friend_challenges
for each row execute function public.set_updated_at();

alter table football.prediction_friend_challenges enable row level security;

drop policy if exists prediction_friend_challenges_participant_read on football.prediction_friend_challenges;
create policy prediction_friend_challenges_participant_read
on football.prediction_friend_challenges
for select
to authenticated
using (
  auth.uid() in (challenger_user_id, opponent_user_id)
);

drop policy if exists prediction_friend_challenges_service_all on football.prediction_friend_challenges;
create policy prediction_friend_challenges_service_all
on football.prediction_friend_challenges
for all
to service_role
using (auth.role() = 'service_role')
with check (auth.role() = 'service_role');

grant select on football.prediction_friend_challenges to authenticated;
grant all on football.prediction_friend_challenges to service_role;

create or replace function public.prediction_create_friend_challenge(
  p_opponent_user_id uuid,
  p_fixture_market_id uuid,
  p_selected_outcome text,
  p_message text default null
) returns jsonb
language plpgsql
security definer
set search_path = public, football
as $$
declare
  v_user_id uuid := auth.uid();
  v_market record;
  v_existing record;
  v_challenge football.prediction_friend_challenges;
  v_selected_outcome text := lower(nullif(btrim(coalesce(p_selected_outcome, '')), ''));
  v_message text := nullif(btrim(coalesce(p_message, '')), '');
  v_club_id bigint;
begin
  if v_user_id is null then
    raise exception 'Authentication is required.';
  end if;

  if p_opponent_user_id is null then
    raise exception 'An opponent is required.';
  end if;

  if p_opponent_user_id = v_user_id then
    raise exception 'You cannot challenge yourself.';
  end if;

  if v_selected_outcome is null then
    raise exception 'A prediction outcome is required.';
  end if;

  select
    fm.id,
    fm.fixture_id,
    fm.market_id,
    fm.outcomes,
    fm.is_locked,
    f.status as fixture_status,
    f.kickoff_at
    into v_market
  from football.fixture_markets fm
  join football.fixtures f on f.id = fm.fixture_id
  where fm.id = p_fixture_market_id
  limit 1;

  if v_market.id is null then
    raise exception 'Fixture market not found.';
  end if;

  if v_market.is_locked
     or v_market.fixture_status in ('live', 'finished')
     or (v_market.kickoff_at is not null and v_market.kickoff_at <= now()) then
    raise exception 'This market is no longer available for challenges.';
  end if;

  if not exists (
    select 1
    from jsonb_array_elements(v_market.outcomes) outcome
    where lower(coalesce(outcome ->> 'key', outcome ->> 'label', '')) = v_selected_outcome
       or lower(coalesce(outcome ->> 'label', outcome ->> 'key', '')) = v_selected_outcome
  ) then
    raise exception 'Selected outcome is not valid for this market.';
  end if;

  v_club_id := football.prediction_fixture_club_id(v_market.fixture_id);

  if not exists (
    select 1
    from public.supporter_friendships friendship
    where friendship.club_id = v_club_id
      and friendship.status = 'accepted'
      and (
        (
          friendship.requester_user_id = v_user_id
          and friendship.addressee_user_id = p_opponent_user_id
        ) or (
          friendship.requester_user_id = p_opponent_user_id
          and friendship.addressee_user_id = v_user_id
        )
      )
  ) then
    raise exception 'Only accepted friends can be challenged.';
  end if;

  select
    challenge.id,
    challenge.status
    into v_existing
  from football.prediction_friend_challenges challenge
  where challenge.fixture_market_id = p_fixture_market_id
    and challenge.status in ('pending', 'accepted')
    and (
      (
        challenge.challenger_user_id = v_user_id
        and challenge.opponent_user_id = p_opponent_user_id
      ) or (
        challenge.challenger_user_id = p_opponent_user_id
        and challenge.opponent_user_id = v_user_id
      )
    )
  order by challenge.created_at desc
  limit 1;

  if v_existing.id is not null then
    return jsonb_build_object(
      'status', v_existing.status,
      'challenge_id', v_existing.id,
      'message', 'A challenge already exists for this fixture.'
    );
  end if;

  insert into football.prediction_friend_challenges (
    club_id,
    fixture_id,
    fixture_market_id,
    challenger_user_id,
    opponent_user_id,
    challenger_outcome,
    challenge_note,
    expires_at
  )
  values (
    v_club_id,
    v_market.fixture_id,
    p_fixture_market_id,
    v_user_id,
    p_opponent_user_id,
    v_selected_outcome,
    v_message,
    v_market.kickoff_at
  )
  returning * into v_challenge;

  return jsonb_build_object(
    'status', 'created',
    'challenge_id', v_challenge.id,
    'message', 'Challenge sent.'
  );
end;
$$;

create or replace function public.prediction_respond_friend_challenge(
  p_challenge_id uuid,
  p_action text default 'accepted',
  p_selected_outcome text default null
) returns jsonb
language plpgsql
security definer
set search_path = public, football
as $$
declare
  v_user_id uuid := auth.uid();
  v_action text := lower(nullif(btrim(coalesce(p_action, '')), ''));
  v_selected_outcome text := lower(nullif(btrim(coalesce(p_selected_outcome, '')), ''));
  v_challenge football.prediction_friend_challenges;
  v_market record;
begin
  if v_user_id is null then
    raise exception 'Authentication is required.';
  end if;

  if v_action not in ('accepted', 'declined', 'cancelled') then
    raise exception 'Unsupported challenge action.';
  end if;

  select *
    into v_challenge
  from football.prediction_friend_challenges challenge
  where challenge.id = p_challenge_id
  for update;

  if v_challenge.id is null then
    raise exception 'Challenge not found.';
  end if;

  if v_action in ('accepted', 'declined') and v_challenge.opponent_user_id <> v_user_id then
    raise exception 'Only the invited supporter can respond to this challenge.';
  end if;

  if v_action = 'cancelled' and v_challenge.challenger_user_id <> v_user_id then
    raise exception 'Only the challenger can cancel this challenge.';
  end if;

  if v_action = 'accepted' then
    if v_selected_outcome is null then
      raise exception 'A response outcome is required.';
    end if;

    select
      fm.id,
      fm.outcomes,
      fm.is_locked,
      f.status as fixture_status,
      f.kickoff_at
      into v_market
    from football.fixture_markets fm
    join football.fixtures f on f.id = fm.fixture_id
    where fm.id = v_challenge.fixture_market_id
    limit 1;

    if v_market.id is null then
      raise exception 'Fixture market not found.';
    end if;

    if v_market.is_locked
       or v_market.fixture_status in ('live', 'finished')
       or (v_market.kickoff_at is not null and v_market.kickoff_at <= now()) then
      raise exception 'This market is no longer available for challenges.';
    end if;

    if not exists (
      select 1
      from jsonb_array_elements(v_market.outcomes) outcome
      where lower(coalesce(outcome ->> 'key', outcome ->> 'label', '')) = v_selected_outcome
         or lower(coalesce(outcome ->> 'label', outcome ->> 'key', '')) = v_selected_outcome
    ) then
      raise exception 'Selected outcome is not valid for this market.';
    end if;
  end if;

  update football.prediction_friend_challenges
  set status = case
        when v_action = 'accepted' then 'accepted'
        when v_action = 'declined' then 'declined'
        else 'cancelled'
      end,
      opponent_outcome = case
        when v_action = 'accepted' then v_selected_outcome
        else opponent_outcome
      end,
      responded_at = case
        when v_action in ('accepted', 'declined') then timezone('utc', now())
        else responded_at
      end,
      updated_at = timezone('utc', now())
  where id = v_challenge.id
  returning * into v_challenge;

  return jsonb_build_object(
    'status', v_challenge.status,
    'challenge_id', v_challenge.id,
    'message', case v_challenge.status
      when 'accepted' then 'Challenge accepted.'
      when 'declined' then 'Challenge declined.'
      else 'Challenge cancelled.'
    end
  );
end;
$$;

create or replace function public.prediction_get_friend_challenges(
  p_status text default null,
  p_limit integer default 20,
  p_offset integer default 0
) returns jsonb
language plpgsql
security definer
stable
set search_path = public, football
as $$
declare
  v_user_id uuid := auth.uid();
  v_status text := lower(nullif(btrim(coalesce(p_status, '')), ''));
  v_rows jsonb;
begin
  if v_user_id is null then
    return '[]'::jsonb;
  end if;

  select coalesce(jsonb_agg(row_data order by created_at desc), '[]'::jsonb)
    into v_rows
  from (
    select
      jsonb_build_object(
        'id', challenge.id,
        'status', challenge.status,
        'club_id', challenge.club_id,
        'fixture_id', challenge.fixture_id,
        'fixture_market_id', challenge.fixture_market_id,
        'competition_name', fixture.competition_name,
        'home_team_name', fixture.home_team_name,
        'home_team_short_name', fixture.home_team_short_name,
        'away_team_name', fixture.away_team_name,
        'away_team_short_name', fixture.away_team_short_name,
        'kickoff_at', fixture.kickoff_at,
        'market_name', market.name,
        'market_short_name', market.short_name,
        'challenger_user_id', challenge.challenger_user_id,
        'challenger_display_name', coalesce(nullif(btrim(challenger_profile.display_name), ''), nullif(btrim(challenger_profile.full_name), ''), challenger_user.public_user_id, 'Supporter'),
        'challenger_outcome', challenge.challenger_outcome,
        'opponent_user_id', challenge.opponent_user_id,
        'opponent_display_name', coalesce(nullif(btrim(opponent_profile.display_name), ''), nullif(btrim(opponent_profile.full_name), ''), opponent_user.public_user_id, 'Supporter'),
        'opponent_outcome', challenge.opponent_outcome,
        'winner_user_id', challenge.winner_user_id,
        'challenge_note', challenge.challenge_note,
        'expires_at', challenge.expires_at,
        'responded_at', challenge.responded_at,
        'settled_at', challenge.settled_at,
        'created_at', challenge.created_at,
        'is_challenger', challenge.challenger_user_id = v_user_id
      ) as row_data,
      challenge.created_at
    from football.prediction_friend_challenges challenge
    join public.football_fixtures_catalog fixture
      on fixture.id = challenge.fixture_id
    join football.fixture_markets fixture_market
      on fixture_market.id = challenge.fixture_market_id
    join football.prediction_markets market
      on market.id = fixture_market.market_id
    left join public.profiles challenger_profile
      on challenger_profile.id = challenge.challenger_user_id
    left join public.users challenger_user
      on challenger_user.id = challenge.challenger_user_id
    left join public.profiles opponent_profile
      on opponent_profile.id = challenge.opponent_user_id
    left join public.users opponent_user
      on opponent_user.id = challenge.opponent_user_id
    where v_user_id in (challenge.challenger_user_id, challenge.opponent_user_id)
      and (v_status is null or lower(challenge.status) = v_status)
    order by challenge.created_at desc
    limit greatest(coalesce(p_limit, 20), 1)
    offset greatest(coalesce(p_offset, 0), 0)
  ) sub;

  return v_rows;
end;
$$;

create or replace function public.prediction_settle_friend_challenges(
  p_fixture_id uuid
) returns integer
language plpgsql
security definer
set search_path = public, football
as $$
declare
  v_count integer := 0;
begin
  if auth.role() != 'service_role' then
    return 0;
  end if;

  with resolved as (
    select
      challenge.id,
      case
        when lower(challenge.challenger_outcome) = lower(settlement.correct_outcome)
             and lower(coalesce(challenge.opponent_outcome, '')) <> lower(settlement.correct_outcome)
          then 'challenger_won'
        when lower(coalesce(challenge.opponent_outcome, '')) = lower(settlement.correct_outcome)
             and lower(challenge.challenger_outcome) <> lower(settlement.correct_outcome)
          then 'opponent_won'
        when lower(challenge.challenger_outcome) = lower(settlement.correct_outcome)
             and lower(coalesce(challenge.opponent_outcome, '')) = lower(settlement.correct_outcome)
          then 'draw'
        else 'draw'
      end as resolved_status,
      case
        when lower(challenge.challenger_outcome) = lower(settlement.correct_outcome)
             and lower(coalesce(challenge.opponent_outcome, '')) <> lower(settlement.correct_outcome)
          then challenge.challenger_user_id
        when lower(coalesce(challenge.opponent_outcome, '')) = lower(settlement.correct_outcome)
             and lower(challenge.challenger_outcome) <> lower(settlement.correct_outcome)
          then challenge.opponent_user_id
        else null
      end as resolved_winner
    from football.prediction_friend_challenges challenge
    join football.fixture_markets fixture_market
      on fixture_market.id = challenge.fixture_market_id
    join football.prediction_settlements settlement
      on settlement.fixture_id = challenge.fixture_id
     and settlement.market_id = fixture_market.market_id
    where challenge.fixture_id = p_fixture_id
      and challenge.status = 'accepted'
  )
  update football.prediction_friend_challenges challenge
  set status = resolved.resolved_status,
      winner_user_id = resolved.resolved_winner,
      settled_at = timezone('utc', now()),
      updated_at = timezone('utc', now())
  from resolved
  where challenge.id = resolved.id;

  get diagnostics v_count = row_count;
  return coalesce(v_count, 0);
end;
$$;

grant execute on function public.prediction_create_friend_challenge(uuid, uuid, text, text) to authenticated;
grant execute on function public.prediction_create_friend_challenge(uuid, uuid, text, text) to service_role;
grant execute on function public.prediction_respond_friend_challenge(uuid, text, text) to authenticated;
grant execute on function public.prediction_respond_friend_challenge(uuid, text, text) to service_role;
grant execute on function public.prediction_get_friend_challenges(text, integer, integer) to authenticated;
grant execute on function public.prediction_get_friend_challenges(text, integer, integer) to service_role;
grant execute on function public.prediction_settle_friend_challenges(uuid) to service_role;

create or replace function public.prediction_settle_fixture(
  p_fixture_id uuid,
  p_settlements jsonb
) returns jsonb
language plpgsql
security definer
set search_path = public, football
as $$
declare
  v_settlement jsonb;
  v_market_slug text;
  v_correct_outcome text;
  v_market_id uuid;
  v_fm_id uuid;
  v_fet_value integer;
  v_won_count integer := 0;
  v_lost_count integer := 0;
  v_total_awarded integer := 0;
  v_total_won integer := 0;
  v_total_lost integer := 0;
  v_markets_processed integer := 0;
  v_club_id bigint;
  v_pred record;
begin
  if auth.role() != 'service_role' then
    return jsonb_build_object('status', 'error', 'message', 'Service role required.');
  end if;

  v_club_id := football.prediction_fixture_club_id(p_fixture_id);

  for v_settlement in
    select * from jsonb_array_elements(p_settlements)
  loop
    v_market_slug := lower(coalesce(v_settlement ->> 'market_slug', ''));
    v_correct_outcome := coalesce(v_settlement ->> 'correct_outcome', '');
    v_won_count := 0;
    v_lost_count := 0;

    select
      market.id,
      fixture_market.id,
      coalesce(fixture_market.fet_value_override, market.default_fet_value)
      into v_market_id, v_fm_id, v_fet_value
    from football.fixture_markets fixture_market
    join football.prediction_markets market on market.id = fixture_market.market_id
    where fixture_market.fixture_id = p_fixture_id
      and lower(market.slug) = v_market_slug
    limit 1;

    if v_market_id is null or v_fm_id is null then
      continue;
    end if;

    update football.fixture_markets
    set is_locked = true,
        locked_at = coalesce(locked_at, now()),
        updated_at = now()
    where id = v_fm_id;

    update football.predictions
    set status = case
          when lower(selected_outcome) = lower(v_correct_outcome) then 'won'
          else 'lost'
        end,
        fet_earned = case
          when lower(selected_outcome) = lower(v_correct_outcome) then v_fet_value
          else 0
        end,
        settled_at = now()
    where fixture_market_id = v_fm_id
      and status in ('pending', 'won', 'lost', 'void');

    select count(*) filter (where prediction.status = 'won'),
           count(*) filter (where prediction.status = 'lost')
      into v_won_count, v_lost_count
    from football.predictions prediction
    where prediction.fixture_market_id = v_fm_id
      and prediction.status in ('won', 'lost');

    if v_club_id is not null and v_won_count > 0 then
      for v_pred in
        select prediction.id, prediction.user_id
        from football.predictions prediction
        where prediction.fixture_market_id = v_fm_id
          and prediction.status = 'won'
      loop
        perform football.award_prediction_fet(
          p_prediction_id := v_pred.id,
          p_user_id := v_pred.user_id,
          p_club_id := v_club_id,
          p_amount := v_fet_value,
          p_fixture_id := p_fixture_id,
          p_market_slug := v_market_slug
        );
      end loop;
    end if;

    insert into football.prediction_settlements (
      fixture_id,
      market_id,
      correct_outcome,
      predictions_won,
      predictions_lost,
      total_fet_awarded,
      settled_at,
      metadata
    )
    values (
      p_fixture_id,
      v_market_id,
      v_correct_outcome,
      v_won_count,
      v_lost_count,
      v_won_count * v_fet_value,
      now(),
      jsonb_build_object('club_id', v_club_id)
    )
    on conflict (fixture_id, market_id) do update
      set correct_outcome = excluded.correct_outcome,
          predictions_won = excluded.predictions_won,
          predictions_lost = excluded.predictions_lost,
          total_fet_awarded = excluded.total_fet_awarded,
          settled_at = excluded.settled_at,
          metadata = excluded.metadata;

    v_total_awarded := v_total_awarded + (v_won_count * v_fet_value);
    v_total_won := v_total_won + v_won_count;
    v_total_lost := v_total_lost + v_lost_count;
    v_markets_processed := v_markets_processed + 1;
  end loop;

  update football.prediction_slips slip
  set status = case
        when exists (
          select 1
          from football.predictions prediction
          where prediction.slip_id = slip.id
            and prediction.status = 'pending'
        ) then 'pending'
        when exists (
          select 1
          from football.predictions prediction
          where prediction.slip_id = slip.id
            and prediction.status = 'won'
        ) then 'won'
        when exists (
          select 1
          from football.predictions prediction
          where prediction.slip_id = slip.id
            and prediction.status = 'lost'
        ) then 'lost'
        else slip.status
      end,
      total_fet_earned = (
        select coalesce(sum(prediction.fet_earned), 0)
        from football.predictions prediction
        where prediction.slip_id = slip.id
      ),
      settled_at = case
        when exists (
          select 1
          from football.predictions prediction
          where prediction.slip_id = slip.id
            and prediction.status = 'pending'
        ) then null
        else now()
      end
  where slip.id in (
    select distinct prediction.slip_id
    from football.predictions prediction
    where prediction.fixture_id = p_fixture_id
      and prediction.slip_id is not null
  );

  perform public.prediction_settle_friend_challenges(p_fixture_id);

  return jsonb_build_object(
    'status', 'settled',
    'fixture_id', p_fixture_id,
    'markets_processed', v_markets_processed,
    'total_won', v_total_won,
    'total_lost', v_total_lost,
    'total_fet_awarded', v_total_awarded
  );
end;
$$;

grant execute on function public.prediction_settle_fixture(uuid, jsonb) to service_role;
