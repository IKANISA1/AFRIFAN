-- Authenticated member queries must use the same column ACLs as the browser.
-- Synthetic rows only; rollback preserves the execution database.
begin;
create extension if not exists pgtap with schema extensions;
set search_path=public,extensions;
select no_plan();
insert into public.african_football_clubs(id,club_name,country_name,club_slug) overriding system value values
 (9958001,'Member Read Club','Rwanda','member-read-club'),
 (9958002,'Other Member Club','Rwanda','member-read-other');
insert into public.partners(id,name,slug,is_active) values
 ('99580000-0000-4000-8000-000000000100','Member Read Club','member-read-club',true);
insert into public.initiatives(id,partner_id,club_id,title,category,is_active,status) values
 ('99580000-0000-4000-8000-000000000201','99580000-0000-4000-8000-000000000100',9958001,'Visible campaign','club',true,'active'),
 ('99580000-0000-4000-8000-000000000202','99580000-0000-4000-8000-000000000100',9958001,'Hidden campaign','club',false,'active'),
 ('99580000-0000-4000-8000-000000000203','99580000-0000-4000-8000-000000000100',9958002,'Foreign campaign','club',true,'active');
select ok(has_column_privilege('authenticated','public.initiatives','created_at','SELECT'),'supporter may sort public campaigns by creation time');
select ok(not has_column_privilege('authenticated','public.initiatives','mock_batch','SELECT'),'private campaign fixture metadata is not exposed');
select ok(not has_table_privilege('authenticated','public.initiatives','UPDATE'),'supporter cannot edit campaigns');
set local role authenticated;
select lives_ok($$select id,title,description,raised_amount,goal_amount from public.initiatives where club_id=9958001 and is_active=true and status='active' order by created_at desc limit 6$$,'actual member campaign query succeeds under authenticated ACLs');
select results_eq($$select title from public.initiatives where club_id=9958001 and is_active=true and status='active' order by created_at desc limit 6$$,$$values('Visible campaign'::text)$$,'member query excludes hidden and other-club campaigns');
select throws_ok($$select mock_batch from public.initiatives$$,'42501','permission denied for table initiatives','private campaign metadata remains denied');
reset role;
select * from finish();
rollback;
