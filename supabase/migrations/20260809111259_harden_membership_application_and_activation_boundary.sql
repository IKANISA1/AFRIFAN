begin;

-- Align the canonical membership catalog and membership record with the six
-- official physical/live-event categories while preserving the legacy values.
alter table public.membership_packages
  drop constraint if exists rs_membership_packages_tier_check,
  drop constraint if exists membership_packages_tier_check,
  add constraint membership_packages_tier_check check (
    tier = any (array[
      'fan',
      'bronze',
      'silver',
      'gold',
      'platinum',
      'imena',
      'inyamibwa',
      'ingenzi-imanzi'
    ]::text[])
  );

alter table public.fan_memberships
  drop constraint if exists rs_fan_memberships_tier_check,
  drop constraint if exists fan_memberships_tier_check,
  add constraint fan_memberships_tier_check check (
    tier = any (array[
      'fan',
      'bronze',
      'silver',
      'gold',
      'platinum',
      'imena',
      'inyamibwa',
      'ingenzi-imanzi'
    ]::text[])
  );

alter table public.membership_packages
  add column if not exists benefit_scope text not null default 'unclassified',
  add column if not exists store_billing_required boolean not null default false,
  drop constraint if exists membership_packages_benefit_scope_check,
  add constraint membership_packages_benefit_scope_check check (
    benefit_scope in (
      'unclassified',
      'physical_membership',
      'digital_entitlement'
    )
  );

comment on column public.membership_packages.benefit_scope is
  'Reviewed commercial classification. Physical membership means physical goods, live-event access, or in-person services; unclassified offers cannot be purchased.';
comment on column public.membership_packages.store_billing_required is
  'True only for a digital entitlement that must use an approved platform billing implementation.';

create index if not exists idx_membership_applications_pending_lookup
on public.membership_applications (user_id, club_id, tier)
where status = 'pending';

-- Public packages are catalog copy only. Supporter/member state is read-only;
-- activation, application and review are all function boundaries.
revoke all privileges on table public.membership_packages
from public, anon, authenticated, service_role;
grant select on table public.membership_packages to anon, authenticated;
grant all privileges on table public.membership_packages to service_role;

revoke all privileges on table public.fan_memberships
from public, anon, authenticated, service_role;
grant select (
  id,
  user_id,
  partner_id,
  club_id,
  tier,
  points,
  joined_at,
  chapter,
  membership_number,
  display_name,
  expires_at,
  renewed_at,
  payment_status,
  status,
  created_at,
  updated_at
) on table public.fan_memberships to authenticated;
grant all privileges on table public.fan_memberships to service_role;

revoke all privileges on table public.membership_applications
from public, anon, authenticated, service_role;
grant select on table public.membership_applications to authenticated;
grant all privileges on table public.membership_applications to service_role;

drop policy if exists membership_packages_admin_all on public.membership_packages;
drop policy if exists membership_packages_public_read on public.membership_packages;
drop policy if exists membership_packages_select_club on public.membership_packages;
drop policy if exists rs_membership_packages_delete_admin on public.membership_packages;
drop policy if exists rs_membership_packages_insert_admin on public.membership_packages;
drop policy if exists rs_membership_packages_select_authenticated on public.membership_packages;
drop policy if exists rs_membership_packages_update_admin on public.membership_packages;
drop policy if exists membership_packages_active_catalog on public.membership_packages;
drop policy if exists membership_packages_active_catalog_anon on public.membership_packages;
drop policy if exists membership_packages_active_catalog_authenticated on public.membership_packages;

create policy membership_packages_active_catalog_anon
on public.membership_packages
for select
to anon
using (
  is_active
  and benefit_scope = 'physical_membership'
  and store_billing_required is false
);

create policy membership_packages_active_catalog_authenticated
on public.membership_packages
for select
to authenticated
using (
  is_active
  and benefit_scope = 'physical_membership'
  and store_billing_required is false
  and (club_id is null or club_id::text = public.requesting_club_id())
);

drop policy if exists fan_memberships_insert_self on public.fan_memberships;
drop policy if exists fan_memberships_select_club on public.fan_memberships;
drop policy if exists fan_memberships_update_self_or_admin on public.fan_memberships;
drop policy if exists partner_admin_reads_all_memberships on public.fan_memberships;
drop policy if exists rs_fan_memberships_delete_admin on public.fan_memberships;
drop policy if exists rs_fan_memberships_insert_own on public.fan_memberships;
drop policy if exists rs_fan_memberships_select_authenticated on public.fan_memberships;
drop policy if exists rs_fan_memberships_update_admin on public.fan_memberships;
drop policy if exists rs_fan_memberships_update_own on public.fan_memberships;
drop policy if exists fan_memberships_club_directory_read on public.fan_memberships;

