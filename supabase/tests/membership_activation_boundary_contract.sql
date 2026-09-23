-- Accepted paid-membership boundary. Runtime matching and idempotency are also
-- exercised by tools/tests/automatic_paid_membership_contract.py.
begin;
create extension if not exists pgtap with schema extensions;
set search_path=public,extensions;
select no_plan();
select ok(
 has_table_privilege('anon','membership_packages','SELECT') and
 has_table_privilege('authenticated','membership_packages','SELECT') and
 not has_table_privilege('authenticated','membership_packages','INSERT') and
 not has_table_privilege('authenticated','fan_memberships','INSERT') and
 not has_table_privilege('authenticated','fan_memberships','UPDATE') and
 has_column_privilege('authenticated','fan_memberships','tier','SELECT'),
 'supporters read their catalog and membership without granting themselves a tier');
select ok(not has_any_column_privilege(role_name,'membership_applications','SELECT,INSERT,UPDATE'),
 role_name || ' cannot access retired membership applications')
from (values ('anon'),('authenticated')) roles(role_name);
select ok(not has_table_privilege('service_role','membership_applications','INSERT,UPDATE,DELETE'),
 'the service API cannot reopen the retired application workflow');
select ok(not has_function_privilege(role_name,procedure.oid,'EXECUTE'),
 role_name || ' cannot call ' || procedure.proname)
from pg_proc procedure cross join (values ('anon'),('authenticated'),('service_role')) roles(role_name)
where procedure.pronamespace='public'::regnamespace
 and (procedure.proname like '%review_membership_application%' or procedure.proname in
 ('activate_free_fan_membership','activate_free_fan_membership_for_club','submit_membership_application'));
select ok(has_function_privilege('authenticated','prepare_membership_payment_for_club(text,bigint)','EXECUTE')
 and not has_function_privilege('anon','prepare_membership_payment_for_club(text,bigint)','EXECUTE')
 and not has_function_privilege('service_role','prepare_membership_payment_for_club(text,bigint)','EXECUTE'),
 'club-bound payment preparation requires a supporter session');
select ok(not has_table_privilege('authenticated','membership_payment_orders','INSERT,UPDATE,DELETE')
 and exists(select 1 from pg_class where oid='membership_payment_orders'::regclass and relrowsecurity),
 'payment snapshots are server-owned and row-level security is enabled');
select ok(not exists(select 1 from membership_packages where is_active and coalesce(nullif(annual_price,0),price,0)<=0),
 'the active catalog contains only paid tiers');
select ok(exists(select 1 from pg_constraint where conrelid='membership_packages'::regclass
 and conname='active_membership_price_positive'),
 'a database constraint prevents publishing a free tier');
select ok(exists(select 1 from pg_class where oid='membership_tiers'::regclass
 and 'security_invoker=true'=any(coalesce(reloptions,'{}'::text[]))),
 'the tier view respects the caller catalog policy');
select ok(exists(select 1 from pg_proc where oid='prepare_membership_payment(text)'::regprocedure
 and prosecdef and proconfig=array['search_path=""']::text[]),
 'payment preparation has an explicit security-definer boundary and fixed search path');
select ok(not exists(select 1 from pg_proc where pronamespace='public'::regnamespace
 and prosrc ~ 'tier\s*=\s*public[.]resolve_fan_tier\([^()]*\),'),
 'wallet balance changes cannot overwrite a purchased membership tier');
select * from finish();
rollback;
