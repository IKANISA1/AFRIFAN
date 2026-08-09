begin;

-- PostgreSQL 17 introduced MAINTAIN as a separate table privilege. Reassert
-- that browser-facing roles never inherit it, including on legacy tables.
revoke maintain on all tables in schema public from anon, authenticated;
revoke maintain on all tables in schema football from anon, authenticated;
revoke maintain on all tables in schema africlub_game from anon, authenticated;

-- Internal award, wallet, settlement and notification helpers are callable by
-- their owner-backed SECURITY DEFINER entry points, never by Data API clients.
revoke execute on function public.apply_membership_points(uuid,uuid,integer,text)
from public, anon, authenticated, service_role;
revoke execute on function public.rs_apply_membership_points(uuid,uuid,integer,text)
from public, anon, authenticated, service_role;
revoke execute on function public.prediction_challenge_adjust_wallet(
  bigint,uuid,bigint,text,text,text,text,text,jsonb
) from public, anon, authenticated, service_role;
revoke execute on function public.prediction_challenge_queue_notification(
  uuid,text,text,text,jsonb
) from public, anon, authenticated, service_role;
revoke execute on function public.prediction_challenge_refund_all(
  uuid,text,text,text,text,integer,integer,jsonb
) from public, anon, authenticated, service_role;
do $acl$
begin
  if pg_catalog.to_regprocedure(
    'public.prediction_settle_jackpot_entries(uuid)'
  ) is not null then
    execute 'revoke execute on function public.prediction_settle_jackpot_entries(uuid) '
      || 'from public, anon, authenticated, service_role';
  end if;
end
$acl$;
revoke execute on function public.prediction_challenge_summary_json(uuid,uuid)
from public, anon, authenticated, service_role;
revoke execute on function public.prediction_challenge_user_json(uuid,bigint)
from public, anon, authenticated, service_role;
revoke execute on function public.partner_prediction_pool_summary_json(uuid,uuid)
from public, anon, authenticated, service_role;
revoke execute on function public.partner_prediction_pool_user_eligible(uuid,uuid)
from public, anon, authenticated, service_role;
revoke execute on function public.fet_get_friendship_row(uuid,uuid,bigint)
from public, anon, authenticated, service_role;

grant execute on function public.apply_membership_points(uuid,uuid,integer,text)
to service_role;
grant execute on function public.rs_apply_membership_points(uuid,uuid,integer,text)
to service_role;
grant execute on function public.prediction_challenge_adjust_wallet(
  bigint,uuid,bigint,text,text,text,text,text,jsonb
) to service_role;
grant execute on function public.prediction_challenge_queue_notification(
  uuid,text,text,text,jsonb
) to service_role;
grant execute on function public.prediction_challenge_refund_all(
  uuid,text,text,text,text,integer,integer,jsonb
) to service_role;
do $acl$
begin
  if pg_catalog.to_regprocedure(
    'public.prediction_settle_jackpot_entries(uuid)'
  ) is not null then
    execute 'grant execute on function public.prediction_settle_jackpot_entries(uuid) '
      || 'to service_role';
  end if;
end
$acl$;
grant execute on function public.prediction_challenge_summary_json(uuid,uuid)
to service_role;
grant execute on function public.prediction_challenge_user_json(uuid,bigint)
to service_role;
grant execute on function public.partner_prediction_pool_summary_json(uuid,uuid)
to service_role;
grant execute on function public.partner_prediction_pool_user_eligible(uuid,uuid)
to service_role;
grant execute on function public.fet_get_friendship_row(uuid,uuid,bigint)
to service_role;

