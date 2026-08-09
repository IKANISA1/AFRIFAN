-- Harden supporter contributions and SMS-ledger reconciliation.
--
-- Supporters may read only tenant-scoped records and create a pending
-- contribution through create_pending_group_contribution(). Confirmation is
-- deliberately reserved for a trusted service transaction that binds an exact
-- SMS ledger entry, reference, amount, club, version token and audit actor.

alter table public.group_contributions
  add column if not exists confirmed_at timestamptz,
  add column if not exists idempotency_key text,
  add column if not exists reconciled_ledger_entry_id uuid,
  add column if not exists reconciliation_id uuid,
  add column if not exists reconciliation_idempotency_key text,
  add column if not exists reconciled_by uuid;

alter table public.group_contributions
  alter column payment_status
    set default 'pending_verification'::public.payment_status;

do $$
begin
  if not exists (
    select 1
      from pg_catalog.pg_constraint
     where conname = 'group_contributions_group_id_fkey'
       and conrelid = 'public.group_contributions'::regclass
  ) then
    alter table public.group_contributions
      add constraint group_contributions_group_id_fkey
      foreign key (group_id)
      references public.groups(id)
      not valid;
  end if;

  if not exists (
    select 1
      from pg_catalog.pg_constraint
     where conname = 'group_contributions_ledger_entry_fkey'
       and conrelid = 'public.group_contributions'::regclass
  ) then
    alter table public.group_contributions
      add constraint group_contributions_ledger_entry_fkey
      foreign key (reconciled_ledger_entry_id)
      references public.momo_ledger_entries(id)
      not valid;
  end if;

  if not exists (
    select 1
      from pg_catalog.pg_constraint
     where conname = 'group_contributions_reconciliation_fkey'
       and conrelid = 'public.group_contributions'::regclass
  ) then
    alter table public.group_contributions
      add constraint group_contributions_reconciliation_fkey
      foreign key (reconciliation_id)
      references public.momo_reconciliations(id)
      not valid;
  end if;

  if not exists (
    select 1
      from pg_catalog.pg_constraint
     where conname = 'group_contributions_idempotency_key_key'
       and conrelid = 'public.group_contributions'::regclass
  ) then
    alter table public.group_contributions
      add constraint group_contributions_idempotency_key_key
      unique (user_id, group_id, idempotency_key);
  end if;
end;
$$;

create unique index if not exists
  idx_group_contributions_reconciliation_idempotency
on public.group_contributions (reconciliation_idempotency_key)
where reconciliation_idempotency_key is not null;

create index if not exists idx_group_contributions_group_user_created
on public.group_contributions (group_id, user_id, created_at desc);

create or replace function public.enforce_group_contribution_identity()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.group_id is distinct from old.group_id
     or new.user_id is distinct from old.user_id
     or new.amount is distinct from old.amount
     or new.momo_reference is distinct from old.momo_reference
     or new.idempotency_key is distinct from old.idempotency_key then
    raise exception
      'Contribution identity, amount, payment reference and idempotency key are immutable.';
  end if;

  if old.reconciled_ledger_entry_id is not null
     and new.reconciled_ledger_entry_id is distinct from old.reconciled_ledger_entry_id then
    raise exception 'A reconciled contribution cannot be rebound to another ledger entry.';
  end if;

  if old.reconciliation_id is not null
     and new.reconciliation_id is distinct from old.reconciliation_id then
    raise exception 'A reconciled contribution cannot be rebound to another reconciliation.';
  end if;

  if old.reconciliation_idempotency_key is not null
     and new.reconciliation_idempotency_key is distinct from old.reconciliation_idempotency_key then
    raise exception 'A reconciliation idempotency key is immutable after binding.';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_group_contributions_immutable_identity
  on public.group_contributions;

create trigger trg_group_contributions_immutable_identity
before update on public.group_contributions
for each row execute function public.enforce_group_contribution_identity();

revoke all on function public.enforce_group_contribution_identity()
  from public, anon, authenticated, service_role;

