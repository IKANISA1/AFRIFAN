-- ==========================================================================
-- AfriClub — African Football Clubs Market Research
-- ==========================================================================
-- Master registry of the top ~93 African football clubs ranked by
-- estimated fan base size. Used for:
--   1) Club onboarding priority / pipeline
--   2) Market sizing & BD targeting
--   3) In-app discovery & club directory
--   4) White-label deployment planning
--
-- Fan base estimates are derived from:
--   country_population × football_penetration × club_market_share
-- ==========================================================================

create table if not exists public.african_football_clubs (
  id                      bigint generated always as identity primary key,

  -- ── Club identity ──
  club_name               text not null,
  country_name            text not null,
  country_flag            text not null default '',
  country_iso_code        text references public.countries(id),

  -- ── Market sizing ──
  country_population      bigint not null default 0,
  football_penetration    numeric(5,2) not null default 0,   -- e.g. 0.55 = 55%
  club_market_share       numeric(5,2) not null default 0,   -- e.g. 0.45 = 45%
  estimated_fan_base      bigint not null default 0,

  -- ── Research metadata ──
  market_research_note    text,

  -- ── Platform status ──
  is_onboarded            boolean not null default false,     -- club is live on AfriClub
  onboarding_priority     smallint,                           -- 1=highest, null=unranked
  is_active               boolean not null default true,

  -- ── Lifecycle ──
  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now(),

  -- ── Constraints ──
  constraint uq_african_football_clubs_name unique (club_name)
);

-- Indexes
create index if not exists idx_afc_country
  on public.african_football_clubs (country_iso_code);

create index if not exists idx_afc_fan_base
  on public.african_football_clubs (estimated_fan_base desc);

create index if not exists idx_afc_active
  on public.african_football_clubs (is_active)
  where is_active = true;

comment on table public.african_football_clubs is
  'Master registry of African football clubs with market research data (fan base estimates, penetration rates, market share).';

-- ==========================================================================
-- RLS Policies
-- ==========================================================================
alter table public.african_football_clubs enable row level security;

-- Public read for active clubs (used in discovery/directory)
create policy "Anyone can read active clubs"
  on public.african_football_clubs for select
  using (is_active = true);

-- Admin-only write access
create policy "Admins can manage clubs"
  on public.african_football_clubs for all
  using (
    auth.role() = 'authenticated' and
    exists (
      select 1 from auth.users u
      where u.id = auth.uid()
      and (u.raw_user_meta_data ->> 'role')::text = 'admin'
    )
  );

-- ==========================================================================
-- Seed data: 93 African football clubs ranked by estimated fan base
-- ==========================================================================
-- Source: Market Research — African Football Fans (2026)
-- Formula: country_pop × football_penetration × club_market_share
-- ==========================================================================