-- The submitted build intentionally disables transfers, redemptions, social
-- discovery, editable cross-user text and staked challenges until the related
-- store-policy, moderation and value decisions are approved. Enforce the same
-- fail-closed boundary at the database, not only in Flutter navigation.
revoke execute on function public.fet_redeem(integer,text,text,bigint)
from public, anon, authenticated, service_role;
revoke execute on function public.fet_redeem_reward(uuid,text,text,bigint)
from public, anon, authenticated, service_role;
revoke execute on function public.fet_transfer(uuid,integer,text,text,bigint)
from public, anon, authenticated, service_role;
revoke execute on function public.fet_request_friend(uuid,bigint,text)
from public, anon, authenticated, service_role;
revoke execute on function public.fet_respond_friend_request(uuid,text,bigint)
from public, anon, authenticated, service_role;
revoke execute on function public.fet_find_supporters(text,bigint,integer)
from public, anon, authenticated, service_role;
revoke execute on function public.fet_get_friends(bigint,integer,text)
from public, anon, authenticated, service_role;
revoke execute on function public.fet_search_supporters(text,bigint,integer)
from public, anon, authenticated, service_role;
revoke execute on function public.fet_get_leaderboard(bigint,integer)
from public, anon, authenticated, service_role;
revoke execute on function public.fet_get_partner_offers(bigint,boolean,integer)
from public, anon, authenticated, service_role;
revoke execute on function public.prediction_create_friend_challenge(
  uuid,uuid,text,text
) from public, anon, authenticated, service_role;
revoke execute on function public.partner_prediction_pool_join(uuid,text,text)
from public, anon, authenticated, service_role;
revoke execute on function public.prediction_challenge_create(
  uuid,integer,integer,bigint,bigint
) from public, anon, authenticated, service_role;
revoke execute on function public.prediction_challenge_join(
  uuid,integer,integer
) from public, anon, authenticated, service_role;
revoke execute on function public.prediction_place_jackpot_entry(uuid,jsonb,text)
from public, anon, authenticated, service_role;
revoke execute on function public.prediction_get_challenge_feed(
  bigint,text[],text,integer,integer,boolean
) from public, anon, authenticated, service_role;
revoke execute on function public.prediction_get_my_challenges(
  bigint,text[],text,integer,integer
) from public, anon, authenticated, service_role;
revoke execute on function public.prediction_get_challenge_detail(uuid,bigint)
from public, anon, authenticated, service_role;
revoke execute on function public.partner_prediction_pool_feed(
  bigint,text[],integer,integer
) from public, anon, authenticated, service_role;

grant execute on function public.fet_redeem(integer,text,text,bigint)
to service_role;
grant execute on function public.fet_redeem_reward(uuid,text,text,bigint)
to service_role;
grant execute on function public.fet_transfer(uuid,integer,text,text,bigint)
to service_role;
grant execute on function public.fet_request_friend(uuid,bigint,text)
to service_role;
grant execute on function public.fet_respond_friend_request(uuid,text,bigint)
to service_role;
grant execute on function public.fet_find_supporters(text,bigint,integer)
to service_role;
grant execute on function public.fet_get_friends(bigint,integer,text)
to service_role;
grant execute on function public.fet_search_supporters(text,bigint,integer)
to service_role;
grant execute on function public.fet_get_leaderboard(bigint,integer)
to service_role;
grant execute on function public.fet_get_partner_offers(bigint,boolean,integer)
to service_role;
grant execute on function public.prediction_create_friend_challenge(
  uuid,uuid,text,text
) to service_role;
grant execute on function public.partner_prediction_pool_join(uuid,text,text)
to service_role;
grant execute on function public.prediction_challenge_create(
  uuid,integer,integer,bigint,bigint
) to service_role;
grant execute on function public.prediction_challenge_join(
  uuid,integer,integer
) to service_role;
grant execute on function public.prediction_place_jackpot_entry(uuid,jsonb,text)
to service_role;
grant execute on function public.prediction_get_challenge_feed(
  bigint,text[],text,integer,integer,boolean
) to service_role;
grant execute on function public.prediction_get_my_challenges(
  bigint,text[],text,integer,integer
) to service_role;
grant execute on function public.prediction_get_challenge_detail(uuid,bigint)
to service_role;
grant execute on function public.partner_prediction_pool_feed(
  bigint,text[],integer,integer
) to service_role;