-- Keep the compatibility `amount` field and the released-view
-- `current_total` field authoritative from the same confirmed rows. The
-- legacy trigger updated only `amount`, leaving supporter progress at zero.
create or replace function public.sync_group_financials()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_group_id uuid := case when tg_op = 'DELETE' then old.group_id else new.group_id end;
  v_user_id uuid := case when tg_op = 'DELETE' then old.user_id else new.user_id end;
  v_confirmed_total bigint;
begin
  if v_group_id is null then
    return case when tg_op = 'DELETE' then old else new end;
  end if;

  select coalesce(pg_catalog.sum(contribution.amount), 0)::bigint
    into v_confirmed_total
    from public.group_contributions as contribution
   where contribution.group_id = v_group_id
     and contribution.status = 'confirmed';

  update public.groups
     set amount = v_confirmed_total::integer,
         current_total = v_confirmed_total
   where id = v_group_id;

  update public.group_members as member
     set contribution_amount = coalesce((
       select pg_catalog.sum(contribution.amount)
         from public.group_contributions as contribution
        where contribution.group_id = member.group_id
          and contribution.user_id = member.user_id
          and contribution.status = 'confirmed'
     ), 0)::integer
   where member.group_id = v_group_id
     and (v_user_id is null or member.user_id = v_user_id);

  return case when tg_op = 'DELETE' then old else new end;
end;
$$;

revoke all on function public.sync_group_financials()
  from public, anon, authenticated, service_role;

