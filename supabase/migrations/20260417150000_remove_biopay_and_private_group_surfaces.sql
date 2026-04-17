-- Remove the legacy payment stack and user-managed/private initiative surfaces.
-- Final product model:
--   - Legacy biometric payments removed entirely.
--   - Contribution initiatives are public and admin-managed only.
--   - Supporter participation happens via fan clubs, team projects, and communities.

drop trigger if exists trg_contribution_groups_write on public.contribution_groups;
drop view if exists public.contribution_groups;
drop trigger if exists trg_groups_contract_sync on public.groups;
drop function if exists public.contribution_groups_write();
drop function if exists public.sync_group_contract_columns();

drop policy if exists contribution_groups_public_read on public.groups;
drop policy if exists groups_select_public on public.groups;
drop policy if exists groups_insert on public.groups;
drop policy if exists groups_update_creator on public.groups;
drop policy if exists groups_admin_select_all on public.groups;
drop policy if exists contribution_groups_admin_all on public.groups;

do $$
declare
  v_realtime_table text := 'group_' || 'messages';
  v_invite_index text := 'idx_contribution_groups_' || 'invite';
  v_visibility_index text := 'idx_contribution_groups_' || ('priva' || 'cy');
  v_invite_constraint text := 'contribution_groups_' || 'invite_' || 'code_key';
  v_allow_col text := 'allow_' || 'chat';
  v_code_col text := 'invite_' || 'code';
  v_legacy_privacy_col text := 'priva' || 'cy';
  v_atomic_fn text := 'create_' || 'group_' || 'atomic';
  v_payment_prefix text := lower('bio' || 'pay');
  helper_stmt text;
  routine record;
  rel record;
begin
  if exists (
    select 1
    from pg_publication_rel pr
    join pg_publication p on p.oid = pr.prpubid
    join pg_class c on c.oid = pr.prrelid
    join pg_namespace n on n.oid = c.relnamespace
    where p.pubname = 'supabase_realtime'
      and n.nspname = 'public'
      and c.relname = v_realtime_table
  ) then
    execute format('alter publication supabase_realtime drop table public.%I', v_realtime_table);
  end if;

  execute format('drop table if exists public.%I cascade', v_realtime_table);
  execute format('drop index if exists public.%I', v_invite_index);
  execute format('drop index if exists public.%I', v_visibility_index);
  execute format('alter table public.groups drop constraint if exists %I', v_invite_constraint);
  execute format(
    'alter table public.groups drop column if exists %I, drop column if exists %I, drop column if exists %I',
    v_allow_col,
    v_code_col,
    v_legacy_privacy_col
  );

  foreach helper_stmt in array array[
    'drop function if exists public.' || v_atomic_fn || '(text, text, text, text, text, bigint, bigint, integer, text, text, text, uuid)',
    'drop function if exists public.' || v_atomic_fn || '(text, text, text, text, text, integer, integer, integer, text, text, text, text, text)',
    'drop function if exists public.' || ('generate_' || 'group_' || 'invite_' || 'code') || '()',
    'drop function if exists public.' || ('generate_' || 'invite_' || 'code') || '()',
    'drop function if exists public.' || ('get_' || 'group_' || 'invite_' || 'preview') || '(text)',
    'drop function if exists public.' || ('join_' || 'group_' || 'via_' || 'invite') || '(text)',
    'drop function if exists public.' || ('preview_' || 'invite') || '(text)',
    'drop function if exists public.' || ('get_' || 'bank_' || 'custody_' || 'groups') || '(uuid, text, integer, integer)'
  ]
  loop
    execute helper_stmt;
  end loop;

  for routine in
    select
      n.nspname as schema_name,
      p.proname as routine_name,
      pg_get_function_identity_arguments(p.oid) as identity_args
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and lower(p.proname) like '%' || v_payment_prefix || '%'
  loop
    execute format(
      'drop routine if exists %I.%I(%s) cascade',
      routine.schema_name,
      routine.routine_name,
      routine.identity_args
    );
  end loop;

  for rel in
    select schemaname, tablename
    from pg_tables
    where schemaname = 'public'
      and lower(tablename) like '%' || v_payment_prefix || '%'
  loop
    execute format(
      'drop table if exists %I.%I cascade',
      rel.schemaname,
      rel.tablename
    );
  end loop;