create policy fan_memberships_club_directory_read
on public.fan_memberships
for select
to authenticated
using (club_id::text = public.requesting_club_id());

drop policy if exists membership_applications_select_own
on public.membership_applications;
drop policy if exists membership_applications_insert_own
on public.membership_applications;
drop policy if exists membership_applications_admin_all
on public.membership_applications;
drop policy if exists membership_applications_owner_read
on public.membership_applications;
drop policy if exists membership_applications_admin_read
on public.membership_applications;

create policy membership_applications_owner_read
on public.membership_applications
for select
to authenticated
using (
  user_id = auth.uid()
  and club_id::text = public.requesting_club_id()
);

create policy membership_applications_admin_read
on public.membership_applications
for select
to authenticated
using (
  club_id::text = public.requesting_club_id()
  and public.is_club_admin(club_id)
);

-- Compatibility read model for clients that previously addressed a table that
-- never existed. It is a security-invoker projection of membership_packages.
drop view if exists public.membership_tiers;
create view public.membership_tiers
with (security_invoker = true)
as
select
  package.id,
  package.partner_id,
  package.club_id,
  package.tier,
  package.tier as category_slug,
  package.title,
  package.title as name,
  package.subtitle,
  package.description,
  package.benefits,
  package.annual_price,
  package.price,
  package.is_active,
  package.is_active as active,
  package.sort_order,
  package.benefit_scope,
  package.store_billing_required,
  package.created_at,
  package.updated_at
from public.membership_packages as package;

revoke all privileges on table public.membership_tiers
from public, anon, authenticated, service_role;
grant select on table public.membership_tiers to anon, authenticated, service_role;

create or replace function public.activate_free_fan_membership()
returns public.fan_memberships
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := auth.uid();
  v_club_id bigint;
  v_partner_id uuid;
  v_membership public.fan_memberships;
begin
  if v_actor_id is null then
    raise exception 'An authenticated supporter is required.';
  end if;

  begin
    v_club_id := nullif(public.requesting_club_id(), '')::bigint;
  exception
    when invalid_text_representation then
      raise exception 'A valid trusted club scope is required.';
  end;

  if v_club_id is null then
    raise exception 'A trusted club scope is required.';
  end if;

  select partner.id
    into v_partner_id
    from public.partners as partner
   where partner.is_active
     and public.compat_parse_partner_id(partner.id) = v_club_id
   order by partner.sort_order, partner.id
   limit 1;

  if v_partner_id is null then
    raise exception 'The active club membership partner is not configured.';
  end if;

  insert into public.fan_memberships (
    user_id,
    partner_id,
    club_id,
    tier,
    points,
    chapter,
    payment_status,
    status
  ) values (
    v_actor_id,
    v_partner_id,
    v_club_id,
    'fan',
    0,
    'Main',
    'verified'::public.payment_status,
    'active'
  )
  on conflict (user_id, club_id)
  do update set
    status = case
      when public.fan_memberships.status = 'suspended'
        then public.fan_memberships.status
      else 'active'
    end,
    payment_status = case
      when public.fan_memberships.tier = 'fan'
        then 'verified'::public.payment_status
      else public.fan_memberships.payment_status
    end,
    updated_at = pg_catalog.now()
  returning * into v_membership;

  return v_membership;
end;
$$;

revoke execute on function public.activate_free_fan_membership()
from public, anon, authenticated, service_role;
grant execute on function public.activate_free_fan_membership()
to authenticated;

create or replace function public.submit_membership_application(
  p_tier text,
  p_payment_reference text,
  p_chapter text default null
) returns public.membership_applications
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := auth.uid();
  v_club_id bigint;
  v_tier text := pg_catalog.lower(
    pg_catalog.btrim(coalesce(p_tier, ''))
  );
  v_payment_reference text := nullif(
    pg_catalog.btrim(coalesce(p_payment_reference, '')),
    ''
  );
  v_chapter text := nullif(pg_catalog.btrim(coalesce(p_chapter, '')), '');
  v_package public.membership_packages;
  v_amount numeric;
  v_application public.membership_applications;