insert into public.african_football_clubs (
  club_name, country_name, country_flag, country_iso_code,
  country_population, football_penetration, club_market_share,
  estimated_fan_base, market_research_note
)
values
  -- #1
  ('Young Africans (Yanga)', 'Tanzania', '🇹🇿', 'TZ',
   67000000, 0.55, 0.45, 16200000,
   'Explains their PR claim of 20M+ (which likely includes Kenya/Uganda spillover).'),

  -- #2
  ('Kaizer Chiefs FC', 'South Africa', '🇿🇦', 'ZA',
   60000000, 0.55, 0.45, 14850000,
   'Math aligns perfectly with their stated 15M-16M PR figures.'),

  -- #3
  ('Simba SC', 'Tanzania', '🇹🇿', 'TZ',
   67000000, 0.55, 0.40, 14400000,
   'The other half of the massive Tanzanian duopoly.'),

  -- #4
  ('TP Mazembe', 'DR Congo', '🇨🇩', 'CD',
   102000000, 0.45, 0.30, 13770000,
   'Continental giants; massive national/regional TAM.'),

  -- #5
  ('Orlando Pirates FC', 'South Africa', '🇿🇦', 'ZA',
   60000000, 0.55, 0.35, 11550000,
   'Closer to reality than previously stated 6M.'),

  -- #6
  ('AS Vita Club', 'DR Congo', '🇨🇩', 'CD',
   102000000, 0.45, 0.25, 11475000,
   'Kinshasa heavyweight.'),

  -- #7
  ('St. George SC', 'Ethiopia', '🇪🇹', 'ET',
   126000000, 0.40, 0.20, 10080000,
   'The dominant historic club in a massive market.'),

  -- #8
  ('Kano Pillars FC', 'Nigeria', '🇳🇬', 'NG',
   223000000, 0.40, 0.10, 8900000,
   'Massive Northern Nigeria TAM outweighs weak domestic league engagement.'),

  -- #9
  ('Asante Kotoko SC', 'Ghana', '🇬🇭', 'GH',
   34000000, 0.50, 0.45, 7650000,
   'Align perfectly with historical CEO estimates (~8M).'),

  -- #10
  ('Ethiopian Coffee SC', 'Ethiopia', '🇪🇹', 'ET',
   126000000, 0.40, 0.15, 7560000,
   'Massive population creates huge absolute numbers.'),

  -- #11
  ('Enyimba FC', 'Nigeria', '🇳🇬', 'NG',
   223000000, 0.40, 0.08, 7120000,
   'Continental success boosts national footprint.'),

  -- #12
  ('Accra Hearts of Oak', 'Ghana', '🇬🇭', 'GH',
   34000000, 0.50, 0.35, 5950000,
   'The southern powerhouse.'),

  -- #13
  ('Petro de Luanda', 'Angola', '🇦🇴', null,
   37000000, 0.50, 0.30, 5550000,
   'Dominant club; highly defensible market share.'),

  -- #14
  ('ASEC Mimosas', 'Ivory Coast', '🇨🇮', 'CI',
   28000000, 0.45, 0.40, 5040000,
   'The undisputed commercial giant of CI.'),

  -- #15
  ('Primeiro de Agosto', 'Angola', '🇦🇴', null,
   37000000, 0.50, 0.25, 4625000,
   'Major historic rival to Petro.'),

  -- #16
  ('Gor Mahia FC', 'Kenya', '🇰🇪', 'KE',
   55000000, 0.40, 0.20, 4400000,
   'Massive legacy support, though fractured by EPL viewing.'),

  -- #17
  ('Nyasa Big Bullets FC', 'Malawi', '🇲🇼', 'MW',
   21000000, 0.45, 0.45, 4230000,
   'Matches local media moniker "The People''s Team".'),

  -- #18
  ('SC Villa', 'Uganda', '🇺🇬', 'UG',
   48000000, 0.40, 0.20, 3840000,
   'Most successful historic club.'),

  -- #19
  ('Dynamos FC', 'Zimbabwe', '🇿🇼', 'ZW',
   16000000, 0.50, 0.45, 3600000,
   'Adjusts PR claim (7M) down to realistic market TAM.'),

  -- #20
  ('AFC Leopards', 'Kenya', '🇰🇪', 'KE',
   55000000, 0.40, 0.15, 3300000,
   'Historic rivals to Gor Mahia.'),

  -- #21
  ('Africa Sports National', 'Ivory Coast', '🇨🇮', 'CI',
   28000000, 0.45, 0.25, 3150000,
   'Fierce rival, slightly smaller base.'),

  -- #22
  ('Express FC', 'Uganda', '🇺🇬', 'UG',
   48000000, 0.40, 0.15, 2880000,
   'Traditional rival "Red Eagles".'),

  -- #23
  ('Mighty Wanderers FC', 'Malawi', '🇲🇼', 'MW',
   21000000, 0.45, 0.30, 2820000,
   'Huge traditional rivalry with Bullets.'),

  -- #24
  ('Rayon Sports FC', 'Rwanda', '🇷🇼', 'RW',
   14000000, 0.50, 0.40, 2800000,
   'Historically the most organically supported club.'),

  -- #25
  ('Djoliba AC', 'Mali', '🇲🇱', null,
   23000000, 0.45, 0.25, 2575000,
   'Bamako heavyweight.'),

  -- #26
  ('Nkana FC', 'Zambia', '🇿🇲', 'ZM',
   20000000, 0.50, 0.25, 2500000,
   'Copperbelt giants; massive passionate base.'),

  -- #27
  ('Highlanders FC', 'Zimbabwe', '🇿🇼', 'ZW',
   16000000, 0.50, 0.30, 2400000,
   'Bulawayo-centric base; intensely loyal.'),

  -- #28
  ('Costa do Sol FC', 'Mozambique', '🇲🇿', 'MZ',
   34000000, 0.45, 0.15, 2295000,
   'Maputo giants.'),

  -- #29
  ('Horoya AC', 'Guinea', '🇬🇳', 'GN',
   14000000, 0.45, 0.35, 2205000,
   'Modern heavy-spenders; captured the new generation.'),

  -- #30
  ('Stade Malien', 'Mali', '🇲🇱', null,
   23000000, 0.45, 0.20, 2060000,
   'Historic Bamako rival.'),

  -- #31
  ('Canon Yaoundé', 'Cameroon', '🇨🇲', 'CM',
   29000000, 0.45, 0.15, 1950000,
   'Legacy club with massive historical following.'),

  -- #32
  ('Rayon Sports FC', 'Rwanda', '🇷🇼', 'RW',
   14000000, 0.50, 0.25, 1750000,
   'Army-backed; massive resources.'),

  -- #33
  ('Union Douala', 'Cameroon', '🇨🇲', 'CM',
   29000000, 0.45, 0.12, 1560000,
   'Economic capital heavyweight.'),

  -- #34
  ('UD Songo FC', 'Mozambique', '🇲🇿', 'MZ',
   34000000, 0.45, 0.10, 1530000,
   'Provincial power backed by energy money.'),

  -- #35
  ('ZESCO United FC', 'Zambia', '🇿🇲', 'ZM',
   20000000, 0.50, 0.15, 1500000,
   'Modern corporate success.'),

  -- #36
  ('Sahel SC', 'Niger', '🇳🇪', null,
   27000000, 0.35, 0.15, 1410000,
   'Capital city base.'),

  -- #37
  ('ASFA Yennenga', 'Burkina Faso', '🇧🇫', null,
   23000000, 0.40, 0.15, 1380000,
   'Historic giant in Ouagadougou.'),

  -- #38
  ('ASC Jaraaf', 'Senegal', '🇸🇳', 'SN',
   18000000, 0.50, 0.15, 1350000,
   'Dakar heavyweight; Senegal highly favors Euro leagues over domestic.'),

  -- #39
  ('Hafia FC', 'Guinea', '🇬🇳', 'GN',
   14000000, 0.45, 0.20, 1260000,
   'Historic continental giants.'),

  -- #40
  ('CNAPS Sport', 'Madagascar', '🇲🇬', 'MG',
   30000000, 0.35, 0.12, 1260000,
   'Consistent modern winners.'),

  -- #41
  ('Étoile Filante', 'Burkina Faso', '🇧🇫', null,
   23000000, 0.40, 0.12, 1104000,
   'Fierce rival to ASFA.'),

  -- #42
  ('Casa Sports', 'Senegal', '🇸🇳', 'SN',
   18000000, 0.50, 0.12, 1080000,
   'Massive regional identity (Casamance).'),

  -- #43
  ('Fosa Juniors FC', 'Madagascar', '🇲🇬', 'MG',
   30000000, 0.35, 0.10, 1050000,
   'Coastal powerhouse.'),

  -- #44
  ('Vital''O FC', 'Burundi', '🇧🇮', null,
   13000000, 0.40, 0.20, 1040000,
   'Most successful club historically.'),

  -- #45
  ('ASKO de Kara', 'Togo', '🇹🇬', null,
   9000000, 0.45, 0.25, 1000000,
   'Recent total dominance.'),

  -- #46
  ('East End Lions FC', 'Sierra Leone', '🇸🇱', 'SL',
   8700000, 0.45, 0.25, 975000,
   'Freetown giants.'),

  -- #47
  ('Espoir FC de Zinder', 'Niger', '🇳🇪', null,
   27000000, 0.35, 0.10, 940000,
   'Provincial support base.'),

  -- #48
  ('Elman FC', 'Somalia', '🇸🇴', null,
   18000000, 0.35, 0.12, 756000,
   'Peace-building legacy boosts support.'),

  -- #49
  ('AC Léopards', 'Congo (Republic)', '🇨🇬', 'CG',
   6100000, 0.45, 0.25, 675000,
   'Continental success boosted numbers.'),

  -- #50
  ('Banadir Stars', 'Somalia', '🇸🇴', null,
   18000000, 0.35, 0.10, 630000,
   'Mogadishu base.'),

  -- #51
  ('Mighty Barrolle FC', 'Liberia', '🇱🇷', 'LR',
   5400000, 0.45, 0.25, 600000,
   'Massive legacy brand.'),

  -- #52
  ('Kallon FC', 'Sierra Leone', '🇸🇱', 'SL',
   8700000, 0.45, 0.15, 585000,
   'Star-owned modern club.'),

  -- #53
  ('Atlabara FC', 'South Sudan', '🇸🇸', null,
   11000000, 0.35, 0.15, 570000,
   'Juba heavyweights.'),

  -- #54
  ('Étoile du Congo', 'Congo (Republic)', '🇨🇬', 'CG',
   6100000, 0.45, 0.20, 540000,
   'Historic Brazzaville giants.'),

  -- #55
  ('Foullah Edifice FC', 'Chad', '🇹🇩', null,
   18000000, 0.35, 0.08, 504000,
   'Lower domestic league commercialization.'),

  -- #56
  ('FC Nouadhibou', 'Mauritania', '🇲🇷', null,
   4800000, 0.35, 0.30, 480000,
   'Total domestic dominance recently.'),

  -- #57
  ('Township Rollers FC', 'Botswana', '🇧🇼', 'BW',
   2700000, 0.45, 0.35, 420000,
   'The undisputed heavyweight in Botswana.'),

  -- #58
  ('Maranatha FC', 'Togo', '🇹🇬', null,
   9000000, 0.45, 0.10, 400000,
   'Legacy side.'),

  -- #59
  ('Al-Hilal Juba FC', 'South Sudan', '🇸🇸', null,
   11000000, 0.35, 0.10, 380000,
   'Regional competitors.'),

  -- #60
  ('LISCR FC', 'Liberia', '🇱🇷', 'LR',
   5400000, 0.45, 0.15, 360000,
   'Corporate backing.'),

  -- #61
  ('AS Coton Chad', 'Chad', '🇹🇩', null,
   18000000, 0.35, 0.05, 315000,
   'Corporate roots.'),

  -- #62
  ('AS Tempête Mocaf', 'Central African Rep.', '🇨🇫', null,
   5800000, 0.35, 0.15, 300000,
   'Capital city base; infrastructure limits reach.'),

  -- #63
  ('African Stars FC', 'Namibia', '🇳🇦', null,
   2600000, 0.40, 0.30, 300000,
   'Biggest drawing team in the country.'),

  -- #64
  ('Musongati FC', 'Burundi', '🇧🇮', null,
   13000000, 0.40, 0.05, 260000,
   'Regional power, limited national reach.'),

  -- #65
  ('Gaborone United FC', 'Botswana', '🇧🇼', 'BW',
   2700000, 0.45, 0.20, 240000,
   'Strong capital-city fanbase.'),

  -- #66
  ('Red Sea FC', 'Eritrea', '🇪🇷', null,
   3700000, 0.35, 0.20, 240000,
   'Historic dominance.'),

  -- #67
  ('Real de Banjul FC', 'Gambia', '🇬🇲', null,
   2700000, 0.45, 0.20, 240000,
   'Premier traditional club.'),

  -- #68
  ('Olympique Réal de Bangui', 'Central African Rep.', '🇨🇫', null,
   5800000, 0.35, 0.10, 200000,
   'Strong contender in Bangui.'),

  -- #69
  ('AS Mangasport', 'Gabon', '🇬🇦', 'GA',
   2400000, 0.45, 0.20, 200000,
   'Sustained domestic success.'),

  -- #70
  ('Black Africa FC', 'Namibia', '🇳🇦', null,
   2600000, 0.40, 0.20, 200000,
   'Historic heavyweights.'),

  -- #71
  ('Mbabane Highlanders', 'Eswatini', '🇸🇿', 'SZ',
   1200000, 0.45, 0.35, 189000,
   'Historic giant; solid TAM capture.'),

  -- #72
  ('Bantu FC', 'Lesotho', '🇱🇸', null,
   2300000, 0.40, 0.20, 184000,
   'Strong community support.'),

  -- #73
  ('Mogas 90 FC', 'Benin', '🇧🇯', 'BJ',
   14000000, 0.40, 0.03, 168000,
   'Low domestic league engagement vs. European leagues.'),

  -- #74
  ('Sport Bissau e Benfica', 'Guinea-Bissau', '🇬🇼', 'GW',
   2100000, 0.40, 0.20, 168000,
   'Tied to Portuguese legacy.'),

  -- #75
  ('Mbabane Swallows', 'Eswatini', '🇸🇿', 'SZ',
   1200000, 0.45, 0.30, 162000,
   'Modern powerhouse.'),

  -- #76
  ('ASC Ksar', 'Mauritania', '🇲🇷', null,
   4800000, 0.35, 0.10, 160000,
   'Older legacy club.'),

  -- #77
  ('CF Mounana', 'Gabon', '🇬🇦', 'GA',
   2400000, 0.45, 0.15, 150000,
   'Good recent success.'),

  -- #78
  ('Sporting Bissau', 'Guinea-Bissau', '🇬🇼', 'GW',
   2100000, 0.40, 0.15, 126000,
   'Tied to Portuguese legacy.'),

  -- #79
  ('Asha FC', 'Eritrea', '🇪🇷', null,
   3700000, 0.35, 0.10, 120000,
   'Smaller market share.'),

  -- #80
  ('Gambia Armed Forces', 'Gambia', '🇬🇲', null,
   2700000, 0.45, 0.10, 120000,
   'Institutional club.'),

  -- #81
  ('ASPAC FC', 'Benin', '🇧🇯', 'BJ',
   14000000, 0.40, 0.02, 112000,
   'Corporate-backed club, smaller organic base.'),

  -- #82
  ('Deportivo Mongomo', 'Equatorial Guinea', '🇬🇶', null,
   1700000, 0.40, 0.15, 102000,
   'Strong regional base.'),

  -- #83
  ('AS Port-Louis 2000', 'Mauritius', '🇲🇺', null,
   1200000, 0.40, 0.20, 96000,
   'Fragmented league; high EPL preference.'),

  -- #84
  ('Lesotho Mounted Police', 'Lesotho', '🇱🇸', null,
   2300000, 0.40, 0.10, 92000,
   'Institutional club.'),

  -- #85
  ('AS Arta/Solar7', 'Djibouti', '🇩🇯', null,
   1100000, 0.40, 0.20, 88000,
   'Recent heavy investment boosted profile.'),

  -- #86
  ('Leones Vegetarianos FC', 'Equatorial Guinea', '🇬🇶', null,
   1700000, 0.40, 0.12, 81600,
   'Fragmented domestic support.'),

  -- #87
  ('Sporting Clube de Praia', 'Cape Verde', '🇨🇻', null,
   600000, 0.50, 0.25, 75000,
   'Highly fragmented island league; capital advantage.'),

  -- #88
  ('Pamplemousses SC', 'Mauritius', '🇲🇺', null,
   1200000, 0.40, 0.15, 72000,
   'Regional power.'),

  -- #89
  ('AS Port', 'Djibouti', '🇩🇯', null,
   1100000, 0.40, 0.15, 66000,
   'Traditional power.'),

  -- #90
  ('Volcan Club', 'Comoros', '🇰🇲', null,
   850000, 0.40, 0.15, 51000,
   'Very small absolute TAM.'),

  -- #91
  ('Fomboni SC', 'Comoros', '🇰🇲', null,
   850000, 0.40, 0.10, 34000,
   'Very small absolute TAM.'),

  -- #92
  ('Sporting Praia Cruz', 'São Tomé & Príncipe', '🇸🇹', null,
   230000, 0.45, 0.30, 30900,
   'Dominant local side.'),

  -- #93
  ('FC Académica do Porto Novo', 'Cape Verde', '🇨🇻', null,
   600000, 0.50, 0.10, 30000,
   'Regional island dominance.'),

  -- #94
  ('FC Porto Real', 'São Tomé & Príncipe', '🇸🇹', null,
   230000, 0.45, 0.15, 15450,
   'Principe island side.'),

  -- #95
  ('St. Michel United FC', 'Seychelles', '🇸🇨', null,
   100000, 0.40, 0.35, 14000,
   'Most successful local club.'),

  -- #96
  ('Anse Reunion FC', 'Seychelles', '🇸🇨', null,
   100000, 0.40, 0.15, 6000,
   'La Digue island support.')

on conflict (club_name) do update set
  country_name          = excluded.country_name,
  country_flag          = excluded.country_flag,
  country_iso_code      = excluded.country_iso_code,
  country_population    = excluded.country_population,
  football_penetration  = excluded.football_penetration,
  club_market_share     = excluded.club_market_share,
  estimated_fan_base    = excluded.estimated_fan_base,
  market_research_note  = excluded.market_research_note,
  updated_at            = now();

-- Mark Rayon Sports as onboarded (pilot club)
update public.african_football_clubs
set is_onboarded = true, onboarding_priority = 1, updated_at = now()
where club_name = 'Rayon Sports FC';
