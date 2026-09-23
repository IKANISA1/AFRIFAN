create extension if not exists pgtap with schema extensions;
begin;
select plan(9);
select ok(exists(select 1 from pg_publication where pubname='supabase_realtime' and not puballtables),
  'realtime publishes an explicit set of tables');
select ok(exists(select 1 from pg_publication_tables where pubname='supabase_realtime'
  and schemaname='public' and tablename='matches'),'legacy match updates are published');
select ok(exists(select 1 from pg_publication_tables where pubname='supabase_realtime'
  and schemaname='football' and tablename='fixtures'),'shared fixture updates are published');
select is((select count(*)::integer from pg_publication_tables where pubname='supabase_realtime'),2,
  'private member, payment, SMS, storage and operator tables are not added');
select ok((select relrowsecurity from pg_class where oid='public.matches'::regclass)
  and (select relrowsecurity from pg_class where oid='football.fixtures'::regclass),
  'both backing tables retain RLS');
select ok(has_column_privilege('anon','public.matches','id','select')
  and has_column_privilege('anon','public.matches','home_score','select')
  and has_column_privilege('anon','football.fixtures','id','select')
  and has_column_privilege('anon','football.fixtures','home_score','select'),
  'guest subscriptions retain the existing public column read contract');
select ok(not has_table_privilege('anon','public.matches','select')
  and not has_column_privilege('anon','public.matches','image_rights_approved_by','select'),
  'publication does not widen legacy match column grants or expose internal image approvals');
select ok(not has_table_privilege('anon','public.matches','insert,update,delete')
  and not has_table_privilege('anon','football.fixtures','insert,update,delete'),
  'guest subscriptions do not gain table mutation rights');
select is((select option from pg_class c cross join lateral unnest(c.reloptions) option
  where c.oid='public.unified_matches'::regclass and option='security_invoker=true'),
  'security_invoker=true','refreshes preserve the invoker-authorized public projection');
select * from finish();
rollback;
