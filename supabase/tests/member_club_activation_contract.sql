-- Synthetic supporters exercise every retained club; all fixtures roll back.
begin;
create extension if not exists pgtap with schema extensions;
set search_path=public,extensions;
select no_plan();

select ok(has_function_privilege('authenticated','public.activate_free_fan_membership_for_club(bigint)','execute')
  and not has_function_privilege('anon','public.activate_free_fan_membership_for_club(bigint)','execute')
  and not has_function_privilege('service_role','public.activate_free_fan_membership_for_club(bigint)','execute'),
  'only authenticated supporters may use the website activation entry point');
select ok((select not prosecdef and proconfig=array['search_path=""'] from pg_proc
  where oid='public.activate_free_fan_membership_for_club(bigint)'::regprocedure),
  'the website guard adds no privileges and fixes its search path');
select set_config('request.jwt.claim.sub','',true);
select set_config('request.jwt.claims','{"role":"authenticated"}',true);
set local role authenticated;
select throws_ok($$select public.activate_free_fan_membership_for_club(24)$$,
  '42501','MEMBER_AUTH_REQUIRED','missing identity cannot activate membership');
reset role;
select set_config('request.jwt.claim.sub','99371000-0000-4000-8000-000000000024',true);
select set_config('request.jwt.claims','{"sub":"99371000-0000-4000-8000-000000000024","role":"authenticated"}',true);
set local role authenticated;
select throws_ok($$select public.activate_free_fan_membership_for_club(24)$$,
  '42501','MEMBER_CLUB_MISMATCH','missing trusted club cannot be replaced by caller input');
reset role;

select set_config('request.jwt.claim.sub','',true);
select set_config('request.jwt.claims','{}',true);
insert into public.partners(id,name,slug,is_active)
select ('99371000-0000-4000-8000-'||lpad(id::text,12,'0'))::uuid,club_name,club_slug,true
from public.african_football_clubs where id in (44,24,26,6);
insert into auth.users(id,aud,role,is_anonymous,phone,phone_confirmed_at)
select ('99371001-0000-4000-8000-'||lpad(id::text,12,'0'))::uuid,
  'authenticated','authenticated',false,'+250799371'||lpad(id::text,3,'0'),now()
from public.african_football_clubs where id in (44,24,26,6);
insert into public.profiles(id,club_id,display_name)
select ('99371001-0000-4000-8000-'||lpad(id::text,12,'0'))::uuid,id,'Synthetic club activation'
from public.african_football_clubs where id in (44,24,26,6);

-- pgTAP calls run as the actual API role inside this helper, not as an owner.
create function pg_temp.check_club_activation(p_club_id bigint) returns setof text
language plpgsql as $$
declare v_user uuid := ('99371001-0000-4000-8000-'||lpad(p_club_id::text,12,'0'))::uuid;
begin
  perform set_config('request.jwt.claim.sub',v_user::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_user,'role','authenticated','club_id',p_club_id::text)::text,true);
  return next throws_ok(format('select public.activate_free_fan_membership_for_club(%s)',case when p_club_id=24 then 26 else 24 end),
    '42501','MEMBER_CLUB_MISMATCH',format('club %s refuses activation from a different website',p_club_id));
  return next throws_ok('select public.activate_free_fan_membership_for_club(null)',
    '42501','MEMBER_CLUB_MISMATCH','null expected club fails closed');
  return next lives_ok(format('select public.activate_free_fan_membership_for_club(%s)',p_club_id),
    format('club %s explicitly activates its own supporter',p_club_id));
  return next lives_ok(format('select public.activate_free_fan_membership_for_club(%s)',p_club_id),
    format('club %s permits an identical activation retry',p_club_id));
  return next is((select count(*) from public.fan_memberships where user_id=v_user and club_id=p_club_id),
    1::bigint,'activation and retry persist exactly one own-club membership');
  return next ok((select status='active' and tier='fan' and points=0 from public.fan_memberships where user_id=v_user and club_id=p_club_id),
    'activation preserves the free tier and zero earned balance');
end;
$$;
grant execute on function pg_temp.check_club_activation(bigint) to authenticated;
set local role authenticated;
select * from pg_temp.check_club_activation(44);
select * from pg_temp.check_club_activation(24);
select * from pg_temp.check_club_activation(26);
select * from pg_temp.check_club_activation(6);
reset role;
select * from finish();
rollback;
