-- =============================================================================
-- Fantasy FET activity framework
-- Canonical fantasy earning catalog per club, with public read RPCs and an
-- idempotent award function that can be used by fantasy flows and jobs.
-- =============================================================================

create or replace function public.fantasy_fet_normalize_label(
  p_value text
) returns text
language sql
immutable
as $$
  select lower(regexp_replace(coalesce(p_value, ''), '[^a-z0-9]+', '', 'g'));
$$;

create or replace function public.fantasy_fet_competition_matches_label(
  p_label text,
  p_slug text,
  p_name text,
  p_short_name text
) returns boolean
language plpgsql
immutable
as $$
declare
  v_label text := public.fantasy_fet_normalize_label(p_label);
  v_slug text := public.fantasy_fet_normalize_label(p_slug);
  v_name text := public.fantasy_fet_normalize_label(p_name);
  v_short_name text := public.fantasy_fet_normalize_label(p_short_name);
begin
  if v_label = '' then
    return false;
  end if;

  if v_label in ('allcompetitions', 'allfantasycompetitions') then
    return true;
  end if;

  if position(v_label in v_slug) > 0
     or position(v_label in v_name) > 0
     or position(v_label in v_short_name) > 0 then
    return true;
  end if;

  case v_label
    when 'epl' then
      return position('premierleague' in v_slug) > 0
        or position('premierleague' in v_name) > 0
        or position('premierleague' in v_short_name) > 0;
    when 'worldcup' then
      return position('worldcup' in v_slug) > 0
        or position('worldcup' in v_name) > 0
        or position('worldcup' in v_short_name) > 0;
    when 'rwandapl' then
      return position('rwanda' in v_slug) > 0
        or position('rwanda' in v_name) > 0
        or position('rwanda' in v_short_name) > 0;
    when 'drclinafoot' then
      return position('linafoot' in v_slug) > 0
        or position('linafoot' in v_name) > 0
        or position('linafoot' in v_short_name) > 0
        or (
          (position('drc' in v_slug) > 0 or position('drc' in v_name) > 0)
          and position('league' in v_name) > 0
        );
    when 'zambiasl' then
      return (
        position('zambia' in v_slug) > 0
        or position('zambia' in v_name) > 0
        or position('zambia' in v_short_name) > 0
      ) and (
        position('superleague' in v_slug) > 0
        or position('superleague' in v_name) > 0
        or position('sl' in v_short_name) > 0
      );
    when 'afcon' then
      return position('afcon' in v_slug) > 0
        or position('afcon' in v_name) > 0
        or position('africacupofnations' in v_name) > 0
        or position('africacupofnations' in v_short_name) > 0;
    when 'cafchampionsleague' then
      return position('cafchampionsleague' in v_slug) > 0
        or position('cafchampionsleague' in v_name) > 0
        or (
          position('caf' in v_slug) > 0
          and position('champions' in v_slug) > 0
        )
        or (
          position('caf' in v_name) > 0
          and position('champions' in v_name) > 0
        );
    when 'caf' then
      return position('caf' in v_slug) > 0
        or position('caf' in v_name) > 0
        or position('caf' in v_short_name) > 0;
    else
      return false;
  end case;
end;
$$;

create table if not exists public.fantasy_fet_activities (
  id uuid primary key default gen_random_uuid(),
  club_id bigint not null references public.african_football_clubs(id) on delete cascade,
  code text not null,
  source_row_label text,
  activity_slug text not null,
  activity_name text not null,
  category text not null,
  fet_value integer,
  frequency_label text not null default 'Defined by club operations',
  applies_to_all_competitions boolean not null default true,
  applicable_competition_labels text[] not null default '{}'::text[],
  mapped_competition_ids uuid[] not null default '{}'::uuid[],
  applicability_summary text not null default 'All competitions',
  notes_conditions text,
  priority text not null default 'medium',
  is_active boolean not null default true,
  is_featured boolean not null default false,
  sort_order integer not null default 0,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint fantasy_fet_activities_code_key unique (club_id, code),
  constraint fantasy_fet_activities_slug_key unique (club_id, activity_slug),
  constraint fantasy_fet_activities_priority_check check (
    priority in ('high', 'medium', 'low')
  ),
  constraint fantasy_fet_activities_fet_value_check check (
    fet_value is null or fet_value >= 0
  )
);

create index if not exists idx_fantasy_fet_activities_club_sort
  on public.fantasy_fet_activities(club_id, is_active, sort_order);

create index if not exists idx_fantasy_fet_activities_category
  on public.fantasy_fet_activities(club_id, category);

drop trigger if exists fantasy_fet_activities_set_updated_at on public.fantasy_fet_activities;
create trigger fantasy_fet_activities_set_updated_at
before update on public.fantasy_fet_activities
for each row execute function public.set_updated_at();

create table if not exists public.fantasy_fet_activity_awards (
  id uuid primary key default gen_random_uuid(),
  club_id bigint not null references public.african_football_clubs(id) on delete cascade,
  activity_id uuid not null references public.fantasy_fet_activities(id) on delete cascade,
  competition_id uuid references fantasy.competitions(id) on delete set null,
  entry_id uuid references fantasy.fantasy_entries(id) on delete set null,
  user_id uuid not null,
  award_key text not null,
  quantity integer not null default 1,
  fet_value integer not null,
  total_fet_awarded integer not null,
  status text not null default 'awarded',
  context jsonb not null default '{}'::jsonb,
  awarded_at timestamptz not null default timezone('utc', now()),
  created_at timestamptz not null default timezone('utc', now()),
  constraint fantasy_fet_activity_awards_award_key_key unique (club_id, award_key),
  constraint fantasy_fet_activity_awards_quantity_check check (quantity > 0),
  constraint fantasy_fet_activity_awards_fet_value_check check (fet_value >= 0),
  constraint fantasy_fet_activity_awards_total_fet_awarded_check check (total_fet_awarded >= 0),
  constraint fantasy_fet_activity_awards_status_check check (
    status in ('awarded', 'reversed')
  )
);

create index if not exists idx_fantasy_fet_activity_awards_user
  on public.fantasy_fet_activity_awards(club_id, user_id, awarded_at desc);

create index if not exists idx_fantasy_fet_activity_awards_activity
  on public.fantasy_fet_activity_awards(activity_id, awarded_at desc);

alter table public.fantasy_fet_activities enable row level security;
alter table public.fantasy_fet_activity_awards enable row level security;