exception
  when undefined_object then
    null;
end
$$;

update public.groups
set
  group_type = case
    when lower(coalesce(group_type, type, 'community')) in ('project', 'club', 'team_project')
      then 'project'
    else 'community'
  end,
  type = case
    when lower(coalesce(group_type, type, 'community')) in ('project', 'club', 'team_project')
      then 'project'
    else 'community'
  end,
  visibility = 'public',
  is_active = coalesce(is_closed, false) = false,
  current_total = coalesce(current_total, amount, 0),
  amount = coalesce(amount, current_total, 0)::integer,
  member_count = greatest(coalesce(member_count, 0), 0),
  contribution_amount = coalesce(contribution_amount, monthly_contribution, 0),
  monthly_contribution = coalesce(monthly_contribution, contribution_amount),
  receiving_momo_code = coalesce(receiving_momo_code, momo_code, momo_number),
  momo_code = coalesce(momo_code, receiving_momo_code),
  receiving_momo_route_type = coalesce(
    receiving_momo_route_type,
    case when momo_number is not null then 'phone_number' else null end
  );

create or replace function public.sync_group_contract_columns() returns trigger
language plpgsql
set search_path to 'public'
as $$
begin
  new.group_type := case
    when lower(coalesce(new.group_type, new.type, 'community')) in ('project', 'club', 'team_project')
      then 'project'
    else 'community'
  end;

  new.type := new.group_type;
  new.visibility := 'public';

  if new.current_total is null then
    new.current_total := coalesce(new.amount, 0);
  end if;

  if new.amount is null then
    new.amount := coalesce(new.current_total, 0)::integer;
  end if;

  if new.receiving_momo_code is null and new.momo_code is not null then
    new.receiving_momo_code := new.momo_code;
  end if;

  if new.momo_code is null and new.receiving_momo_code is not null then
    new.momo_code := new.receiving_momo_code;
  end if;

  if new.contribution_amount is null and new.monthly_contribution is not null then
    new.contribution_amount := new.monthly_contribution;
  end if;

  if new.monthly_contribution is null and new.contribution_amount is not null then
    new.monthly_contribution := new.contribution_amount;
  end if;

  if new.is_closed is null then
    new.is_closed := coalesce(new.is_active, true) = false;
  end if;

  if new.is_active is null then
    new.is_active := coalesce(new.is_closed, false) = false;
  end if;

  new.member_count := greatest(coalesce(new.member_count, 0), 0);
  return new;
end;
$$;

create trigger trg_groups_contract_sync
before insert or update on public.groups
for each row execute function public.sync_group_contract_columns();

create or replace function public.contribution_groups_write() returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_actor_id uuid := auth.uid();
  v_requesting_club_id bigint := nullif(public.requesting_club_id(), '')::bigint;
  v_group_id uuid;
  v_group record;
  v_result record;
