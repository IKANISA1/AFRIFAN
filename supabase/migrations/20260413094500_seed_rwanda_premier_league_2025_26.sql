do $$
declare
  v_competition_id uuid;
  v_season_id uuid;
begin
  select id
    into v_competition_id
  from football.competitions
  where slug = 'rwanda-premier-league';

  if v_competition_id is null then
    raise exception 'football.competitions row for rwanda-premier-league is missing.';
  end if;

  select id
    into v_season_id
  from football.seasons
  where slug = 'rwanda-premier-league-2026';

  if v_season_id is null then
    raise exception 'football.seasons row for rwanda-premier-league-2026 is missing.';
  end if;

  update football.seasons
  set
    starts_on = date '2025-09-12',
    ends_on = date '2026-05-31',
    status = 'active',
    metadata = metadata || jsonb_build_object(
      'data_compiled_at', '2026-04-13',
      'sources', jsonb_build_array(
        'rwandapremierleague.rw',
        'Wikipedia',
        'Tribuna',
        'Sofascore',
        'Transfermarkt'
      )
    )
  where id = v_season_id;

  with team_values (
    slug,
    name,
    short_name,
    city,
    country_code,
    country_name,
    stadium,
    founded_year,
    seeded_rank,
    note,
    source_club_slug
  ) as (
    values
      ('apr-fc', 'APR FC', 'APR', 'Kigali', 'RW', 'Rwanda', 'Stade Nyamirambo', 1993, 1, 'Defending champions; six consecutive league titles and 23 overall.', null),
      ('rayon-sports-fc', 'Rayon Sports FC', 'Rayon Sports', 'Kigali', 'RW', 'Rwanda', 'Stade Amahoro / Kigali Pele Stadium', 1968, 2, 'Nine league titles; largest fanbase in Rwanda.', 'rayon_sports_rw'),
      ('as-kigali-fc', 'AS Kigali FC', 'AS Kigali', 'Kigali', 'RW', 'Rwanda', 'Kigali Pele Stadium', null, 3, 'Consistent top-four finisher.', null),
      ('police-fc-rw', 'Police FC', 'Police FC', 'Kigali', 'RW', 'Rwanda', 'Kigali Pele Stadium', null, 4, 'Rwanda Police Force-affiliated club.', null),
      ('mukura-victory-sports', 'Mukura Victory Sports', 'Mukura VS', 'Huye', 'RW', 'Rwanda', 'Huye Stadium', 1963, 5, 'Rwandan Cup winners in 2018.', null),
      ('bugesera-fc', 'Bugesera FC', 'Bugesera', 'Bugesera', 'RW', 'Rwanda', 'Bugesera Stadium', null, 6, 'Rising club from Eastern Province.', null),
      ('gorilla-fc', 'Gorilla FC', 'Gorilla FC', 'Musanze', 'RW', 'Rwanda', 'Volcanoes Stadium', null, 7, 'Based near Volcanoes National Park.', null),
      ('gasogi-united', 'Gasogi United', 'Gasogi', 'Gasogi, Kigali', 'RW', 'Rwanda', 'Kigali area', null, 8, 'Former Division 1 club promoted previously.', null),
      ('rutsiro-fc', 'Rutsiro FC', 'Rutsiro', 'Rutsiro', 'RW', 'Rwanda', 'Rutsiro Stadium', null, 9, 'Western Province club.', null),
      ('kiyovu-sports', 'Kiyovu Sports', 'Kiyovu', 'Kigali', 'RW', 'Rwanda', 'Kigali Pele Stadium', null, 10, 'First ever Rwanda Premier League winners in 1975.', null),
      ('amagaju-fc', 'Amagaju FC', 'Amagaju', 'Southern Province', 'RW', 'Rwanda', 'Huye Stadium', null, 11, 'Survived relegation on the final day of 2024/25.', null),
      ('etincelles-fc', 'Etincelles FC', 'Etincelles', 'Northern Province', 'RW', 'Rwanda', 'Musanze Stadium', null, 12, 'Also known as The Sparks.', null),
      ('musanze-fc', 'Musanze FC', 'Musanze', 'Musanze', 'RW', 'Rwanda', 'Musanze Stadium', null, 13, 'Northern Province club.', null),
      ('marine-fc-rw', 'Marine FC', 'Marine FC', 'Kigali', 'RW', 'Rwanda', 'Kigali Pele Stadium', null, 14, 'Also known as Marines.', null),
      ('al-hilal-omdurman', 'Al-Hilal Omdurman', 'Al-Hilal', 'Omdurman', 'SD', 'Sudan', 'Al-Hilal Stadium', null, 15, 'Guest club competing in Rwanda due to the Sudan conflict.', null),
      ('al-merrikh', 'Al Merrikh', 'Al Merrikh', 'Omdurman', 'SD', 'Sudan', 'Al-Merreikh Stadium', null, 16, 'Guest club competing in Rwanda due to the Sudan conflict.', null),
      ('gicumbi-fc', 'Gicumbi FC', 'Gicumbi', 'Gicumbi', 'RW', 'Rwanda', 'Gicumbi Stadium', null, 17, 'Promoted in 2025 from Division 1.', null),
      ('as-muhanga-fc', 'AS Muhanga FC', 'AS Muhanga', 'Muhanga', 'RW', 'Rwanda', 'Muhanga Stadium', null, 18, 'Promoted in 2025 from Division 1.', null)
  ),
  resolved_clubs as (
    select
      tv.*,
      (
        select afc.id
        from public.african_football_clubs afc
        where (
          tv.source_club_slug is not null
          and afc.club_slug = tv.source_club_slug
        )
        or lower(regexp_replace(afc.club_name, '[^a-z0-9]+', '', 'g')) =
           lower(regexp_replace(tv.name, '[^a-z0-9]+', '', 'g'))
        limit 1
      ) as source_club_id
    from team_values tv
  )
  insert into football.teams as t (
    slug,
    name,
    short_name,
    team_type,
    country_code,
    country_name,
    city,
    founded_year,
    source_club_id,
    metadata
  )
  select
    rc.slug,
    rc.name,
    rc.short_name,
    'club'::football.team_type,
    rc.country_code,
    rc.country_name,
    rc.city,
    rc.founded_year,
    rc.source_club_id,
    jsonb_strip_nulls(
      jsonb_build_object(
        'stadium', rc.stadium,
        'season_seed_rank', rc.seeded_rank,
        'notes', rc.note
      )
    )
  from resolved_clubs rc
  on conflict (slug) do update
  set
    name = excluded.name,
    short_name = excluded.short_name,
    country_code = excluded.country_code,
    country_name = excluded.country_name,
    city = excluded.city,
    founded_year = excluded.founded_year,
    source_club_id = coalesce(excluded.source_club_id, t.source_club_id),
    is_active = true,
    metadata = t.metadata || excluded.metadata;

  with season_team_values (team_slug, seeded_rank, note) as (
    values
      ('apr-fc', 1, 'Defending champions entering 2025/26.'),
      ('rayon-sports-fc', 2, 'Largest fanbase in Rwanda.'),
      ('as-kigali-fc', 3, 'Top-three finisher in 2024/25.'),
      ('police-fc-rw', 4, 'Top-four finisher in 2024/25.'),
      ('mukura-victory-sports', 5, 'Experienced Huye-based side.'),
      ('bugesera-fc', 6, 'Eastern Province representation.'),
      ('gorilla-fc', 7, 'Northern Rwanda club.'),
      ('gasogi-united', 8, 'Kigali-based club.'),
      ('rutsiro-fc', 9, 'Western Province club.'),
      ('kiyovu-sports', 10, 'Historic Kigali club.'),
      ('amagaju-fc', 11, 'Avoided relegation in 2024/25.'),
      ('etincelles-fc', 12, 'Northern Province side.'),
      ('musanze-fc', 13, 'Northern Province side.'),
      ('marine-fc-rw', 14, 'Also called Marines.'),
      ('al-hilal-omdurman', 15, 'Guest Sudanese club.'),
      ('al-merrikh', 16, 'Guest Sudanese club.'),
      ('gicumbi-fc', 17, 'Promoted for 2025/26.'),
      ('as-muhanga-fc', 18, 'Promoted for 2025/26.')
  )
  insert into football.season_teams as st (
    season_id,
    team_id,
    seeded_rank,
    metadata
  )
  select
    v_season_id,
    t.id,
    stv.seeded_rank,
    jsonb_build_object('notes', stv.note)
  from season_team_values stv
  join football.teams t
    on t.slug = stv.team_slug
  on conflict (season_id, team_id) do update
  set
    seeded_rank = excluded.seeded_rank,
    is_active = true,
    metadata = st.metadata || excluded.metadata;

  with standings_values (position, team_slug, snapshot_note) as (
    values
      (1, 'apr-fc', 'Position-only snapshot as of 2026-04-13; detailed stats unavailable in source pack.'),
      (2, 'rayon-sports-fc', 'Position-only snapshot as of 2026-04-13; detailed stats unavailable in source pack.'),
      (3, 'musanze-fc', 'Position-only snapshot as of 2026-04-13; detailed stats unavailable in source pack.'),
      (4, 'police-fc-rw', 'Position-only snapshot as of 2026-04-13; detailed stats unavailable in source pack.'),
      (5, 'marine-fc-rw', 'Position-only snapshot as of 2026-04-13; detailed stats unavailable in source pack.'),
      (6, 'gicumbi-fc', 'Position-only snapshot as of 2026-04-13; detailed stats unavailable in source pack.'),
      (7, 'mukura-victory-sports', 'Position-only snapshot as of 2026-04-13; detailed stats unavailable in source pack.'),
      (8, 'al-merrikh', 'Position-only snapshot as of 2026-04-13; detailed stats unavailable in source pack.'),
      (9, 'as-muhanga-fc', 'Position-only snapshot as of 2026-04-13; detailed stats unavailable in source pack.'),
      (10, 'rutsiro-fc', 'Position-only snapshot as of 2026-04-13; detailed stats unavailable in source pack.'),
      (11, 'amagaju-fc', 'Position-only snapshot as of 2026-04-13; detailed stats unavailable in source pack.'),
      (12, 'gorilla-fc', 'Position-only snapshot as of 2026-04-13; detailed stats unavailable in source pack.'),
      (13, 'etincelles-fc', 'Position-only snapshot as of 2026-04-13; detailed stats unavailable in source pack.'),
      (14, 'gasogi-united', 'Position-only snapshot as of 2026-04-13; detailed stats unavailable in source pack.'),
      (15, 'al-hilal-omdurman', 'Position-only snapshot as of 2026-04-13; detailed stats unavailable in source pack.'),
      (16, 'kiyovu-sports', 'Position-only snapshot as of 2026-04-13; detailed stats unavailable in source pack.'),
      (17, 'as-kigali-fc', 'Position-only snapshot as of 2026-04-13; detailed stats unavailable in source pack.'),
      (18, 'bugesera-fc', 'Position-only snapshot as of 2026-04-13; detailed stats unavailable in source pack.')
  )
  insert into football.standings as st (
    competition_id,
    season_id,
    team_id,
    stage_name,
    group_name,
    position,
    played,
    won,
    drawn,
    lost,
    goals_for,
    goals_against,
    goal_difference,
    points,
    notes,
    metadata
  )
  select
    v_competition_id,
    v_season_id,
    t.id,
    'overall',
    '',
    sv.position,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    sv.snapshot_note,
    jsonb_build_object(
      'stats_complete', false,
      'snapshot_date', '2026-04-13',
      'snapshot_type', 'position_only'
    )
  from standings_values sv
  join football.teams t
    on t.slug = sv.team_slug
  on conflict (season_id, stage_name, group_name, team_id) do update
  set
    position = excluded.position,
    notes = excluded.notes,
    metadata = st.metadata || excluded.metadata;

  with fixture_values (
    round_label,
    match_date_text,
    home_slug,
    away_slug,
    home_score,
    away_score,
    status_text,
    venue_name
  ) as (
    values
      ('1', '12 Sep 2025', 'mukura-victory-sports', 'musanze-fc', 1, 0, 'FT', 'Huye Stadium'),
      ('1', '13 Sep 2025', 'bugesera-fc', 'gicumbi-fc', 1, 0, 'FT', 'Bugesera Stadium'),
      ('1', '13 Sep 2025', 'police-fc-rw', 'rutsiro-fc', 2, 1, 'FT', 'Kigali Pele Stadium'),
      ('1', '13 Sep 2025', 'etincelles-fc', 'gasogi-united', 0, 0, 'FT', 'Musanze Stadium'),
      ('1', '14 Sep 2025', 'kiyovu-sports', 'rayon-sports-fc', 0, 2, 'FT', 'Kigali Pele Stadium'),
      ('1', '14 Sep 2025', 'as-kigali-fc', 'amagaju-fc', 1, 2, 'FT', 'Kigali Pele Stadium'),
      ('1', '14 Sep 2025', 'apr-fc', 'marine-fc-rw', null, null, 'PP', 'Stade Nyamirambo'),
      ('2', '18 Sep 2025', 'gorilla-fc', 'mukura-victory-sports', 1, 1, 'FT', 'Musanze Stadium'),
      ('2', '19 Sep 2025', 'gicumbi-fc', 'apr-fc', 1, 2, 'FT', 'Gicumbi Stadium'),
      ('2', '19 Sep 2025', 'as-muhanga-fc', 'kiyovu-sports', 0, 1, 'FT', 'Muhanga Stadium'),
      ('2', '19 Sep 2025', 'rutsiro-fc', 'gasogi-united', 2, 3, 'FT', 'Rutsiro Stadium'),
      ('2', '20 Sep 2025', 'musanze-fc', 'as-kigali-fc', 1, 0, 'FT', 'Musanze Stadium'),
      ('2', '20 Sep 2025', 'amagaju-fc', 'bugesera-fc', 0, 0, 'FT', 'Huye Stadium'),
      ('3', '05 Oct 2025', 'gorilla-fc', 'rayon-sports-fc', 0, 2, 'FT', 'Musanze Stadium'),
      ('3', '17 Oct 2025', 'gorilla-fc', 'gicumbi-fc', null, null, 'FT', 'Musanze Stadium'),
      ('3', '18 Oct 2025', 'bugesera-fc', 'gasogi-united', null, null, 'FT', 'Bugesera Stadium'),
      ('3', '18 Oct 2025', 'as-muhanga-fc', 'etincelles-fc', null, null, 'FT', 'Muhanga Stadium'),
      ('3', '18 Oct 2025', 'as-kigali-fc', 'marine-fc-rw', null, null, 'FT', 'Kigali Pele Stadium'),
      ('3', '18 Oct 2025', 'rayon-sports-fc', 'rutsiro-fc', null, null, 'FT', 'Stade Amahoro'),
      ('3', '19 Oct 2025', 'police-fc-rw', 'amagaju-fc', null, null, 'FT', 'Kigali Pele Stadium'),
      ('3', '19 Oct 2025', 'apr-fc', 'mukura-victory-sports', null, null, 'FT', 'Stade Nyamirambo'),
      ('3', '20 Oct 2025', 'al-hilal-omdurman', 'musanze-fc', null, null, 'FT', 'TBC'),
      ('GS', '27 Nov 2025', 'bugesera-fc', 'al-merrikh', 1, 0, 'FT', 'Bugesera Stadium'),
      ('GS', '04 Dec 2025', 'gasogi-united', 'al-hilal-omdurman', 0, 2, 'FT', 'Kigali Pele Stadium'),
      ('GS', '09 Dec 2025', 'al-hilal-omdurman', 'mukura-victory-sports', 2, 0, 'FT', 'TBC'),
      ('GS', '12 Dec 2025', 'al-hilal-omdurman', 'bugesera-fc', 3, 1, 'FT', 'TBC'),
      ('GS', '15 Dec 2025', 'al-merrikh', 'amagaju-fc', 1, 0, 'FT', 'TBC'),
      ('GS', '16 Dec 2025', 'al-hilal-omdurman', 'rutsiro-fc', 1, 2, 'FT', 'TBC'),
      ('GS', '17 Dec 2025', 'etincelles-fc', 'al-merrikh', 1, 2, 'FT', 'Musanze Stadium'),
      ('JAN', '08 Jan 2026', 'al-hilal-omdurman', 'etincelles-fc', null, null, 'FT', 'TBC'),
      ('JAN', '08 Jan 2026', 'al-merrikh', 'police-fc-rw', null, null, 'FT', 'TBC'),
      ('JAN', '09 Jan 2026', 'as-muhanga-fc', 'gicumbi-fc', null, null, 'FT', 'Muhanga Stadium'),
      ('JAN', '09 Jan 2026', 'as-kigali-fc', 'rutsiro-fc', null, null, 'FT', 'Kigali Pele Stadium'),
      ('JAN', '11 Jan 2026', 'kiyovu-sports', 'police-fc-rw', null, null, 'FT', 'Kigali Pele Stadium'),
      ('JAN', '11 Jan 2026', 'etincelles-fc', 'bugesera-fc', null, null, 'FT', 'Musanze Stadium'),
      ('JAN', '11 Jan 2026', 'musanze-fc', 'marine-fc-rw', null, null, 'FT', 'Musanze Stadium'),
      ('JAN', '12 Jan 2026', 'al-merrikh', 'mukura-victory-sports', null, null, 'FT', 'TBC'),
      ('JAN', '13 Jan 2026', 'al-hilal-omdurman', 'amagaju-fc', null, null, 'FT', 'TBC'),
      ('JAN', '17 Jan 2026', 'rayon-sports-fc', 'al-hilal-omdurman', null, null, 'FT', 'Stade Amahoro'),
      ('JAN', '17 Jan 2026', 'apr-fc', 'al-merrikh', null, null, 'FT', 'Stade Nyamirambo'),
      ('JAN', '19 Jan 2026', 'al-hilal-omdurman', 'apr-fc', null, null, 'FT', 'TBC'),
      ('JAN', '20 Jan 2026', 'al-hilal-omdurman', 'al-merrikh', null, null, 'FT', 'TBC'),
      ('JAN', '21 Jan 2026', 'al-merrikh', 'rayon-sports-fc', null, null, 'FT', 'TBC'),
      ('JAN', '22 Jan 2026', 'al-hilal-omdurman', 'as-muhanga-fc', null, null, 'FT', 'TBC'),
      ('JAN', '31 Jan 2026', 'mukura-victory-sports', 'etincelles-fc', null, null, 'FT', 'Huye Stadium'),
      ('JAN', '31 Jan 2026', 'bugesera-fc', 'al-hilal-omdurman', null, null, 'FT', 'Bugesera Stadium'),
      ('FEB', '04 Feb 2026', 'gasogi-united', 'apr-fc', null, null, 'FT', 'Kigali Pele Stadium'),
      ('FEB', '05 Feb 2026', 'as-kigali-fc', 'rayon-sports-fc', null, null, 'FT', 'Kigali Pele Stadium'),
      ('FEB', '06 Feb 2026', 'gorilla-fc', 'rutsiro-fc', null, null, 'FT', 'Musanze Stadium'),
      ('FEB', '07 Feb 2026', 'etincelles-fc', 'musanze-fc', null, null, 'FT', 'Musanze Stadium'),
      ('FEB', '07 Feb 2026', 'kiyovu-sports', 'mukura-victory-sports', null, null, 'FT', 'Kigali Pele Stadium'),
      ('FEB', '07 Feb 2026', 'bugesera-fc', 'apr-fc', null, null, 'FT', 'Bugesera Stadium'),
      ('FEB', '08 Feb 2026', 'as-muhanga-fc', 'gasogi-united', null, null, 'FT', 'Muhanga Stadium'),
      ('FEB', '08 Feb 2026', 'gicumbi-fc', 'amagaju-fc', null, null, 'FT', 'Gicumbi Stadium'),
      ('FEB', '08 Feb 2026', 'marine-fc-rw', 'al-merrikh', null, null, 'FT', 'Kigali Pele Stadium'),
      ('FEB', '08 Feb 2026', 'police-fc-rw', 'as-kigali-fc', null, null, 'FT', 'Kigali Pele Stadium'),
      ('FEB', '10 Feb 2026', 'al-hilal-omdurman', 'al-merrikh', null, null, 'FT', 'TBC'),
      ('FEB', '13 Feb 2026', 'musanze-fc', 'al-merrikh', null, null, 'FT', 'Musanze Stadium'),
      ('FEB', '13 Feb 2026', 'police-fc-rw', 'rayon-sports-fc', null, null, 'FT', 'Kigali Pele Stadium'),
      ('MAR', '01 Mar 2026', 'as-muhanga-fc', 'police-fc-rw', 1, 1, 'FT', 'Muhanga Stadium'),
      ('MAR', '15 Mar 2026', 'as-muhanga-fc', 'mukura-victory-sports', 2, 1, 'FT', 'Muhanga Stadium'),
      ('MAR', '15 Mar 2026', 'gorilla-fc', 'marine-fc-rw', 1, 1, 'FT', 'Musanze Stadium'),
      ('MAR', '16 Mar 2026', 'gicumbi-fc', 'police-fc-rw', 1, 2, 'FT', 'Gicumbi Stadium'),
      ('MAR', '16 Mar 2026', 'rayon-sports-fc', 'al-merrikh', 0, 0, 'FT', 'Stade Amahoro'),
      ('MAR', '21 Mar 2026', 'bugesera-fc', 'as-kigali-fc', 2, 0, 'FT', 'Bugesera Stadium'),
      ('MAR', '22 Mar 2026', 'apr-fc', 'amagaju-fc', 1, 0, 'FT', 'Stade Nyamirambo'),
      ('MAR', '22 Mar 2026', 'police-fc-rw', 'etincelles-fc', 1, 1, 'FT', 'Kigali Pele Stadium'),
      ('MAR', '22 Mar 2026', 'rutsiro-fc', 'kiyovu-sports', 0, 1, 'FT', 'Rutsiro Stadium'),
      ('MAR', '22 Mar 2026', 'rayon-sports-fc', 'gasogi-united', 3, 0, 'FT', 'Stade Amahoro'),
      ('APR', '03 Apr 2026', 'kiyovu-sports', 'gasogi-united', null, null, 'SCH', 'Kigali Pele Stadium'),
      ('APR', '03 Apr 2026', 'as-kigali-fc', 'mukura-victory-sports', null, null, 'SCH', 'Kigali Pele Stadium'),
      ('APR', '04 Apr 2026', 'bugesera-fc', 'etincelles-fc', null, null, 'SCH', 'Bugesera Stadium'),
      ('APR', '04 Apr 2026', 'amagaju-fc', 'police-fc-rw', null, null, 'SCH', 'Huye Stadium'),
      ('APR', '04 Apr 2026', 'al-merrikh', 'rutsiro-fc', null, null, 'SCH', 'TBC'),
      ('APR', '04 Apr 2026', 'rayon-sports-fc', 'gicumbi-fc', null, null, 'SCH', 'Stade Amahoro'),
      ('APR', '05 Apr 2026', 'gorilla-fc', 'musanze-fc', null, null, 'SCH', 'Musanze Stadium'),
      ('APR', '05 Apr 2026', 'apr-fc', 'as-muhanga-fc', null, null, 'SCH', 'Stade Nyamirambo'),
      ('APR', '06 Apr 2026', 'al-hilal-omdurman', 'marine-fc-rw', null, null, 'SCH', 'TBC'),
      ('APR', '17 Apr 2026', 'gasogi-united', 'gorilla-fc', null, null, 'SCH', 'Kigali Pele Stadium'),
      ('APR', '17 Apr 2026', 'marine-fc-rw', 'as-kigali-fc', null, null, 'SCH', 'Kigali Pele Stadium'),
      ('APR', '17 Apr 2026', 'musanze-fc', 'amagaju-fc', null, null, 'SCH', 'Musanze Stadium'),
      ('APR', '18 Apr 2026', 'gicumbi-fc', 'as-muhanga-fc', null, null, 'SCH', 'Gicumbi Stadium'),
      ('APR', '18 Apr 2026', 'etincelles-fc', 'apr-fc', null, null, 'SCH', 'Musanze Stadium'),
      ('APR', '18 Apr 2026', 'mukura-victory-sports', 'al-merrikh', null, null, 'SCH', 'Huye Stadium'),
      ('APR', '18 Apr 2026', 'kiyovu-sports', 'al-hilal-omdurman', null, null, 'SCH', 'Kigali Pele Stadium'),
      ('APR', '19 Apr 2026', 'rutsiro-fc', 'rayon-sports-fc', null, null, 'SCH', 'Rutsiro Stadium'),
      ('APR', '19 Apr 2026', 'police-fc-rw', 'bugesera-fc', null, null, 'SCH', 'Kigali Pele Stadium'),
      ('APR', '24 Apr 2026', 'as-muhanga-fc', 'gorilla-fc', null, null, 'SCH', 'Muhanga Stadium'),
      ('APR', '24 Apr 2026', 'as-kigali-fc', 'gasogi-united', null, null, 'SCH', 'Kigali Pele Stadium'),
      ('APR', '24 Apr 2026', 'gicumbi-fc', 'rutsiro-fc', null, null, 'SCH', 'Gicumbi Stadium'),
      ('APR', '25 Apr 2026', 'mukura-victory-sports', 'apr-fc', null, null, 'SCH', 'Huye Stadium'),
      ('APR', '25 Apr 2026', 'al-hilal-omdurman', 'musanze-fc', null, null, 'SCH', 'TBC'),
      ('APR', '25 Apr 2026', 'police-fc-rw', 'marine-fc-rw', null, null, 'SCH', 'Kigali Pele Stadium')
  )
  insert into football.fixtures as f (
    competition_id,
    season_id,
    stage_name,
    group_name,
    round_name,
    matchday,
    kickoff_at,
    venue_name,
    home_team_id,
    away_team_id,
    home_score,
    away_score,
    status,
    external_provider,
    external_fixture_id,
    metadata
  )
  select
    v_competition_id,
    v_season_id,
    case
      when fv.round_label = 'GS' then 'guest_series'
      else 'regular_season'
    end,
    '',
    case
      when fv.round_label ~ '^[0-9]+$' then format('Round %s', fv.round_label)
      when fv.round_label = 'GS' then 'Guest Series'
      when fv.round_label = 'JAN' then 'January slate'
      when fv.round_label = 'FEB' then 'February slate'
      when fv.round_label = 'MAR' then 'March slate'
      when fv.round_label = 'APR' then 'April slate'
      else fv.round_label
    end,
    case
      when fv.round_label ~ '^[0-9]+$' then fv.round_label::integer
      else null
    end,
    ((to_date(fv.match_date_text, 'DD Mon YYYY')::timestamp + interval '12 hour') at time zone 'Africa/Kigali'),
    fv.venue_name,
    ht.id,
    at.id,
    fv.home_score,
    fv.away_score,
    case fv.status_text
      when 'FT' then 'finished'::football.fixture_status
      when 'SCH' then 'scheduled'::football.fixture_status
      when 'PP' then 'postponed'::football.fixture_status
      else 'scheduled'::football.fixture_status
    end,
    'manual-rwanda-premier-league',
    format(
      'rwpl-2025-26-%s-%s-%s-%s',
      lower(fv.round_label),
      to_char(to_date(fv.match_date_text, 'DD Mon YYYY'), 'YYYYMMDD'),
      fv.home_slug,
      fv.away_slug
    ),
    jsonb_build_object(
      'status_source', fv.status_text,
      'score_confirmed', fv.home_score is not null and fv.away_score is not null,
      'compiled_at', '2026-04-13'
    )
  from fixture_values fv
  join football.teams ht
    on ht.slug = fv.home_slug
  join football.teams at
    on at.slug = fv.away_slug
  on conflict (external_provider, external_fixture_id) do update
  set
    stage_name = excluded.stage_name,
    round_name = excluded.round_name,
    matchday = excluded.matchday,
    kickoff_at = excluded.kickoff_at,
    venue_name = excluded.venue_name,
    home_team_id = excluded.home_team_id,
    away_team_id = excluded.away_team_id,
    home_score = excluded.home_score,
    away_score = excluded.away_score,
    status = excluded.status,
    metadata = f.metadata || excluded.metadata;

  with player_values (
    team_slug,
    squad_number,
    position,
    full_name,
    nationality_name,
    age_years,
    notes
  ) as (
    values
      ('rayon-sports-fc', 1, 'GK', 'Adolphe Hakizimana', 'Rwanda', 24, null),
      ('rayon-sports-fc', 2, 'GK', 'Bonheur Hategekimana', 'Rwanda', null, null),
      ('rayon-sports-fc', 3, 'GK', 'Simon Tamale', 'Uganda', 31, null),
      ('rayon-sports-fc', 4, 'GK', 'Mutuyimana Evariste', 'Rwanda', null, null),
      ('rayon-sports-fc', 5, 'GK', 'Kassim Ndayisenga', 'Rwanda', null, null),
      ('rayon-sports-fc', 6, 'DEF', 'Ali Omar Serumogo', 'Uganda', 30, null),
      ('rayon-sports-fc', 7, 'DEF', 'Hakim Bugingo', 'Rwanda', null, null),
      ('rayon-sports-fc', 8, 'DEF', 'Didier Junior Mucyo', 'Rwanda', 25, null),
      ('rayon-sports-fc', 9, 'DEF', 'Aimable Nsabimana', 'Rwanda', 28, null),
      ('rayon-sports-fc', 10, 'DEF', 'Elie Ishimwe Ganijuru', 'Rwanda', 27, null),
      ('rayon-sports-fc', 11, 'DEF', 'Gabriel Mugabo', 'Rwanda', null, null),
      ('rayon-sports-fc', 12, 'DEF', 'Yves Rwigema', 'Rwanda', null, null),
      ('rayon-sports-fc', 13, 'DEF', 'Sadam Nyandwi', 'Rwanda', null, null),
      ('rayon-sports-fc', 14, 'DEF', 'Habimana Hussein', 'Rwanda', null, null),
      ('rayon-sports-fc', 15, 'MID', 'Felix Bavakure Ndekwe', 'Rwanda', null, null),
      ('rayon-sports-fc', 16, 'MID', 'Eric Ngendahimana', 'Rwanda', 36, null),
      ('rayon-sports-fc', 17, 'MID', 'Francois Mugisha', 'Rwanda', 29, null),
      ('rayon-sports-fc', 18, 'MID', 'Rachid Kalisa', 'Rwanda', 29, null),
      ('rayon-sports-fc', 19, 'MID', 'Aruna Moussa Madjaliva', 'Mali', 25, null),
      ('rayon-sports-fc', 20, 'MID', 'Fabrice Mugheni', 'Rwanda', null, null),
      ('rayon-sports-fc', 21, 'MID', 'Franck Lomami', 'DR Congo', null, null),
      ('rayon-sports-fc', 22, 'MID', 'Nova Bayama', 'Rwanda', null, null),
      ('rayon-sports-fc', 23, 'MID', 'Muhire Kevin', 'Rwanda', null, null),
      ('rayon-sports-fc', 24, 'FWD', 'Musa Esenu', 'Uganda', 31, null),
      ('rayon-sports-fc', 25, 'FWD', 'Charles Bbaale', 'Uganda', 26, null),
      ('rayon-sports-fc', 26, 'FWD', 'Eid Mugadam Abakar Mugadam', 'Chad', 26, null),
      ('rayon-sports-fc', 27, 'FWD', 'Prince Rudasingwa', 'Rwanda', 22, '193 cm'),
      ('rayon-sports-fc', 28, 'FWD', 'Youssef Rharb', 'Morocco', null, null),
      ('rayon-sports-fc', 29, 'FWD', 'Hadji Iraguha', 'Rwanda', 27, null),
      ('rayon-sports-fc', 30, 'FWD', 'Sunday Oni Jimoh', 'Nigeria', null, null),
      ('rayon-sports-fc', 31, 'FWD', 'Ngagne Fall', 'Senegal', null, 'Led scorers in Nov 2024'),
      ('apr-fc', 1, 'GK', 'Yvan Uzamuwe Ruhamyankiko', 'Rwanda', null, null),
      ('apr-fc', 2, 'GK', 'Jean Pierre Mario Ishimwe', 'Rwanda', 23, null),
      ('apr-fc', 3, 'GK', 'Pavelh Ndzila', 'DR Congo', 30, '185 cm'),
      ('apr-fc', 4, 'DEF', 'Clement Niyigena', 'Rwanda', 24, 'Best Player 2024/25'),
      ('apr-fc', 5, 'DEF', 'Claude Niyomugabo', 'Rwanda', 28, '174 cm'),
      ('apr-fc', 6, 'DEF', 'Dieudonne Ndayishimiye', 'Rwanda', 26, null),
      ('apr-fc', 7, 'DEF', 'Aliou Souane', 'Senegal', 24, null),
      ('apr-fc', 8, 'DEF', 'Yunusu Watara Nshimiyimana', 'Rwanda', 23, null),
      ('apr-fc', 9, 'DEF', 'Jean Gilbert Byiringiro', 'Rwanda', 25, 'Rwanda national team'),
      ('apr-fc', 10, 'MID', 'Taddeo Lwanga', 'Uganda', 31, '182 cm'),
      ('apr-fc', 11, 'MID', 'Richmond Lamptey', 'Ghana', 28, '176 cm'),
      ('apr-fc', 12, 'MID', 'Elie Kategaya', 'Rwanda', null, null),
      ('apr-fc', 13, 'MID', 'Arsene Tuyisenge', 'Rwanda', 25, null),
      ('apr-fc', 14, 'MID', 'Frodouard Mugiraneza', 'Rwanda', null, null),
      ('apr-fc', 15, 'MID', 'Dauda Yussif Seidu', 'Ghana', 24, null),
      ('apr-fc', 16, 'MID', 'Ramadhan Niyibizi', 'Rwanda', 25, 'Top scorer candidate'),
      ('apr-fc', 17, 'MID', 'Jean Rene Ishimwe', 'Rwanda', null, null),
      ('apr-fc', 18, 'FWD', 'Mahamadou Lamine Bah', 'Guinea', null, null),
      ('apr-fc', 19, 'FWD', 'Djibirl Ouattara', 'Ivory Coast', null, 'Best player finalist 2024/25')
  ),
  enriched_players as (
    select
      pv.team_slug,
      pv.squad_number,
      pv.position,
      pv.full_name,
      pv.nationality_name,
      pv.age_years,
      pv.notes,
      lower(regexp_replace(pv.team_slug || '-' || pv.full_name, '[^a-z0-9]+', '-', 'g')) as player_slug,
      case pv.nationality_name
        when 'Rwanda' then 'RW'
        when 'Uganda' then 'UG'
        when 'DR Congo' then 'CD'
        when 'Mali' then 'ML'
        when 'Morocco' then 'MA'
        when 'Nigeria' then 'NG'
        when 'Senegal' then 'SN'
        when 'Chad' then 'TD'
        when 'Ghana' then 'GH'
        when 'Guinea' then 'GN'
        when 'Ivory Coast' then 'CI'
        else null
      end as nationality_code
    from player_values pv
  )
  insert into football.players as p (
    slug,
    full_name,
    short_name,
    nationality_code,
    nationality_name,
    primary_position,
    metadata
  )
  select
    ep.player_slug,
    ep.full_name,
    ep.full_name,
    ep.nationality_code,
    ep.nationality_name,
    ep.position,
    jsonb_strip_nulls(
      jsonb_build_object(
        'reported_age', ep.age_years,
        'notes', ep.notes
      )
    )
  from enriched_players ep
  on conflict (slug) do update
  set
    full_name = excluded.full_name,
    short_name = excluded.short_name,
    nationality_code = excluded.nationality_code,
    nationality_name = excluded.nationality_name,
    primary_position = excluded.primary_position,
    is_active = true,
    metadata = p.metadata || excluded.metadata;

  with player_values (
    team_slug,
    squad_number,
    position,
    full_name,
    nationality_name,
    age_years,
    notes
  ) as (
    values
      ('rayon-sports-fc', 1, 'GK', 'Adolphe Hakizimana', 'Rwanda', 24, null),
      ('rayon-sports-fc', 2, 'GK', 'Bonheur Hategekimana', 'Rwanda', null, null),
      ('rayon-sports-fc', 3, 'GK', 'Simon Tamale', 'Uganda', 31, null),
      ('rayon-sports-fc', 4, 'GK', 'Mutuyimana Evariste', 'Rwanda', null, null),
      ('rayon-sports-fc', 5, 'GK', 'Kassim Ndayisenga', 'Rwanda', null, null),
      ('rayon-sports-fc', 6, 'DEF', 'Ali Omar Serumogo', 'Uganda', 30, null),
      ('rayon-sports-fc', 7, 'DEF', 'Hakim Bugingo', 'Rwanda', null, null),
      ('rayon-sports-fc', 8, 'DEF', 'Didier Junior Mucyo', 'Rwanda', 25, null),
      ('rayon-sports-fc', 9, 'DEF', 'Aimable Nsabimana', 'Rwanda', 28, null),
      ('rayon-sports-fc', 10, 'DEF', 'Elie Ishimwe Ganijuru', 'Rwanda', 27, null),
      ('rayon-sports-fc', 11, 'DEF', 'Gabriel Mugabo', 'Rwanda', null, null),
      ('rayon-sports-fc', 12, 'DEF', 'Yves Rwigema', 'Rwanda', null, null),
      ('rayon-sports-fc', 13, 'DEF', 'Sadam Nyandwi', 'Rwanda', null, null),
      ('rayon-sports-fc', 14, 'DEF', 'Habimana Hussein', 'Rwanda', null, null),
      ('rayon-sports-fc', 15, 'MID', 'Felix Bavakure Ndekwe', 'Rwanda', null, null),
      ('rayon-sports-fc', 16, 'MID', 'Eric Ngendahimana', 'Rwanda', 36, null),
      ('rayon-sports-fc', 17, 'MID', 'Francois Mugisha', 'Rwanda', 29, null),
      ('rayon-sports-fc', 18, 'MID', 'Rachid Kalisa', 'Rwanda', 29, null),
      ('rayon-sports-fc', 19, 'MID', 'Aruna Moussa Madjaliva', 'Mali', 25, null),
      ('rayon-sports-fc', 20, 'MID', 'Fabrice Mugheni', 'Rwanda', null, null),
      ('rayon-sports-fc', 21, 'MID', 'Franck Lomami', 'DR Congo', null, null),
      ('rayon-sports-fc', 22, 'MID', 'Nova Bayama', 'Rwanda', null, null),
      ('rayon-sports-fc', 23, 'MID', 'Muhire Kevin', 'Rwanda', null, null),
      ('rayon-sports-fc', 24, 'FWD', 'Musa Esenu', 'Uganda', 31, null),
      ('rayon-sports-fc', 25, 'FWD', 'Charles Bbaale', 'Uganda', 26, null),
      ('rayon-sports-fc', 26, 'FWD', 'Eid Mugadam Abakar Mugadam', 'Chad', 26, null),
      ('rayon-sports-fc', 27, 'FWD', 'Prince Rudasingwa', 'Rwanda', 22, '193 cm'),
      ('rayon-sports-fc', 28, 'FWD', 'Youssef Rharb', 'Morocco', null, null),
      ('rayon-sports-fc', 29, 'FWD', 'Hadji Iraguha', 'Rwanda', 27, null),
      ('rayon-sports-fc', 30, 'FWD', 'Sunday Oni Jimoh', 'Nigeria', null, null),
      ('rayon-sports-fc', 31, 'FWD', 'Ngagne Fall', 'Senegal', null, 'Led scorers in Nov 2024'),
      ('apr-fc', 1, 'GK', 'Yvan Uzamuwe Ruhamyankiko', 'Rwanda', null, null),
      ('apr-fc', 2, 'GK', 'Jean Pierre Mario Ishimwe', 'Rwanda', 23, null),
      ('apr-fc', 3, 'GK', 'Pavelh Ndzila', 'DR Congo', 30, '185 cm'),
      ('apr-fc', 4, 'DEF', 'Clement Niyigena', 'Rwanda', 24, 'Best Player 2024/25'),
      ('apr-fc', 5, 'DEF', 'Claude Niyomugabo', 'Rwanda', 28, '174 cm'),
      ('apr-fc', 6, 'DEF', 'Dieudonne Ndayishimiye', 'Rwanda', 26, null),
      ('apr-fc', 7, 'DEF', 'Aliou Souane', 'Senegal', 24, null),
      ('apr-fc', 8, 'DEF', 'Yunusu Watara Nshimiyimana', 'Rwanda', 23, null),
      ('apr-fc', 9, 'DEF', 'Jean Gilbert Byiringiro', 'Rwanda', 25, 'Rwanda national team'),
      ('apr-fc', 10, 'MID', 'Taddeo Lwanga', 'Uganda', 31, '182 cm'),
      ('apr-fc', 11, 'MID', 'Richmond Lamptey', 'Ghana', 28, '176 cm'),
      ('apr-fc', 12, 'MID', 'Elie Kategaya', 'Rwanda', null, null),
      ('apr-fc', 13, 'MID', 'Arsene Tuyisenge', 'Rwanda', 25, null),
      ('apr-fc', 14, 'MID', 'Frodouard Mugiraneza', 'Rwanda', null, null),
      ('apr-fc', 15, 'MID', 'Dauda Yussif Seidu', 'Ghana', 24, null),
      ('apr-fc', 16, 'MID', 'Ramadhan Niyibizi', 'Rwanda', 25, 'Top scorer candidate'),
      ('apr-fc', 17, 'MID', 'Jean Rene Ishimwe', 'Rwanda', null, null),
      ('apr-fc', 18, 'FWD', 'Mahamadou Lamine Bah', 'Guinea', null, null),
      ('apr-fc', 19, 'FWD', 'Djibirl Ouattara', 'Ivory Coast', null, 'Best player finalist 2024/25')
  )
  insert into football.player_registrations as pr (
    player_id,
    team_id,
    season_id,
    squad_number,
    position,
    is_active,
    metadata
  )
  select
    p.id,
    t.id,
    v_season_id,
    pv.squad_number,
    pv.position,
    true,
    jsonb_strip_nulls(
      jsonb_build_object(
        'reported_age', pv.age_years,
        'notes', pv.notes
      )
    )
  from player_values pv
  join football.teams t
    on t.slug = pv.team_slug
  join football.players p
    on p.slug = lower(regexp_replace(pv.team_slug || '-' || pv.full_name, '[^a-z0-9]+', '-', 'g'))
  on conflict (player_id, team_id, season_id) do update
  set
    squad_number = excluded.squad_number,
    position = excluded.position,
    is_active = true,
    metadata = pr.metadata || excluded.metadata;
end
$$;