drop policy if exists fantasy_fet_activities_public_read on public.fantasy_fet_activities;
create policy fantasy_fet_activities_public_read
on public.fantasy_fet_activities
for select
using (
  is_active = true and (club_id)::text = public.requesting_club_id()
);

drop policy if exists fantasy_fet_activities_admin_all on public.fantasy_fet_activities;
create policy fantasy_fet_activities_admin_all
on public.fantasy_fet_activities
using (((club_id)::text = public.requesting_club_id()) and public.is_club_admin(club_id))
with check (((club_id)::text = public.requesting_club_id()) and public.is_club_admin(club_id));

drop policy if exists fantasy_fet_awards_owner_read on public.fantasy_fet_activity_awards;
create policy fantasy_fet_awards_owner_read
on public.fantasy_fet_activity_awards
for select
using (
  auth.uid() = user_id
  and (club_id)::text = public.requesting_club_id()
);

drop policy if exists fantasy_fet_awards_admin_read on public.fantasy_fet_activity_awards;
create policy fantasy_fet_awards_admin_read
on public.fantasy_fet_activity_awards
for select
using (public.is_admin_user());

create or replace function public.fantasy_fet_get_activities(
  p_club_id bigint default null::bigint,
  p_competition_slug text default null::text,
  p_include_inactive boolean default false
) returns table(
  id uuid,
  club_id bigint,
  code text,
  source_row_label text,
  activity_slug text,
  activity_name text,
  category text,
  fet_value integer,
  frequency_label text,
  applies_to_all_competitions boolean,
  applicable_competition_labels text[],
  mapped_competition_ids uuid[],
  applicability_summary text,
  notes_conditions text,
  priority text,
  is_active boolean,
  is_featured boolean,
  sort_order integer
)
language plpgsql
stable
security definer
set search_path to 'public'
as $$
declare
  v_club_id bigint;
  v_competition_id uuid;
  v_competition_slug text;
  v_competition_name text;
  v_competition_short_name text;
begin
  v_club_id := public.fet_resolve_public_club_id(p_club_id);
  if v_club_id is null then
    return;
  end if;

  if nullif(btrim(coalesce(p_competition_slug, '')), '') is not null then
    select
      competition.id,
      competition.slug,
      competition.name,
      competition.short_name
    into
      v_competition_id,
      v_competition_slug,
      v_competition_name,
      v_competition_short_name
    from public.fantasy_competitions competition
    where lower(competition.slug) = lower(p_competition_slug)
    limit 1;
  end if;

  return query
  select
    activity.id,
    activity.club_id,
    activity.code,
    activity.source_row_label,
    activity.activity_slug,
    activity.activity_name,
    activity.category,
    activity.fet_value,
    activity.frequency_label,
    activity.applies_to_all_competitions,
    activity.applicable_competition_labels,
    activity.mapped_competition_ids,
    activity.applicability_summary,
    activity.notes_conditions,
    activity.priority,
    activity.is_active,
    activity.is_featured,
    activity.sort_order
  from public.fantasy_fet_activities activity
  where activity.club_id = v_club_id
    and (p_include_inactive or activity.is_active = true)
    and (
      v_competition_id is null
      or activity.applies_to_all_competitions = true
      or v_competition_id = any(activity.mapped_competition_ids)
      or exists (
        select 1
        from unnest(activity.applicable_competition_labels) as label(value)
        where public.fantasy_fet_competition_matches_label(
          label.value,
          v_competition_slug,
          v_competition_name,
          v_competition_short_name
        )
      )
    )
  order by activity.is_featured desc, activity.sort_order asc, activity.code asc;
end;
$$;

create or replace function public.fantasy_fet_get_summary(
  p_club_id bigint default null::bigint,
  p_competition_slug text default null::text
) returns table(
  total_activities integer,
  active_activities integer,
  featured_activities integer,
  missing_fet_count integer,
  high_priority_count integer,
  category_count integer,
  total_defined_fet integer
)
language sql
stable
security definer
set search_path to 'public'
as $$
  with filtered as (
    select *
    from public.fantasy_fet_get_activities(
      p_club_id => p_club_id,
      p_competition_slug => p_competition_slug,
      p_include_inactive => true
    )
  )
  select
    count(*)::integer as total_activities,
    count(*) filter (where is_active = true)::integer as active_activities,
    count(*) filter (where is_featured = true)::integer as featured_activities,
    count(*) filter (where fet_value is null)::integer as missing_fet_count,
    count(*) filter (where priority = 'high')::integer as high_priority_count,
    count(distinct category)::integer as category_count,
    coalesce(sum(fet_value), 0)::integer as total_defined_fet
  from filtered;
$$;

create or replace function public.fantasy_fet_get_my_activity_log(
  p_club_id bigint default null::bigint,
  p_limit integer default 12
) returns table(
  id uuid,
  club_id bigint,
  activity_id uuid,
  activity_code text,
  activity_name text,
  competition_id uuid,
  entry_id uuid,
  award_key text,
  quantity integer,
  fet_value integer,
  total_fet_awarded integer,
  status text,
  context jsonb,
  awarded_at timestamptz
)
language plpgsql
stable
security definer
set search_path to 'public'
as $$
declare
  v_club_id bigint;
begin
  v_club_id := public.fet_resolve_public_club_id(p_club_id);
  if v_club_id is null or auth.uid() is null then
    return;
  end if;

  return query
  select
    award.id,
    award.club_id,
    award.activity_id,
    activity.code,
    activity.activity_name,
    award.competition_id,
    award.entry_id,
    award.award_key,
    award.quantity,
    award.fet_value,
    award.total_fet_awarded,
    award.status,
    award.context,
    award.awarded_at
  from public.fantasy_fet_activity_awards award
  join public.fantasy_fet_activities activity
    on activity.id = award.activity_id
  where award.club_id = v_club_id
    and award.user_id = auth.uid()
  order by award.awarded_at desc
  limit greatest(coalesce(p_limit, 12), 1);
end;
$$;

create or replace function public.fantasy_fet_award_activity(
  p_activity_code text,
  p_award_key text,
  p_club_id bigint default null::bigint,
  p_competition_slug text default null::text,
  p_entry_id uuid default null::uuid,
  p_quantity integer default 1,
  p_user_id uuid default null::uuid,
  p_context jsonb default '{}'::jsonb
) returns table(
  id uuid,
  club_id bigint,
  activity_id uuid,
  activity_code text,
  activity_name text,
  awarded_fet integer,
  total_membership_points integer,
  award_key text,
  was_existing boolean
)
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_club_id bigint;
  v_user_id uuid := coalesce(p_user_id, auth.uid());
  v_quantity integer := greatest(coalesce(p_quantity, 1), 1);
  v_activity public.fantasy_fet_activities%rowtype;
  v_award public.fantasy_fet_activity_awards%rowtype;
  v_competition_id uuid;
  v_membership public.fan_memberships;
  v_was_existing boolean := false;