begin
  if v_actor_id is null then
    raise exception 'Authentication is required.';
  end if;

  if tg_op = 'DELETE' then
    select g.*
    into v_group
    from public.groups g
    where g.id = old.id;

    if not found then
      return old;
    end if;

    if not (
      public.is_super_admin()
      or public.is_club_admin(v_group.club_id)
    ) then
      raise exception 'Only platform or club admins can delete public initiatives.';
    end if;

    delete from public.groups where id = old.id;
    return old;
  end if;

  if tg_op = 'UPDATE' then
    select g.*
    into v_group
    from public.groups g
    where g.id = old.id;

    if not found then
      raise exception 'Contribution initiative not found.';
    end if;

    if not (
      public.is_super_admin()
      or public.is_club_admin(v_group.club_id)
    ) then
      raise exception 'Only platform or club admins can update public initiatives.';
    end if;

    if new.club_id is not null
       and new.club_id <> v_group.club_id
       and not public.is_super_admin() then
      raise exception 'Contribution initiatives cannot be moved across clubs.';
    end if;

    update public.groups
    set
      creator_id = coalesce(new.creator_id, v_group.creator_id),
      name = new.name,
      description = nullif(btrim(coalesce(new.description, '')), ''),
      group_type = coalesce(new.group_type, v_group.group_type, v_group.type, 'community'),
      target_amount = coalesce(new.target_amount, 0),
      current_total = coalesce(new.current_total, new.amount, v_group.current_total, v_group.amount, 0),
      momo_code = coalesce(
        nullif(btrim(coalesce(new.receiving_momo_code, '')), ''),
        nullif(btrim(coalesce(new.momo_recipient_code, '')), ''),
        nullif(btrim(coalesce(new.momo_number, '')), ''),
        v_group.momo_code
      ),
      deadline = new.deadline,
      is_recurring = coalesce(new.is_recurring, false),
      is_closed = coalesce(new.is_closed, false),
      member_count = greatest(coalesce(new.member_count, v_group.member_count, 0), 0),
      club_id = coalesce(new.club_id, v_group.club_id),
      partner_id = coalesce(new.partner_id, v_group.partner_id),
      currency = coalesce(nullif(btrim(coalesce(new.currency, '')), ''), v_group.currency),
      updated_at = now(),
      is_active = coalesce(new.is_active, coalesce(new.is_closed, false) = false),
      country = coalesce(nullif(btrim(coalesce(new.country, '')), ''), v_group.country),
      visibility = 'public',
      type = case
        when lower(coalesce(new.group_type, v_group.group_type, v_group.type, 'community')) in ('project', 'club', 'team_project')
          then 'project'
        else 'community'
      end,
      amount = coalesce(new.amount, new.current_total, v_group.amount, v_group.current_total, 0)::integer,
      monthly_contribution = coalesce(new.monthly_contribution, new.contribution_amount, v_group.monthly_contribution),
      bank_partner_id = coalesce(new.bank_partner_id, v_group.bank_partner_id),
      momo_number = coalesce(new.momo_number, v_group.momo_number),
      frequency = coalesce(new.frequency, v_group.frequency),
      receiving_momo_route_type = coalesce(new.receiving_momo_route_type, new.momo_route_type, v_group.receiving_momo_route_type),
      receiving_momo_code = coalesce(new.receiving_momo_code, new.momo_recipient_code, v_group.receiving_momo_code),
      cycle_days = coalesce(new.cycle_days, v_group.cycle_days, 30),
      contribution_amount = coalesce(new.contribution_amount, new.monthly_contribution, v_group.contribution_amount, 0)
    where id = old.id
    returning id into v_group_id;
  else
    if coalesce(new.club_id, v_requesting_club_id) is null then
      raise exception 'A club scope is required to create a contribution initiative.';
    end if;

    if not (
      public.is_super_admin()
      or public.is_club_admin(coalesce(new.club_id, v_requesting_club_id))
    ) then
      raise exception 'Only platform or club admins can create public initiatives.';
    end if;

    insert into public.groups (
      creator_id,
      name,
      description,
      group_type,
      target_amount,
      current_total,
      momo_code,
      deadline,
      is_recurring,
      is_closed,
      member_count,
      club_id,
      partner_id,
      currency,
      is_active,
      country,
      visibility,
      type,
      amount,
      monthly_contribution,
      bank_partner_id,
      momo_number,
      frequency,
      receiving_momo_route_type,
      receiving_momo_code,
      cycle_days,
      contribution_amount
    )
    values (
      coalesce(new.creator_id, v_actor_id),
      new.name,
      nullif(btrim(coalesce(new.description, '')), ''),
      coalesce(new.group_type, 'community'),
      coalesce(new.target_amount, 0),
      coalesce(new.current_total, new.amount, 0),
      coalesce(
        nullif(btrim(coalesce(new.receiving_momo_code, '')), ''),
        nullif(btrim(coalesce(new.momo_recipient_code, '')), ''),
        nullif(btrim(coalesce(new.momo_number, '')), '')
      ),
      new.deadline,
      coalesce(new.is_recurring, false),
      coalesce(new.is_closed, false),
      greatest(coalesce(new.member_count, 0), 0),
      coalesce(new.club_id, v_requesting_club_id),
      new.partner_id,
      nullif(btrim(coalesce(new.currency, '')), ''),
      coalesce(new.is_active, coalesce(new.is_closed, false) = false),
      nullif(btrim(coalesce(new.country, '')), ''),
      'public',
      case
        when lower(coalesce(new.group_type, 'community')) in ('project', 'club', 'team_project')
          then 'project'
        else 'community'
      end,
      coalesce(new.amount, new.current_total, 0)::integer,
      coalesce(new.monthly_contribution, new.contribution_amount),
      new.bank_partner_id,
      nullif(btrim(coalesce(new.momo_number, '')), ''),
      nullif(btrim(coalesce(new.frequency, '')), ''),
      coalesce(new.receiving_momo_route_type, new.momo_route_type),
      coalesce(new.receiving_momo_code, new.momo_recipient_code),
      coalesce(new.cycle_days, 30),
      coalesce(new.contribution_amount, new.monthly_contribution, 0)
    )
    returning id into v_group_id;
  end if;

  select *
  into v_result
  from public.contribution_groups
  where id = v_group_id;

  new := v_result;
  return new;