-- Operational MoMo inspection and retention procedures contain raw routing
-- diagnostics or destructive behavior and are never public API endpoints.
revoke execute on function public.get_momo_validation_issues()
from public, anon, authenticated, service_role;
revoke execute on function public.redact_momo_sms_artifacts_due(
  interval,interval,integer
) from public, anon, authenticated, service_role;
revoke execute on function public.run_momo_sms_migration_safety_check()
from public, anon, authenticated, service_role;
grant execute on function public.get_momo_validation_issues() to service_role;
grant execute on function public.redact_momo_sms_artifacts_due(
  interval,interval,integer
) to service_role;
grant execute on function public.run_momo_sms_migration_safety_check()
to service_role;

-- Maintenance and lookup helpers are server operations. Their default PUBLIC
-- ACLs otherwise permit destructive cleanup, rate-limit poisoning, or auth
-- account enumeration through the Data API.
revoke execute on function public.cleanup_stale_fcm_tokens()
from public, anon, authenticated, service_role;
revoke execute on function public.find_auth_user_by_phone_or_email(text,text)
from public, anon, authenticated, service_role;
revoke execute on function public.consume_request_rate_limit(
  text,integer,integer
) from public, anon, authenticated, service_role;
grant execute on function public.cleanup_stale_fcm_tokens() to service_role;
grant execute on function public.find_auth_user_by_phone_or_email(text,text)
to service_role;
grant execute on function public.consume_request_rate_limit(
  text,integer,integer
) to service_role;

-- Legacy partner, audit, RBAC and mobility helpers disclose unscoped records
-- or accept spoofable actors. No submitted client calls them; retain only a
-- trusted server route until a scoped replacement is separately reviewed.
revoke execute on function public.get_partner_payment_route(uuid,text)
from public, anon, authenticated, service_role;
revoke execute on function public.record_admin_action(
  text,text,text,jsonb,jsonb,text
) from public, anon, authenticated, service_role;
revoke execute on function public.get_admin_access_for_user(uuid)
from public, anon, authenticated, service_role;
revoke execute on function public.get_nearby_drivers(
  double precision,double precision,text,text,double precision
) from public, anon, authenticated, service_role;
revoke execute on function public.get_scheduled_trips(
  double precision,double precision,text,text,text,double precision
) from public, anon, authenticated, service_role;
grant execute on function public.get_partner_payment_route(uuid,text)
to service_role;
grant execute on function public.record_admin_action(
  text,text,text,jsonb,jsonb,text
) to service_role;
grant execute on function public.get_admin_access_for_user(uuid)
to service_role;
grant execute on function public.get_nearby_drivers(
  double precision,double precision,text,text,double precision
) to service_role;
grant execute on function public.get_scheduled_trips(
  double precision,double precision,text,text,text,double precision
) to service_role;

-- Retire the compatibility reviewer that predates authoritative package and
-- store-billing eligibility checks. The web API uses the replacement function.
revoke execute on function public.admin_review_membership_application_if_unchanged(
  uuid,timestamp with time zone,text,text,bigint,uuid,uuid
) from public, anon, authenticated, service_role;

drop policy if exists fan_memberships_club_directory_read
on public.fan_memberships;
drop policy if exists fan_memberships_owner_or_admin_read
on public.fan_memberships;
create policy fan_memberships_owner_or_admin_read
on public.fan_memberships
for select
to authenticated
using (
  club_id::text = public.requesting_club_id()
  and (
    user_id = (select auth.uid())
    or public.is_club_admin(club_id)
  )
);

-- Paid physical membership applications remain disabled until an immutable
-- provider reconciliation can set the stored payment state independently of
-- the reviewer. Free membership activation remains available.
revoke execute on function public.submit_membership_application(text,text,text)
from public, anon, authenticated, service_role;

