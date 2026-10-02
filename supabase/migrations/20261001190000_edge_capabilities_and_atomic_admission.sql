begin;

-- Current server assignments are the sole staff authority. Legacy profile flags
-- and JWT metadata remain display data and cannot outlive a revoked grant.
create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.admin_role_assignments a
    where a.user_id = auth.uid() and a.is_active and a.revoked_at is null
      and a.role in ('admin', 'super_admin'));
$$;
create or replace function public.is_admin_user() returns boolean
language sql stable security definer set search_path = '' as $$
  select public.is_admin();
$$;
create or replace function public.is_super_admin() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.admin_role_assignments a
    where a.user_id = auth.uid() and a.is_active and a.revoked_at is null
      and a.role = 'super_admin');
$$;
create or replace function public.is_club_admin(p_club_id bigint default null) returns boolean
language sql stable security definer set search_path = '' as $$
  select public.is_admin() or exists (
    select 1 from public.admin_role_assignments a
    where a.user_id = auth.uid() and a.is_active and a.revoked_at is null
      and a.role in ('club_admin', 'club_moderator', 'partner', 'rayon_sport', 'bank')
      and a.club_id = coalesce(p_club_id, case
        when public.requesting_club_id() ~ '^[1-9][0-9]*$'
        then public.requesting_club_id()::bigint end)
  );