create or replace function public.is_group_member(
  p_group_id uuid,
  p_user_id uuid default auth.uid()
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_authenticated_user_id uuid := auth.uid();
  v_effective_user_id uuid;
begin
  if coalesce(auth.role(), '') = 'service_role' then
    v_effective_user_id := p_user_id;
  else
    if v_authenticated_user_id is null
       or p_user_id is distinct from v_authenticated_user_id then
      return false;
    end if;
    v_effective_user_id := v_authenticated_user_id;
  end if;

  if p_group_id is null or v_effective_user_id is null then
    return false;
  end if;

  return exists (
    select 1
      from public.group_members as member
     where member.group_id = p_group_id
       and member.user_id = v_effective_user_id
  );
end;
$$;

revoke all on function public.is_group_member(uuid, uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.is_group_member(uuid, uuid)
  to authenticated, service_role;

create or replace function public.create_pending_group_contribution(
  p_group_id uuid,
  p_amount integer,
  p_payment_reference text,
  p_idempotency_key text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := auth.uid();
  v_club_claim text := public.requesting_club_id();
  v_club_id bigint;
  v_reference text;
  v_idempotency_key text;
  v_group public.groups%rowtype;
  v_contribution public.group_contributions%rowtype;
  v_inserted boolean := false;
begin
  if v_actor_id is null then
    raise exception 'An authenticated supporter is required.';
  end if;

  if v_club_claim is null or v_club_claim !~ '^[0-9]+$' then
    raise exception 'A valid authenticated club scope is required.';
  end if;
  v_club_id := v_club_claim::bigint;

  if p_group_id is null then
    raise exception 'A contribution group is required.';
  end if;

  if p_amount is null or p_amount < 1 or p_amount > 100000000 then
    raise exception 'Contribution amount must be between 1 and 100000000 RWF.';
  end if;

  v_reference := pg_catalog.upper(
    pg_catalog.regexp_replace(
      pg_catalog.btrim(coalesce(p_payment_reference, '')),
      '[^A-Za-z0-9]',
      '',
      'g'
    )
  );
  if pg_catalog.length(v_reference) < 6
     or pg_catalog.length(v_reference) > 64 then
    raise exception 'A valid payment reference between 6 and 64 characters is required.';
  end if;

  v_idempotency_key := pg_catalog.lower(
    pg_catalog.regexp_replace(
      pg_catalog.btrim(
        coalesce(p_idempotency_key, 'momo:' || v_reference)
      ),
      '[^A-Za-z0-9:_-]',
      '',
      'g'
    )
  );
  if pg_catalog.length(v_idempotency_key) < 8
     or pg_catalog.length(v_idempotency_key) > 128 then
    raise exception 'A valid idempotency key between 8 and 128 characters is required.';
  end if;

  select contribution_group.*
    into v_group
    from public.groups as contribution_group
   where contribution_group.id = p_group_id
     and contribution_group.club_id = v_club_id
     and coalesce(contribution_group.is_active, true)
     and not coalesce(contribution_group.is_closed, false)
     and coalesce(contribution_group.visibility, 'public') = 'public'
   for share;

  if not found then
    raise exception 'Contribution group is unavailable in the authenticated club.';
  end if;

  if not public.is_group_member(p_group_id, v_actor_id) then
    raise exception 'Only a current group member may contribute.';
  end if;

  select contribution.*
    into v_contribution
    from public.group_contributions as contribution
   where contribution.momo_reference = v_reference
   for update;

  if found then
    if v_contribution.user_id is distinct from v_actor_id
       or v_contribution.group_id is distinct from p_group_id
       or v_contribution.amount is distinct from p_amount
       or v_contribution.idempotency_key is distinct from v_idempotency_key then
      raise exception 'Payment reference is already bound to another contribution request.';
    end if;
  else
    begin
      insert into public.group_contributions (
        group_id,
        user_id,
        amount,
        status,
        payment_status,
        momo_reference,
        idempotency_key
      ) values (
        p_group_id,
        v_actor_id,
        p_amount,
        'pending',
        'pending_verification'::public.payment_status,
        v_reference,
        v_idempotency_key
      )
      on conflict on constraint group_contributions_idempotency_key_key
      do nothing
      returning * into v_contribution;
      v_inserted := found;
    exception
      when unique_violation then
        v_contribution := null;
    end;

    if v_contribution.id is null then
      select contribution.*
        into v_contribution
        from public.group_contributions as contribution
       where (
         contribution.user_id = v_actor_id
         and contribution.group_id = p_group_id
         and contribution.idempotency_key = v_idempotency_key
       ) or contribution.momo_reference = v_reference
       order by
         case when contribution.idempotency_key = v_idempotency_key then 0 else 1 end
       limit 1
       for update;
    end if;

    if v_contribution.id is null
       or v_contribution.user_id is distinct from v_actor_id
       or v_contribution.group_id is distinct from p_group_id
       or v_contribution.amount is distinct from p_amount
       or v_contribution.momo_reference is distinct from v_reference
       or v_contribution.idempotency_key is distinct from v_idempotency_key then
      raise exception 'Idempotency key or payment reference conflicts with another request.';
    end if;
  end if;

  return pg_catalog.jsonb_build_object(
    'id', v_contribution.id,
    'status', v_contribution.status,
    'payment_status', v_contribution.payment_status,
    'created_at', v_contribution.created_at,
    'updated_at', v_contribution.updated_at,
    'replayed', not v_inserted
  );
end;
$$;

revoke all on function public.create_pending_group_contribution(
  uuid,
  integer,
  text,
  text
) from public, anon, authenticated, service_role;
grant execute on function public.create_pending_group_contribution(
  uuid,
  integer,
  text,
  text
) to authenticated;

create or replace function public.reconcile_group_contribution_from_sms(
  p_contribution_id uuid,
  p_ledger_entry_id uuid,
  p_expected_contribution_updated_at timestamptz,
  p_expected_ledger_updated_at timestamptz,
  p_idempotency_key text,
  p_actor_id uuid,
  p_actor_context text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_idempotency_key text;
  v_actor_context text;
  v_reference text;
  v_ledger_reference text;
  v_parsed_reference text;
  v_contribution public.group_contributions%rowtype;
  v_group public.groups%rowtype;
  v_ledger public.momo_ledger_entries%rowtype;
  v_parsed public.momo_sms_parsed%rowtype;
  v_reconciliation public.momo_reconciliations%rowtype;
  v_reconciled_at timestamptz := pg_catalog.clock_timestamp();
begin
  if p_contribution_id is null
     or p_ledger_entry_id is null
     or p_expected_contribution_updated_at is null
     or p_expected_ledger_updated_at is null then
    raise exception 'Contribution, ledger entry and exact loaded versions are required.';
  end if;

  if p_actor_id is null then
    raise exception 'A trusted reconciliation actor is required for audit.';
  end if;

  v_actor_context := pg_catalog.lower(
    pg_catalog.regexp_replace(
      pg_catalog.btrim(coalesce(p_actor_context, '')),
      '[^A-Za-z0-9._:-]',
      '',
      'g'
    )
  );
  if pg_catalog.length(v_actor_context) < 3
     or pg_catalog.length(v_actor_context) > 80 then
    raise exception 'A bounded reconciliation actor context is required.';
  end if;

  v_idempotency_key := pg_catalog.lower(
    pg_catalog.regexp_replace(
      pg_catalog.btrim(coalesce(p_idempotency_key, '')),
      '[^A-Za-z0-9:_-]',
      '',
      'g'
    )
  );
  if pg_catalog.length(v_idempotency_key) < 8
     or pg_catalog.length(v_idempotency_key) > 128 then
    raise exception 'A valid reconciliation idempotency key is required.';
  end if;

  select contribution.*
    into v_contribution
    from public.group_contributions as contribution
   where contribution.id = p_contribution_id
   for update;

  if not found then
    raise exception 'Contribution was not found.';
  end if;

  if v_contribution.status = 'confirmed'
     and v_contribution.payment_status = 'verified'::public.payment_status
     and v_contribution.reconciled_ledger_entry_id = p_ledger_entry_id
     and v_contribution.reconciliation_idempotency_key = v_idempotency_key then
    return pg_catalog.jsonb_build_object(
      'status', 'idempotent_replay',
      'contribution_id', v_contribution.id,
      'ledger_entry_id', v_contribution.reconciled_ledger_entry_id,
      'reconciliation_id', v_contribution.reconciliation_id,
      'confirmed_at', v_contribution.confirmed_at
    );
  end if;

  if v_contribution.status <> 'pending'
     or v_contribution.payment_status <> 'pending_verification'::public.payment_status then
    raise exception 'Only a pending, unverified contribution may be reconciled.';
  end if;

  if v_contribution.updated_at is distinct from p_expected_contribution_updated_at then
    raise exception 'Contribution changed after it was loaded; reconciliation was rolled back.';
  end if;

  select contribution_group.*
    into v_group
    from public.groups as contribution_group
   where contribution_group.id = v_contribution.group_id;

  if not found or v_group.club_id is null then
    raise exception 'Contribution group has no valid club boundary.';
  end if;

  select ledger_entry.*
    into v_ledger
    from public.momo_ledger_entries as ledger_entry
   where ledger_entry.id = p_ledger_entry_id
   for update;

  if not found then
    raise exception 'SMS ledger entry was not found.';
  end if;

  if v_ledger.updated_at is distinct from p_expected_ledger_updated_at then
    raise exception 'SMS ledger entry changed after it was loaded; reconciliation was rolled back.';
  end if;

  select parsed_sms.*
    into v_parsed
    from public.momo_sms_parsed as parsed_sms
   where parsed_sms.id = v_ledger.parsed_sms_id;

  if not found then
    raise exception 'SMS ledger entry is not bound to a parsed SMS record.';
  end if;

  v_reference := pg_catalog.upper(
    pg_catalog.regexp_replace(
      pg_catalog.btrim(coalesce(v_contribution.momo_reference, '')),
      '[^A-Za-z0-9]',
      '',
      'g'
    )
  );
  v_ledger_reference := pg_catalog.upper(
    pg_catalog.regexp_replace(
      pg_catalog.btrim(coalesce(v_ledger.external_reference, '')),
      '[^A-Za-z0-9]',
      '',
      'g'
    )
  );
  v_parsed_reference := pg_catalog.upper(
    pg_catalog.regexp_replace(
      pg_catalog.btrim(coalesce(v_parsed.momo_tx_id, '')),
      '[^A-Za-z0-9]',
      '',
      'g'
    )
  );

  if pg_catalog.length(v_reference) < 6
     or v_ledger_reference is distinct from v_reference
     or v_parsed_reference is distinct from v_reference then
    raise exception 'Contribution and SMS payment references do not match exactly.';
  end if;

  if v_ledger.user_id is distinct from v_contribution.user_id
     or v_parsed.user_id is distinct from v_contribution.user_id then
    raise exception 'Contribution and SMS ownership do not match.';
  end if;

  if v_ledger.club_id is distinct from v_group.club_id
     or v_parsed.club_id is distinct from v_group.club_id then
    raise exception 'Contribution and SMS club boundaries do not match.';
  end if;

  if v_ledger.amount is distinct from v_contribution.amount
     or v_parsed.amount is distinct from v_contribution.amount then
    raise exception 'Contribution and SMS amounts do not match exactly.';
  end if;

  if pg_catalog.upper(v_ledger.currency) is distinct from pg_catalog.upper(v_group.currency)
     or pg_catalog.upper(v_parsed.currency) is distinct from pg_catalog.upper(v_group.currency) then
    raise exception 'Contribution and SMS currencies do not match.';
  end if;

  if v_ledger.entry_type <> 'debit' or v_parsed.tx_direction <> 'debit' then
    raise exception 'Only an outgoing supporter payment may confirm a contribution.';
  end if;

  if v_ledger.target_record_id is not null
     and (
       v_ledger.target_table is distinct from 'group_contributions'
       or v_ledger.target_record_id is distinct from v_contribution.id
     ) then
    raise exception 'SMS ledger entry is already bound to another target.';
  end if;

  select reconciliation.*
    into v_reconciliation
    from public.momo_reconciliations as reconciliation
   where reconciliation.parsed_sms_id = v_ledger.parsed_sms_id
   for update;

  if found then
    if v_reconciliation.match_status <> 'matched'
       or v_reconciliation.target_table is distinct from 'group_contributions'
       or v_reconciliation.target_record_id is distinct from v_contribution.id
       or v_reconciliation.metadata ->> 'idempotency_key' is distinct from v_idempotency_key
       or v_reconciliation.metadata ->> 'ledger_entry_id' is distinct from v_ledger.id::text then
      raise exception 'Parsed SMS reconciliation is already bound to another decision.';
    end if;
  else
    insert into public.momo_reconciliations (
      parsed_sms_id,
      user_id,
      target_table,
      target_record_id,
      match_type,
      match_status,
      confidence,
      notes,
      metadata,
      reconciled_at,
      country_code,
      club_id
    ) values (
      v_ledger.parsed_sms_id,
      v_contribution.user_id,
      'group_contributions',
      v_contribution.id,
      'exact_sms_reference',
      'matched',
      1.0000,
      'Atomic service reconciliation with exact amount, reference, owner and club binding.',
      pg_catalog.jsonb_build_object(
        'actor_id', p_actor_id,
        'actor_context', v_actor_context,
        'idempotency_key', v_idempotency_key,
        'ledger_entry_id', v_ledger.id
      ),
      v_reconciled_at,
      v_ledger.country_code,
      v_group.club_id
    )
    returning * into v_reconciliation;
  end if;

  update public.momo_ledger_entries
     set target_table = 'group_contributions',
         target_record_id = v_contribution.id,
         ledger_status = 'posted',
         metadata = coalesce(metadata, '{}'::jsonb)
           || pg_catalog.jsonb_build_object(
             'reconciliation_id', v_reconciliation.id,
             'reconciliation_actor_id', p_actor_id,
             'reconciliation_actor_context', v_actor_context,
             'reconciliation_idempotency_key', v_idempotency_key
           )
   where id = v_ledger.id
     and updated_at = p_expected_ledger_updated_at;

  if not found then
    raise exception 'SMS ledger entry changed during reconciliation; transaction was rolled back.';
  end if;

  update public.group_contributions
     set status = 'confirmed',
         payment_status = 'verified'::public.payment_status,
         confirmed_at = v_reconciled_at,
         reconciled_ledger_entry_id = v_ledger.id,
         reconciliation_id = v_reconciliation.id,
         reconciliation_idempotency_key = v_idempotency_key,
         reconciled_by = p_actor_id
   where id = v_contribution.id
     and status = 'pending'
     and payment_status = 'pending_verification'::public.payment_status
     and updated_at = p_expected_contribution_updated_at
  returning * into v_contribution;

  if not found then
    raise exception 'Contribution changed during reconciliation; transaction was rolled back.';
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
    metadata,
    notes
  ) values (
    p_actor_id,
    p_actor_id,
    'group_contribution_sms_reconciled',
    'group_contributions',
    v_contribution.id::text,
    pg_catalog.jsonb_build_object(
      'status', 'pending',
      'payment_status', 'pending_verification',
      'updated_at', p_expected_contribution_updated_at
    ),
    pg_catalog.jsonb_build_object(
      'status', v_contribution.status,
      'payment_status', v_contribution.payment_status,
      'updated_at', v_contribution.updated_at,
      'confirmed_at', v_contribution.confirmed_at
    ),
    v_group.club_id,
    'group_contribution',
    v_contribution.id::text,
    pg_catalog.jsonb_build_object(
      'actor_context', v_actor_context,
      'idempotency_key', v_idempotency_key,
      'ledger_entry_id', v_ledger.id,
      'parsed_sms_id', v_ledger.parsed_sms_id,
      'reconciliation_id', v_reconciliation.id,
      'binding', 'exact_amount_reference_owner_club_and_versions'
    ),
    'Atomic service reconciliation from a verified SMS ledger entry.'
  );

  return pg_catalog.jsonb_build_object(
    'status', 'confirmed',
    'contribution_id', v_contribution.id,
    'ledger_entry_id', v_ledger.id,
    'reconciliation_id', v_reconciliation.id,
    'confirmed_at', v_contribution.confirmed_at
  );
end;
$$;

revoke all on function public.reconcile_group_contribution_from_sms(
  uuid,
  uuid,
  timestamptz,
  timestamptz,
  text,
  uuid,
  text
) from public, anon, authenticated, service_role;
grant execute on function public.reconcile_group_contribution_from_sms(
  uuid,
  uuid,
  timestamptz,
  timestamptz,
  text,
  uuid,
  text
) to service_role;

-- Retire the legacy unbound confirmation entry point from client roles on
-- installations where that compatibility RPC is still present.
do $$
begin
  if pg_catalog.to_regprocedure('public.confirm_contribution(uuid)') is not null then
    execute 'revoke all on function public.confirm_contribution(uuid) '
      'from public, anon, authenticated, service_role';
    execute 'grant execute on function public.confirm_contribution(uuid) '
      'to service_role';
  end if;
end;
$$;

-- Public initiatives remain readable, while authenticated reads are tied to
-- the club in the signed request. Closed records are visible only to club
-- administrators in that same tenant.
drop policy if exists contribution_groups_public_read on public.groups;
drop policy if exists contribution_groups_authenticated_read on public.groups;
drop policy if exists contribution_groups_select_club on public.groups;
drop policy if exists contribution_groups_admin_all on public.groups;
drop policy if exists groups_select_public on public.groups;

create policy contribution_groups_public_read
on public.groups
for select
to anon
using (
  coalesce(is_active, true)
  and not coalesce(is_closed, false)
  and coalesce(visibility, 'public') = 'public'
);

create policy contribution_groups_authenticated_read
on public.groups
for select
to authenticated
using (
  club_id::text = public.requesting_club_id()
  and coalesce(visibility, 'public') = 'public'
  and (
    (
      coalesce(is_active, true)
      and not coalesce(is_closed, false)
    )
    or public.is_club_admin(club_id)
  )
);

drop policy if exists group_members_select_members on public.group_members;
drop policy if exists group_members_authenticated_read on public.group_members;

create policy group_members_authenticated_read
on public.group_members
for select
to authenticated
using (
  exists (
    select 1
      from public.groups as contribution_group
     where contribution_group.id = group_members.group_id
       and contribution_group.club_id::text = public.requesting_club_id()
       and (
         group_members.user_id = (select auth.uid())
         or public.is_group_member(group_members.group_id)
         or public.is_club_admin(contribution_group.club_id)
       )
  )
);

drop policy if exists contributions_insert on public.group_contributions;
drop policy if exists contributions_select on public.group_contributions;
drop policy if exists group_contributions_authenticated_read
  on public.group_contributions;

create policy group_contributions_authenticated_read
on public.group_contributions
for select
to authenticated
using (
  exists (
    select 1
      from public.groups as contribution_group
     where contribution_group.id = group_contributions.group_id
       and contribution_group.club_id::text = public.requesting_club_id()
       and (
         group_contributions.user_id = (select auth.uid())
         or public.is_group_member(group_contributions.group_id)
         or public.is_club_admin(contribution_group.club_id)
       )
  )
);

drop policy if exists "Users can delete own ledger entries"
  on public.momo_ledger_entries;
drop policy if exists momo_ledger_entries_select_own
  on public.momo_ledger_entries;
drop policy if exists momo_ledger_entries_authenticated_read
  on public.momo_ledger_entries;

create policy momo_ledger_entries_authenticated_read
on public.momo_ledger_entries
for select
to authenticated
using (
  user_id = (select auth.uid())
  and club_id::text = public.requesting_club_id()
);

drop policy if exists "Users can delete own reconciliations"
  on public.momo_reconciliations;
drop policy if exists momo_reconciliations_select_own
  on public.momo_reconciliations;
drop policy if exists momo_reconciliations_authenticated_read
  on public.momo_reconciliations;

create policy momo_reconciliations_authenticated_read
on public.momo_reconciliations
for select
to authenticated
using (
  user_id = (select auth.uid())
  and club_id::text = public.requesting_club_id()
);

alter table public.groups enable row level security;
alter table public.group_members enable row level security;
alter table public.group_contributions enable row level security;
alter table public.momo_ledger_entries enable row level security;
alter table public.momo_reconciliations enable row level security;

-- Remove all supporter-side writes and expose only fields used by released
-- contribution and statement screens. The trusted service keeps its existing
-- ingestion duties while reconciliation is moved to the atomic RPC above.
revoke all on table public.groups
  from public, anon, authenticated;
revoke all on table public.contribution_groups
  from public, anon, authenticated;
revoke all on table public.group_members
  from public, anon, authenticated;
revoke all on table public.group_contributions
  from public, anon, authenticated;
revoke all on table public.momo_ledger_entries
  from public, anon, authenticated;
revoke all on table public.momo_reconciliations
  from public, anon, authenticated;

grant select (
  id,
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
  created_at,
  club_id,
  partner_id,
  currency,
  updated_at,
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
) on public.groups to anon, authenticated;

grant select on public.contribution_groups to anon, authenticated;

grant select (
  id,
  group_id,
  user_id,
  display_name,
  is_admin,
  is_anonymous,
  contribution_amount,
  joined_at
) on public.group_members to authenticated;

grant select (
  id,
  group_id,
  user_id,
  amount,
  status,
  payment_status,
  momo_reference,
  confirmed_at,
  created_at,
  updated_at
) on public.group_contributions to authenticated;

grant select (
  id,
  amount,
  currency,
  external_reference,
  counterparty_name,
  description,
  tx_category,
  cashflow_bucket,
  ledger_status,
  tx_datetime,
  created_at,
  updated_at,
  club_id
) on public.momo_ledger_entries to authenticated;

grant select (
  id,
  target_table,
  target_record_id,
  match_type,
  match_status,
  confidence,
  reconciled_at,
  created_at,
  updated_at,
  club_id
) on public.momo_reconciliations to authenticated;

grant select, insert, update, delete on public.groups to service_role;
grant select, insert, update, delete on public.contribution_groups to service_role;
grant select, insert, update, delete on public.group_members to service_role;
grant select, insert, update, delete on public.group_contributions to service_role;
grant select, insert, update, delete on public.momo_ledger_entries to service_role;
grant select, insert, update, delete on public.momo_reconciliations to service_role;

comment on function public.create_pending_group_contribution(
  uuid,
  integer,
  text,
  text
) is
  'Creates only the authenticated member''s own-club pending contribution, with a normalized immutable payment reference and idempotent replay.';

comment on function public.reconcile_group_contribution_from_sms(
  uuid,
  uuid,
  timestamptz,
  timestamptz,
  text,
  uuid,
  text
) is
  'Service-only atomic reconciliation: exact owner, club, amount, currency, reference and updated_at binding with immutable audit evidence.';
