-- Product retirement must remove backend capability as well as frontend routes.
create extension if not exists pgtap with schema extensions;
begin;
select plan(10);

select is((select count(*)::integer from pg_tables where schemaname='public'
  and (tablename ~ '^venue' or tablename in ('fet_ledger_reservations','ticket_verifier_assignments','ticket_redemption_events'))),0,
  'retired operational tables are absent');
select is((select count(*)::integer from pg_proc where pronamespace='public'::regnamespace
  and (proname ~ '^venue_' or proname in ('grant_ticket_verifier_assignment','revoke_ticket_verifier_assignment','redeem_ticket_for_verifier','prevent_ticket_redemption_event_mutation'))),0,
  'retired write and staff-authority functions are absent');
select is((select count(*)::integer from public.platform_route_registry
  where surface='venue' or feature_key like 'venue_%' or path_pattern ~ '^/(venue(s)?|fanzone/venue|admin/venues|admin/tickets/verifiers)(/|$)'),0,
  'runtime routes cannot advertise the removed product');
select is((select count(*)::integer from public.platform_features where feature_key like 'venue_%'),0,
  'retired feature flags are absent');
select is((select count(*)::integer from public.platform_option_sets where surface='venue' or option_set_key like 'venue_%'),0,
  'retired option sets are absent');
select is((select count(*)::integer from (
  select href from public.site_navigation_items where surface='venue' or feature_key like 'venue_%' or href ~ '^/(venue(s)?|fanzone/venue|admin/venues|admin/tickets/verifiers)(/|$)'
  union all
  select href from public.site_search_items where surface='venue' or feature_key like 'venue_%' or href ~ '^/(venue(s)?|fanzone/venue|admin/venues|admin/tickets/verifiers)(/|$)'
) removed),0,'navigation and search have no removed destinations');
select ok(not public.get_platform_config('mobile',24) ? 'venue_governance_controls'
  and not public.get_platform_config('web',24) ? 'venue_governance_controls',
  'public configuration no longer exposes venue governance');
select is((select count(*)::integer from information_schema.columns where table_schema='public' and table_name='ticket_events'
  and column_name in ('venue_id','verification_enabled')),0,
  'ticket events have no dependency on retired operators');
select is((select count(*)::integer from information_schema.columns where table_schema='public' and table_name='ticket_events'
  and column_name in ('location_name','location_address','location_country_code','location_timezone') and is_nullable='NO'),4,
  'ticket events own the stadium details required by Wallet passes');
select is((select count(*)::integer from pg_proc where pronamespace='public'::regnamespace and prokind='f'
  and prosrc ~ 'public\.(venues|venue_|ticket_verifier_assignments|ticket_redemption_events)'),0,
  'retained functions do not reference removed operational tables');

select * from finish();
rollback;
