-- Only for test_predict_database.py's disposable, network-disabled database.
-- Reuses that harness's synthetic Predict club, buyer, verifier and partner.
-- A controlled confirmed ticket isolates admission from provider settlement.
begin;
insert into public.venues(id, club_id, slug, display_name, status, approved_public_profile)
values ('99460000-0000-4000-8000-000000000710', 9946001,
  'concurrent-ticket-test', 'Concurrency Test Venue', 'approved', false);
insert into public.matches(id, partner_id, club_id, home_team, away_team,
  competition, venue, match_date, kickoff_time, capacity)
values ('99460000-0000-4000-8000-000000000711',
  '99460000-0000-4000-8000-000000000100', 9946001,
  'Test Home', 'Test Away', 'Test Cup', 'Concurrency Test Venue',
  current_date, '23:00', 20);
insert into public.ticket_organizations(id, club_id, slug, display_name,
  status, google_wallet_issuer_id)
values ('99460000-0000-4000-8000-000000000712', 9946001,
  'concurrent-ticket-test', 'Concurrency Test Organization', 'active', '1234567890123456');
insert into public.tickets(id, match_id, user_id, club_id, seat_type,
  amount_paid, status, confirmed_at)
values ('99460000-0000-4000-8000-000000000713',
  '99460000-0000-4000-8000-000000000711',
  '99460000-0000-4000-8000-000000000001', 9946001,
  'General admission', 5000, 'valid', now());
insert into public.ticket_events(id, club_id, organization_id, match_id,
  venue_id, status, entry_opens_at, entry_closes_at,
  google_wallet_enabled, verification_enabled)
values ('99460000-0000-4000-8000-000000000714', 9946001,
  '99460000-0000-4000-8000-000000000712',
  '99460000-0000-4000-8000-000000000711',
  '99460000-0000-4000-8000-000000000710', 'active',
  now() - interval '1 hour', now() + interval '1 hour', true, true);
select public.grant_ticket_verifier_assignment(
  '99460000-0000-4000-8000-000000000005', 9946001,
  '99460000-0000-4000-8000-000000000714',
  '99460000-0000-4000-8000-000000000005', 'NORTH',
  now() - interval '30 minutes', now() + interval '30 minutes');
commit;
