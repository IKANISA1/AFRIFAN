-- Exercise the portal's actual client role, not a privileged fixture session.
create extension if not exists pgtap with schema extensions;
begin;
select plan(17);

insert into public.african_football_clubs (id, club_name, country_name, club_slug)
overriding system value
values (9957001, 'Venue ACL club', 'Rwanda', 'qa-venue-acl'),
       (9957002, 'Other venue ACL club', 'Rwanda', 'qa-venue-acl-other');
insert into auth.users (id, aud, role) values
('99570000-0000-4000-8000-000000000001', 'authenticated', 'authenticated'),
('99570000-0000-4000-8000-000000000002', 'authenticated', 'authenticated'),
('99570000-0000-4000-8000-000000000003', 'authenticated', 'authenticated');
insert into public.users (id, phone, full_name) values
('99570000-0000-4000-8000-000000000001', '+250795570001', 'Venue staff'),
('99570000-0000-4000-8000-000000000002', '+250795570002', 'Other staff'),
('99570000-0000-4000-8000-000000000003', '+250795570003', 'Unassigned member');
insert into public.profiles (id, club_id) values
('99570000-0000-4000-8000-000000000001', 9957001),
('99570000-0000-4000-8000-000000000002', 9957002),
('99570000-0000-4000-8000-000000000003', 9957001);
insert into public.venues (id, club_id, slug, display_name, city, status, approved_public_profile) values
('99570000-0000-4000-8000-000000000101', 9957001, 'qa-venue-acl-private', 'Assigned private venue', 'Kigali', 'approved', false),
('99570000-0000-4000-8000-000000000102', 9957002, 'qa-venue-acl-other-private', 'Other private venue', 'Kigali', 'approved', false);
insert into public.venue_staff_memberships (club_id, venue_id, user_id, role, notes) values
(9957001, '99570000-0000-4000-8000-000000000101', '99570000-0000-4000-8000-000000000001', 'staff', 'Private assignment note'),
(9957002, '99570000-0000-4000-8000-000000000102', '99570000-0000-4000-8000-000000000002', 'staff', 'Private other note');

select ok(has_column_privilege('authenticated', 'public.venue_staff_memberships', 'club_id', 'SELECT'), 'portal can read membership scope');
select ok(has_column_privilege('authenticated', 'public.venue_staff_memberships', 'granted_at', 'SELECT'), 'portal can order active memberships');
select ok(has_column_privilege('authenticated', 'public.venues', 'display_name', 'SELECT'), 'portal can read venue identity');
select ok(not has_column_privilege('authenticated', 'public.venue_staff_memberships', 'notes', 'SELECT'), 'private assignment notes remain unavailable');
select ok(not has_table_privilege('authenticated', 'public.venue_staff_memberships', 'INSERT,UPDATE,DELETE'), 'staff grants do not enable membership writes');
select ok(not has_table_privilege('authenticated', 'public.venues', 'INSERT,UPDATE,DELETE'), 'venue identity reads do not enable venue writes');
select ok(not has_any_column_privilege('anon', 'public.venue_staff_memberships', 'SELECT'), 'anonymous membership access stays denied');

set local request.jwt.claim.sub='99570000-0000-4000-8000-000000000001';
set local role authenticated;
select results_eq($$select club_id, venue_id, role from public.venue_staff_memberships where user_id=auth.uid() and is_active order by granted_at limit 1$$,
  $$values (9957001::bigint, '99570000-0000-4000-8000-000000000101'::uuid, 'staff'::text)$$,
  'the exact active membership lookup succeeds as the assigned client');
select results_eq($$select id, club_id, display_name, city from public.venues where id='99570000-0000-4000-8000-000000000101' and club_id=9957001$$,
  $$values ('99570000-0000-4000-8000-000000000101'::uuid, 9957001::bigint, 'Assigned private venue'::text, 'Kigali'::text)$$,
  'the exact assigned venue lookup succeeds without public listing');
select is((select count(*) from public.venue_staff_memberships where user_id='99570000-0000-4000-8000-000000000002'), 0::bigint, 'other staff identities remain hidden by RLS');
select is((select count(id) from public.venues where id='99570000-0000-4000-8000-000000000102'), 0::bigint, 'other private venues remain hidden by RLS');
select throws_ok('select notes from public.venue_staff_memberships', '42501', null, 'staff cannot read private notes');
select throws_ok($$update public.venue_staff_memberships set role='owner' where user_id=auth.uid()$$, '42501', null, 'staff cannot promote themselves');
reset role;

set local request.jwt.claim.sub='99570000-0000-4000-8000-000000000003';
set local role authenticated;
select is((select count(*) from public.venue_staff_memberships where user_id=auth.uid() and is_active), 0::bigint, 'an unassigned member gets no venue membership');
select is((select count(id) from public.venues where id='99570000-0000-4000-8000-000000000101'), 0::bigint, 'same club alone does not expose a private venue');
reset role;

update public.venue_staff_memberships set is_active=false where user_id='99570000-0000-4000-8000-000000000001';
set local request.jwt.claim.sub='99570000-0000-4000-8000-000000000001';
set local role authenticated;
select is((select count(*) from public.venue_staff_memberships where user_id=auth.uid() and is_active), 0::bigint, 'a revoked membership no longer opens the portal');
select is((select count(id) from public.venues where id='99570000-0000-4000-8000-000000000101'), 0::bigint, 'a revoked staff member cannot read the private venue');
reset role;
select * from finish();
rollback;