$$;
create or replace function public.is_partner_admin(p_partner_id uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  with scoped_clubs as (
    select club_id from public.partner_payment_routes where partner_id = p_partner_id
    union select club_id from public.initiatives where partner_id = p_partner_id
    union select club_id from public.matches where partner_id = p_partner_id
    union select club_id from public.membership_packages where partner_id = p_partner_id
    union select club_id from public.shop_products where partner_id = p_partner_id
    union select club_id from public.shop_orders where partner_id = p_partner_id
  )
  select public.is_admin() or exists (
    select 1 from public.admin_role_assignments a
    where a.user_id = auth.uid() and a.is_active and a.revoked_at is null and (
      (a.role in ('partner', 'rayon_sport', 'bank') and a.partner_scope_id = p_partner_id)
      or (a.role in ('club_admin', 'club_moderator') and a.club_id in (select club_id from scoped_clubs))
    )
  );
$$;
-- CREATE OR REPLACE preserves existing ACLs. Explicitly retain least privilege.
revoke all on function public.is_admin(), public.is_club_admin(bigint)
  from public;
revoke all on function public.is_admin_user(), public.is_super_admin(), public.is_partner_admin(uuid)
  from public, anon;

-- One bounded security-admission bucket per subject / operation / trusted scope.
-- The event telemetry table is intentionally no longer the admission authority.
create table public.edge_rate_limit_buckets (
  bucket_key text primary key check (length(bucket_key) between 1 and 512),
  accepted_at timestamptz[] not null default '{}'::timestamptz[],
  expires_at timestamptz not null,
  check (cardinality(accepted_at) <= 1000)
);
create index edge_rate_limit_buckets_expiry on public.edge_rate_limit_buckets(expires_at);
alter table public.edge_rate_limit_buckets enable row level security;
revoke all on public.edge_rate_limit_buckets from public, anon, authenticated, service_role;

create function public.consume_edge_rate_limit(
  p_bucket_key text, p_limit integer, p_window_seconds integer
) returns table(allowed boolean, retry_after_seconds integer)
language plpgsql security definer set search_path = '' as $$
declare
  v_now timestamptz;
  v_timestamps timestamptz[];
  v_window interval;
  v_allowed boolean;
  v_retry integer := 0;
begin
  if coalesce(auth.role(), '') <> 'service_role' then
    raise exception 'EDGE_ADMISSION_SERVICE_REQUIRED' using errcode = '42501';
  end if;
  if p_bucket_key is null or length(p_bucket_key) not between 1 and 512
    or p_limit is null or p_limit not between 1 and 1000
    or p_window_seconds is null or p_window_seconds not between 1 and 86400 then
    raise exception 'EDGE_ADMISSION_INVALID_BUDGET' using errcode = '22023';
  end if;
  v_window := make_interval(secs => p_window_seconds);
  insert into public.edge_rate_limit_buckets(bucket_key, expires_at)
    values (p_bucket_key, clock_timestamp() + v_window)
    on conflict (bucket_key) do nothing;
  select b.accepted_at into strict v_timestamps
    from public.edge_rate_limit_buckets b where b.bucket_key = p_bucket_key for update;
  -- Sample time after a contended lock, rather than using transaction start time.
  v_now := clock_timestamp();
  select coalesce(array_agg(t order by t), '{}'::timestamptz[]) into v_timestamps
    from unnest(v_timestamps) t where t > v_now - v_window;
  v_allowed := cardinality(v_timestamps) < p_limit;
  if v_allowed then
    v_timestamps := array_append(v_timestamps, v_now);
  else
    v_retry := greatest(1, ceil(extract(epoch from v_timestamps[1] + v_window - v_now))::integer);
  end if;
  update public.edge_rate_limit_buckets set accepted_at = v_timestamps,
    expires_at = v_timestamps[cardinality(v_timestamps)] + v_window
    where bucket_key = p_bucket_key;
  -- Bounded cleanup. SKIP LOCKED avoids waiting for another admission transaction.
  delete from public.edge_rate_limit_buckets b where b.bucket_key in (
    select expired.bucket_key from public.edge_rate_limit_buckets expired
    where expired.expires_at <= v_now and expired.bucket_key <> p_bucket_key
    order by expired.expires_at limit 64 for update skip locked
  );
  return query select v_allowed, v_retry;
end;
$$;
revoke all on function public.consume_edge_rate_limit(text, integer, integer)
  from public, anon, authenticated, service_role;
grant execute on function public.consume_edge_rate_limit(text, integer, integer) to service_role;

-- These routines alter shared fixtures across tenants. Preserve the historical
-- engine privately, and remove both old overbroad service-executable entrypoints.
alter function public.prediction_admin_settle(uuid, integer, integer, text)
  rename to prediction_admin_settle_legacy_internal;
alter function public.prediction_admin_settle(uuid, integer, integer, text, integer, integer)
  rename to prediction_admin_settle_internal;
revoke all on function public.prediction_admin_settle_legacy_internal(uuid, integer, integer, text)
  from public, anon, authenticated, service_role;
revoke all on function public.prediction_admin_settle_internal(uuid, integer, integer, text, integer, integer)
  from public, anon, authenticated, service_role;

create function public.prediction_admin_settle_as_actor(
  p_fixture_id uuid, p_home_score integer, p_away_score integer,
  p_actor_id uuid, p_operation_id uuid,
  p_ht_home_score integer default null, p_ht_away_score integer default null
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_assignment uuid;
  v_result jsonb;
begin
  if coalesce(auth.role(), '') <> 'service_role' or p_actor_id is null or p_operation_id is null then
    raise exception 'SETTLEMENT_AUTHORITY_REQUIRED' using errcode = '42501';
  end if;
  if p_home_score is null or p_home_score not between 0 and 99
    or p_away_score is null or p_away_score not between 0 and 99
    or (p_ht_home_score is null) <> (p_ht_away_score is null)
    or p_ht_home_score not between 0 and p_home_score
    or p_ht_away_score not between 0 and p_away_score then
    raise exception 'SETTLEMENT_INVALID_SCORES' using errcode = '22023';
  end if;
  -- A fixture is shared global data, not a caller-supplied club resource.
  -- Take its lock before checking the grant: a revoke while waiting must win.
  perform 1 from football.fixtures f where f.id = p_fixture_id for update;
  if not found then
    raise exception 'SETTLEMENT_FIXTURE_NOT_FOUND' using errcode = 'P0002';
  end if;
  select a.id into v_assignment from public.admin_role_assignments a
    where a.user_id = p_actor_id and a.is_active and a.revoked_at is null
      and a.role in ('admin', 'super_admin') order by a.id limit 1 for share;
  if v_assignment is null then
    raise exception 'SETTLEMENT_GLOBAL_ADMIN_REQUIRED' using errcode = '42501';
  end if;
  v_result := public.prediction_admin_settle_internal(p_fixture_id, p_home_score,
    p_away_score, 'finished', p_ht_home_score, p_ht_away_score);
  if v_result->>'status' <> 'success' then
    raise exception 'SETTLEMENT_NOT_CONFIRMED';
  end if;
  insert into public.admin_audit_log(actor_id, user_id, action, target_table,
    target_id, entity_type, entity_id, metadata)
    values (p_actor_id, p_actor_id, 'prediction.global_fixture_settle',
      'football.fixtures', p_fixture_id::text, 'fixture', p_fixture_id::text,
      jsonb_build_object('operation_id', p_operation_id, 'assignment_id', v_assignment,
        'home_score', p_home_score, 'away_score', p_away_score));
  return v_result || jsonb_build_object('operation_id', p_operation_id);
end;
$$;
revoke all on function public.prediction_admin_settle_as_actor(uuid, integer, integer, uuid, uuid, integer, integer)
  from public, anon, authenticated, service_role;
grant execute on function public.prediction_admin_settle_as_actor(uuid, integer, integer, uuid, uuid, integer, integer)
  to service_role;

commit;