begin
  if v_actor_id is null then
    raise exception 'An authenticated supporter is required.';
  end if;

  begin
    v_club_id := nullif(public.requesting_club_id(), '')::bigint;
  exception
    when invalid_text_representation then
      raise exception 'A valid trusted club scope is required.';
  end;

  if v_club_id is null then
    raise exception 'A trusted club scope is required.';
  end if;

  if v_tier = ''
     or v_payment_reference is null
     or pg_catalog.length(v_payment_reference) > 120
     or pg_catalog.length(coalesce(v_chapter, '')) > 80 then
    raise exception 'Tier, payment reference and chapter are invalid.';
  end if;

  select package.*
    into v_package
    from public.membership_packages as package
   where package.is_active
     and package.tier = v_tier
     and package.club_id = v_club_id
   order by package.sort_order, package.id
   limit 1
   for share;

  if v_package.id is null then
    raise exception 'The selected membership offer is not configured for this club.';
  end if;

  if v_package.benefit_scope <> 'physical_membership'
     or v_package.store_billing_required then
    raise exception 'The selected membership offer is not approved for this payment route.';
  end if;

  v_amount := case
    when coalesce(v_package.annual_price, 0) > 0
      then v_package.annual_price
    else coalesce(v_package.price, 0)
  end;

  if v_amount <= 0
     or v_amount <> pg_catalog.trunc(v_amount)
     or v_amount > 2147483647 then
    raise exception 'The selected membership offer price is invalid.';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      v_actor_id::text || ':' || v_club_id::text || ':' || v_tier,
      0
    )
  );

  select application.*
    into v_application
    from public.membership_applications as application
   where application.user_id = v_actor_id
     and application.club_id = v_club_id
     and application.tier = v_tier
     and application.status = 'pending'
   order by application.application_date desc, application.id
   limit 1;

  if v_application.id is not null then
    return v_application;
  end if;

  insert into public.membership_applications (
    user_id,
    club_id,
    tier,
    status,
    payment_status,
    metadata
  ) values (
    v_actor_id,
    v_club_id,
    v_tier,
    'pending',
    'unpaid',
    pg_catalog.jsonb_build_object(
      'package_id', v_package.id,
      'package_title', v_package.title,
      'amount', v_amount::integer,
      'currency_code', 'RWF',
      'chapter', coalesce(v_chapter, 'Main'),
      'payment_reference', v_payment_reference,
      'benefit_scope', v_package.benefit_scope,
      'store_billing_required', v_package.store_billing_required,
      'source', 'mobile_physical_membership_application'
    )
  )
  returning * into v_application;

  insert into public.admin_audit_log (
    actor_id,
    user_id,
    action,
    target_table,
    target_id,
    old_data,
    new_data,
    club_id,
    entity_type,
    entity_id,
    metadata
  ) values (
    v_actor_id,
    v_actor_id,
    'supporter_membership_application_created',
    'membership_applications',
    v_application.id::text,
    null,
    pg_catalog.jsonb_build_object(
      'tier', v_application.tier,
      'status', v_application.status,
      'payment_status', v_application.payment_status,
      'updated_at', v_application.updated_at
    ),
    v_club_id,
    'membership_application',
    v_application.id::text,
    pg_catalog.jsonb_build_object(
      'authoritative_offer', true,
      'benefit_scope', v_package.benefit_scope,
      'source', 'mobile_physical_membership_application'
    )
  );

  return v_application;
end;
$$;

revoke execute on function public.submit_membership_application(text,text,text)
from public, anon, authenticated, service_role;
grant execute on function public.submit_membership_application(text,text,text)
to authenticated;

create or replace function public.review_membership_application_if_unchanged(
  p_application_id uuid,
  p_expected_updated_at timestamp with time zone,
  p_decision text,
  p_payment_status text,
  p_actor_id uuid,
  p_notes text default null
) returns public.membership_applications
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_decision text := pg_catalog.lower(
    pg_catalog.btrim(coalesce(p_decision, ''))
  );
  v_payment_status text := pg_catalog.lower(
    pg_catalog.btrim(coalesce(p_payment_status, ''))
  );
  v_previous public.membership_applications;
  v_application public.membership_applications;
  v_package public.membership_packages;
  v_partner_id uuid;