drop policy if exists membership_packages_active_catalog_anon
on public.membership_packages;
drop policy if exists membership_packages_active_catalog_authenticated
on public.membership_packages;
create policy membership_packages_active_catalog_anon
on public.membership_packages
for select
to anon
using (
  is_active
  and benefit_scope = 'physical_membership'
  and store_billing_required is false
  and coalesce(annual_price, price, 0) = 0
);
create policy membership_packages_active_catalog_authenticated
on public.membership_packages
for select
to authenticated
using (
  is_active
  and benefit_scope = 'physical_membership'
  and store_billing_required is false
  and coalesce(annual_price, price, 0) = 0
  and (club_id is null or club_id::text = public.requesting_club_id())
);

-- Normalize the one reviewed receiving route, then keep legacy/raw variants
-- out of the compatibility view. Anonymous consumers receive only public
-- initiative fields; authenticated same-club consumers may request the one
-- canonical route needed to launch a payment.
with normalized_routes as (
  select
    contribution_group.id,
    coalesce(
      nullif(pg_catalog.btrim(contribution_group.receiving_momo_code), ''),
      nullif(pg_catalog.btrim(contribution_group.momo_code), ''),
      nullif(pg_catalog.btrim(contribution_group.momo_number), '')
    ) as route_code,
    case
      when coalesce(
        nullif(pg_catalog.btrim(contribution_group.receiving_momo_code), ''),
        nullif(pg_catalog.btrim(contribution_group.momo_code), ''),
        nullif(pg_catalog.btrim(contribution_group.momo_number), '')
      ) is null then null
      else coalesce(
        nullif(pg_catalog.btrim(contribution_group.receiving_momo_route_type), ''),
        case
          when nullif(pg_catalog.btrim(contribution_group.momo_number), '')
            is not null then 'phone_number'
          else 'code'
        end
      )
    end as route_type
  from public.groups as contribution_group
)
update public.groups as contribution_group
set
  receiving_momo_code = normalized_routes.route_code,
  receiving_momo_route_type = normalized_routes.route_type
from normalized_routes
where normalized_routes.id = contribution_group.id
  and (
    contribution_group.receiving_momo_code
      is distinct from normalized_routes.route_code
    or contribution_group.receiving_momo_route_type
      is distinct from normalized_routes.route_type
  );

create or replace view public.contribution_groups
with (security_invoker = true) as
select
  g.id,
  null::uuid as creator_id,
  g.name,
  g.description,
  case
    when pg_catalog.lower(coalesce(g.group_type, g.type, 'community'))
      in ('project', 'club', 'team_project') then 'project'
    else 'community'
  end as group_type,
  g.target_amount,
  coalesce(g.current_total, g.amount, 0) as current_total,
  g.receiving_momo_code as momo_recipient_code,
  g.receiving_momo_route_type as momo_route_type,
  g.deadline,
  g.is_recurring,
  g.is_closed,
  g.member_count,
  g.created_at,
  g.club_id,
  g.partner_id,
  g.currency,
  g.updated_at,
  g.is_active,
  g.country,
  g.type,
  g.amount,
  g.monthly_contribution,
  null::text as bank_partner_id,
  null::text as momo_number,
  g.frequency,
  null::text as receiving_momo_route_type,
  null::text as receiving_momo_code,
  g.cycle_days,
  g.contribution_amount
from public.groups as g
where coalesce(g.visibility, 'public') = 'public';

revoke all privileges on table public.groups
from public, anon, authenticated;
revoke all privileges on table public.contribution_groups
from public, anon, authenticated;

grant select (
  id,name,description,group_type,target_amount,current_total,deadline,
  is_recurring,is_closed,member_count,created_at,club_id,partner_id,currency,
  updated_at,is_active,country,visibility,type,amount,monthly_contribution,
  frequency,cycle_days,contribution_amount
) on table public.groups to anon, authenticated;
grant select (receiving_momo_route_type,receiving_momo_code)
on table public.groups to authenticated;

