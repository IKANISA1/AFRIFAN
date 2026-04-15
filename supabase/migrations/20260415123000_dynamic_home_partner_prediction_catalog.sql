-- Dynamic home/admin content + partner catalog + prediction support catalog.

-- ── Normalize supported-country guardrails for admin-managed tables ─────

alter table public.quick_actions
  add column if not exists action_key text,
  add column if not exists icon_key text;

drop index if exists idx_quick_actions_action_key_unique;
create unique index if not exists idx_quick_actions_action_key_unique
  on public.quick_actions (action_key);

alter table public.quick_actions
  drop constraint if exists quick_actions_country_local_scope_check;

alter table public.quick_actions
  add constraint quick_actions_country_supported_check
  check (
    country is null
    or upper(country) in ('RW', 'CD', 'ZM')
  );

alter table public.partners
  add column if not exists gamification_enabled boolean not null default false;

alter table public.partners
  drop constraint if exists partners_country_rwanda_only_check;

alter table public.partners
  add constraint partners_country_supported_check
  check (upper(country) in ('RW', 'CD', 'ZM'));

alter table public.partner_services
  add column if not exists service_slug text,
  add column if not exists gamification_enabled boolean not null default false;

drop index if exists idx_partner_services_partner_service_slug_unique;
create unique index if not exists idx_partner_services_partner_service_slug_unique
  on public.partner_services (partner_id, service_slug);

alter table public.partner_services
  drop constraint if exists partner_services_country_rwanda_only_check;

alter table public.partner_services
  add constraint partner_services_country_supported_check
  check (
    country is null
    or upper(country) in ('RW', 'CD', 'ZM')
  );

alter table public.partner_payment_routes
  drop constraint if exists partner_payment_routes_country_rwanda_only_check;

alter table public.partner_payment_routes
  add constraint partner_payment_routes_country_supported_check
  check (upper(country) in ('RW', 'CD', 'ZM'));

-- ── Canonical quick actions for the home screen ─────────────────────────

insert into public.quick_actions (
  action_key,
  title,
  subtitle,
  emoji,
  icon_key,
  route,
  country,
  sort_order,
  is_active
)
values
  (
    'predict',
    'Predict',
    'Open prediction fixtures',
    '⚽',
    'predict',
    '/fanzone/fixtures',
    null,
    10,
    true
  ),
  (
    'my_picks',
    'My Picks',
    'Track your prediction slips',
    '🧾',
    'myPicks',
    '/fanzone/my',
    null,
    20,
    true
  ),
  (
    'live',
    'Live',
    'Watch live matchday updates',
    '📺',
    'live',
    '/live',
    null,
    30,
    true
  ),
  (
    'leaderboard',
    'Leaderboard',
    'See the top supporter rankings',
    '🏆',
    'leaderboard',
    '/fanzone/leaderboard',
    null,
    40,
    true
  ),
  (
    'wallet',
    'Wallet',
    'View FET balance and rewards',
    '💳',
    'wallet',
    '/fanzone/wallet',
    null,
    50,
    true
  ),
  (
    'tickets',
    'Tickets',
    'Access ticketing journeys',
    '🎟️',
    'tickets',
    '/tickets',
    null,
    60,
    true
  )
on conflict (action_key) do update
set
  title = excluded.title,
  subtitle = excluded.subtitle,
  emoji = excluded.emoji,
  icon_key = excluded.icon_key,
  route = excluded.route,
  country = excluded.country,
  sort_order = excluded.sort_order,
  is_active = excluded.is_active,
  updated_at = now();

-- ── Partner catalog required by the current product brief ───────────────

