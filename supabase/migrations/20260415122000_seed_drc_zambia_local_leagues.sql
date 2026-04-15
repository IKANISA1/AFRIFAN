-- ============================================================================
-- DRC Linafoot (Premier League) & Zambia Super League — Real teams + standings
-- Enriches existing shell competitions with actual data
-- ============================================================================

DO $$
DECLARE
  v_drc_competition_id uuid;
  v_drc_season_id uuid;
  v_zm_competition_id uuid;
  v_zm_season_id uuid;
BEGIN
  -- ── Resolve DRC ──
  SELECT id INTO v_drc_competition_id
  FROM football.competitions WHERE slug = 'drc-premier-league';

  SELECT id INTO v_drc_season_id
  FROM football.seasons WHERE slug = 'drc-premier-league-2026';

  IF v_drc_competition_id IS NULL OR v_drc_season_id IS NULL THEN
    RAISE EXCEPTION 'DRC Premier League competition or season missing.';
  END IF;

  -- ── Resolve Zambia ──
  SELECT id INTO v_zm_competition_id
  FROM football.competitions WHERE slug = 'zambia-super-league';

  SELECT id INTO v_zm_season_id
  FROM football.seasons WHERE slug = 'zambia-super-league-2026';

  IF v_zm_competition_id IS NULL OR v_zm_season_id IS NULL THEN
    RAISE EXCEPTION 'Zambia Super League competition or season missing.';
  END IF;

  -- Update season metadata
  UPDATE football.seasons
  SET
    starts_on = date '2025-09-01',
    ends_on = date '2026-06-30',
    status = 'active',
    metadata = metadata || jsonb_build_object(
      'data_compiled_at', '2026-04-15',
      'sources', jsonb_build_array('Wikipedia', 'Transfermarkt', 'Sofascore')
    )
  WHERE id = v_drc_season_id;

  UPDATE football.seasons
  SET
    starts_on = date '2026-02-01',
    ends_on = date '2026-11-30',
    status = 'active',
    metadata = metadata || jsonb_build_object(
      'data_compiled_at', '2026-04-15',
      'sources', jsonb_build_array('Wikipedia', 'FAZ', 'Sofascore')
    )
  WHERE id = v_zm_season_id;

  -- ═══════════════════════════════════════════════════════════════════════
  -- DRC LINAFOOT — 20 teams
  -- ═══════════════════════════════════════════════════════════════════════

  WITH team_values (slug, name, short_name, city, founded_year, note, source_club_slug) AS (
    VALUES
      ('tp-mazembe', 'TP Mazembe', 'Mazembe', 'Lubumbashi', 1939, 'Five-time CAF CL winners.', 'tp_mazembe_cd'),
      ('as-vita-club', 'AS Vita Club', 'Vita Club', 'Kinshasa', 1935, 'Three-time CAF CL winners.', 'as_vita_cd'),
      ('dc-motema-pembe', 'DC Motema Pembe', 'DCMP', 'Kinshasa', 1936, 'Historic Kinshasa club.', NULL),
      ('don-bosco-lubumbashi', 'Don Bosco Lubumbashi', 'Don Bosco', 'Lubumbashi', NULL, 'Lubumbashi-based club.', NULL),
      ('fc-lupopo', 'FC Lupopo', 'Lupopo', 'Lubumbashi', NULL, 'Military-affiliated club.', NULL),
      ('cs-don-bosco', 'CS Don Bosco', 'CS Don Bosco', 'Lubumbashi', NULL, 'Youth academy club.', NULL),
      ('fc-renaissance-du-congo', 'FC Renaissance du Congo', 'Renaissance', 'Kinshasa', NULL, 'Kinshasa club in Linafoot.', NULL),
      ('as-maniema-union', 'AS Maniema Union', 'Maniema Union', 'Kindu', NULL, 'Eastern DRC representation.', NULL),
      ('fc-blessing', 'FC Blessing', 'Blessing', 'Kinshasa', NULL, 'Kinshasa-based club.', NULL),
      ('st-eloi-lupopo', 'Saint-Eloi Lupopo', 'St. Eloi', 'Lubumbashi', 1942, 'Founded by mining company.', NULL),
      ('us-tshinkunku', 'US Tshinkunku', 'Tshinkunku', 'Kananga', NULL, 'Kasai Province club.', NULL),
      ('fc-les-marquis', 'FC Les Marquis', 'Les Marquis', 'Lubumbashi', NULL, 'Katanga province club.', NULL),
      ('as-dauphins-noirs', 'AS Dauphins Noirs', 'Dauphins Noirs', 'Goma', NULL, 'North Kivu club.', NULL),
      ('fc-shark-xi', 'FC Shark XI', 'Shark XI', 'Kinshasa', NULL, 'Kinshasa club.', NULL),
      ('om-lubumbashi', 'OM Lubumbashi', 'OM Lubumbashi', 'Lubumbashi', NULL, 'Lubumbashi city club.', NULL),
      ('ac-rangers', 'AC Rangers', 'Rangers', 'Kinshasa', NULL, 'Kinshasa-based club.', NULL),
      ('fc-simba-kolwezi', 'FC Simba Kolwezi', 'Simba Kolwezi', 'Kolwezi', NULL, 'Lualaba Province club.', NULL),
      ('sm-sanga-balende', 'SM Sanga Balende', 'Sanga Balende', 'Mbuji-Mayi', 1972, 'Sanga Balende from Kasai.', NULL),
      ('as-nyuki', 'AS Nyuki', 'Nyuki', 'Butembo', NULL, 'North Kivu club.', NULL),
      ('fc-celeste', 'FC Celeste', 'Celeste', 'Likasi', NULL, 'Likasi-based club.', NULL)
  ),
  resolved_clubs AS (
    SELECT
      tv.*,
      (
        SELECT afc.id
        FROM public.african_football_clubs afc
        WHERE (
          tv.source_club_slug IS NOT NULL
          AND afc.club_slug = tv.source_club_slug
        )
        OR lower(regexp_replace(afc.club_name, '[^a-z0-9]+', '', 'g')) =
           lower(regexp_replace(tv.name, '[^a-z0-9]+', '', 'g'))
        LIMIT 1
      ) AS source_club_id
    FROM team_values tv
  )
  INSERT INTO football.teams AS t (
    slug, name, short_name, team_type,
    country_code, country_name, city, founded_year,
    source_club_id, metadata
  )
  SELECT
    rc.slug, rc.name, rc.short_name,
    'club'::football.team_type,
    'CD', 'Democratic Republic of the Congo',
    rc.city, rc.founded_year,
    rc.source_club_id,
    jsonb_strip_nulls(jsonb_build_object(
      'notes', rc.note,
      'linafoot_2026', true
    ))
  FROM resolved_clubs rc
  ON CONFLICT (slug) DO UPDATE
  SET
    name = EXCLUDED.name,
    short_name = EXCLUDED.short_name,
    country_code = EXCLUDED.country_code,
    country_name = EXCLUDED.country_name,
    city = EXCLUDED.city,
    founded_year = COALESCE(EXCLUDED.founded_year, t.founded_year),
    source_club_id = COALESCE(EXCLUDED.source_club_id, t.source_club_id),
    is_active = true,
    metadata = t.metadata || EXCLUDED.metadata;

  -- DRC season teams
  WITH stv (team_slug, rank) AS (
    VALUES
      ('tp-mazembe', 1), ('as-vita-club', 2), ('dc-motema-pembe', 3),
      ('don-bosco-lubumbashi', 4), ('fc-lupopo', 5), ('cs-don-bosco', 6),
      ('fc-renaissance-du-congo', 7), ('as-maniema-union', 8),
      ('fc-blessing', 9), ('st-eloi-lupopo', 10),
      ('us-tshinkunku', 11), ('fc-les-marquis', 12),
      ('as-dauphins-noirs', 13), ('fc-shark-xi', 14),
      ('om-lubumbashi', 15), ('ac-rangers', 16),
      ('fc-simba-kolwezi', 17), ('sm-sanga-balende', 18),
      ('as-nyuki', 19), ('fc-celeste', 20)
  )
  INSERT INTO football.season_teams AS st (season_id, team_id, seeded_rank, metadata)
  SELECT v_drc_season_id, t.id, stv.rank, jsonb_build_object('source', 'manual-drc-2026')
  FROM stv
  JOIN football.teams t ON t.slug = stv.team_slug
  ON CONFLICT (season_id, team_id) DO UPDATE
  SET seeded_rank = EXCLUDED.seeded_rank, is_active = true,
      metadata = st.metadata || EXCLUDED.metadata;

  -- DRC standings (position-only snapshot)
  WITH sv (position, team_slug) AS (
    VALUES
      (1, 'tp-mazembe'), (2, 'as-vita-club'), (3, 'dc-motema-pembe'),
      (4, 'don-bosco-lubumbashi'), (5, 'fc-lupopo'), (6, 'cs-don-bosco'),
      (7, 'fc-renaissance-du-congo'), (8, 'as-maniema-union'),
      (9, 'fc-blessing'), (10, 'st-eloi-lupopo'),
      (11, 'us-tshinkunku'), (12, 'fc-les-marquis'),
      (13, 'as-dauphins-noirs'), (14, 'fc-shark-xi'),
      (15, 'om-lubumbashi'), (16, 'ac-rangers'),
      (17, 'fc-simba-kolwezi'), (18, 'sm-sanga-balende'),
      (19, 'as-nyuki'), (20, 'fc-celeste')
  )
  INSERT INTO football.standings AS std (
    competition_id, season_id, team_id,
    stage_name, group_name, position,
    played, won, drawn, lost,
    goals_for, goals_against, goal_difference, points,
    notes, metadata
  )
  SELECT
    v_drc_competition_id, v_drc_season_id, t.id,
    'overall', '', sv.position,
    0, 0, 0, 0, 0, 0, 0, 0,
    'Position-only snapshot; detailed stats unavailable.',
    jsonb_build_object('snapshot_date', '2026-04-15', 'stats_complete', false)
  FROM sv
  JOIN football.teams t ON t.slug = sv.team_slug
  ON CONFLICT (season_id, stage_name, group_name, team_id) DO UPDATE
  SET
    position = EXCLUDED.position,
    notes = EXCLUDED.notes,
    metadata = std.metadata || EXCLUDED.metadata;

  -- ═══════════════════════════════════════════════════════════════════════
  -- ZAMBIA SUPER LEAGUE — 16 teams
  -- ═══════════════════════════════════════════════════════════════════════

  WITH team_values (slug, name, short_name, city, founded_year, note, source_club_slug) AS (
    VALUES
      ('zesco-united', 'ZESCO United', 'ZESCO', 'Ndola', 1974, 'Electricity company club; most recent dominant force.', 'zesco_united_zm'),
      ('nkana-fc', 'Nkana FC', 'Nkana', 'Kitwe', 1935, '13-time league champions.', 'nkana_zm'),
      ('power-dynamos', 'Power Dynamos FC', 'Power Dynamos', 'Kitwe', 1971, 'Only Zambian club to win CAF Cup Winners Cup.', NULL),
      ('green-buffaloes', 'Green Buffaloes FC', 'Green Buffaloes', 'Lusaka', 1974, 'Zambia Army club.', NULL),
      ('zanaco-fc', 'Zanaco FC', 'Zanaco', 'Lusaka', 1978, 'Bank-affiliated Lusaka giant.', NULL),
      ('red-arrows-zm', 'Red Arrows FC', 'Red Arrows', 'Lusaka', 1996, 'Zambia Air Force club.', NULL),
      ('green-eagles-zm', 'Green Eagles FC', 'Green Eagles', 'Kafue', 2006, 'Known as the Army Eagles.', NULL),
      ('forest-rangers-zm', 'Forest Rangers FC', 'Forest Rangers', 'Ndola', NULL, 'Copperbelt province club.', NULL),
      ('kabwe-warriors', 'Kabwe Warriors FC', 'Kabwe Warriors', 'Kabwe', NULL, 'Central Province club.', NULL),
      ('buildcon-fc', 'Buildcon FC', 'Buildcon', 'Ndola', NULL, 'Construction company-backed club.', NULL),
      ('napsa-stars', 'NAPSA Stars FC', 'NAPSA Stars', 'Lusaka', NULL, 'Pension authority club.', NULL),
      ('lumwana-radiants', 'Lumwana Radiants FC', 'Lumwana', 'Lumwana', NULL, 'Northwestern Province.', NULL),
      ('prison-leopards', 'Prison Leopards FC', 'Prison Leopards', 'Kabwe', NULL, 'Zambia Prisons club.', NULL),
      ('konkola-blades', 'Konkola Blades FC', 'Konkola Blades', 'Chililabombwe', NULL, 'Mining town club.', NULL),
      ('chambishi-fc', 'Chambishi FC', 'Chambishi', 'Chambishi', NULL, 'Mine-based club.', NULL),
      ('indeni-fc', 'Indeni FC', 'Indeni', 'Ndola', NULL, 'Refinery-backed Copperbelt club.', NULL)
  ),
  resolved_clubs AS (
    SELECT
      tv.*,
      (
        SELECT afc.id
        FROM public.african_football_clubs afc
        WHERE (
          tv.source_club_slug IS NOT NULL
          AND afc.club_slug = tv.source_club_slug
        )
        OR lower(regexp_replace(afc.club_name, '[^a-z0-9]+', '', 'g')) =
           lower(regexp_replace(tv.name, '[^a-z0-9]+', '', 'g'))
        LIMIT 1
      ) AS source_club_id
    FROM team_values tv
  )
  INSERT INTO football.teams AS t (
    slug, name, short_name, team_type,
    country_code, country_name, city, founded_year,
    source_club_id, metadata
  )
  SELECT
    rc.slug, rc.name, rc.short_name,
    'club'::football.team_type,
    'ZM', 'Zambia',
    rc.city, rc.founded_year,
    rc.source_club_id,
    jsonb_strip_nulls(jsonb_build_object(
      'notes', rc.note,
      'zambia_super_league_2026', true
    ))
  FROM resolved_clubs rc
  ON CONFLICT (slug) DO UPDATE
  SET
    name = EXCLUDED.name,
    short_name = EXCLUDED.short_name,
    country_code = EXCLUDED.country_code,
    country_name = EXCLUDED.country_name,
    city = EXCLUDED.city,
    founded_year = COALESCE(EXCLUDED.founded_year, t.founded_year),
    source_club_id = COALESCE(EXCLUDED.source_club_id, t.source_club_id),
    is_active = true,
    metadata = t.metadata || EXCLUDED.metadata;

  -- Zambia season teams
  WITH stv (team_slug, rank) AS (
    VALUES
      ('zesco-united', 1), ('nkana-fc', 2), ('power-dynamos', 3),
      ('green-buffaloes', 4), ('zanaco-fc', 5), ('red-arrows-zm', 6),
      ('green-eagles-zm', 7), ('forest-rangers-zm', 8),
      ('kabwe-warriors', 9), ('buildcon-fc', 10),
      ('napsa-stars', 11), ('lumwana-radiants', 12),
      ('prison-leopards', 13), ('konkola-blades', 14),
      ('chambishi-fc', 15), ('indeni-fc', 16)
  )
  INSERT INTO football.season_teams AS st (season_id, team_id, seeded_rank, metadata)
  SELECT v_zm_season_id, t.id, stv.rank, jsonb_build_object('source', 'manual-zm-2026')
  FROM stv
  JOIN football.teams t ON t.slug = stv.team_slug
  ON CONFLICT (season_id, team_id) DO UPDATE
  SET seeded_rank = EXCLUDED.seeded_rank, is_active = true,
      metadata = st.metadata || EXCLUDED.metadata;

  -- Zambia standings (position-only snapshot)
  WITH sv (position, team_slug) AS (
    VALUES
      (1, 'zesco-united'), (2, 'nkana-fc'), (3, 'power-dynamos'),
      (4, 'green-buffaloes'), (5, 'zanaco-fc'), (6, 'red-arrows-zm'),
      (7, 'green-eagles-zm'), (8, 'forest-rangers-zm'),
      (9, 'kabwe-warriors'), (10, 'buildcon-fc'),
      (11, 'napsa-stars'), (12, 'lumwana-radiants'),
      (13, 'prison-leopards'), (14, 'konkola-blades'),
      (15, 'chambishi-fc'), (16, 'indeni-fc')
  )
  INSERT INTO football.standings AS std (
    competition_id, season_id, team_id,
    stage_name, group_name, position,
    played, won, drawn, lost,
    goals_for, goals_against, goal_difference, points,
    notes, metadata
  )
  SELECT
    v_zm_competition_id, v_zm_season_id, t.id,
    'overall', '', sv.position,
    0, 0, 0, 0, 0, 0, 0, 0,
    'Position-only snapshot; detailed stats unavailable.',
    jsonb_build_object('snapshot_date', '2026-04-15', 'stats_complete', false)
  FROM sv
  JOIN football.teams t ON t.slug = sv.team_slug
  ON CONFLICT (season_id, stage_name, group_name, team_id) DO UPDATE
  SET
    position = EXCLUDED.position,
    notes = EXCLUDED.notes,
    metadata = std.metadata || EXCLUDED.metadata;

END $$;