grant select (
  id,name,description,group_type,target_amount,current_total,deadline,
  is_recurring,is_closed,member_count,created_at,club_id,partner_id,currency,
  updated_at,is_active,country,type,amount,monthly_contribution,frequency,
  cycle_days,contribution_amount
) on table public.contribution_groups to anon, authenticated;
grant select (momo_recipient_code,momo_route_type)
on table public.contribution_groups to authenticated;

grant select, insert, update, delete on table public.groups to service_role;
grant select, insert, update, delete on table public.contribution_groups
to service_role;

-- Restore the exact PWA/CMS privileges used by server routes after the global
-- default-ACL hardening. Browser roles receive only active banner display
-- fields; engagement and push persistence remains service-only.
revoke all privileges on table public.home_banners
from public, anon, authenticated, service_role;
grant select (
  id,title,subtitle,badge_label,cta_label,route,image_url,sort_order,is_active,
  created_at,updated_at,club_id,distribution
) on table public.home_banners to anon, authenticated;
grant select, insert, update, delete on table public.home_banners
to service_role;

revoke all privileges on table public.pwa_engagement_events
from public, anon, authenticated, service_role;
grant insert on table public.pwa_engagement_events to service_role;

revoke all privileges on table public.web_push_subscriptions
from public, anon, authenticated, service_role;
grant select, insert, update on table public.web_push_subscriptions
to service_role;

-- Settlement, fixture-market maintenance, identity allocation, and admin-phone
-- refresh routines are trusted server operations. PostgreSQL gives new
-- functions EXECUTE to PUBLIC unless it is explicitly removed, so reset every
-- relevant ACL before granting the one intended service principal.
revoke execute on function football.award_prediction_fet(
  uuid,uuid,bigint,integer,uuid,text
) from public, anon, authenticated, service_role;
revoke execute on function football.seed_fixture_prediction_markets(uuid,boolean)
from public, anon, authenticated, service_role;
revoke execute on function football.generate_fixture_markets(uuid)
from public, anon, authenticated, service_role;
revoke execute on function football.update_fixture_market_odds(uuid,jsonb)
from public, anon, authenticated, service_role;
revoke execute on function football.update_fixture_odds_batch(uuid,jsonb)
from public, anon, authenticated, service_role;
revoke execute on function football.seed_fixture_prediction_markets_trigger()
from public, anon, authenticated, service_role;
revoke execute on function football.trg_auto_generate_fixture_markets()
from public, anon, authenticated, service_role;

grant execute on function football.award_prediction_fet(
  uuid,uuid,bigint,integer,uuid,text
) to service_role;
grant execute on function football.seed_fixture_prediction_markets(uuid,boolean)
to service_role;
grant execute on function football.generate_fixture_markets(uuid)
to service_role;
grant execute on function football.update_fixture_market_odds(uuid,jsonb)
to service_role;
grant execute on function football.update_fixture_odds_batch(uuid,jsonb)
to service_role;
grant execute on function football.seed_fixture_prediction_markets_trigger()
to service_role;
grant execute on function football.trg_auto_generate_fixture_markets()
to service_role;

revoke execute on function public.prediction_get_friend_challenges(
  text,integer,integer
) from public, anon, authenticated, service_role;
revoke execute on function public.prediction_respond_friend_challenge(
  uuid,text,text
) from public, anon, authenticated, service_role;
revoke execute on function public.prediction_get_active_jackpot_round(bigint)
from public, anon, authenticated, service_role;
revoke execute on function public.partner_prediction_pool_create(
  uuid,uuid,text,integer,integer,uuid,text,integer,text,jsonb,bigint
) from public, anon, authenticated, service_role;
revoke execute on function public.partner_prediction_pool_settle(uuid)
from public, anon, authenticated, service_role;
revoke execute on function public.refresh_admin_phone_access_for_user(uuid)
from public, anon, authenticated, service_role;
revoke execute on function public.next_public_user_id()
from public, anon, authenticated, service_role;