insert into public.partners (
  slug,
  name,
  category,
  country,
  emoji,
  subtitle,
  description,
  is_active,
  sort_order,
  gamification_enabled,
  metadata
)
values
  (
    'equity-bank',
    'Equity Bank',
    'bank',
    'RW',
    '🏦',
    'Custodian of group savings and financing',
    'Admin-managed banking partner for custody, savings, and financing journeys.',
    true,
    10,
    true,
    jsonb_build_object(
      'service_domain', 'savings_finance',
      'activation_mode', 'admin_panel',
      'supported_countries', jsonb_build_array('RW', 'CD', 'ZM')
    )
  ),
  (
    'urwego-finance',
    'Urwego Finance',
    'bank',
    'RW',
    '💼',
    'Custodian of group savings and financing',
    'Admin-managed microfinance partner for community savings and financing.',
    true,
    20,
    true,
    jsonb_build_object(
      'service_domain', 'savings_finance',
      'activation_mode', 'admin_panel',
      'supported_countries', jsonb_build_array('RW', 'CD', 'ZM')
    )
  ),
  (
    'radiant-insurance',
    'Radiant Insurance',
    'organization',
    'RW',
    '🛡️',
    'Insurance services',
    'Admin-managed insurance partner for supporter, family, and group protection journeys.',
    true,
    30,
    true,
    jsonb_build_object(
      'service_domain', 'insurance',
      'activation_mode', 'admin_panel',
      'supported_countries', jsonb_build_array('RW', 'CD', 'ZM')
    )
  ),
  (
    'mobio',
    'Mobio',
    'organization',
    'RW',
    '🛵',
    'Mobility services',
    'Admin-managed mobility partner for transport and movement-related fan experiences.',
    true,
    40,
    true,
    jsonb_build_object(
      'service_domain', 'mobility',
      'activation_mode', 'admin_panel',
      'supported_countries', jsonb_build_array('RW', 'CD', 'ZM')
    )
  ),
  (
    'cool',
    'Cool',
    'organization',
    'RW',
    '🤝',
    'Group savings and community fundraising',
    'Admin-managed community partner for group savings and fundraising activations.',
    true,
    50,
    true,
    jsonb_build_object(
      'service_domain', 'community_finance',
      'activation_mode', 'admin_panel',
      'supported_countries', jsonb_build_array('RW', 'CD', 'ZM')
    )
  )
on conflict (slug) do update
set
  name = excluded.name,
  category = excluded.category,
  country = excluded.country,
  emoji = excluded.emoji,
  subtitle = excluded.subtitle,
  description = excluded.description,
  is_active = excluded.is_active,
  sort_order = excluded.sort_order,
  gamification_enabled = excluded.gamification_enabled,
  metadata = coalesce(public.partners.metadata, '{}'::jsonb) || excluded.metadata,
  updated_at = now();

with service_seed as (
  select
    p.id as partner_id,
    p.slug as partner_slug,
    seed.service_slug,
    seed.title,
    seed.subtitle,
    seed.emoji,
    seed.category,
    seed.cta_label,
    seed.cta_action,
    seed.country,
    seed.sort_order,
    seed.gamification_enabled
  from public.partners p
  join (
    values
      (
        'equity-bank',
        'custodian-savings',
        'Custodian Savings',
        'Secure group savings custody',
        '🏦',
        'bank',
        'Open Savings',
        'internal:group_savings_custodian',
        'RW',
        10,
        true
      ),
      (
        'equity-bank',
        'group-financing',
        'Group Financing',
        'Financing support for registered groups',
        '📈',
        'bank',
        'Request Financing',
        'internal:group_financing',
        'RW',
        20,
        true
      ),
      (
        'urwego-finance',
        'custodian-savings',
        'Custodian Savings',
        'Secure group savings custody',
        '💼',
        'bank',
        'Open Savings',
        'internal:group_savings_custodian',
        'RW',
        10,
        true
      ),
      (
        'urwego-finance',
        'group-financing',
        'Group Financing',
        'Financing support for registered groups',
        '📊',
        'bank',
        'Request Financing',
        'internal:group_financing',
        'RW',
        20,
        true
      ),
      (
        'mobio',
        'mobility',
        'Mobility',
        'Transport and commuting support',
        '🛵',
        'mobility',
        'Explore Mobility',
        'internal:mobility',
        'RW',
        10,
        true
      ),
      (
        'radiant-insurance',
        'insurance',
        'Insurance',
        'Community and member cover options',
        '🛡️',
        'insurance',
        'View Covers',
        'internal:insurance',
        'RW',
        10,
        true
      ),
      (
        'cool',
        'group-savings',
        'Group Savings',
        'Community saving circles and goals',
        '🤝',
        'community',
        'Open Group Savings',
        'internal:group_savings',
        'RW',
        10,
        true
      ),
      (
        'cool',
        'community-fundraising',
        'Community Fundraising',
        'Launch shared fundraising campaigns',
        '📣',
        'community',
        'Start Fundraising',
        'internal:community_fundraising',
        'RW',
        20,
        true
      )
  ) as seed(
    partner_slug,
    service_slug,
    title,
    subtitle,
    emoji,
    category,
    cta_label,
    cta_action,
    country,
    sort_order,
    gamification_enabled
  )
    on seed.partner_slug = p.slug
)
insert into public.partner_services (
  partner_id,
  service_slug,
  title,
  subtitle,
  emoji,
  category,
  cta_label,
  cta_action,
  country,
  sort_order,
  is_active,
  gamification_enabled
)
select
  partner_id,
  service_slug,
  title,
  subtitle,
  emoji,
  category,
  cta_label,
  cta_action,
  country,
  sort_order,
  true,
  gamification_enabled