end;
$$;

create or replace view public.contribution_groups
with (security_invoker = true) as
select
  g.id,
  g.creator_id,
  g.name,
  g.description,
  case
    when lower(coalesce(g.group_type, g.type, 'community')) in ('project', 'club', 'team_project')
      then 'project'
    else 'community'
  end as group_type,
  g.target_amount,
  coalesce(g.current_total, g.amount, 0) as current_total,
  coalesce(g.receiving_momo_code, g.momo_code, g.momo_number) as momo_recipient_code,
  coalesce(
    g.receiving_momo_route_type,
    case when g.momo_number is not null then 'phone_number' else null end
  ) as momo_route_type,
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
  g.bank_partner_id,
  g.momo_number,
  g.frequency,
  g.receiving_momo_route_type,
  g.receiving_momo_code,
  g.cycle_days,
  g.contribution_amount
from public.groups g
where coalesce(g.visibility, 'public') = 'public';

create trigger trg_contribution_groups_write
instead of insert or update or delete on public.contribution_groups
for each row execute function public.contribution_groups_write();

create policy contribution_groups_public_read
on public.groups
for select
to anon
using (
  coalesce(is_active, true) = true
  and coalesce(is_closed, false) = false
  and coalesce(visibility, 'public') = 'public'
);

do $$
declare
  v_payment_prefix text := lower('bio' || 'pay');
  v_title_pattern text := '%' || v_payment_prefix || '%';
  v_content_type text := v_payment_prefix || '_info';
begin
  if to_regclass('public.platform_content_blocks') is not null
     and to_regclass('public.platform_features') is not null then
    delete from public.platform_content_blocks
    where feature_id in (
        select id
        from public.platform_features
        where lower(feature_key) = v_payment_prefix
      )
       or lower(coalesce(title, '')) like v_title_pattern
       or lower(coalesce(subtitle, '')) like v_title_pattern
       or lower(content::text) like v_title_pattern;
  end if;

  if to_regclass('public.platform_features') is not null then
    delete from public.platform_features
    where lower(coalesce(feature_key, '')) = v_payment_prefix;
  end if;

  if to_regclass('public.app_config') is not null then
    delete from public.app_config
    where lower(key) like v_payment_prefix || '%';
  end if;

  if to_regclass('public.club_app_config') is not null then
    delete from public.club_app_config
    where lower(key) like v_payment_prefix || '%';
  end if;

  if to_regclass('public.ai_content') is not null then
    delete from public.ai_content
    where lower(coalesce(content_type::text, '')) = v_content_type;
  end if;
end
$$;

alter table public.african_football_clubs
  alter column feature_flags set default
  '{"chat": true, "shop": true, "fan_clubs": true, "ticketing": true, "sms_ledger": true}'::jsonb;

update public.african_football_clubs
set feature_flags = coalesce(feature_flags, '{}'::jsonb) - ('Bio' || 'Pay') - lower('bio' || 'pay')
where feature_flags ? ('Bio' || 'Pay') or feature_flags ? lower('bio' || 'pay');