grant execute on function public.prediction_get_friend_challenges(
  text,integer,integer
) to service_role;
grant execute on function public.prediction_respond_friend_challenge(
  uuid,text,text
) to service_role;
grant execute on function public.prediction_get_active_jackpot_round(bigint)
to service_role;
grant execute on function public.partner_prediction_pool_create(
  uuid,uuid,text,integer,integer,uuid,text,integer,text,jsonb,bigint
) to service_role;
grant execute on function public.partner_prediction_pool_settle(uuid)
to service_role;
grant execute on function public.refresh_admin_phone_access_for_user(uuid)
to service_role;
grant execute on function public.next_public_user_id()
to service_role;

-- Payment references entered by a device are request correlations, not proof
-- of provider settlement. Until a trusted reconciliation path is present for
-- ticket and shop payments, clients may cancel pending records but may not
-- create new payment-bearing records directly.
revoke execute on function public.purchase_club_tickets(
  uuid,uuid,text,integer,text
) from public, anon, authenticated, service_role;
grant execute on function public.purchase_club_tickets(
  uuid,uuid,text,integer,text
) to service_role;

revoke execute on function public.create_shop_order(jsonb,text,text)
from public, anon, authenticated, service_role;
grant execute on function public.create_shop_order(jsonb,text,text)
to service_role;

create or replace function public.enforce_ticket_provider_attestation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_reference text := pg_catalog.upper(
    pg_catalog.regexp_replace(
      pg_catalog.btrim(coalesce(new.momo_reference, '')),
      '[^A-Za-z0-9]',
      '',
      'g'
    )
  );
begin
  -- Cancellation of a still-pending supporter request remains safe and does
  -- not need provider evidence. Only attestation to VALID is gated here.
  if old.status = 'pending' and new.status = 'valid' then
    if pg_catalog.length(v_reference) < 6
       or not exists (
         select 1
           from public.momo_reconciliations as reconciliation
           join public.momo_sms_parsed as parsed_sms
             on parsed_sms.id = reconciliation.parsed_sms_id
           join public.momo_ledger_entries as ledger_entry
             on ledger_entry.parsed_sms_id = parsed_sms.id
          where reconciliation.target_table = 'tickets'
            and (
              reconciliation.target_record_id = new.id
              or coalesce(
                reconciliation.metadata -> 'ticket_ids',
                '[]'::jsonb
              ) @> pg_catalog.jsonb_build_array(new.id)
            )
            and reconciliation.match_status = 'matched'
            and reconciliation.reconciled_at is not null
            and reconciliation.user_id = new.user_id
            and reconciliation.club_id = new.club_id
            and not coalesce(reconciliation.is_mock, false)
            and parsed_sms.parse_status = 'parsed'
            and parsed_sms.tx_direction = 'debit'
            and parsed_sms.user_id = new.user_id
            and parsed_sms.club_id = new.club_id
            and parsed_sms.amount = ledger_entry.amount
            and not coalesce(parsed_sms.is_mock, false)
            and ledger_entry.entry_type = 'debit'
            and ledger_entry.ledger_status = 'posted'
            and ledger_entry.target_table = 'tickets'
            and (
              ledger_entry.target_record_id = new.id
              or coalesce(
                ledger_entry.metadata -> 'ticket_ids',
                '[]'::jsonb
              ) @> pg_catalog.jsonb_build_array(new.id)
            )
            and ledger_entry.user_id = new.user_id
            and ledger_entry.club_id = new.club_id
            and ledger_entry.amount = (
              select coalesce(
                pg_catalog.sum(ticket.amount_paid),
                0::bigint
              )::integer
                from public.tickets as ticket
               where ticket.user_id = new.user_id
                 and ticket.club_id = new.club_id
                 and ticket.status in ('pending', 'valid')
                 and pg_catalog.upper(
                   pg_catalog.regexp_replace(
                     pg_catalog.btrim(coalesce(ticket.momo_reference, '')),
                     '[^A-Za-z0-9]',
                     '',
                     'g'
                   )
                 ) = v_reference
            )
            and not coalesce(ledger_entry.is_mock, false)
            and pg_catalog.upper(
              pg_catalog.regexp_replace(
                pg_catalog.btrim(coalesce(parsed_sms.momo_tx_id, '')),
                '[^A-Za-z0-9]',
                '',
                'g'
              )
            ) = v_reference
            and pg_catalog.upper(
              pg_catalog.regexp_replace(
                pg_catalog.btrim(coalesce(ledger_entry.external_reference, '')),
                '[^A-Za-z0-9]',
                '',
                'g'
              )
            ) = v_reference
       ) then
      raise exception
        'A matched, posted provider payment is required before ticket validation.';
    end if;

    new.confirmed_at := coalesce(
      new.confirmed_at,
      pg_catalog.timezone('utc', pg_catalog.now())
    );
  end if;

  return new;
