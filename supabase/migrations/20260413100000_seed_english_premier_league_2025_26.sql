do $$
declare
  v_competition_id uuid;
  v_season_id uuid;
begin
  select id
    into v_competition_id
  from football.competitions
  where slug = 'english-premier-league';

  if v_competition_id is null then
    raise exception 'football.competitions row for english-premier-league is missing.';
  end if;

  select id
    into v_season_id
  from football.seasons
  where slug = 'english-premier-league-2025-2026';

  if v_season_id is null then
    raise exception 'football.seasons row for english-premier-league-2025-2026 is missing.';
  end if;

  update football.seasons
  set
    starts_on = date '2025-08-15',
    ends_on = date '2026-05-24',
    status = 'active',
    metadata = metadata || jsonb_build_object(
      'data_compiled_at', '2026-04-13',
      'snapshot_date', '2026-04-12',
      'defending_champions', 'Liverpool',
      'top_scorer', jsonb_build_object('name', 'Erling Haaland', 'goals', 22),
      'fixtures_scope', 'selected_matchdays',
      'sources', jsonb_build_array(
        'Wikipedia',
        'premierleague.com',
        'BBC Sport',
        'ESPN'
      ),
      'known_anomalies', jsonb_build_array(
        'Selected fixtures only; not a full season schedule.',
        'Provided source includes Southampton in GW1 as a fixture-only club reference.',
        'Provided source includes repeated Arsenal vs Manchester City and Leeds United vs Arsenal home fixtures.'
      )
    )
  where id = v_season_id;

  with team_values (
    slug,
    name,
    short_name,
    city,
    stadium,
    capacity,
    manager_name,
    captain_name,
    kit_supplier,
    country_code,
    country_name,
    register_for_season,
    team_note
  ) as (
    values
      ('arsenal', 'Arsenal', 'Arsenal', 'London (Holloway)', 'Emirates Stadium', 60704, 'Mikel Arteta', 'Martin Ødegaard', 'Adidas', 'ENG', 'England', true, null),
      ('aston-villa', 'Aston Villa', 'Aston Villa', 'Birmingham', 'Villa Park', 42785, 'Unai Emery', 'John McGinn', 'Adidas', 'ENG', 'England', true, null),
      ('bournemouth', 'Bournemouth', 'Bournemouth', 'Bournemouth', 'Vitality Stadium', 11307, 'Andoni Iraola', 'Adam Smith', 'Umbro', 'ENG', 'England', true, null),
      ('brentford', 'Brentford', 'Brentford', 'London (Brentford)', 'Brentford Community Stadium', 17250, 'Keith Andrews', 'Nathan Collins', 'Joma', 'ENG', 'England', true, null),
      ('brighton-hove-albion', 'Brighton & Hove Albion', 'Brighton', 'Falmer', 'Falmer Stadium (Amex)', 31876, 'Fabian Hürzeler', 'Lewis Dunk', 'Nike', 'ENG', 'England', true, null),
      ('burnley', 'Burnley', 'Burnley', 'Burnley', 'Turf Moor', 21944, 'Scott Parker', 'Josh Cullen', 'Castore', 'ENG', 'England', true, null),
      ('chelsea', 'Chelsea', 'Chelsea', 'London (Fulham)', 'Stamford Bridge', 40343, 'Liam Rosenior', 'Reece James', 'Nike', 'ENG', 'England', true, null),
      ('crystal-palace', 'Crystal Palace', 'Crystal Palace', 'London (Selhurst)', 'Selhurst Park', 25486, 'Oliver Glasner', 'Dean Henderson', 'Macron', 'ENG', 'England', true, null),
      ('everton', 'Everton', 'Everton', 'Liverpool (Vauxhall)', 'Hill Dickinson Stadium', 52888, 'David Moyes', 'Séamus Coleman', 'Castore', 'ENG', 'England', true, null),
      ('fulham', 'Fulham', 'Fulham', 'London (Fulham)', 'Craven Cottage', 25700, 'Marco Silva', 'Tom Cairney', 'Adidas', 'ENG', 'England', true, null),
      ('leeds-united', 'Leeds United', 'Leeds', 'Leeds', 'Elland Road', 37890, 'Daniel Farke', 'Ethan Ampadu', 'Adidas', 'ENG', 'England', true, null),
      ('liverpool', 'Liverpool', 'Liverpool', 'Liverpool (Anfield)', 'Anfield', 61276, 'Arne Slot', 'Virgil van Dijk', 'Adidas', 'ENG', 'England', true, 'Defending champions'),
      ('manchester-city', 'Manchester City', 'Man City', 'Manchester', 'Etihad Stadium', 55107, 'Pep Guardiola', 'Bernardo Silva', 'Puma', 'ENG', 'England', true, null),
      ('manchester-united', 'Manchester United', 'Man United', 'Trafford', 'Old Trafford', 74140, 'Michael Carrick', 'Bruno Fernandes', 'Adidas', 'ENG', 'England', true, null),
      ('newcastle-united', 'Newcastle United', 'Newcastle', 'Newcastle upon Tyne', 'St James'' Park', 52258, 'Eddie Howe', 'Bruno Guimarães', 'Adidas', 'ENG', 'England', true, null),
      ('nottingham-forest', 'Nottingham Forest', 'Forest', 'West Bridgford', 'City Ground', 30445, 'Vítor Pereira', 'Ryan Yates', 'Adidas', 'ENG', 'England', true, null),
      ('sunderland', 'Sunderland', 'Sunderland', 'Sunderland', 'Stadium of Light', 49000, 'Régis Le Bris', 'Granit Xhaka', 'Hummel', 'ENG', 'England', true, null),
      ('tottenham-hotspur', 'Tottenham Hotspur', 'Tottenham', 'London (Tottenham)', 'Tottenham Hotspur Stadium', 62850, 'Igor Tudor', 'Cristian Romero', 'Nike', 'ENG', 'England', true, null),
      ('west-ham-united', 'West Ham United', 'West Ham', 'London (Stratford)', 'London Stadium', 62500, 'Nuno Espírito Santo', 'Jarrod Bowen', 'Umbro', 'ENG', 'England', true, null),
      ('wolverhampton-wanderers', 'Wolverhampton Wanderers', 'Wolves', 'Wolverhampton', 'Molineux Stadium', 32050, 'Rob Edwards', 'Toti Gomes', 'Sudu', 'ENG', 'England', true, 'Kit supplier preserved exactly as provided in source pack.'),
      ('southampton', 'Southampton', 'Southampton', 'Southampton', null, null, null, null, null, 'ENG', 'England', false, 'Fixture-only club reference from supplied selected matchdays; not registered in the provided 2025/26 team list.')
  )
  insert into football.teams as t (
    slug,
    name,
    short_name,
    team_type,
    country_code,
    country_name,
    city,
    metadata
  )
  select
    tv.slug,
    tv.name,
    tv.short_name,
    'club'::football.team_type,
    tv.country_code,
    tv.country_name,
    tv.city,
    jsonb_strip_nulls(
      jsonb_build_object(
        'stadium', tv.stadium,
        'capacity', tv.capacity,
        'manager_name', tv.manager_name,
        'captain_name', tv.captain_name,
        'kit_supplier', tv.kit_supplier,
        'team_note', tv.team_note
      )
    )
  from team_values tv
  on conflict (slug) do update
  set
    name = excluded.name,
    short_name = excluded.short_name,
    country_code = excluded.country_code,
    country_name = excluded.country_name,
    city = excluded.city,
    is_active = true,
    metadata = t.metadata || excluded.metadata;

  with season_team_values (team_slug, seeded_rank) as (
    values
      ('arsenal', 1),
      ('aston-villa', 2),
      ('bournemouth', 3),
      ('brentford', 4),
      ('brighton-hove-albion', 5),
      ('burnley', 6),
      ('chelsea', 7),
      ('crystal-palace', 8),
      ('everton', 9),
      ('fulham', 10),
      ('leeds-united', 11),
      ('liverpool', 12),
      ('manchester-city', 13),
      ('manchester-united', 14),
      ('newcastle-united', 15),
      ('nottingham-forest', 16),
      ('sunderland', 17),
      ('tottenham-hotspur', 18),
      ('west-ham-united', 19),
      ('wolverhampton-wanderers', 20)
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
    jsonb_build_object('source', 'manual-epl-2025-26-pack')
  from season_team_values stv
  join football.teams t
    on t.slug = stv.team_slug
  on conflict (season_id, team_id) do update
  set
    seeded_rank = excluded.seeded_rank,
    is_active = true,
    metadata = st.metadata || excluded.metadata;

  with standings_values (
    position,
    team_slug,
    played,
    won,
    drawn,
    lost,
    goals_for,
    goals_against,
    goal_difference,
    points,
    status_text
  ) as (
    values
      (1, 'arsenal', 29, 19, 7, 3, 56, 21, 35, 64, 'Champions League'),
      (2, 'manchester-city', 28, 18, 5, 5, 57, 25, 32, 59, 'Champions League'),
      (3, 'manchester-united', 28, 14, 9, 5, 50, 38, 12, 51, 'Champions League'),
      (4, 'aston-villa', 28, 15, 6, 7, 38, 30, 8, 51, 'Champions League'),
      (5, 'liverpool', 28, 14, 6, 8, 47, 37, 10, 48, 'Europa League'),
      (6, 'chelsea', 28, 12, 9, 7, 48, 31, 17, 45, 'Conference League (possible)'),
      (7, 'brentford', 28, 13, 4, 11, 44, 40, 4, 43, null),
      (8, 'everton', 28, 11, 7, 10, 32, 33, -1, 40, null),
      (9, 'fulham', 28, 12, 4, 12, 40, 42, -2, 40, null),
      (10, 'bournemouth', 28, 9, 12, 7, 44, 46, -2, 39, null),
      (11, 'brighton-hove-albion', 28, 9, 10, 9, 38, 35, 3, 37, null),
      (12, 'sunderland', 28, 9, 10, 9, 29, 34, -5, 37, null),
      (13, 'newcastle-united', 28, 10, 6, 12, 40, 42, -2, 36, null),
      (14, 'crystal-palace', 28, 9, 8, 11, 30, 34, -4, 35, null),
      (15, 'leeds-united', 28, 7, 10, 11, 37, 47, -10, 31, null),
      (16, 'tottenham-hotspur', 28, 7, 8, 13, 38, 43, -5, 29, null),
      (17, 'nottingham-forest', 28, 7, 6, 15, 26, 41, -15, 27, null),
      (18, 'west-ham-united', 28, 6, 7, 15, 34, 54, -20, 25, 'Relegation zone'),
      (19, 'burnley', 28, 4, 7, 17, 32, 56, -24, 19, 'Relegation zone'),
      (20, 'wolverhampton-wanderers', 29, 2, 7, 20, 20, 51, -31, 13, 'Relegation zone')
  )
  insert into football.standings as std (
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
    sv.played,
    sv.won,
    sv.drawn,
    sv.lost,
    sv.goals_for,
    sv.goals_against,
    sv.goal_difference,
    sv.points,
    sv.status_text,
    jsonb_strip_nulls(
      jsonb_build_object(
        'snapshot_date', '2026-04-12',
        'snapshot_matchweek', 29,
        'table_status', sv.status_text
      )
    )
  from standings_values sv
  join football.teams t
    on t.slug = sv.team_slug
  on conflict (season_id, stage_name, group_name, team_id) do update
  set
    position = excluded.position,
    played = excluded.played,
    won = excluded.won,
    drawn = excluded.drawn,
    lost = excluded.lost,
    goals_for = excluded.goals_for,
    goals_against = excluded.goals_against,
    goal_difference = excluded.goal_difference,
    points = excluded.points,
    notes = excluded.notes,
    metadata = std.metadata || excluded.metadata;

  with fixture_values (
    gw_label,
    match_date_text,
    home_slug,
    away_slug,
    home_score,
    away_score,
    status_text,
    venue_name
  ) as (
    values
      ('1', '15 Aug 2025', 'manchester-united', 'fulham', 1, 0, 'FT', 'Old Trafford'),
      ('1', '15 Aug 2025', 'arsenal', 'brentford', 2, 0, 'FT', 'Emirates Stadium'),
      ('1', '15 Aug 2025', 'chelsea', 'burnley', 1, 1, 'FT', 'Stamford Bridge'),
      ('1', '15 Aug 2025', 'everton', 'brighton-hove-albion', 0, 3, 'FT', 'Hill Dickinson Stadium'),
      ('1', '15 Aug 2025', 'liverpool', 'sunderland', 2, 0, 'FT', 'Anfield'),
      ('1', '16 Aug 2025', 'wolverhampton-wanderers', 'manchester-city', 0, 4, 'FT', 'Molineux Stadium'),
      ('1', '16 Aug 2025', 'crystal-palace', 'aston-villa', 1, 1, 'FT', 'Selhurst Park'),
      ('1', '16 Aug 2025', 'newcastle-united', 'southampton', 2, 1, 'FT', 'St James'' Park'),
      ('1', '16 Aug 2025', 'nottingham-forest', 'bournemouth', 0, 1, 'FT', 'City Ground'),
      ('1', '16 Aug 2025', 'west-ham-united', 'leeds-united', 0, 1, 'FT', 'London Stadium'),
      ('2', '22 Aug 2025', 'arsenal', 'leeds-united', 5, 0, 'FT', 'Emirates Stadium'),
      ('2', '22 Aug 2025', 'west-ham-united', 'chelsea', 1, 5, 'FT', 'London Stadium'),
      ('2', '23 Aug 2025', 'manchester-city', 'newcastle-united', 2, 1, 'FT', 'Etihad Stadium'),
      ('2', '23 Aug 2025', 'liverpool', 'brentford', 3, 0, 'FT', 'Anfield'),
      ('3', '30 Aug 2025', 'manchester-united', 'burnley', 3, 2, 'FT', 'Old Trafford'),
      ('3', '30 Aug 2025', 'tottenham-hotspur', 'newcastle-united', 2, 1, 'FT', 'Tottenham Hotspur Stadium'),
      ('3', '31 Aug 2025', 'arsenal', 'fulham', 1, 0, 'FT', 'Emirates Stadium'),
      ('3', '31 Aug 2025', 'leeds-united', 'arsenal', 0, 4, 'FT', 'Elland Road'),
      ('4', '14 Sep 2025', 'arsenal', 'manchester-city', 2, 0, 'FT', 'Emirates Stadium'),
      ('4', '14 Sep 2025', 'liverpool', 'nottingham-forest', 3, 1, 'FT', 'Anfield'),
      ('5', '20 Sep 2025', 'arsenal', 'manchester-city', 1, 1, 'FT', 'Emirates Stadium'),
      ('5', '21 Sep 2025', 'brentford', 'liverpool', 3, 2, 'FT', 'Brentford Community Stadium'),
      ('5', '21 Sep 2025', 'chelsea', 'sunderland', 1, 2, 'FT', 'Stamford Bridge'),
      ('5', '21 Sep 2025', 'manchester-united', 'brighton-hove-albion', 4, 2, 'FT', 'Old Trafford'),
      ('6', '27 Sep 2025', 'newcastle-united', 'fulham', 2, 1, 'FT', 'St James'' Park'),
      ('6', '28 Sep 2025', 'arsenal', 'newcastle-united', 1, 2, 'FT', 'Emirates Stadium'),
      ('7', '04 Oct 2025', 'bournemouth', 'nottingham-forest', 2, 0, 'FT', 'Vitality Stadium'),
      ('7', '05 Oct 2025', 'aston-villa', 'manchester-city', 1, 0, 'FT', 'Villa Park'),
      ('7', '05 Oct 2025', 'arsenal', 'crystal-palace', 1, 0, 'FT', 'Emirates Stadium'),
      ('7', '05 Oct 2025', 'wolverhampton-wanderers', 'burnley', 2, 3, 'FT', 'Molineux Stadium'),
      ('7', '06 Oct 2025', 'everton', 'tottenham-hotspur', 0, 3, 'FT', 'Hill Dickinson Stadium'),
      ('8', '18 Oct 2025', 'crystal-palace', 'bournemouth', 3, 3, 'FT', 'Selhurst Park'),
      ('8', '18 Oct 2025', 'nottingham-forest', 'chelsea', 0, 3, 'FT', 'City Ground'),
      ('8', '19 Oct 2025', 'west-ham-united', 'brentford', 0, 2, 'FT', 'London Stadium'),
      ('9', '24 Oct 2025', 'leeds-united', 'west-ham-united', 2, 1, 'FT', 'Elland Road'),
      ('9', '25 Oct 2025', 'chelsea', 'sunderland', 1, 2, 'FT', 'Stamford Bridge'),
      ('9', '25 Oct 2025', 'newcastle-united', 'fulham', 2, 1, 'FT', 'St James'' Park'),
      ('9', '25 Oct 2025', 'brentford', 'liverpool', 3, 2, 'FT', 'Brentford Community Stadium'),
      ('10', '01 Nov 2025', 'arsenal', 'burnley', 2, 0, 'FT', 'Emirates Stadium'),
      ('10', '01 Nov 2025', 'everton', 'arsenal', 0, 1, 'FT', 'Hill Dickinson Stadium'),
      ('11', '08 Nov 2025', 'arsenal', 'tottenham-hotspur', 4, 1, 'FT', 'Emirates Stadium'),
      ('11', '09 Nov 2025', 'manchester-city', 'chelsea', 3, 1, 'FT', 'Etihad Stadium'),
      ('12', '22 Nov 2025', 'arsenal', 'liverpool', 2, 0, 'FT', 'Emirates Stadium'),
      ('12', '23 Nov 2025', 'liverpool', 'wolverhampton-wanderers', 2, 1, 'FT', 'Anfield'),
      ('13', '29 Nov 2025', 'chelsea', 'arsenal', 1, 1, 'FT', 'Stamford Bridge'),
      ('13', '30 Nov 2025', 'fulham', 'manchester-city', 4, 5, 'FT', 'Craven Cottage'),
      ('14', '03 Dec 2025', 'arsenal', 'brentford', 3, 0, 'FT', 'Emirates Stadium'),
      ('15', '20 Dec 2025', 'newcastle-united', 'chelsea', 2, 2, 'FT', 'St James'' Park'),
      ('15', '20 Dec 2025', 'bournemouth', 'burnley', 1, 1, 'FT', 'Vitality Stadium'),
      ('15', '20 Dec 2025', 'manchester-city', 'west-ham-united', 3, 0, 'FT', 'Etihad Stadium'),
      ('15', '20 Dec 2025', 'tottenham-hotspur', 'liverpool', 1, 2, 'FT', 'Tottenham Hotspur Stadium'),
      ('15', '20 Dec 2025', 'everton', 'arsenal', 0, 1, 'FT', 'Hill Dickinson Stadium'),
      ('15', '20 Dec 2025', 'leeds-united', 'crystal-palace', 4, 1, 'FT', 'Elland Road'),
      ('15', '21 Dec 2025', 'aston-villa', 'manchester-united', 2, 1, 'FT', 'Villa Park'),
      ('15', '22 Dec 2025', 'fulham', 'nottingham-forest', 1, 0, 'FT', 'Craven Cottage'),
      ('16', '26 Dec 2025', 'manchester-united', 'newcastle-united', 1, 0, 'FT', 'Old Trafford'),
      ('16', '27 Dec 2025', 'nottingham-forest', 'manchester-city', 1, 2, 'FT', 'City Ground'),
      ('16', '27 Dec 2025', 'arsenal', 'brighton-hove-albion', 2, 1, 'FT', 'Emirates Stadium'),
      ('16', '27 Dec 2025', 'brentford', 'bournemouth', 4, 1, 'FT', 'Brentford Community Stadium'),
      ('16', '27 Dec 2025', 'burnley', 'everton', 0, 0, 'FT', 'Turf Moor'),
      ('16', '27 Dec 2025', 'liverpool', 'wolverhampton-wanderers', 2, 1, 'FT', 'Anfield'),
      ('17', '31 Jan 2026', 'leeds-united', 'arsenal', 0, 4, 'FT', 'Elland Road'),
      ('18', '04 Jan 2026', 'brentford', 'everton', 4, 2, 'FT', 'Brentford Community Stadium'),
      ('18', '04 Jan 2026', 'chelsea', 'wolverhampton-wanderers', 3, 1, 'FT', 'Stamford Bridge'),
      ('23', '07 Feb 2026', 'chelsea', 'wolverhampton-wanderers', 3, 1, 'FT', 'Stamford Bridge'),
      ('24', '21 Feb 2026', 'arsenal', 'sunderland', 2, 0, 'FT', 'Emirates Stadium'),
      ('24', '22 Feb 2026', 'manchester-city', 'aston-villa', 2, 0, 'FT', 'Etihad Stadium'),
      ('25', '01 Mar 2026', 'arsenal', 'west-ham-united', 3, 0, 'FT', 'Emirates Stadium'),
      ('25', '02 Mar 2026', 'manchester-city', 'liverpool', 1, 0, 'FT', 'Etihad Stadium'),
      ('GW30', '13 Rayon Sports 2026', 'leeds-united', 'arsenal', null, null, 'SCH', 'Elland Road'),
      ('GW30', '13 Rayon Sports 2026', 'chelsea', 'manchester-city', null, null, 'SCH', 'Stamford Bridge'),
      ('GW30', '13 Rayon Sports 2026', 'liverpool', 'fulham', null, null, 'SCH', 'Anfield'),
      ('GW30', '13 Rayon Sports 2026', 'newcastle-united', 'bournemouth', null, null, 'SCH', 'St James'' Park'),
      ('GW30', '13 Rayon Sports 2026', 'sunderland', 'tottenham-hotspur', null, null, 'SCH', 'Stadium of Light'),
      ('GW30', '14 Rayon Sports 2026', 'brighton-hove-albion', 'west-ham-united', null, null, 'SCH', 'Falmer Stadium'),
      ('GW30', '14 Rayon Sports 2026', 'brentford', 'everton', null, null, 'SCH', 'Brentford Community Stadium'),
      ('GW30', '14 Rayon Sports 2026', 'burnley', 'crystal-palace', null, null, 'SCH', 'Turf Moor'),
      ('GW30', '14 Rayon Sports 2026', 'manchester-united', 'nottingham-forest', null, null, 'SCH', 'Old Trafford'),
      ('GW30', '14 Rayon Sports 2026', 'aston-villa', 'wolverhampton-wanderers', null, null, 'SCH', 'Villa Park'),
      ('GW31', '20 Rayon Sports 2026', 'crystal-palace', 'west-ham-united', null, null, 'SCH', 'Selhurst Park'),
      ('GW31', '24 Rayon Sports 2026', 'sunderland', 'nottingham-forest', null, null, 'SCH', 'Stadium of Light'),
      ('GW31', '25 Rayon Sports 2026', 'arsenal', 'newcastle-united', null, null, 'SCH', 'Emirates Stadium'),
      ('GW31', '25 Rayon Sports 2026', 'liverpool', 'crystal-palace', null, null, 'SCH', 'Anfield'),
      ('GW31', '26 Rayon Sports 2026', 'burnley', 'manchester-city', null, null, 'SCH', 'Turf Moor'),
      ('GW31', '26 Rayon Sports 2026', 'brighton-hove-albion', 'chelsea', null, null, 'SCH', 'Falmer Stadium'),
      ('GW31', '27 Rayon Sports 2026', 'manchester-united', 'brentford', null, null, 'SCH', 'Old Trafford'),
      ('GW32', '02 May 2026', 'arsenal', 'fulham', null, null, 'SCH', 'Emirates Stadium'),
      ('GW32', '02 May 2026', 'newcastle-united', 'brighton-hove-albion', null, null, 'SCH', 'St James'' Park'),
      ('GW32', '02 May 2026', 'aston-villa', 'tottenham-hotspur', null, null, 'SCH', 'Villa Park'),
      ('GW33', '09 May 2026', null, null, null, null, 'SCH', 'Various'),
      ('GW38', '24 May 2026', 'arsenal', 'everton', null, null, 'SCH', 'Emirates Stadium'),
      ('GW38', '24 May 2026', 'manchester-city', 'brentford', null, null, 'SCH', 'Etihad Stadium'),
      ('GW38', '24 May 2026', 'liverpool', 'nottingham-forest', null, null, 'SCH', 'Anfield'),
      ('GW38', '24 May 2026', 'chelsea', 'newcastle-united', null, null, 'SCH', 'Stamford Bridge'),
      ('GW38', '24 May 2026', 'wolverhampton-wanderers', 'tottenham-hotspur', null, null, 'SCH', 'Molineux Stadium'),
      ('GW38', '24 May 2026', 'burnley', 'west-ham-united', null, null, 'SCH', 'Turf Moor'),
      ('GW38', '24 May 2026', 'sunderland', 'leeds-united', null, null, 'SCH', 'Stadium of Light'),
      ('GW38', '24 May 2026', 'brighton-hove-albion', 'aston-villa', null, null, 'SCH', 'Falmer Stadium'),
      ('GW38', '24 May 2026', 'fulham', 'manchester-united', null, null, 'SCH', 'Craven Cottage'),
      ('GW38', '24 May 2026', 'crystal-palace', 'bournemouth', null, null, 'SCH', 'Selhurst Park')
  )
  insert into football.fixtures as fx (
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
    'regular_season',
    '',
    case
      when fv.gw_label ~ '^GW[0-9]+$' then replace(fv.gw_label, 'GW', 'Gameweek ')
      else format('Gameweek %s', fv.gw_label)
    end,
    case
      when regexp_replace(fv.gw_label, '\D', '', 'g') <> '' then regexp_replace(fv.gw_label, '\D', '', 'g')::integer
      else null
    end,
    (to_date(fv.match_date_text, 'DD Mon YYYY')::timestamp + interval '15 hour') at time zone 'Europe/London',
    fv.venue_name,
    ht.id,
    at.id,
    fv.home_score,
    fv.away_score,
    case fv.status_text
      when 'FT' then 'finished'::football.fixture_status
      when 'SCH' then 'scheduled'::football.fixture_status
      else 'scheduled'::football.fixture_status
    end,
    'manual-premier-league-2025-26',
    format(
      'epl-2025-26-%s-%s-%s-%s',
      lower(fv.gw_label),
      to_char(to_date(fv.match_date_text, 'DD Mon YYYY'), 'YYYYMMDD'),
      fv.home_slug,
      fv.away_slug
    ),
    jsonb_build_object(
      'status_source', fv.status_text,
      'fixture_scope', 'selected_matchdays',
      'compiled_at', '2026-04-13'
    )
  from fixture_values fv
  join football.teams ht
    on ht.slug = fv.home_slug
  join football.teams at
    on at.slug = fv.away_slug
  where fv.home_slug is not null
    and fv.away_slug is not null
  on conflict (external_provider, external_fixture_id) do update
  set
    round_name = excluded.round_name,
    matchday = excluded.matchday,
    kickoff_at = excluded.kickoff_at,
    venue_name = excluded.venue_name,
    home_team_id = excluded.home_team_id,
    away_team_id = excluded.away_team_id,
    home_score = excluded.home_score,
    away_score = excluded.away_score,
    status = excluded.status,
    metadata = fx.metadata || excluded.metadata;
end
$$;