begin
  if nullif(btrim(coalesce(p_activity_code, '')), '') is null then
    raise exception 'Activity code is required.';
  end if;

  if nullif(btrim(coalesce(p_award_key, '')), '') is null then
    raise exception 'award_key is required for idempotent fantasy FET awards.';
  end if;

  if v_user_id is null then
    raise exception 'Authenticated user context is required.';
  end if;

  v_club_id := public.fet_resolve_public_club_id(p_club_id);
  if v_club_id is null then
    raise exception 'Club context is required for fantasy FET awards.';
  end if;

  if p_competition_slug is not null then
    select id
      into v_competition_id
    from public.fantasy_competitions
    where lower(slug) = lower(p_competition_slug)
    limit 1;
  end if;

  if p_entry_id is not null then
    if not exists (
      select 1
      from fantasy.fantasy_entries entry_row
      where entry_row.id = p_entry_id
        and entry_row.user_id = v_user_id
        and (v_competition_id is null or entry_row.competition_id = v_competition_id)
    ) then
      raise exception 'Fantasy entry is not available for this user.';
    end if;
  end if;

  select *
    into v_activity
  from public.fantasy_fet_activities activity
  where activity.club_id = v_club_id
    and upper(activity.code) = upper(p_activity_code)
    and activity.is_active = true
    and (
      v_competition_id is null
      or activity.applies_to_all_competitions = true
      or v_competition_id = any(activity.mapped_competition_ids)
      or exists (
        select 1
        from public.fantasy_competitions competition,
             unnest(activity.applicable_competition_labels) as label(value)
        where competition.id = v_competition_id
          and public.fantasy_fet_competition_matches_label(
            label.value,
            competition.slug,
            competition.name,
            competition.short_name
          )
      )
    )
  limit 1;

  if v_activity.id is null then
    raise exception 'Fantasy activity % is not configured for this club scope.', p_activity_code;
  end if;

  if v_activity.fet_value is null then
    raise exception 'Fantasy activity % does not have an FET value yet.', v_activity.code;
  end if;

  insert into public.fantasy_fet_activity_awards (
    club_id,
    activity_id,
    competition_id,
    entry_id,
    user_id,
    award_key,
    quantity,
    fet_value,
    total_fet_awarded,
    context
  )
  values (
    v_club_id,
    v_activity.id,
    v_competition_id,
    p_entry_id,
    v_user_id,
    p_award_key,
    v_quantity,
    v_activity.fet_value,
    v_activity.fet_value * v_quantity,
    coalesce(p_context, '{}'::jsonb)
  )
  on conflict (club_id, award_key) do nothing
  returning *
  into v_award;

  if v_award.id is null then
    v_was_existing := true;

    select *
      into v_award
    from public.fantasy_fet_activity_awards award
    where award.club_id = v_club_id
      and award.award_key = p_award_key
    limit 1;
  else
    v_membership := public.add_fan_points(
      v_user_id,
      v_club_id::text,
      v_award.total_fet_awarded,
      'fantasy_activity:' || lower(v_activity.code)
    );
  end if;

  return query
  select
    v_award.id,
    v_award.club_id,
    v_award.activity_id,
    v_activity.code,
    v_activity.activity_name,
    v_award.total_fet_awarded,
    case
      when v_membership.id is not null then coalesce(v_membership.points, 0)
      else (
        select coalesce(points, 0)
        from public.fan_memberships membership
        where membership.user_id = v_user_id
          and membership.club_id = v_club_id
        limit 1
      )
    end,
    v_award.award_key,
    v_was_existing;
end;
$$;

grant execute on function public.fantasy_fet_get_activities(bigint, text, boolean) to anon;
grant execute on function public.fantasy_fet_get_activities(bigint, text, boolean) to authenticated;
grant execute on function public.fantasy_fet_get_activities(bigint, text, boolean) to service_role;

grant execute on function public.fantasy_fet_get_summary(bigint, text) to anon;
grant execute on function public.fantasy_fet_get_summary(bigint, text) to authenticated;
grant execute on function public.fantasy_fet_get_summary(bigint, text) to service_role;

grant execute on function public.fantasy_fet_get_my_activity_log(bigint, integer) to authenticated;
grant execute on function public.fantasy_fet_get_my_activity_log(bigint, integer) to service_role;

grant execute on function public.fantasy_fet_award_activity(text, text, bigint, text, uuid, integer, uuid, jsonb) to authenticated;
grant execute on function public.fantasy_fet_award_activity(text, text, bigint, text, uuid, integer, uuid, jsonb) to service_role;

