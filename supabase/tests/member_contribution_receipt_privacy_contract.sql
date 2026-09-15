-- Real role-switched reads for the member portal's receipt projection.
-- Synthetic fixtures deliberately include another owner and a foreign club.
begin;
create extension if not exists pgtap with schema extensions;
select plan(7);

insert into public.african_football_clubs(id,club_name,country_name,club_slug)
overriding system value values
  (9953001,'Receipt Contract Club','Rwanda','receipt-contract-club'),
  (9953002,'Foreign Receipt Club','Rwanda','receipt-contract-foreign');
insert into public.partners(id,name,slug,is_active) values
  ('99530000-0000-4000-8000-000000000100','Receipt Partner','receipt-contract-partner',true);
insert into auth.users(id,aud,role,is_anonymous) values
  ('99530000-0000-4000-8000-000000000001','authenticated','authenticated',false),
  ('99530000-0000-4000-8000-000000000002','authenticated','authenticated',false);
insert into public.users(id,phone,full_name) values
  ('99530000-0000-4000-8000-000000000001','+250799530001','Receipt Owner'),
  ('99530000-0000-4000-8000-000000000002','+250799530002','Other Receipt Owner');
insert into public.profiles(id,club_id) values
  ('99530000-0000-4000-8000-000000000001',9953001),
  ('99530000-0000-4000-8000-000000000002',9953001);
insert into public.initiatives(id,partner_id,club_id,title,category) values
  ('99530000-0000-4000-8000-000000000200','99530000-0000-4000-8000-000000000100',9953001,'Receipt fund','membership'),
  ('99530000-0000-4000-8000-000000000201','99530000-0000-4000-8000-000000000100',9953002,'Foreign fund','membership');
insert into public.initiative_contributions(id,initiative_id,user_id,club_id,amount,momo_reference) values
  ('99530000-0000-4000-8000-000000000301','99530000-0000-4000-8000-000000000200','99530000-0000-4000-8000-000000000001',9953001,1000,'QA-RECEIPT-OWN'),
  ('99530000-0000-4000-8000-000000000302','99530000-0000-4000-8000-000000000200','99530000-0000-4000-8000-000000000002',9953001,2000,'QA-RECEIPT-OTHER'),
  ('99530000-0000-4000-8000-000000000303','99530000-0000-4000-8000-000000000201','99530000-0000-4000-8000-000000000001',9953002,3000,'QA-RECEIPT-FOREIGN');

select set_config('request.jwt.claim.sub','99530000-0000-4000-8000-000000000001',true);
select set_config('request.jwt.claims','{"sub":"99530000-0000-4000-8000-000000000001","role":"authenticated","club_id":"9953001"}',true);
set local role authenticated;
select results_eq(
  $$select momo_reference from public.initiative_contributions order by momo_reference$$,
  array['QA-RECEIPT-OWN']::text[],
  'an unfiltered member query returns only its own club receipt reference'
);
select is(
  (select count(*)::integer from public.initiative_contributions
   where user_id='99530000-0000-4000-8000-000000000002'),
  0,'filtering another supporter cannot reveal their receipt'
);
select is(
  (select count(*)::integer from public.initiative_contributions where club_id=9953002),
  0,'an own-user receipt from a different club is not visible'
);
select throws_ok(
  $$update public.initiative_contributions set status='confirmed'
    where id='99530000-0000-4000-8000-000000000301'$$,
  '42501','permission denied for table initiative_contributions',
  'reading a reference does not allow the supporter to confirm payment'
);
select throws_ok(
  $$insert into public.initiative_contributions(initiative_id,user_id,club_id,amount,momo_reference)
    values('99530000-0000-4000-8000-000000000200','99530000-0000-4000-8000-000000000001',9953001,1,'QA-FORGED')$$,
  '42501','permission denied for table initiative_contributions',
  'the supporter cannot invent a receipt through a direct insert'
);
reset role;

set local role anon;
select throws_ok(
  $$select momo_reference from public.initiative_contributions$$,
  '42501','permission denied for table initiative_contributions',
  'an anonymous role cannot read any receipt reference'
);
reset role;

set local role service_role;
select is(
  (select count(*)::integer from public.initiative_contributions
   where id in ('99530000-0000-4000-8000-000000000301',
                '99530000-0000-4000-8000-000000000302',
                '99530000-0000-4000-8000-000000000303')),
  3,'the reconciliation service retains access to all three synthetic receipts'
);
reset role;
select * from finish();
rollback;
