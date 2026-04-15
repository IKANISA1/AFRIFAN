-- ============================================================================
-- Corrective cleanup for duplicate catalog, partner, and home content records
-- ============================================================================

-- ── 1. Canonicalize UEFA Champions League competition/season identity ───────

do $$
declare
  v_legacy_competition_id uuid;
  v_duplicate_competition_id uuid;
  v_legacy_season_id uuid;
begin
  select id
  into v_legacy_competition_id
  from football.competitions
  where slug = 'champions-league';

  select id
  into v_duplicate_competition_id
  from football.competitions
  where slug = 'uefa-champions-league';

  if v_legacy_competition_id is not null
     and v_duplicate_competition_id is not null
     and v_legacy_competition_id <> v_duplicate_competition_id then

    update public.prediction_supported_competitions
    set
      competition_id = v_legacy_competition_id,
      metadata = coalesce(metadata, '{}'::jsonb)
        || jsonb_build_object('normalized_from_competition_slug', 'uefa-champions-league'),
      updated_at = now()
    where competition_id = v_duplicate_competition_id
      and not exists (
        select 1
        from public.prediction_supported_competitions existing
        where existing.competition_id = v_legacy_competition_id
      );

    delete from football.seasons duplicate_season
    where duplicate_season.competition_id = v_duplicate_competition_id
      and duplicate_season.slug = 'uefa-champions-league-2025-26'
      and not exists (
        select 1 from football.fixtures f where f.season_id = duplicate_season.id
      )
      and not exists (
        select 1 from football.season_teams st where st.season_id = duplicate_season.id
      )
      and not exists (
        select 1 from football.standings s where s.season_id = duplicate_season.id
      );

    select id
    into v_legacy_season_id
    from football.seasons
    where slug = 'champions-league-2025-2026';

    if v_legacy_season_id is not null
       and not exists (
         select 1 from football.seasons where slug = 'uefa-champions-league-2025-26'
       ) then
      update football.seasons
      set
        slug = 'uefa-champions-league-2025-26',
        label = '2025/26',
        updated_at = now()
      where id = v_legacy_season_id;
    end if;

    delete from football.competitions duplicate_competition
    where duplicate_competition.id = v_duplicate_competition_id
      and not exists (
        select 1 from football.seasons s where s.competition_id = duplicate_competition.id
      )
      and not exists (
        select 1 from football.fixtures f where f.competition_id = duplicate_competition.id
      )
      and not exists (
        select 1 from football.standings s where s.competition_id = duplicate_competition.id
      )
      and not exists (
        select 1
        from public.prediction_supported_competitions psc
        where psc.competition_id = duplicate_competition.id
      );

    if not exists (
      select 1
      from football.competitions
      where slug = 'uefa-champions-league'
        and id <> v_legacy_competition_id
    ) then
      update football.competitions
      set
        slug = 'uefa-champions-league',
        short_name = 'UCL',
        updated_at = now()
      where id = v_legacy_competition_id
        and slug = 'champions-league';
    end if;
  end if;
end;
$$;

do $$
declare
  v_legacy_season_id uuid;
begin
  delete from football.seasons duplicate_season
  where duplicate_season.slug = 'la-liga-2025-26'
    and not exists (
      select 1 from football.fixtures f where f.season_id = duplicate_season.id
    )
    and not exists (
      select 1 from football.season_teams st where st.season_id = duplicate_season.id
    )
    and not exists (
      select 1 from football.standings s where s.season_id = duplicate_season.id
    );

  select id
  into v_legacy_season_id
  from football.seasons
  where slug = 'la-liga-2025-2026';

  if v_legacy_season_id is not null
     and not exists (
       select 1 from football.seasons where slug = 'la-liga-2025-26'
     ) then
    update football.seasons
    set
      slug = 'la-liga-2025-26',
      label = '2025/26',
      updated_at = now()
    where id = v_legacy_season_id;
  end if;
end;
$$;

create unique index if not exists idx_football_competitions_name_unique
  on football.competitions ((lower(btrim(name))));

create unique index if not exists idx_football_seasons_competition_year_unique
  on football.seasons (competition_id, year_start, year_end);