do $fantasy_fet_seed$
declare
  v_seed jsonb := $$[{"sort_order": 10, "code": "FFA001", "source_row_label": "1", "activity_slug": "complete-account-registration", "activity_name": "Complete account registration", "category": "Onboarding", "fet_value": 50, "frequency_label": "Once", "applies_to_all_competitions": true, "applicable_competition_labels": [], "applicability_summary": "All competitions", "notes_conditions": "phone verified signup", "priority": "high", "is_active": true, "is_featured": true}, {"sort_order": 20, "code": "FFA002", "source_row_label": "2", "activity_slug": "verify-phone-number-otp", "activity_name": "Verify phone number (OTP)", "category": "Onboarding", "fet_value": 50, "frequency_label": "Once", "applies_to_all_competitions": true, "applicable_competition_labels": [], "applicability_summary": "All competitions", "notes_conditions": "Required for token withdrawals", "priority": "high", "is_active": true, "is_featured": true}, {"sort_order": 30, "code": "FFA003", "source_row_label": "4", "activity_slug": "link-twitter-x-account", "activity_name": "Link Twitter/X account", "category": "Onboarding", "fet_value": 50, "frequency_label": "Once per platform", "applies_to_all_competitions": true, "applicable_competition_labels": [], "applicability_summary": "All competitions", "notes_conditions": "One-time per social platform (max 3 platforms)", "priority": "medium", "is_active": true, "is_featured": false}, {"sort_order": 40, "code": "FFA004", "source_row_label": "5", "activity_slug": "link-facebook-account", "activity_name": "Link Facebook account", "category": "Onboarding", "fet_value": 50, "frequency_label": "Once", "applies_to_all_competitions": true, "applicable_competition_labels": [], "applicability_summary": "All competitions", "notes_conditions": "One-time bonus", "priority": "medium", "is_active": true, "is_featured": false}, {"sort_order": 50, "code": "FFA005", "source_row_label": "6", "activity_slug": "link-instagram-account", "activity_name": "Link Instagram account", "category": "Onboarding", "fet_value": 50, "frequency_label": "Once", "applies_to_all_competitions": true, "applicable_competition_labels": [], "applicability_summary": "All competitions", "notes_conditions": "One-time bonus", "priority": "medium", "is_active": true, "is_featured": false}, {"sort_order": 60, "code": "FFA006", "source_row_label": "8", "activity_slug": "select-favourite-team-s", "activity_name": "Select favourite team(s)", "category": "Onboarding", "fet_value": 50, "frequency_label": "Once", "applies_to_all_competitions": true, "applicable_competition_labels": [], "applicability_summary": "All competitions", "notes_conditions": "Personalises match recommendations", "priority": "low", "is_active": true, "is_featured": false}, {"sort_order": 70, "code": "FFA007", "source_row_label": "9", "activity_slug": "select-favourite-competitions", "activity_name": "Select favourite competitions", "category": "Onboarding", "fet_value": 50, "frequency_label": "Once", "applies_to_all_competitions": true, "applicable_competition_labels": [], "applicability_summary": "All competitions", "notes_conditions": "EPL, World Cup, Rwanda PL, DRC, Zambia, etc.", "priority": "low", "is_active": true, "is_featured": false}, {"sort_order": 80, "code": "FFA008", "source_row_label": "10", "activity_slug": "create-first-fantasy-team", "activity_name": "Create first fantasy team", "category": "Onboarding", "fet_value": 100, "frequency_label": "Once per competition", "applies_to_all_competitions": true, "applicable_competition_labels": [], "applicability_summary": "All competitions", "notes_conditions": "Separate bonus per competition joined", "priority": "high", "is_active": true, "is_featured": true}, {"sort_order": 90, "code": "FFA009", "source_row_label": "11", "activity_slug": "refer-a-friend-referral-code-used", "activity_name": "Refer a friend (referral code used)", "category": "Onboarding", "fet_value": 100, "frequency_label": "Per referral — no cap", "applies_to_all_competitions": true, "applicable_competition_labels": [], "applicability_summary": "All competitions", "notes_conditions": "Both referrer AND referee earn 100 FET each", "priority": "high", "is_active": true, "is_featured": true}, {"sort_order": 100, "code": "FFA010", "source_row_label": "13", "activity_slug": "build-submit-a-fantasy-team-gameweek", "activity_name": "Build & submit a fantasy team (gameweek)", "category": "Fantasy Team", "fet_value": 100, "frequency_label": "Per gameweek", "applies_to_all_competitions": false, "applicable_competition_labels": ["EPL", "World Cup", "Rwanda PL", "DRC Linafoot", "Zambia SL", "AFCON", "CAF"], "applicability_summary": "EPL · World Cup · Rwanda PL · DRC Linafoot · Zambia SL · AFCON · CAF", "notes_conditions": "Must be submitted before gameweek deadline", "priority": "high", "is_active": true, "is_featured": true}, {"sort_order": 110, "code": "FFA011", "source_row_label": "14", "activity_slug": "make-a-valid-free-player-transfer", "activity_name": "Make a valid free player transfer", "category": "Fantasy Team", "fet_value": 100, "frequency_label": "Per transfer (max 3/GW)", "applies_to_all_competitions": false, "applicable_competition_labels": ["EPL", "World Cup", "AFCON"], "applicability_summary": "EPL · World Cup · AFCON", "notes_conditions": "Free transfers only; penalty transfers excluded", "priority": "medium", "is_active": true, "is_featured": false}, {"sort_order": 120, "code": "FFA012", "source_row_label": "15", "activity_slug": "use-captain-vice-captain-feature", "activity_name": "Use captain / vice-captain feature", "category": "Fantasy Team", "fet_value": 50, "frequency_label": "Per gameweek", "applies_to_all_competitions": true, "applicable_competition_labels": [], "applicability_summary": "All fantasy competitions", "notes_conditions": "Must designate before deadline", "priority": "medium", "is_active": true, "is_featured": false}, {"sort_order": 130, "code": "FFA013", "source_row_label": "16", "activity_slug": "your-player-scores-a-goal", "activity_name": "Your player scores a goal", "category": "Fantasy Team", "fet_value": 100, "frequency_label": "Per goal", "applies_to_all_competitions": true, "applicable_competition_labels": [], "applicability_summary": "All competitions", "notes_conditions": "Real-match data powered scoring", "priority": "high", "is_active": true, "is_featured": true}, {"sort_order": 140, "code": "FFA014", "source_row_label": "17", "activity_slug": "your-player-gets-an-assist", "activity_name": "Your player gets an assist", "category": "Fantasy Team", "fet_value": 50, "frequency_label": "Per assist", "applies_to_all_competitions": true, "applicable_competition_labels": [], "applicability_summary": "All competitions", "notes_conditions": null, "priority": "high", "is_active": true, "is_featured": true}, {"sort_order": 150, "code": "FFA015", "source_row_label": "18", "activity_slug": "your-goalkeeper-defender-keeps-a-clean-sheet", "activity_name": "Your goalkeeper/defender keeps a clean sheet", "category": "Fantasy Team", "fet_value": 50, "frequency_label": "Per clean sheet", "applies_to_all_competitions": true, "applicable_competition_labels": [], "applicability_summary": "All competitions", "notes_conditions": "Player must play 60+ minutes", "priority": "high", "is_active": true, "is_featured": true}, {"sort_order": 160, "code": "FFA016", "source_row_label": "19", "activity_slug": "your-goalkeeper-saves-a-penalty", "activity_name": "Your goalkeeper saves a penalty", "category": "Fantasy Team", "fet_value": 50, "frequency_label": "Per event", "applies_to_all_competitions": true, "applicable_competition_labels": [], "applicability_summary": "All competitions", "notes_conditions": "High-value bonus event", "priority": "medium", "is_active": true, "is_featured": false}, {"sort_order": 170, "code": "FFA017", "source_row_label": "26", "activity_slug": "your-player-wins-player-of-the-match", "activity_name": "Your player wins Player of the Match", "category": "Fantasy Team", "fet_value": 100, "frequency_label": "Per occurrence", "applies_to_all_competitions": true, "applicable_competition_labels": [], "applicability_summary": "All competitions", "notes_conditions": "Powered by official match data feed", "priority": "medium", "is_active": true, "is_featured": false}, {"sort_order": 180, "code": "FFA018", "source_row_label": "27", "activity_slug": "your-player-scores-a-hat-trick", "activity_name": "Your player scores a hat-trick", "category": "Fantasy Team", "fet_value": 500, "frequency_label": "Per occurrence", "applies_to_all_competitions": true, "applicable_competition_labels": [], "applicability_summary": "All competitions", "notes_conditions": "Ultra-rare event bonus", "priority": "low", "is_active": true, "is_featured": true}, {"sort_order": 190, "code": "FFA019", "source_row_label": "31", "activity_slug": "season-long-finish-top-1-000-overall-ranking", "activity_name": "Season-long: finish top 1,000 overall ranking", "category": "Fantasy Team", "fet_value": 500, "frequency_label": "Per season", "applies_to_all_competitions": false, "applicable_competition_labels": ["EPL", "World Cup"], "applicability_summary": "EPL · World Cup", "notes_conditions": "Premium seasonal achievement", "priority": "high", "is_active": true, "is_featured": true}, {"sort_order": 200, "code": "FFA020", "source_row_label": "32", "activity_slug": "season-long-finish-top-10-000-overall-ranking", "activity_name": "Season-long: finish top 10,000 overall ranking", "category": "Fantasy Team", "fet_value": 200, "frequency_label": "Per season", "applies_to_all_competitions": false, "applicable_competition_labels": ["EPL", "World Cup"], "applicability_summary": "EPL · World Cup", "notes_conditions": null, "priority": "high", "is_active": true, "is_featured": true}, {"sort_order": 210, "code": "FFA021", "source_row_label": "33", "activity_slug": "season-long-finish-top-100-000-overall-ranking", "activity_name": "Season-long: finish top 100,000 overall ranking", "category": "Fantasy Team", "fet_value": 75, "frequency_label": "Per season", "applies_to_all_competitions": false, "applicable_competition_labels": ["EPL", "World Cup"], "applicability_summary": "EPL · World Cup", "notes_conditions": null, "priority": "medium", "is_active": true, "is_featured": false}, {"sort_order": 220, "code": "FFA022", "source_row_label": "34", "activity_slug": "predict-correct-match-score-exact-scoreline", "activity_name": "Predict correct match score (exact scoreline)", "category": "Predictions", "fet_value": 500, "frequency_label": "Per match predicted", "applies_to_all_competitions": true, "applicable_competition_labels": [], "applicability_summary": "All competitions", "notes_conditions": "Highest-value prediction activity", "priority": "high", "is_active": true, "is_featured": true}, {"sort_order": 230, "code": "FFA023", "source_row_label": "35", "activity_slug": "predict-correct-match-result-win-draw-loss", "activity_name": "Predict correct match result (Win / Draw / Loss)", "category": "Predictions", "fet_value": 100, "frequency_label": "Per match", "applies_to_all_competitions": true, "applicable_competition_labels": [], "applicability_summary": "All competitions", "notes_conditions": "Most accessible prediction for casual fans", "priority": "high", "is_active": true, "is_featured": true}, {"sort_order": 240, "code": "FFA024", "source_row_label": "36", "activity_slug": "predict-first-goalscorer-correctly", "activity_name": "Predict first goalscorer correctly", "category": "Predictions", "fet_value": 100, "frequency_label": "Per match", "applies_to_all_competitions": true, "applicable_competition_labels": [], "applicability_summary": "All competitions", "notes_conditions": "Anytime scorer prediction = 15 FET", "priority": "high", "is_active": true, "is_featured": true}, {"sort_order": 250, "code": "FFA025", "source_row_label": "37", "activity_slug": "predict-man-of-the-match-correctly", "activity_name": "Predict Man of the Match correctly", "category": "Predictions", "fet_value": 200, "frequency_label": "Per match", "applies_to_all_competitions": true, "applicable_competition_labels": [], "applicability_summary": "All competitions", "notes_conditions": null, "priority": "medium", "is_active": true, "is_featured": true}, {"sort_order": 260, "code": "FFA026", "source_row_label": "38", "activity_slug": "predict-correct-total-goals-over-under", "activity_name": "Predict correct total goals (over/under)", "category": "Predictions", "fet_value": 100, "frequency_label": "Per match", "applies_to_all_competitions": true, "applicable_competition_labels": [], "applicability_summary": "All competitions", "notes_conditions": "Over/Under style prediction", "priority": "medium", "is_active": true, "is_featured": false}, {"sort_order": 270, "code": "FFA027", "source_row_label": "39", "activity_slug": "predict-both-teams-to-score-btts-correctly", "activity_name": "Predict Both Teams to Score (BTTS) correctly", "category": "Predictions", "fet_value": 100, "frequency_label": "Per match", "applies_to_all_competitions": true, "applicable_competition_labels": [], "applicability_summary": "All competitions", "notes_conditions": null, "priority": "medium", "is_active": true, "is_featured": false}, {"sort_order": 280, "code": "FFA028", "source_row_label": "40", "activity_slug": "predict-correct-half-time-result", "activity_name": "Predict correct half-time result", "category": "Predictions", "fet_value": 100, "frequency_label": "Per match", "applies_to_all_competitions": true, "applicable_competition_labels": [], "applicability_summary": "All competitions", "notes_conditions": null, "priority": "medium", "is_active": true, "is_featured": false}, {"sort_order": 290, "code": "FFA029", "source_row_label": "41", "activity_slug": "predict-correct-number-of-yellow-cards", "activity_name": "Predict correct number of yellow cards", "category": "Predictions", "fet_value": 100, "frequency_label": "Per match", "applies_to_all_competitions": true, "applicable_competition_labels": [], "applicability_summary": "All competitions", "notes_conditions": null, "priority": "low", "is_active": true, "is_featured": false}, {"sort_order": 300, "code": "FFA030", "source_row_label": "42", "activity_slug": "predict-tournament-winner-pre-tournament", "activity_name": "Predict tournament winner (pre-tournament)", "category": "Predictions", "fet_value": 10000, "frequency_label": "Per tournament", "applies_to_all_competitions": false, "applicable_competition_labels": ["World Cup", "AFCON", "CAF Champions League"], "applicability_summary": "World Cup · AFCON · CAF Champions League", "notes_conditions": "Pre-tournament submission only", "priority": "high", "is_active": true, "is_featured": true}, {"sort_order": 310, "code": "FFA031", "source_row_label": "43", "activity_slug": "predict-season-top-scorer-pre-season", "activity_name": "Predict season top scorer (pre-season)", "category": "Predictions", "fet_value": 5000, "frequency_label": "Per season", "applies_to_all_competitions": false, "applicable_competition_labels": ["EPL", "Rwanda PL", "Zambia SL"], "applicability_summary": "EPL · Rwanda PL · Zambia SL", "notes_conditions": "Pre-season submission only", "priority": "high", "is_active": true, "is_featured": true}, {"sort_order": 320, "code": "FFA032", "source_row_label": "44", "activity_slug": "prediction-streak-5-correct-in-a-row", "activity_name": "Prediction streak — 5 correct in a row", "category": "Predictions", "fet_value": 500, "frequency_label": "Per streak milestone", "applies_to_all_competitions": true, "applicable_competition_labels": [], "applicability_summary": "All competitions", "notes_conditions": "Streak bonuses cascade with streak length", "priority": "high", "is_active": true, "is_featured": true}, {"sort_order": 330, "code": "FFA033", "source_row_label": "45", "activity_slug": "prediction-streak-10-correct-in-a-row", "activity_name": "Prediction streak — 10 correct in a row", "category": "Predictions", "fet_value": 1000, "frequency_label": "Per streak milestone", "applies_to_all_competitions": true, "applicable_competition_labels": [], "applicability_summary": "All competitions", "notes_conditions": null, "priority": "high", "is_active": true, "is_featured": true}, {"sort_order": 340, "code": "FFA034", "source_row_label": "46", "activity_slug": "weekly-prediction-leaderboard-1st-place", "activity_name": "Weekly prediction leaderboard — 1st place", "category": "Predictions", "fet_value": 150, "frequency_label": "Weekly", "applies_to_all_competitions": true, "applicable_competition_labels": [], "applicability_summary": "All competitions", "notes_conditions": "Weekly platform-wide prediction contest", "priority": "high", "is_active": true, "is_featured": true}, {"sort_order": 350, "code": "FFA035", "source_row_label": "47", "activity_slug": "weekly-prediction-leaderboard-2nd-place", "activity_name": "Weekly prediction leaderboard — 2nd place", "category": "Predictions", "fet_value": 100, "frequency_label": "Weekly", "applies_to_all_competitions": true, "applicable_competition_labels": [], "applicability_summary": "All competitions", "notes_conditions": null, "priority": "high", "is_active": true, "is_featured": true}, {"sort_order": 360, "code": "FFA036", "source_row_label": "48", "activity_slug": "weekly-prediction-leaderboard-3rd-place", "activity_name": "Weekly prediction leaderboard — 3rd place", "category": "Predictions", "fet_value": 500, "frequency_label": "Weekly", "applies_to_all_competitions": true, "applicable_competition_labels": [], "applicability_summary": "All competitions", "notes_conditions": null, "priority": "medium", "is_active": true, "is_featured": true}, {"sort_order": 370, "code": "FFA037", "source_row_label": "49", "activity_slug": "complete-a-full-matchday-prediction-card-all-matches", "activity_name": "Complete a full matchday prediction card (all matches)", "category": "Predictions", "fet_value": 100, "frequency_label": "Per matchday", "applies_to_all_competitions": true, "applicable_competition_labels": [], "applicability_summary": "All competitions", "notes_conditions": "All matches in a matchday predicted", "priority": "medium", "is_active": true, "is_featured": false}, {"sort_order": 380, "code": "FFA038", "source_row_label": "50", "activity_slug": "share-your-fantasy-team-on-twitter-x", "activity_name": "Share your fantasy team on Twitter/X", "category": "Social", "fet_value": 50, "frequency_label": "Once per gameweek", "applies_to_all_competitions": true, "applicable_competition_labels": [], "applicability_summary": "All competitions", "notes_conditions": "Verified via platform API integration", "priority": "medium", "is_active": true, "is_featured": false}, {"sort_order": 390, "code": "FFA039", "source_row_label": "51", "activity_slug": "share-your-fantasy-team-on-facebook", "activity_name": "Share your fantasy team on Facebook", "category": "Social", "fet_value": 50, "frequency_label": "Once per gameweek", "applies_to_all_competitions": true, "applicable_competition_labels": [], "applicability_summary": "All competitions", "notes_conditions": "Verified via platform API integration", "priority": "medium", "is_active": true, "is_featured": false}, {"sort_order": 400, "code": "FFA040", "source_row_label": "52", "activity_slug": "share-a-match-prediction-on-social-media", "activity_name": "Share a match prediction on social media", "category": "Social", "fet_value": 50, "frequency_label": "Once per match", "applies_to_all_competitions": true, "applicable_competition_labels": [], "applicability_summary": "All competitions", "notes_conditions": null, "priority": "medium", "is_active": true, "is_featured": false}, {"sort_order": 410, "code": "FFA041", "source_row_label": "53", "activity_slug": "share-app-invite-link", "activity_name": "Share app invite link", "category": "Social", "fet_value": 100, "frequency_label": "Max 3x per week", "applies_to_all_competitions": true, "applicable_competition_labels": [], "applicability_summary": "All competitions", "notes_conditions": "Unique tracked referral link", "priority": "high", "is_active": true, "is_featured": true}, {"sort_order": 420, "code": "FFA042", "source_row_label": "54", "activity_slug": "post-a-match-highlight-or-reaction-in-app", "activity_name": "Post a match highlight or reaction in-app", "category": "Social", "fet_value": null, "frequency_label": "Once per match", "applies_to_all_competitions": true, "applicable_competition_labels": [], "applicability_summary": "All competitions", "notes_conditions": "In-app social post", "priority": "low", "is_active": true, "is_featured": false}, {"sort_order": 430, "code": "FFA043", "source_row_label": "55", "activity_slug": "earn-10-likes-on-a-community-post", "activity_name": "Earn 10 likes on a community post", "category": "Social", "fet_value": 100, "frequency_label": "Per milestone", "applies_to_all_competitions": true, "applicable_competition_labels": [], "applicability_summary": "All competitions", "notes_conditions": "Quality content reward", "priority": "medium", "is_active": true, "is_featured": false}, {"sort_order": 440, "code": "FFA044", "source_row_label": "56", "activity_slug": "write-a-match-review-post-match-analysis", "activity_name": "Write a match review / post-match analysis", "category": "Social", "fet_value": null, "frequency_label": "Once per match", "applies_to_all_competitions": true, "applicable_competition_labels": [], "applicability_summary": "All competitions", "notes_conditions": "Minimum 50 words required", "priority": "medium", "is_active": true, "is_featured": false}, {"sort_order": 450, "code": "FFA045", "source_row_label": "57", "activity_slug": "follow-official-league-page-in-app", "activity_name": "Follow official league page in-app", "category": "Social", "fet_value": 50, "frequency_label": "Per league (max 5)", "applies_to_all_competitions": true, "applicable_competition_labels": [], "applicability_summary": "All competitions", "notes_conditions": "EPL, Rwanda PL, DRC, Zambia, CAF pages", "priority": "low", "is_active": true, "is_featured": false}, {"sort_order": 460, "code": "FFA046", "source_row_label": "60", "activity_slug": "participate-in-live-in-match-poll", "activity_name": "Participate in live in-match poll", "category": "Live Engagement", "fet_value": 50, "frequency_label": "Per poll", "applies_to_all_competitions": true, "applicable_competition_labels": [], "applicability_summary": "All competitions", "notes_conditions": "e.g. Who will score next?", "priority": "medium", "is_active": true, "is_featured": false}, {"sort_order": 470, "code": "FFA047", "source_row_label": "61", "activity_slug": "rate-a-player-s-performance-post-match", "activity_name": "Rate a player's performance post-match", "category": "Live Engagement", "fet_value": 50, "frequency_label": "Per match", "applies_to_all_competitions": true, "applicable_competition_labels": [], "applicability_summary": "All competitions", "notes_conditions": "Fan ratings / player of the match voting", "priority": "low", "is_active": true, "is_featured": false}, {"sort_order": 480, "code": "FFA048", "source_row_label": "62", "activity_slug": "complete-weekly-football-knowledge-quiz", "activity_name": "Complete weekly football knowledge quiz", "category": "Live Engagement", "fet_value": 50, "frequency_label": "Weekly", "applies_to_all_competitions": true, "applicable_competition_labels": [], "applicability_summary": "All competitions", "notes_conditions": "10-question quiz on any football topic", "priority": "high", "is_active": true, "is_featured": true}, {"sort_order": 490, "code": "FFA049", "source_row_label": "63", "activity_slug": "answer-daily-trivia-question-correctly", "activity_name": "Answer daily trivia question correctly", "category": "Live Engagement", "fet_value": 50, "frequency_label": "Daily", "applies_to_all_competitions": true, "applicable_competition_labels": [], "applicability_summary": "All competitions", "notes_conditions": "1 attempt per day only", "priority": "high", "is_active": true, "is_featured": true}, {"sort_order": 500, "code": "FFA050", "source_row_label": "67", "activity_slug": "create-a-public-mini-league", "activity_name": "Create a public mini-league", "category": "Community", "fet_value": 100, "frequency_label": "Per league created", "applies_to_all_competitions": true, "applicable_competition_labels": [], "applicability_summary": "All competitions", "notes_conditions": "Minimum 5 members must join to qualify", "priority": "high", "is_active": true, "is_featured": true}, {"sort_order": 510, "code": "FFA051", "source_row_label": "68", "activity_slug": "invite-a-friend-who-joins-your-mini-league", "activity_name": "Invite a friend who joins your mini-league", "category": "Community", "fet_value": null, "frequency_label": "Per friend who joins", "applies_to_all_competitions": true, "applicable_competition_labels": [], "applicability_summary": "All competitions", "notes_conditions": null, "priority": "high", "is_active": true, "is_featured": true}, {"sort_order": 520, "code": "FFA052", "source_row_label": "69", "activity_slug": "mini-league-reaches-20-members", "activity_name": "Mini-league reaches 20 members", "category": "Community", "fet_value": 50, "frequency_label": "Once per league", "applies_to_all_competitions": true, "applicable_competition_labels": [], "applicability_summary": "All competitions", "notes_conditions": "Community milestone achievement", "priority": "medium", "is_active": true, "is_featured": false}, {"sort_order": 530, "code": "FFA053", "source_row_label": "70", "activity_slug": "win-your-mini-league-end-of-season", "activity_name": "Win your mini-league (end of season)", "category": "Community", "fet_value": 1000, "frequency_label": "Per season", "applies_to_all_competitions": true, "applicable_competition_labels": [], "applicability_summary": "All competitions", "notes_conditions": "Winner of each active mini-league", "priority": "high", "is_active": true, "is_featured": true}, {"sort_order": 540, "code": "FFA054", "source_row_label": "72", "activity_slug": "get-featured-as-fan-of-the-week", "activity_name": "Get featured as Fan of the Week", "category": "Community", "fet_value": 100, "frequency_label": "Weekly", "applies_to_all_competitions": true, "applicable_competition_labels": [], "applicability_summary": "All competitions", "notes_conditions": "Voted or selected by editorial team", "priority": "medium", "is_active": true, "is_featured": false}, {"sort_order": 550, "code": "FFA055", "source_row_label": "73", "activity_slug": "7-day-consecutive-login-streak", "activity_name": "7-day consecutive login streak", "category": "Loyalty & Streaks", "fet_value": null, "frequency_label": "Per 7-day milestone", "applies_to_all_competitions": true, "applicable_competition_labels": [], "applicability_summary": "All competitions", "notes_conditions": "Resets if a day is missed", "priority": "high", "is_active": true, "is_featured": true}, {"sort_order": 560, "code": "FFA056", "source_row_label": "74", "activity_slug": "30-day-consecutive-login-streak", "activity_name": "30-day consecutive login streak", "category": "Loyalty & Streaks", "fet_value": null, "frequency_label": "Per 30-day milestone", "applies_to_all_competitions": true, "applicable_competition_labels": [], "applicability_summary": "All competitions", "notes_conditions": null, "priority": "high", "is_active": true, "is_featured": true}, {"sort_order": 570, "code": "FFA057", "source_row_label": "75", "activity_slug": "submit-team-every-gameweek-in-a-full-season", "activity_name": "Submit team every gameweek in a full season", "category": "Loyalty & Streaks", "fet_value": 100, "frequency_label": "Per season", "applies_to_all_competitions": true, "applicable_competition_labels": [], "applicability_summary": "All competitions", "notes_conditions": "Perfect attendance bonus", "priority": "high", "is_active": true, "is_featured": true}, {"sort_order": 580, "code": "FFA058", "source_row_label": "76", "activity_slug": "reach-silver-tier-1-000-fet-earned-lifetime", "activity_name": "Reach Silver tier (1,000 FET earned lifetime)", "category": "Loyalty & Streaks", "fet_value": 100, "frequency_label": "Once", "applies_to_all_competitions": true, "applicable_competition_labels": [], "applicability_summary": "All competitions", "notes_conditions": "Lifetime earnings threshold", "priority": "high", "is_active": true, "is_featured": true}, {"sort_order": 590, "code": "FFA059", "source_row_label": "77", "activity_slug": "reach-gold-tier-5-000-fet-earned-lifetime", "activity_name": "Reach Gold tier (5,000 FET earned lifetime)", "category": "Loyalty & Streaks", "fet_value": 200, "frequency_label": "Once", "applies_to_all_competitions": true, "applicable_competition_labels": [], "applicability_summary": "All competitions", "notes_conditions": "Unlocks partner discount perks", "priority": "high", "is_active": true, "is_featured": true}, {"sort_order": 600, "code": "FFA060", "source_row_label": "78", "activity_slug": "reach-platinum-tier-15-000-fet-earned-lifetime", "activity_name": "Reach Platinum tier (15,000 FET earned lifetime)", "category": "Loyalty & Streaks", "fet_value": 500, "frequency_label": "Once", "applies_to_all_competitions": true, "applicable_competition_labels": [], "applicability_summary": "All competitions", "notes_conditions": "VIP rewards and early feature access", "priority": "high", "is_active": true, "is_featured": true}, {"sort_order": 610, "code": "FFA061", "source_row_label": "79", "activity_slug": "1-year-platform-anniversary-reward", "activity_name": "1-year platform anniversary reward", "category": "Loyalty & Streaks", "fet_value": 500, "frequency_label": "Annually", "applies_to_all_competitions": true, "applicable_competition_labels": [], "applicability_summary": "All competitions", "notes_conditions": null, "priority": "medium", "is_active": true, "is_featured": true}, {"sort_order": 620, "code": "FFA062", "source_row_label": "80", "activity_slug": "first-fet-spend-at-partner-first-transaction", "activity_name": "First FET spend at partner (first transaction)", "category": "Loyalty & Streaks", "fet_value": 100, "frequency_label": "Once", "applies_to_all_competitions": true, "applicable_competition_labels": [], "applicability_summary": "All competitions", "notes_conditions": "Encourages token utility loop closure", "priority": "high", "is_active": true, "is_featured": true}, {"sort_order": 630, "code": "FFA063", "source_row_label": "81", "activity_slug": "win-weekly-prediction-tournament", "activity_name": "Win weekly prediction tournament", "category": "Competitions", "fet_value": 100, "frequency_label": "Weekly", "applies_to_all_competitions": true, "applicable_competition_labels": [], "applicability_summary": "All competitions", "notes_conditions": "Platform-wide weekly contest", "priority": "high", "is_active": true, "is_featured": true}, {"sort_order": 640, "code": "FFA064", "source_row_label": "82", "activity_slug": "win-gameweek-fantasy-tournament", "activity_name": "Win gameweek fantasy tournament", "category": "Competitions", "fet_value": 300, "frequency_label": "Per gameweek", "applies_to_all_competitions": false, "applicable_competition_labels": ["EPL", "World Cup", "AFCON"], "applicability_summary": "EPL · World Cup · AFCON", "notes_conditions": "Separate prize per competition", "priority": "high", "is_active": true, "is_featured": true}, {"sort_order": 650, "code": "FFA065", "source_row_label": "83", "activity_slug": "participate-in-local-league-special-matchday-event", "activity_name": "Participate in local league special matchday event", "category": "Competitions", "fet_value": 100, "frequency_label": "Per event", "applies_to_all_competitions": false, "applicable_competition_labels": ["Rwanda PL", "DRC Linafoot", "Zambia SL"], "applicability_summary": "Rwanda PL · DRC Linafoot · Zambia SL", "notes_conditions": "Match-day special challenges", "priority": "high", "is_active": true, "is_featured": true}, {"sort_order": 660, "code": "FFA066", "source_row_label": "84", "activity_slug": "correct-bracket-prediction-knockout-round", "activity_name": "Correct bracket prediction — knockout round", "category": "Competitions", "fet_value": 100, "frequency_label": "Per round correct", "applies_to_all_competitions": false, "applicable_competition_labels": ["World Cup", "AFCON", "CAF Champions League"], "applicability_summary": "World Cup · AFCON · CAF Champions League", "notes_conditions": "Full bracket challenge activity", "priority": "high", "is_active": true, "is_featured": true}, {"sort_order": 670, "code": "FFA067", "source_row_label": "85", "activity_slug": "top-fet-earner-of-the-month-platform-wide", "activity_name": "Top FET earner of the month (platform-wide)", "category": "Competitions", "fet_value": 400, "frequency_label": "Monthly", "applies_to_all_competitions": true, "applicable_competition_labels": [], "applicability_summary": "All competitions", "notes_conditions": "Monthly fantasy points leaderboard leader", "priority": "high", "is_active": true, "is_featured": true}]$$::jsonb;
