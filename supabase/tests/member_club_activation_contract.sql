-- Retired website free-activation endpoints cannot bypass paid memberships.
begin;
create extension if not exists pgtap with schema extensions;
set search_path=public,extensions;
select no_plan();
select ok(not has_function_privilege(role_name,procedure_name,'EXECUTE'),
  role_name || ' cannot call retired membership entry point ' || procedure_name)
from (values ('anon'),('authenticated'),('service_role')) roles(role_name)
cross join (values ('public.activate_free_fan_membership()'),
  ('public.activate_free_fan_membership_for_club(bigint)'),
  ('public.submit_membership_application(text,text,text)')) procedures(procedure_name);
select ok(has_function_privilege('authenticated','public.prepare_membership_payment(text)','EXECUTE')
  and not has_function_privilege('anon','public.prepare_membership_payment(text)','EXECUTE'),
  'only an authenticated account can prepare a paid membership');
select ok(not has_table_privilege('authenticated','public.membership_payment_orders','INSERT')
  and not has_table_privilege('authenticated','public.membership_payment_orders','UPDATE'),
  'supporters cannot manufacture paid order or activation evidence');
select * from finish();
rollback;