end;
$$;

revoke execute on function public.enforce_ticket_provider_attestation()
from public, anon, authenticated, service_role;

drop trigger if exists trg_tickets_require_provider_attestation
on public.tickets;
create trigger trg_tickets_require_provider_attestation
before update of status on public.tickets
for each row execute function public.enforce_ticket_provider_attestation();

comment on function public.enforce_ticket_provider_attestation() is
  'Rejects pending-to-valid ticket transitions unless exact non-mock parsed SMS, posted ledger and matched reconciliation evidence bind the ticket or ticket batch, owner, club, total amount and provider reference.';

-- Preserve the released catalog row shape while removing internal operational
-- notes from every public response. Existing clients already treat this field
-- as nullable, so nulling it avoids a return-type-breaking DROP/CREATE.
create or replace function public.fet_get_catalog(
  p_club_id bigint default null::bigint,
  p_include_inactive boolean default false
) returns table(
  id uuid,
  club_id bigint,
  code text,
  template_scope text,
  category text,
  item_name text,
  fet_value integer,
  trigger_condition text,
  activation_timing text,
  description text,
  badge_name text,
  implementation_notes text,
  sort_order integer,
  is_active boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_club_id bigint;
begin
  v_club_id := public.fet_resolve_public_club_id(p_club_id);
  if v_club_id is null then
    return;
  end if;

  return query
  select
    catalog.id,
    catalog.club_id,
    catalog.code,
    catalog.template_scope,
    catalog.category,
    catalog.item_name,
    catalog.fet_value,
    catalog.trigger_condition,
    catalog.activation_timing,
    catalog.description,
    catalog.badge_name,
    null::text as implementation_notes,
    catalog.sort_order,
    catalog.is_active
  from public.fan_engagement_token_catalog as catalog
  where catalog.club_id = v_club_id
    and (p_include_inactive or catalog.is_active)
  order by catalog.sort_order, catalog.code;
end;
$$;

revoke execute on function public.fet_get_catalog(bigint,boolean)
from public, anon, authenticated, service_role;
grant execute on function public.fet_get_catalog(bigint,boolean)
to anon, authenticated, service_role;

comment on function public.fet_get_catalog(bigint,boolean) is
  'Public FET catalog with a compatibility-null implementation_notes field; internal implementation notes are never exposed.';

-- Device-side synchronization writes one immutable audit record after each
-- scan. The app and monitor also read the caller's own records. There is no
-- client update/delete path.
alter table public.momo_sms_sync_runs enable row level security;

revoke all privileges on table public.momo_sms_sync_runs
from public, anon, authenticated;
grant select, insert on table public.momo_sms_sync_runs to authenticated;
grant select, insert, update, delete on table public.momo_sms_sync_runs
to service_role;

drop policy if exists momo_sms_sync_runs_delete_own
on public.momo_sms_sync_runs;
drop policy if exists momo_sms_sync_runs_insert_own
on public.momo_sms_sync_runs;
drop policy if exists momo_sms_sync_runs_select_own
on public.momo_sms_sync_runs;

create policy momo_sms_sync_runs_insert_own
on public.momo_sms_sync_runs
for insert
to authenticated
with check ((select auth.uid()) = user_id);

create policy momo_sms_sync_runs_select_own
on public.momo_sms_sync_runs
for select
to authenticated
using ((select auth.uid()) = user_id);

-- A failed client dialer launch may abandon only the caller's own pending,
-- unbound contribution. Add the terminal state without relaxing any existing
-- confirmation/reconciliation transition.
alter table public.group_contributions
drop constraint if exists group_contributions_status_check;
alter table public.group_contributions
add constraint group_contributions_status_check
check (status in ('pending', 'confirmed', 'failed', 'cancelled'));

create or replace function public.cancel_pending_group_contribution_payment_launch(
  p_contribution_id uuid
) returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := auth.uid();
  v_club_claim text := public.requesting_club_id();
  v_club_id bigint;
  v_previous public.group_contributions%rowtype;
  v_updated public.group_contributions%rowtype;
begin
  if v_actor_id is null then
    raise exception 'An authenticated supporter is required.';
  end if;

  if p_contribution_id is null then
    raise exception 'A contribution request is required.';
  end if;

  if v_club_claim is null or v_club_claim !~ '^[0-9]+$' then
    raise exception 'A valid authenticated club scope is required.';
  end if;
  v_club_id := v_club_claim::bigint;

  select contribution.*
    into v_previous
    from public.group_contributions as contribution
    join public.groups as contribution_group
      on contribution_group.id = contribution.group_id
   where contribution.id = p_contribution_id
     and contribution.user_id = v_actor_id
     and contribution_group.club_id = v_club_id
   for update of contribution;

  if not found then
    raise exception 'Contribution was not found in the active supporter account.';
  end if;

  if v_previous.status <> 'pending'
     or v_previous.payment_status <> 'pending_verification'::public.payment_status then
    raise exception 'Only a pending, unverified contribution may be cancelled.';
  end if;

  if v_previous.momo_reference is not null
     or v_previous.reconciled_ledger_entry_id is not null
     or v_previous.reconciliation_id is not null then
    raise exception 'A provider-bound contribution cannot be cancelled from payment launch.';
  end if;

  update public.group_contributions as contribution
     set status = 'cancelled'
   where contribution.id = v_previous.id
     and contribution.status = 'pending'
     and contribution.momo_reference is null
  returning contribution.* into v_updated;

  if not found then
    raise exception 'Contribution changed before cancellation; refresh and review.';
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
    v_actor_id,
    v_actor_id,
    'supporter_contribution_payment_launch_cancelled',
    'group_contributions',
    v_updated.id::text,
    pg_catalog.jsonb_build_object(
      'status', v_previous.status,
      'updated_at', v_previous.updated_at
    ),
    pg_catalog.jsonb_build_object(
      'status', v_updated.status,
      'updated_at', v_updated.updated_at
    ),
    v_club_id,
    'group_contribution',
    v_updated.id::text,
    pg_catalog.jsonb_build_object(
      'scope', 'active_club',
      'source', 'mobile_payment_dialer_launch',
      'provider_reference_bound', false
    )
  );

  return true;
end;
$$;

revoke execute on function public.cancel_pending_group_contribution_payment_launch(uuid)
from public, anon, authenticated, service_role;
grant execute on function public.cancel_pending_group_contribution_payment_launch(uuid)
to authenticated;

comment on function public.cancel_pending_group_contribution_payment_launch(uuid) is
  'Cancels only the authenticated supporter''s own-club pending contribution when no provider payment or reconciliation evidence has been bound.';

comment on view public.contribution_groups is
  'Security-invoker compatibility projection. Public initiative fields are column-granted to anon/authenticated; only authenticated same-club readers can select the canonical receiving route; legacy raw routing and creator fields are null.';

commit;
