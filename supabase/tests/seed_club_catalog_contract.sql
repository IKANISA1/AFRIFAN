create extension if not exists pgtap with schema extensions;
begin;
select plan(10);
create temporary table qa_expected_clubs (id bigint primary key, currency text, nickname text, country_code text, primary_color text, secondary_color text, accent_color text) on commit drop;
insert into qa_expected_clubs values
  (6, 'CDF', 'AS Vita Club', 'CD', '#006400', '#000000', '#FFD700'),
  (26, 'ZMW', 'Nkana FC', 'ZM', '#CC0000', '#D1D5DB', '#000000'),
  (24, 'RWF', 'Gikundiro', 'RW', '#0038A8', '#001742', '#D9B24C'),
  (44, 'BIF', 'Vital''O', 'BI', '#7B2D8E', '#D1D5DB', '#FFD700');
select is((select count(*)::integer from public.african_football_clubs),4,
  'fresh supported-club catalog contains only the four retained products');
select is((select count(*)::integer from public.african_football_clubs c join qa_expected_clubs e using(id) where c.is_active),4,
  'every configured club is available in a clean local catalog');
select is((select count(*)::integer from public.african_football_clubs c join qa_expected_clubs e using(id) where c.currency_code is distinct from e.currency),0,
  'club currencies match the app configurations');
select is((select count(*)::integer from public.admin_role_assignments a left join public.users u on u.id=a.user_id where u.id is null),0,
  'catalog seed has no orphaned operator assignments');
select ok((select last_value >= (select max(id) from public.african_football_clubs) from public.african_football_clubs_id_seq),
  'new club identities cannot collide with the seeded catalog');
select is((select count(*)::integer from public.african_football_clubs c join qa_expected_clubs e using(id)
  where c.nickname_brand_identity is not distinct from e.nickname),4,
  'all configured club display identities are usable by the admin selector');
select is((select count(*)::integer from public.african_football_clubs c join qa_expected_clubs e using(id)
  where c.country_iso_code is not distinct from e.country_code),4,
  'all configured club country codes support strict settings validation');
select is((select count(*)::integer from public.african_football_clubs c join qa_expected_clubs e using(id)
  where c.primary_color_hex is not distinct from e.primary_color
    and c.secondary_color_hex is not distinct from e.secondary_color
    and c.accent_color_hex is not distinct from e.accent_color),4,
  'all configured club palettes match their existing app identity');
select is((select count(distinct country.id)::integer from public.countries country
  join qa_expected_clubs expected on expected.country_code = country.id),4,
  'all configured club countries have required parent records');
select ok(not exists(select 1 from public.countries country
  join qa_expected_clubs expected on expected.country_code = country.id
  where country.id not in ('CD','RW','ZM')
    and (country.is_active or country.telecom_provider <> '' or country.momo_brand <> ''
      or country.ussd_number_format <> '' or country.ussd_code_format <> '')),
  'reference-only country parents do not activate unconfigured provider routes');
select * from finish();
rollback;