begin
  if p_application_id is null
     or p_expected_updated_at is null
     or p_actor_id is null then
    raise exception 'Application, loaded version and review actor are required.';
  end if;

  if v_decision not in ('approved', 'rejected')
     or v_payment_status not in ('paid', 'failed', 'unpaid')
     or pg_catalog.length(coalesce(p_notes, '')) > 500 then
    raise exception 'Membership review values are invalid.';
  end if;

  select application.*
    into v_previous
    from public.membership_applications as application
   where application.id = p_application_id
   for update;

  if not found then
    raise exception 'Membership application was not found.';
  end if;

  if v_previous.status <> 'pending' then
    raise exception 'Membership application is no longer pending. Refresh before retrying.';
  end if;

  if v_previous.updated_at is distinct from p_expected_updated_at then
    raise exception
      'Membership application changed after it was loaded. Refresh before retrying.';
  end if;

  if not exists (
    select 1
    from public.admin_role_assignments as assignment
    where assignment.user_id = p_actor_id
      and assignment.is_active
      and assignment.revoked_at is null
      and (
        assignment.role in ('admin', 'super_admin')
        or (
          assignment.club_id = v_previous.club_id
          and assignment.role in ('club_admin', 'club_moderator', 'rayon_sport')
        )
      )
  ) and not exists (
    select 1
    from public.users as app_user
    where app_user.id = p_actor_id
      and app_user.is_admin
  ) then
    raise exception 'Membership review actor is not authorized for this club.';
  end if;

  if v_decision = 'approved'
     and (
       v_payment_status <> 'paid'
       or v_previous.payment_status <> 'paid'
     ) then
    raise exception
      'Approved memberships require a separately verified payment state.';
  end if;

  update public.membership_applications as application
     set status = v_decision,
         payment_status = v_payment_status,
         reviewer_id = p_actor_id,
         review_date = pg_catalog.now(),
         notes = nullif(pg_catalog.btrim(coalesce(p_notes, '')), '')
   where application.id = v_previous.id
  returning application.* into v_application;

  if v_decision = 'approved' then
    select package.*
      into v_package
      from public.membership_packages as package
     where package.id = (v_previous.metadata ->> 'package_id')::uuid
       and package.is_active
       and package.tier = v_previous.tier
       and package.club_id = v_previous.club_id
       and package.benefit_scope = 'physical_membership'
       and not package.store_billing_required
     limit 1;

    if v_package.id is null then
      raise exception 'Membership offer is no longer eligible for activation.';
    end if;

    v_partner_id := v_package.partner_id;

    insert into public.fan_memberships (
      user_id,
      partner_id,
      club_id,
      tier,
      points,
      chapter,
      payment_status,
      status,
      renewed_at,
      expires_at
    ) values (
      v_previous.user_id,
      v_partner_id,
      v_previous.club_id,
      v_previous.tier,
      0,
      coalesce(nullif(v_previous.metadata ->> 'chapter', ''), 'Main'),
      'verified'::public.payment_status,
      'active',
      pg_catalog.now(),
      pg_catalog.now() + interval '1 year'
    )
    on conflict (user_id, club_id)
    do update set
      partner_id = excluded.partner_id,
      tier = excluded.tier,
      chapter = excluded.chapter,
      payment_status = excluded.payment_status,
      status = excluded.status,
      renewed_at = excluded.renewed_at,
      expires_at = excluded.expires_at,
      updated_at = pg_catalog.now();
  end if;

  insert into public.admin_audit_log (
    actor_id,
    user_id,
    action,
    target_table,
    target_id,
    old_data,
    new_data,
    club_id,
    entity_type,
    entity_id,
    metadata
  ) values (
    p_actor_id,
    v_previous.user_id,
    'membership_application_reviewed',
    'membership_applications',
    v_application.id::text,
    pg_catalog.jsonb_build_object(
      'status', v_previous.status,
      'payment_status', v_previous.payment_status,
      'updated_at', v_previous.updated_at
    ),
    pg_catalog.jsonb_build_object(
      'status', v_application.status,
      'payment_status', v_application.payment_status,
      'updated_at', v_application.updated_at
    ),
    v_application.club_id,
    'membership_application',
    v_application.id::text,
    pg_catalog.jsonb_build_object(
      'optimistic_concurrency', true,
      'membership_activated', v_decision = 'approved',
      'benefit_scope', coalesce(v_package.benefit_scope, 'not_applicable')
    )
  );

  return v_application;
end;
$$;

revoke execute on function public.review_membership_application_if_unchanged(
  uuid,
  timestamp with time zone,
  text,
  text,
  uuid,
  text
) from public, anon, authenticated, service_role;
grant execute on function public.review_membership_application_if_unchanged(
  uuid,
  timestamp with time zone,
  text,
  text,
  uuid,
  text
) to service_role;

commit;
