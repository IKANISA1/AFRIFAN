-- Admin-managed LiveScore web ingestion sources.
-- The sync runner reads this table each cycle and fails closed when no active
-- sources are configured.

begin;

create table if not exists public.livescore_competition_sources (
  id uuid primary key default gen_random_uuid(),
  club_id bigint references public.african_football_clubs(id) on delete cascade,
  source_provider text not null default 'livescore',
  source_key text not null,
  display_name text not null,
  match_aliases text[] not null default '{}'::text[],
  country_aliases text[] not null default '{}'::text[],
  external_competition_ids text[] not null default '{}'::text[],
  source_urls text[] not null default array['https://www.livescore.com/en/']::text[],
  sync_fixtures boolean not null default true,
  sync_live boolean not null default true,
  sync_results boolean not null default true,
  sync_assets boolean not null default true,
  priority integer not null default 100,
  is_active boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint livescore_competition_sources_provider_check check (source_provider = 'livescore'),
  constraint livescore_competition_sources_key_check check (length(btrim(source_key)) > 0),
  constraint livescore_competition_sources_name_check check (length(btrim(display_name)) > 0),
  constraint livescore_competition_sources_aliases_check check (array_length(match_aliases, 1) > 0),
  constraint livescore_competition_sources_urls_check check (array_length(source_urls, 1) > 0)
);

create unique index if not exists idx_livescore_competition_sources_scope_key
  on public.livescore_competition_sources (
    source_provider,
    coalesce(club_id, 0),
    source_key
  );

create index if not exists idx_livescore_competition_sources_active
  on public.livescore_competition_sources (is_active, priority, display_name);

drop trigger if exists livescore_competition_sources_set_updated_at
  on public.livescore_competition_sources;
create trigger livescore_competition_sources_set_updated_at
before update on public.livescore_competition_sources
for each row execute function public.set_updated_at();

alter table public.livescore_competition_sources enable row level security;

drop policy if exists livescore_competition_sources_admin_read
  on public.livescore_competition_sources;
create policy livescore_competition_sources_admin_read
on public.livescore_competition_sources
for select
to authenticated
using (
  public.is_super_admin()
  or club_id is null
  or public.is_club_admin(club_id)
);

drop policy if exists livescore_competition_sources_admin_write
  on public.livescore_competition_sources;
create policy livescore_competition_sources_admin_write
on public.livescore_competition_sources
for all
to authenticated
using (
  public.is_super_admin()
  or (club_id is not null and public.is_club_admin(club_id))
)
with check (
  public.is_super_admin()
  or (club_id is not null and public.is_club_admin(club_id))
);

grant select on public.livescore_competition_sources to authenticated;
grant select, insert, update, delete on public.livescore_competition_sources to service_role;

insert into public.livescore_competition_sources (
  source_key,
  display_name,
  match_aliases,
  country_aliases,
  source_urls,
  priority,
  metadata
)
values
  (
    'fifa-world-cup-2026',
    '2026 World Cup',
    array['2026 World Cup', 'FIFA World Cup 2026', 'World Cup 2026']::text[],
    array[]::text[],
    array['https://www.livescore.com/en/football/world-cup/']::text[],
    10,
    jsonb_build_object('seeded_from', '20260629123000_livescore_competition_sources')
  ),
  (
    'uefa-champions-league',
    'UEFA Champions League',
    array['UEFA Champions League', 'URFA Champions League', 'Champions League']::text[],
    array[]::text[],
    array['https://www.livescore.com/en/football/champions-league/']::text[],
    20,
    jsonb_build_object('seeded_from', '20260629123000_livescore_competition_sources')
  ),
  (
    'uefa-europa-league',
    'UEFA Europa League',
    array['UEFA Europa League', 'Europa League']::text[],
    array[]::text[],
    array['https://www.livescore.com/en/football/europa-league/']::text[],
    30,
    jsonb_build_object('seeded_from', '20260629123000_livescore_competition_sources')
  ),
  (
    'premier-league',
    'Premier League',
    array['Premier League', 'English Premier League', 'England Premier League']::text[],
    array['England', 'GB', 'United Kingdom']::text[],
    array['https://www.livescore.com/en/football/england/premier-league/']::text[],
    40,
    jsonb_build_object('seeded_from', '20260629123000_livescore_competition_sources')
  ),
  (
    'la-liga',
    'La Liga',
    array['La Liga', 'LALIGA', 'Primera Division', 'Spanish Primera Division']::text[],
    array['Spain', 'ES']::text[],
    array['https://www.livescore.com/en/football/spain/laliga/']::text[],
    50,
    jsonb_build_object('seeded_from', '20260629123000_livescore_competition_sources')
  ),
  (
    'bundesliga',
    'Bundesliga',
    array['Bundesliga', 'German Bundesliga']::text[],
    array['Germany', 'DE']::text[],
    array['https://www.livescore.com/en/football/germany/bundesliga/']::text[],
    60,
    jsonb_build_object('seeded_from', '20260629123000_livescore_competition_sources')
  ),
  (
    'serbia-a',
    'Serbia A',
    array['Serbia A', 'Serbian SuperLiga', 'SuperLiga Srbije', 'Mozzart Bet SuperLiga']::text[],
    array['Serbia', 'RS']::text[],
    array['https://www.livescore.com/en/football/serbia/']::text[],
    70,
    jsonb_build_object('seeded_from', '20260629123000_livescore_competition_sources')
  ),
  (
    'ligue-1',
    'Ligue 1',
    array['Ligue 1', 'Ligue 1 McDonalds', 'French Ligue 1']::text[],
    array['France', 'FR']::text[],
    array['https://www.livescore.com/en/football/france/ligue-1/']::text[],
    80,
    jsonb_build_object('seeded_from', '20260629123000_livescore_competition_sources')
  ),
  (
    'rwanda-premier-league',
    'Rwanda Premier League',
    array['Rwanda Premier League', 'Rwanda National League', 'Primus National League']::text[],
    array['Rwanda', 'RW']::text[],
    array['https://www.livescore.com/en/football/rwanda/']::text[],
    90,
    jsonb_build_object('seeded_from', '20260629123000_livescore_competition_sources')
  ),
  (
    'dr-congo-linafoot',
    'DR Congo Linafoot',
    array[
      'DR Congo Linafoot',
      'DRC Linafoot',
      'Linafoot',
      'Ligue Nationale de Football',
      'Vodacom Ligue 1'
    ]::text[],
    array['DR Congo', 'DRC', 'Democratic Republic of the Congo', 'CD']::text[],
    array['https://www.livescore.com/en/football/dr-congo/']::text[],
    100,
    jsonb_build_object('seeded_from', '20260629123000_livescore_competition_sources')
  ),
  (
    'zambia-premier-league',
    'Zambia Premier League',
    array['Zambia Premier League', 'Zambian Premier League', 'Zambia Super League', 'MTN Super League']::text[],
    array['Zambia', 'ZM']::text[],
    array['https://www.livescore.com/en/football/zambia/']::text[],
    110,
    jsonb_build_object('seeded_from', '20260629123000_livescore_competition_sources')
  )
on conflict (source_provider, (coalesce(club_id, 0)), source_key)
do update set
  display_name = excluded.display_name,
  match_aliases = excluded.match_aliases,
  country_aliases = excluded.country_aliases,
  source_urls = excluded.source_urls,
  priority = excluded.priority,
  is_active = true,
  metadata = public.livescore_competition_sources.metadata || excluded.metadata,
  updated_at = timezone('utc', now());

commit;