begin
  insert into public.fantasy_fet_activities (
    club_id,
    code,
    source_row_label,
    activity_slug,
    activity_name,
    category,
    fet_value,
    frequency_label,
    applies_to_all_competitions,
    applicable_competition_labels,
    applicability_summary,
    notes_conditions,
    priority,
    is_active,
    is_featured,
    sort_order
  )
  select
    club.id,
    seed.code,
    seed.source_row_label,
    seed.activity_slug,
    seed.activity_name,
    seed.category,
    seed.fet_value,
    seed.frequency_label,
    seed.applies_to_all_competitions,
    seed.applicable_competition_labels,
    seed.applicability_summary,
    seed.notes_conditions,
    seed.priority,
    seed.is_active,
    seed.is_featured,
    seed.sort_order
  from public.african_football_clubs club
  cross join jsonb_to_recordset(v_seed) as seed(
    sort_order integer,
    code text,
    source_row_label text,
    activity_slug text,
    activity_name text,
    category text,
    fet_value integer,
    frequency_label text,
    applies_to_all_competitions boolean,
    applicable_competition_labels text[],
    applicability_summary text,
    notes_conditions text,
    priority text,
    is_active boolean,
    is_featured boolean
  )
  on conflict (club_id, code) do nothing;
end;
$fantasy_fet_seed$;