from service_seed
on conflict (partner_id, service_slug) do update
set
  title = excluded.title,
  subtitle = excluded.subtitle,
  emoji = excluded.emoji,
  category = excluded.category,
  cta_label = excluded.cta_label,
  cta_action = excluded.cta_action,
  country = excluded.country,
  sort_order = excluded.sort_order,
  is_active = excluded.is_active,
  gamification_enabled = excluded.gamification_enabled,
  updated_at = now();

-- ── Extend the football competition catalog for prediction support ──────

insert into football.competitions (
  slug,
  name,
  short_name,
  competition_kind,
  region,
  country_code,
  country_name,
  organizer,
  format_notes,
  metadata
)
values
  (
    'la-liga',
    'La Liga',
    'La Liga',
    'league',
    'europe',
    'ESP',
    'Spain',
    'LALIGA',
    'Top-flight league competition for clubs in Spain.',
    jsonb_build_object('tier', 1, 'supports_tables', true, 'supports_fixtures', true, 'supports_player_registrations', true)
  ),
  (
    'uefa-champions-league',
    'UEFA Champions League',
    'UCL',
    'cup',
    'europe',
    null,
    'Europe',
    'UEFA',
    'Elite continental competition with league and knockout phases.',
    jsonb_build_object('tier', 1, 'supports_tables', true, 'supports_fixtures', true, 'supports_player_registrations', true)
  )
on conflict (slug) do update
set
  name = excluded.name,
  short_name = excluded.short_name,
  competition_kind = excluded.competition_kind,
  region = excluded.region,
  country_code = excluded.country_code,
  country_name = excluded.country_name,
  organizer = excluded.organizer,
  format_notes = excluded.format_notes,
  metadata = football.competitions.metadata || excluded.metadata,
  is_active = true;

insert into football.seasons (
  competition_id,
  slug,
  label,
  year_start,
  year_end,
  status,
  metadata
)
select
  c.id,
  seed.slug,
  seed.label,
  seed.year_start,
  seed.year_end,
  seed.status::football.season_status,
  seed.metadata
from football.competitions c
join (
  values
    (
      'la-liga',
      'la-liga-2025-26',
      '2025/26',
      2025,
      2026,
      'planned',
      jsonb_build_object('source', 'admin_seed')
    ),
    (
      'uefa-champions-league',
      'uefa-champions-league-2025-26',
      '2025/26',
      2025,
      2026,
      'planned',
      jsonb_build_object('source', 'admin_seed')
    )
) as seed(competition_slug, slug, label, year_start, year_end, status, metadata)
  on seed.competition_slug = c.slug
where not exists (
  select 1
  from football.seasons s
  where s.slug = seed.slug
);

-- ── Curated competition support layer for predictions ───────────────────

create table if not exists public.prediction_supported_competitions (
  id uuid primary key default gen_random_uuid(),
  competition_id uuid not null references football.competitions(id) on delete cascade,
  highlight_label text,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (competition_id)
);

