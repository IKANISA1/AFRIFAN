-- Future objects must start private; features opt in with explicit grants.
create extension if not exists pgtap with schema extensions;
begin;
select plan(7);

create table public.qa_default_acl_probe (id integer primary key, private_note text);
alter table public.qa_default_acl_probe enable row level security;
create function public.qa_default_acl_probe() returns integer
language sql security definer set search_path = '' as 'select 7';

select ok(not has_table_privilege('anon', 'public.qa_default_acl_probe', 'SELECT,INSERT,UPDATE,DELETE'),
  'new tables do not inherit anonymous DML');
select ok(not has_table_privilege('authenticated', 'public.qa_default_acl_probe', 'SELECT,INSERT,UPDATE,DELETE'),
  'new tables do not inherit authenticated DML');
select ok(not has_function_privilege('anon', 'public.qa_default_acl_probe()', 'EXECUTE'),
  'new privileged functions cannot be called anonymously');
select ok(not has_function_privilege('authenticated', 'public.qa_default_acl_probe()', 'EXECUTE'),
  'new privileged functions require an explicit authenticated grant');
select ok(not exists (
  select 1 from pg_proc p cross join lateral aclexplode(coalesce(p.proacl, acldefault('f',p.proowner))) a
  where p.oid='public.qa_default_acl_probe()'::regprocedure and a.grantee=0 and a.privilege_type='EXECUTE'
), 'new functions do not inherit execution through PUBLIC');
select ok(has_table_privilege('service_role', 'public.qa_default_acl_probe', 'SELECT,INSERT,UPDATE,DELETE'),
  'trusted service table defaults are preserved while their callers are audited');

grant execute on function public.qa_default_acl_probe() to authenticated;
set local role authenticated;
select is(public.qa_default_acl_probe(), 7, 'an explicit feature grant enables the intended caller');
reset role;
select * from finish();
rollback;