-- ── 2. Remove unused duplicate teams introduced by recent seed batches ──────

delete from football.teams t
where t.slug in (
  'ucl-arsenal',
  'ucl-liverpool',
  'ucl-manchester-city',
  'brugge-cercle',
  'green-eagles-fc-zm',
  'kansanshi-dynamos-fc-zm',
  'maestro-united-zambia-zm',
  'mines-united-fc-zm',
  'mutondo-stars-fc-zm',
  'prison-leopards-fc-zm'
)
and not exists (
  select 1 from football.fixtures f
  where f.home_team_id = t.id or f.away_team_id = t.id
)
and not exists (
  select 1 from football.season_teams st
  where st.team_id = t.id
)
and not exists (
  select 1 from football.standings s
  where s.team_id = t.id
)
and not exists (
  select 1 from football.player_registrations pr
  where pr.team_id = t.id
);

-- ── 3. Normalize legacy partner service slugs and merge duplicate partners ──

update public.partner_services
set
  service_slug = coalesce(
    nullif(
      regexp_replace(
        regexp_replace(lower(coalesce(title, '')), '[^a-z0-9]+', '-', 'g'),
        '(^-|-$)',
        '',
        'g'
      ),
      ''
    ),
    'service-' || left(id::text, 8)
  ),
  updated_at = now()
where service_slug is null or btrim(service_slug) = '';

do $$
declare
  v_legacy_partner_id uuid;
  v_canonical_partner_id uuid;
begin
  -- Urwego Finance
  select id into v_legacy_partner_id
  from public.partners
  where slug = 'urwego';

  select id into v_canonical_partner_id
  from public.partners
  where slug = 'urwego-finance';

  if v_legacy_partner_id is not null
     and v_canonical_partner_id is not null
     and v_legacy_partner_id <> v_canonical_partner_id then

    insert into public.admin_role_assignments (
      id,
      user_id,
      role,
      partner_scope_id,
      granted_by,
      granted_at,
      revoked_at,
      is_active,
      notes,
      club_id
    )
    select
      gen_random_uuid(),
      ara.user_id,
      ara.role,
      v_canonical_partner_id,
      ara.granted_by,
      ara.granted_at,
      ara.revoked_at,
      ara.is_active,
      ara.notes,
      ara.club_id
    from public.admin_role_assignments ara
    where partner_scope_id = v_legacy_partner_id
      and not exists (
        select 1
        from public.admin_role_assignments existing
        where existing.user_id = ara.user_id
          and existing.role = ara.role
          and existing.partner_scope_id = v_canonical_partner_id
      );

    delete from public.admin_role_assignments
    where partner_scope_id = v_legacy_partner_id;

    update public.partner_services
    set
      partner_id = v_canonical_partner_id,
      updated_at = now()
    where partner_id = v_legacy_partner_id;

    delete from public.partners
    where id = v_legacy_partner_id;
  end if;

  -- Radiant Insurance
  select id into v_legacy_partner_id
  from public.partners
  where slug = 'radiant';

  select id into v_canonical_partner_id
  from public.partners
  where slug = 'radiant-insurance';

  if v_legacy_partner_id is not null
     and v_canonical_partner_id is not null
     and v_legacy_partner_id <> v_canonical_partner_id then
    update public.partner_services
    set
      partner_id = v_canonical_partner_id,
      updated_at = now()
    where partner_id = v_legacy_partner_id;

    delete from public.partners
    where id = v_legacy_partner_id;
  end if;
end;
$$;

create unique index if not exists idx_partners_name_unique
  on public.partners ((lower(btrim(name))));

-- ── 4. Deduplicate active home banners per route within a club ──────────────

with ranked as (
  select
    id,
    row_number() over (
      partition by club_id, title, subtitle, badge_label, cta_label, route,
      coalesce(image_url, ''), sort_order, is_active
      order by created_at, id
    ) as rn
  from public.home_banners
)
delete from public.home_banners hb
using ranked r
where hb.id = r.id
  and r.rn > 1;

create unique index if not exists idx_home_banners_active_route_unique
  on public.home_banners (club_id, route)
  where is_active = true;