create index if not exists idx_prediction_supported_competitions_active_sort
  on public.prediction_supported_competitions (is_active, sort_order, created_at desc);

alter table public.prediction_supported_competitions enable row level security;

drop policy if exists prediction_supported_competitions_select_all
  on public.prediction_supported_competitions;
create policy prediction_supported_competitions_select_all
on public.prediction_supported_competitions
for select
using (true);

drop policy if exists prediction_supported_competitions_insert_admin
  on public.prediction_supported_competitions;
create policy prediction_supported_competitions_insert_admin
on public.prediction_supported_competitions
for insert
to authenticated
with check (public.is_admin_user());

drop policy if exists prediction_supported_competitions_update_admin
  on public.prediction_supported_competitions;
create policy prediction_supported_competitions_update_admin
on public.prediction_supported_competitions
for update
to authenticated
using (public.is_admin_user())
with check (public.is_admin_user());

drop policy if exists prediction_supported_competitions_delete_admin
  on public.prediction_supported_competitions;
create policy prediction_supported_competitions_delete_admin
on public.prediction_supported_competitions
for delete
to authenticated
using (public.is_admin_user());

drop trigger if exists trg_prediction_supported_competitions_updated
  on public.prediction_supported_competitions;
create trigger trg_prediction_supported_competitions_updated
before update on public.prediction_supported_competitions
for each row execute function public.set_updated_at();

drop trigger if exists trg_audit_prediction_supported_competitions
  on public.prediction_supported_competitions;
create trigger trg_audit_prediction_supported_competitions
after insert or update or delete on public.prediction_supported_competitions
for each row execute function public.log_admin_mutation();

insert into public.prediction_supported_competitions (
  competition_id,
  highlight_label,
  sort_order,
  is_active,
  metadata
)
select
  c.id,
  seed.highlight_label,
  seed.sort_order,
  true,
  jsonb_build_object('source', 'product_brief')
from football.competitions c
join (
  values
    ('fifa-world-cup-2026', 'Featured', 10),
    ('english-premier-league', 'Featured', 20),
    ('la-liga', 'Featured', 30),
    ('uefa-champions-league', 'Featured', 40),
    ('rwanda-premier-league', 'Local', 50),
    ('drc-premier-league', 'Local', 60),
    ('zambia-super-league', 'Local', 70)
) as seed(slug, highlight_label, sort_order)
  on seed.slug = c.slug
on conflict (competition_id) do update
set
  highlight_label = excluded.highlight_label,
  sort_order = excluded.sort_order,
  is_active = excluded.is_active,
  metadata = public.prediction_supported_competitions.metadata || excluded.metadata,
  updated_at = now();

create or replace view public.prediction_supported_competitions_catalog
with (security_invoker = true) as
select
  psc.id as support_id,
  psc.sort_order as support_sort_order,
  psc.highlight_label,
  psc.is_active as is_supported,
  coalesce(fx.fixture_count, 0) as fixture_count,
  c.id,
  c.slug,
  c.name,
  c.short_name,
  c.competition_kind,
  c.region,
  c.country_code,
  c.country_name,
  c.organizer,
  c.gender,
  c.format_notes,
  c.is_active,
  c.metadata,
  c.created_at,
  c.updated_at
from public.prediction_supported_competitions psc
join public.football_competitions_catalog c
  on c.id = psc.competition_id
left join lateral (
  select count(*)::integer as fixture_count
  from football.fixtures f
  where f.competition_id = psc.competition_id
) fx on true;

create or replace view public.prediction_supported_fixtures_catalog
with (security_invoker = true) as
select
  f.*
from public.football_fixtures_catalog f
join public.prediction_supported_competitions psc
  on psc.competition_id = f.competition_id
where psc.is_active = true;

grant select on public.prediction_supported_competitions to anon, authenticated, service_role;
grant select on public.prediction_supported_competitions_catalog to anon, authenticated, service_role;
grant select on public.prediction_supported_fixtures_catalog to anon, authenticated, service_role;
