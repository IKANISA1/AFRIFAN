begin;

-- Google Wallet is a presentation channel. AFRICLUB remains the authority for
-- payment finality, ticket state, admission, verifier authorization, and audit.

create table public.ticket_organizations (
  id uuid primary key default gen_random_uuid(),
  club_id bigint not null references public.african_football_clubs(id) on delete cascade,
  slug text not null,
  display_name text not null,
  status text not null default 'draft',
  google_wallet_issuer_id text,
  created_by uuid,
  created_at timestamp with time zone not null default timezone('utc', now()),
  updated_at timestamp with time zone not null default timezone('utc', now()),
  constraint ticket_organizations_slug_check check (
    slug ~ '^[a-z0-9][a-z0-9-]{1,80}$'
  ),
  constraint ticket_organizations_name_check check (
    length(btrim(display_name)) between 2 and 120
  ),
  constraint ticket_organizations_status_check check (
    status = any (array['draft', 'active', 'suspended', 'archived'])
  ),
  constraint ticket_organizations_issuer_check check (
    google_wallet_issuer_id is null
    or google_wallet_issuer_id ~ '^[0-9]{8,32}$'
  )
);

create unique index idx_ticket_organizations_club_slug
  on public.ticket_organizations (club_id, slug);
create index idx_ticket_organizations_club_status
  on public.ticket_organizations (club_id, status);

create trigger ticket_organizations_set_updated_at
before update on public.ticket_organizations
for each row execute function public.set_updated_at();

create table public.ticket_events (
  id uuid primary key default gen_random_uuid(),
  club_id bigint not null references public.african_football_clubs(id) on delete cascade,
  organization_id uuid not null references public.ticket_organizations(id) on delete cascade,
  match_id uuid not null references public.matches(id) on delete cascade,
  venue_id uuid not null references public.venues(id) on delete restrict,
  status text not null default 'draft',
  entry_opens_at timestamp with time zone not null,
  entry_closes_at timestamp with time zone not null,
  google_wallet_enabled boolean not null default false,
  verification_enabled boolean not null default false,
  created_by uuid,
  created_at timestamp with time zone not null default timezone('utc', now()),
  updated_at timestamp with time zone not null default timezone('utc', now()),
  constraint ticket_events_status_check check (
    status = any (array['draft', 'active', 'paused', 'completed', 'cancelled'])
  ),
  constraint ticket_events_window_check check (
    entry_closes_at > entry_opens_at
  )
);

create unique index idx_ticket_events_club_match
  on public.ticket_events (club_id, match_id);
create index idx_ticket_events_organization_status
  on public.ticket_events (organization_id, status, entry_opens_at, entry_closes_at);
create index idx_ticket_events_venue_status
  on public.ticket_events (venue_id, status, entry_opens_at, entry_closes_at);

create trigger ticket_events_set_updated_at
before update on public.ticket_events
for each row execute function public.set_updated_at();

create table public.ticket_verifier_assignments (
  id uuid primary key default gen_random_uuid(),
  club_id bigint not null references public.african_football_clubs(id) on delete cascade,
  organization_id uuid not null references public.ticket_organizations(id) on delete cascade,
  ticket_event_id uuid not null references public.ticket_events(id) on delete cascade,
  venue_id uuid not null references public.venues(id) on delete cascade,
  user_id uuid not null,
  gate_code text,
  starts_at timestamp with time zone not null,
  ends_at timestamp with time zone not null,
  is_active boolean not null default true,
  granted_by uuid not null,
  granted_at timestamp with time zone not null default timezone('utc', now()),
  revoked_by uuid,
  revoked_at timestamp with time zone,
  created_at timestamp with time zone not null default timezone('utc', now()),
  updated_at timestamp with time zone not null default timezone('utc', now()),
  constraint ticket_verifier_assignments_gate_check check (
    gate_code is null
    or gate_code ~ '^[A-Z0-9][A-Z0-9_-]{0,31}$'
  ),
  constraint ticket_verifier_assignments_window_check check (ends_at > starts_at),
  constraint ticket_verifier_assignments_revocation_check check (
    (is_active and revoked_at is null and revoked_by is null)
    or (not is_active and revoked_at is not null)
  )
);

create unique index idx_ticket_verifier_assignments_active_scope
  on public.ticket_verifier_assignments (
    ticket_event_id,
    user_id,
    coalesce(gate_code, '*')
  ) where is_active;
create index idx_ticket_verifier_assignments_user_active
  on public.ticket_verifier_assignments (
    user_id,
    is_active,
    club_id,
    starts_at,
    ends_at
  );
create index idx_ticket_verifier_assignments_event_active
  on public.ticket_verifier_assignments (
    ticket_event_id,
    is_active,
    starts_at,
    ends_at
  );
create index idx_ticket_verifier_assignments_organization
  on public.ticket_verifier_assignments (organization_id, is_active, user_id);
create index idx_ticket_verifier_assignments_venue
  on public.ticket_verifier_assignments (venue_id, is_active, user_id);

create trigger ticket_verifier_assignments_set_updated_at
before update on public.ticket_verifier_assignments
for each row execute function public.set_updated_at();

create table public.ticket_wallet_credentials (
  id uuid primary key default gen_random_uuid(),
  club_id bigint not null references public.african_football_clubs(id) on delete cascade,
  organization_id uuid not null references public.ticket_organizations(id) on delete cascade,
  ticket_event_id uuid not null references public.ticket_events(id) on delete cascade,
  ticket_id uuid not null references public.tickets(id) on delete cascade,
  credential_version integer not null default 1,
  status text not null default 'active',
  issued_at timestamp with time zone not null default timezone('utc', now()),
  revoked_at timestamp with time zone,
  rotated_at timestamp with time zone,
  created_at timestamp with time zone not null default timezone('utc', now()),
  updated_at timestamp with time zone not null default timezone('utc', now()),
  constraint ticket_wallet_credentials_version_check check (credential_version > 0),
  constraint ticket_wallet_credentials_status_check check (
    status = any (array['active', 'rotated', 'revoked'])
  )
);

create unique index idx_ticket_wallet_credentials_active_ticket
  on public.ticket_wallet_credentials (ticket_id)
  where status = 'active';
create unique index idx_ticket_wallet_credentials_ticket_version
  on public.ticket_wallet_credentials (ticket_id, credential_version);
create index idx_ticket_wallet_credentials_event_status
  on public.ticket_wallet_credentials (ticket_event_id, status);
create index idx_ticket_wallet_credentials_organization
  on public.ticket_wallet_credentials (organization_id, status);
create index idx_ticket_wallet_credentials_club
  on public.ticket_wallet_credentials (club_id, status);

create trigger ticket_wallet_credentials_set_updated_at
before update on public.ticket_wallet_credentials
for each row execute function public.set_updated_at();

create table public.google_wallet_ticket_passes (
  id uuid primary key default gen_random_uuid(),
  club_id bigint not null references public.african_football_clubs(id) on delete cascade,
  organization_id uuid not null references public.ticket_organizations(id) on delete cascade,
  ticket_event_id uuid not null references public.ticket_events(id) on delete cascade,
  ticket_id uuid not null references public.tickets(id) on delete cascade,
  credential_id uuid not null references public.ticket_wallet_credentials(id) on delete restrict,
  class_id text not null,
  object_id text not null,
  wallet_state text not null default 'ACTIVE',
  last_synced_at timestamp with time zone,
  last_error_code text,
  created_at timestamp with time zone not null default timezone('utc', now()),
  updated_at timestamp with time zone not null default timezone('utc', now()),
  constraint google_wallet_ticket_passes_state_check check (
    wallet_state = any (array['ACTIVE', 'COMPLETED', 'EXPIRED', 'INACTIVE'])
  ),
  constraint google_wallet_ticket_passes_class_check check (
    length(btrim(class_id)) between 3 and 255
  ),
  constraint google_wallet_ticket_passes_object_check check (
    length(btrim(object_id)) between 3 and 255
  )
);

create unique index idx_google_wallet_ticket_passes_ticket
  on public.google_wallet_ticket_passes (ticket_id);
create unique index idx_google_wallet_ticket_passes_object
  on public.google_wallet_ticket_passes (object_id);
create index idx_google_wallet_ticket_passes_event_state
  on public.google_wallet_ticket_passes (ticket_event_id, wallet_state);
create index idx_google_wallet_ticket_passes_organization
  on public.google_wallet_ticket_passes (organization_id, wallet_state);
create index idx_google_wallet_ticket_passes_club
  on public.google_wallet_ticket_passes (club_id, wallet_state);

create trigger google_wallet_ticket_passes_set_updated_at
before update on public.google_wallet_ticket_passes
for each row execute function public.set_updated_at();

create table public.google_wallet_ticket_outbox (
  id uuid primary key default gen_random_uuid(),
  club_id bigint not null references public.african_football_clubs(id) on delete cascade,
  pass_id uuid not null references public.google_wallet_ticket_passes(id) on delete cascade,
  ticket_id uuid not null references public.tickets(id) on delete cascade,
  desired_state text not null,
  status text not null default 'pending',
  operation_key text not null,
  attempts integer not null default 0,
  claim_token uuid,
  available_at timestamp with time zone not null default timezone('utc', now()),
  claimed_at timestamp with time zone,
  completed_at timestamp with time zone,
  dead_lettered_at timestamp with time zone,
  last_error_code text,
  created_at timestamp with time zone not null default timezone('utc', now()),
  updated_at timestamp with time zone not null default timezone('utc', now()),
  constraint google_wallet_ticket_outbox_state_check check (
    desired_state = any (array['ACTIVE', 'COMPLETED', 'EXPIRED', 'INACTIVE'])
  ),
  constraint google_wallet_ticket_outbox_status_check check (
    status = any (array['pending', 'processing', 'completed', 'failed', 'dead_letter'])
  ),
  constraint google_wallet_ticket_outbox_attempts_check check (attempts >= 0),
  constraint google_wallet_ticket_outbox_operation_key_check check (
    length(btrim(operation_key)) between 8 and 200
  )
);

create unique index idx_google_wallet_ticket_outbox_operation_key
  on public.google_wallet_ticket_outbox (operation_key);
create index idx_google_wallet_ticket_outbox_pending
  on public.google_wallet_ticket_outbox (status, available_at, created_at)
  where status in ('pending', 'failed');
create unique index idx_google_wallet_ticket_outbox_processing_pass
  on public.google_wallet_ticket_outbox (pass_id)
  where status = 'processing';
create index idx_google_wallet_ticket_outbox_pass
  on public.google_wallet_ticket_outbox (pass_id, created_at desc);
create index idx_google_wallet_ticket_outbox_ticket
  on public.google_wallet_ticket_outbox (ticket_id, created_at desc);
create index idx_google_wallet_ticket_outbox_club
  on public.google_wallet_ticket_outbox (club_id, status, available_at);

create trigger google_wallet_ticket_outbox_set_updated_at
before update on public.google_wallet_ticket_outbox
for each row execute function public.set_updated_at();

create table public.ticket_redemption_events (
  id uuid primary key default gen_random_uuid(),
  club_id bigint not null references public.african_football_clubs(id) on delete cascade,
  organization_id uuid not null references public.ticket_organizations(id) on delete restrict,
  ticket_event_id uuid not null references public.ticket_events(id) on delete restrict,
  venue_id uuid not null references public.venues(id) on delete restrict,
  ticket_id uuid not null references public.tickets(id) on delete restrict,
  credential_id uuid not null references public.ticket_wallet_credentials(id) on delete restrict,
  verifier_assignment_id uuid references public.ticket_verifier_assignments(id) on delete restrict,
  verifier_user_id uuid not null,
  operation_id uuid not null,
  gate_code text,
  decision text not null,
  result jsonb not null default '{}'::jsonb,
  scanned_at timestamp with time zone not null default timezone('utc', now()),
  created_at timestamp with time zone not null default timezone('utc', now()),
  constraint ticket_redemption_events_decision_check check (
    decision = any (
      array[
        'admitted',
        'already_used',
        'pending_payment',
        'cancelled',
        'refunded',
        'voided',
        'expired',
        'outside_window',
        'wrong_gate',
        'permission_denied',
        'credential_inactive'
      ]
    )
  ),
  constraint ticket_redemption_events_gate_check check (
    gate_code is null
    or gate_code ~ '^[A-Z0-9][A-Z0-9_-]{0,31}$'
  )
);

create unique index idx_ticket_redemption_events_operation
  on public.ticket_redemption_events (verifier_user_id, operation_id);
create index idx_ticket_redemption_events_ticket_created
  on public.ticket_redemption_events (ticket_id, scanned_at desc);
create index idx_ticket_redemption_events_event_created
  on public.ticket_redemption_events (ticket_event_id, scanned_at desc);
create index idx_ticket_redemption_events_assignment_created
  on public.ticket_redemption_events (verifier_assignment_id, scanned_at desc);
create index idx_ticket_redemption_events_venue_created
  on public.ticket_redemption_events (venue_id, scanned_at desc);
create index idx_ticket_redemption_events_organization_created
  on public.ticket_redemption_events (organization_id, scanned_at desc);
create index idx_ticket_redemption_events_club_created
  on public.ticket_redemption_events (club_id, scanned_at desc);

-- These records repeat tenant and event scope deliberately so security checks
-- and operational queries stay local. Reject inconsistent denormalized scope at
-- the database boundary instead of trusting a dashboard or Edge Function.
create or replace function public.enforce_ticketing_scope_consistency()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_table_name = 'ticket_events' then
    if not exists (
      select 1
      from public.ticket_organizations as organization
      where organization.id = new.organization_id
        and organization.club_id = new.club_id
    ) or not exists (
      select 1
      from public.matches as match
      where match.id = new.match_id
        and match.club_id = new.club_id
    ) or not exists (
      select 1
      from public.venues as venue
      where venue.id = new.venue_id
        and venue.club_id = new.club_id
    ) then
      raise exception 'Ticket event scope is inconsistent.';
    end if;
  elsif tg_table_name = 'ticket_verifier_assignments' then
    if not exists (
      select 1
      from public.ticket_events as event
      where event.id = new.ticket_event_id
        and event.club_id = new.club_id
        and event.organization_id = new.organization_id
        and event.venue_id = new.venue_id
    ) then
      raise exception 'Ticket verifier assignment scope is inconsistent.';
    end if;
  elsif tg_table_name = 'ticket_wallet_credentials' then
    if not exists (
      select 1
      from public.ticket_events as event
      join public.tickets as ticket
        on ticket.id = new.ticket_id
       and ticket.club_id = new.club_id
       and ticket.match_id = event.match_id
      where event.id = new.ticket_event_id
        and event.club_id = new.club_id
        and event.organization_id = new.organization_id
    ) then
      raise exception 'Ticket Wallet credential scope is inconsistent.';
    end if;
  elsif tg_table_name = 'google_wallet_ticket_passes' then
    if not exists (
      select 1
      from public.ticket_wallet_credentials as credential
      where credential.id = new.credential_id
        and credential.club_id = new.club_id
        and credential.organization_id = new.organization_id
        and credential.ticket_event_id = new.ticket_event_id
        and credential.ticket_id = new.ticket_id
    ) then
      raise exception 'Google Wallet pass scope is inconsistent.';
    end if;
  elsif tg_table_name = 'google_wallet_ticket_outbox' then
    if not exists (
      select 1
      from public.google_wallet_ticket_passes as pass
      where pass.id = new.pass_id
        and pass.club_id = new.club_id
        and pass.ticket_id = new.ticket_id
    ) then
      raise exception 'Google Wallet outbox scope is inconsistent.';
    end if;
  elsif tg_table_name = 'ticket_redemption_events' then
    if not exists (
      select 1
      from public.ticket_wallet_credentials as credential
      join public.ticket_events as event
        on event.id = credential.ticket_event_id
       and event.club_id = credential.club_id
       and event.organization_id = credential.organization_id
      where credential.id = new.credential_id
        and credential.club_id = new.club_id
        and credential.organization_id = new.organization_id
        and credential.ticket_event_id = new.ticket_event_id
        and credential.ticket_id = new.ticket_id
        and event.venue_id = new.venue_id
    ) or (
      new.verifier_assignment_id is not null
      and not exists (
        select 1
        from public.ticket_verifier_assignments as assignment
        where assignment.id = new.verifier_assignment_id
          and assignment.user_id = new.verifier_user_id
          and assignment.club_id = new.club_id
          and assignment.organization_id = new.organization_id
          and assignment.ticket_event_id = new.ticket_event_id
          and assignment.venue_id = new.venue_id
      )
    ) then
      raise exception 'Ticket redemption scope is inconsistent.';
    end if;
  end if;

  return new;
end;
$$;

create trigger ticket_events_enforce_scope
before insert or update on public.ticket_events
for each row execute function public.enforce_ticketing_scope_consistency();

create trigger ticket_verifier_assignments_enforce_scope
before insert or update on public.ticket_verifier_assignments
for each row execute function public.enforce_ticketing_scope_consistency();

create trigger ticket_wallet_credentials_enforce_scope
before insert or update on public.ticket_wallet_credentials
for each row execute function public.enforce_ticketing_scope_consistency();

create trigger google_wallet_ticket_passes_enforce_scope
before insert or update on public.google_wallet_ticket_passes
for each row execute function public.enforce_ticketing_scope_consistency();

create trigger google_wallet_ticket_outbox_enforce_scope
before insert or update on public.google_wallet_ticket_outbox
for each row execute function public.enforce_ticketing_scope_consistency();

create trigger ticket_redemption_events_enforce_scope
before insert on public.ticket_redemption_events
for each row execute function public.enforce_ticketing_scope_consistency();

revoke all on function public.enforce_ticketing_scope_consistency()
from public, anon, authenticated, service_role;

alter table public.ticket_organizations enable row level security;
alter table public.ticket_events enable row level security;
alter table public.ticket_verifier_assignments enable row level security;
alter table public.ticket_wallet_credentials enable row level security;
alter table public.google_wallet_ticket_passes enable row level security;
alter table public.google_wallet_ticket_outbox enable row level security;
alter table public.ticket_redemption_events enable row level security;

-- Reset public-schema default ACLs before adding the exact Data API projection.
revoke all on table public.ticket_organizations
  from public, anon, authenticated, service_role;
revoke all on table public.ticket_events
  from public, anon, authenticated, service_role;
revoke all on table public.ticket_verifier_assignments
  from public, anon, authenticated, service_role;
revoke all on table public.ticket_wallet_credentials
  from public, anon, authenticated, service_role;
revoke all on table public.google_wallet_ticket_passes
  from public, anon, authenticated, service_role;
revoke all on table public.google_wallet_ticket_outbox
  from public, anon, authenticated, service_role;
revoke all on table public.ticket_redemption_events
  from public, anon, authenticated, service_role;

grant select (
  id, club_id, slug, display_name, status, created_at, updated_at
) on table public.ticket_organizations to authenticated;
grant select (
  id, club_id, organization_id, match_id, venue_id, status,
  entry_opens_at, entry_closes_at, google_wallet_enabled,
  verification_enabled, created_at, updated_at
) on table public.ticket_events to authenticated;
grant select (
  id, club_id, organization_id, ticket_event_id, venue_id, user_id,
  gate_code, starts_at, ends_at, is_active, granted_at, revoked_at,
  created_at, updated_at
) on table public.ticket_verifier_assignments to authenticated;
grant select (
  id, club_id, organization_id, ticket_event_id, venue_id, ticket_id,
  verifier_assignment_id, verifier_user_id, operation_id, gate_code,
  decision, result, scanned_at, created_at
) on table public.ticket_redemption_events to authenticated;

grant all on table public.ticket_organizations to service_role;
grant all on table public.ticket_events to service_role;
grant all on table public.ticket_verifier_assignments to service_role;
grant all on table public.ticket_wallet_credentials to service_role;
grant all on table public.google_wallet_ticket_passes to service_role;
grant all on table public.google_wallet_ticket_outbox to service_role;
grant all on table public.ticket_redemption_events to service_role;

create policy ticket_organizations_assigned_or_admin_read
on public.ticket_organizations for select
to authenticated
using (
  (
    club_id::text = public.requesting_club_id()
    and public.is_club_admin(club_id)
  )
  or public.is_super_admin()
  or exists (
    select 1
    from public.ticket_verifier_assignments as assignment
    where assignment.organization_id = ticket_organizations.id
      and assignment.user_id = (select auth.uid())
      and assignment.is_active
  )
);

create policy ticket_organizations_admin_insert
on public.ticket_organizations for insert
to authenticated
with check (
  (club_id::text = public.requesting_club_id() and public.is_club_admin(club_id))
  or public.is_super_admin()
);

create policy ticket_organizations_admin_update
on public.ticket_organizations for update
to authenticated
using (
  (club_id::text = public.requesting_club_id() and public.is_club_admin(club_id))
  or public.is_super_admin()
)
with check (
  (club_id::text = public.requesting_club_id() and public.is_club_admin(club_id))
  or public.is_super_admin()
);

create policy ticket_organizations_admin_delete
on public.ticket_organizations for delete
to authenticated
using (
  (club_id::text = public.requesting_club_id() and public.is_club_admin(club_id))
  or public.is_super_admin()
);

create policy ticket_events_assigned_or_admin_read
on public.ticket_events for select
to authenticated
using (
  (
    club_id::text = public.requesting_club_id()
    and public.is_club_admin(club_id)
  )
  or public.is_super_admin()
  or exists (
    select 1
    from public.ticket_verifier_assignments as assignment
    where assignment.ticket_event_id = ticket_events.id
      and assignment.user_id = (select auth.uid())
      and assignment.is_active
  )
);

create policy ticket_events_admin_insert
on public.ticket_events for insert
to authenticated
with check (
  (club_id::text = public.requesting_club_id() and public.is_club_admin(club_id))
  or public.is_super_admin()
);

create policy ticket_events_admin_update
on public.ticket_events for update
to authenticated
using (
  (club_id::text = public.requesting_club_id() and public.is_club_admin(club_id))
  or public.is_super_admin()
)
with check (
  (club_id::text = public.requesting_club_id() and public.is_club_admin(club_id))
  or public.is_super_admin()
);

create policy ticket_events_admin_delete
on public.ticket_events for delete
to authenticated
using (
  (club_id::text = public.requesting_club_id() and public.is_club_admin(club_id))
  or public.is_super_admin()
);

create policy ticket_verifier_assignments_self_or_admin_read
on public.ticket_verifier_assignments for select
to authenticated
using (
  (
    user_id = (select auth.uid())
    and club_id::text = public.requesting_club_id()
  )
  or (
    club_id::text = public.requesting_club_id()
    and public.is_club_admin(club_id)
  )
  or public.is_super_admin()
);

create policy ticket_verifier_assignments_admin_insert
on public.ticket_verifier_assignments for insert
to authenticated
with check (
  (club_id::text = public.requesting_club_id() and public.is_club_admin(club_id))
  or public.is_super_admin()
);

create policy ticket_verifier_assignments_admin_update
on public.ticket_verifier_assignments for update
to authenticated
using (
  (club_id::text = public.requesting_club_id() and public.is_club_admin(club_id))
  or public.is_super_admin()
)
with check (
  (club_id::text = public.requesting_club_id() and public.is_club_admin(club_id))
  or public.is_super_admin()
);

create policy ticket_verifier_assignments_admin_delete
on public.ticket_verifier_assignments for delete
to authenticated
using (
  (club_id::text = public.requesting_club_id() and public.is_club_admin(club_id))
  or public.is_super_admin()
);

create policy ticket_redemption_events_assigned_or_admin_read
on public.ticket_redemption_events for select
to authenticated
using (
  (
    verifier_user_id = (select auth.uid())
    and club_id::text = public.requesting_club_id()
    and exists (
      select 1
      from public.ticket_verifier_assignments as assignment
      where assignment.id = ticket_redemption_events.verifier_assignment_id
        and assignment.user_id = (select auth.uid())
    )
  )
  or (
    club_id::text = public.requesting_club_id()
    and public.is_club_admin(club_id)
  )
  or public.is_super_admin()
);

create policy ticket_redemption_events_service_insert
on public.ticket_redemption_events for insert to service_role with check (true);
create policy ticket_redemption_events_service_update
on public.ticket_redemption_events for update to service_role
using (true) with check (true);
create policy ticket_redemption_events_service_delete
on public.ticket_redemption_events for delete to service_role using (true);

-- Private operational tables remain service-only even if future default grants
-- change. The policies are defense in depth for direct service-role sessions.
create policy ticket_wallet_credentials_service_read
on public.ticket_wallet_credentials for select to service_role using (true);
create policy ticket_wallet_credentials_service_insert
on public.ticket_wallet_credentials for insert to service_role with check (true);
create policy ticket_wallet_credentials_service_update
on public.ticket_wallet_credentials for update to service_role
using (true) with check (true);
create policy ticket_wallet_credentials_service_delete
on public.ticket_wallet_credentials for delete to service_role using (true);

create policy google_wallet_ticket_passes_service_read
on public.google_wallet_ticket_passes for select to service_role using (true);
create policy google_wallet_ticket_passes_service_insert
on public.google_wallet_ticket_passes for insert to service_role with check (true);
create policy google_wallet_ticket_passes_service_update
on public.google_wallet_ticket_passes for update to service_role
using (true) with check (true);
create policy google_wallet_ticket_passes_service_delete
on public.google_wallet_ticket_passes for delete to service_role using (true);

create policy google_wallet_ticket_outbox_service_read
on public.google_wallet_ticket_outbox for select to service_role using (true);
create policy google_wallet_ticket_outbox_service_insert
on public.google_wallet_ticket_outbox for insert to service_role with check (true);
create policy google_wallet_ticket_outbox_service_update
on public.google_wallet_ticket_outbox for update to service_role
using (true) with check (true);
create policy google_wallet_ticket_outbox_service_delete
on public.google_wallet_ticket_outbox for delete to service_role using (true);

create or replace function public.prevent_ticket_redemption_event_mutation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  raise exception 'Ticket redemption events are immutable.';
end;
$$;

create trigger ticket_redemption_events_immutable_update
before update on public.ticket_redemption_events
for each row execute function public.prevent_ticket_redemption_event_mutation();

create trigger ticket_redemption_events_immutable_delete
before delete on public.ticket_redemption_events
for each row execute function public.prevent_ticket_redemption_event_mutation();

revoke all on function public.prevent_ticket_redemption_event_mutation()
from public, anon, authenticated, service_role;

create or replace function public.grant_ticket_verifier_assignment(
  p_actor_id uuid,
  p_club_id bigint,
  p_ticket_event_id uuid,
  p_target_user_id uuid,
  p_gate_code text,
  p_starts_at timestamp with time zone,
  p_ends_at timestamp with time zone
) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_event public.ticket_events;
  v_assignment_id uuid;
  v_gate_code text := nullif(upper(btrim(coalesce(p_gate_code, ''))), '');
begin
  if p_actor_id is null
     or p_club_id is null
     or p_ticket_event_id is null
     or p_target_user_id is null
     or p_starts_at is null
     or p_ends_at is null then
    raise exception 'Verifier assignment scope is required.';
  end if;

  if not exists (
    select 1
    from public.admin_role_assignments as assignment
    where assignment.user_id = p_actor_id
      and assignment.is_active
      and (
        assignment.role in ('super_admin', 'admin')
        or (
          assignment.role in ('club_admin', 'rayon_sport')
          and assignment.club_id = p_club_id
        )
      )
  ) then
    raise exception 'Club-admin authority is required.';
  end if;

  if v_gate_code is not null
     and v_gate_code !~ '^[A-Z0-9][A-Z0-9_-]{0,31}$' then
    raise exception 'Gate code is invalid.';
  end if;

  select event.*
  into v_event
  from public.ticket_events as event
  where event.id = p_ticket_event_id
    and event.club_id = p_club_id
    and event.status not in ('completed', 'cancelled')
  for update;

  if not found then
    raise exception 'Ticket event is unavailable or outside the active club.';
  end if;

  if p_starts_at < v_event.entry_opens_at
     or p_ends_at > v_event.entry_closes_at
     or p_ends_at <= p_starts_at then
    raise exception 'Verifier shift must stay inside the event entry window.';
  end if;

  if not exists (
    select 1
    from public.profiles as profile
    where profile.id = p_target_user_id
      and profile.club_id = p_club_id
      and profile.is_active
  ) then
    raise exception 'Verifier must have an active profile in the selected club.';
  end if;

  if exists (
    select 1
    from public.ticket_verifier_assignments as assignment
    where assignment.ticket_event_id = v_event.id
      and assignment.user_id = p_target_user_id
      and coalesce(assignment.gate_code, '*') = coalesce(v_gate_code, '*')
      and assignment.is_active
  ) then
    raise exception 'An active verifier assignment already exists for this event and gate.';
  end if;

  insert into public.ticket_verifier_assignments (
    club_id,
    organization_id,
    ticket_event_id,
    venue_id,
    user_id,
    gate_code,
    starts_at,
    ends_at,
    granted_by
  ) values (
    p_club_id,
    v_event.organization_id,
    v_event.id,
    v_event.venue_id,
    p_target_user_id,
    v_gate_code,
    p_starts_at,
    p_ends_at,
    p_actor_id
  ) returning id into v_assignment_id;

  insert into public.admin_audit_log (
    actor_id,
    user_id,
    action,
    target_table,
    target_id,
    new_data,
    club_id,
    entity_type,
    entity_id,
    metadata
  ) values (
    p_actor_id,
    p_actor_id,
    'ticket_verifier_assignment_granted',
    'ticket_verifier_assignments',
    v_assignment_id::text,
    jsonb_build_object(
      'target_user_id', p_target_user_id,
      'ticket_event_id', v_event.id,
      'organization_id', v_event.organization_id,
      'venue_id', v_event.venue_id,
      'gate_code', v_gate_code,
      'starts_at', p_starts_at,
      'ends_at', p_ends_at,
      'is_active', true
    ),
    p_club_id,
    'ticket_verifier_assignment',
    v_assignment_id::text,
    jsonb_build_object(
      'scope', 'organization_event_venue_gate',
      'source', 'admin_ticket_verifier_workspace'
    )
  );

  return v_assignment_id;
end;
$$;

revoke all on function public.grant_ticket_verifier_assignment(
  uuid, bigint, uuid, uuid, text, timestamp with time zone, timestamp with time zone
) from public, anon, authenticated, service_role;
grant execute on function public.grant_ticket_verifier_assignment(
  uuid, bigint, uuid, uuid, text, timestamp with time zone, timestamp with time zone
) to service_role;

create or replace function public.revoke_ticket_verifier_assignment(
  p_actor_id uuid,
  p_club_id bigint,
  p_assignment_id uuid,
  p_expected_updated_at timestamp with time zone
) returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_assignment public.ticket_verifier_assignments;
  v_now timestamp with time zone := timezone('utc', now());
begin
  if p_actor_id is null
     or p_club_id is null
     or p_assignment_id is null
     or p_expected_updated_at is null then
    raise exception 'Verifier assignment revocation scope is required.';
  end if;

  if not exists (
    select 1
    from public.admin_role_assignments as assignment
    where assignment.user_id = p_actor_id
      and assignment.is_active
      and (
        assignment.role in ('super_admin', 'admin')
        or (
          assignment.role in ('club_admin', 'rayon_sport')
          and assignment.club_id = p_club_id
        )
      )
  ) then
    raise exception 'Club-admin authority is required.';
  end if;

  select assignment.*
  into v_assignment
  from public.ticket_verifier_assignments as assignment
  where assignment.id = p_assignment_id
    and assignment.club_id = p_club_id
  for update;

  if not found then
    raise exception 'Verifier assignment was not found in the active club.';
  end if;
  if not v_assignment.is_active then
    raise exception 'Verifier assignment is already inactive.';
  end if;
  if v_assignment.updated_at is distinct from p_expected_updated_at then
    raise exception 'Verifier assignment changed after it was loaded.';
  end if;

  update public.ticket_verifier_assignments as assignment
  set is_active = false,
      revoked_by = p_actor_id,
      revoked_at = v_now
  where assignment.id = v_assignment.id;

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
    p_actor_id,
    'ticket_verifier_assignment_revoked',
    'ticket_verifier_assignments',
    v_assignment.id::text,
    jsonb_build_object(
      'target_user_id', v_assignment.user_id,
      'ticket_event_id', v_assignment.ticket_event_id,
      'organization_id', v_assignment.organization_id,
      'venue_id', v_assignment.venue_id,
      'gate_code', v_assignment.gate_code,
      'starts_at', v_assignment.starts_at,
      'ends_at', v_assignment.ends_at,
      'is_active', true
    ),
    jsonb_build_object(
      'is_active', false,
      'revoked_by', p_actor_id,
      'revoked_at', v_now
    ),
    p_club_id,
    'ticket_verifier_assignment',
    v_assignment.id::text,
    jsonb_build_object(
      'scope', 'organization_event_venue_gate',
      'source', 'admin_ticket_verifier_workspace'
    )
  );

  return true;
end;
$$;

revoke all on function public.revoke_ticket_verifier_assignment(
  uuid, bigint, uuid, timestamp with time zone
) from public, anon, authenticated, service_role;
grant execute on function public.revoke_ticket_verifier_assignment(
  uuid, bigint, uuid, timestamp with time zone
) to service_role;

create or replace function public.prepare_google_wallet_ticket(
  p_ticket_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_club_id bigint;
  v_ticket public.tickets;
  v_match public.matches;
  v_event public.ticket_events;
  v_venue public.venues;
  v_organization public.ticket_organizations;
  v_credential public.ticket_wallet_credentials;
begin
  if v_actor is null then
    return jsonb_build_object('status', 'error', 'code', 'auth_required');
  end if;

  begin
    v_club_id := nullif(public.requesting_club_id(), '')::bigint;
  exception
    when invalid_text_representation then
      return jsonb_build_object('status', 'error', 'code', 'club_scope_required');
  end;

  if v_club_id is null or p_ticket_id is null then
    return jsonb_build_object('status', 'error', 'code', 'invalid_request');
  end if;

  select ticket.*
  into v_ticket
  from public.tickets as ticket
  where ticket.id = p_ticket_id
    and ticket.user_id = v_actor
    and ticket.club_id = v_club_id
  for update;

  if not found then
    return jsonb_build_object('status', 'error', 'code', 'ticket_not_found');
  end if;

  if v_ticket.is_mock then
    return jsonb_build_object('status', 'error', 'code', 'mock_ticket_forbidden');
  end if;

  if v_ticket.status <> 'valid' or v_ticket.confirmed_at is null then
    return jsonb_build_object(
      'status',
      'error',
      'code',
      case
        when v_ticket.status = 'pending' then 'payment_pending'
        else 'ticket_not_active'
      end
    );
  end if;

  select match.*
  into v_match
  from public.matches as match
  where match.id = v_ticket.match_id
    and match.club_id = v_club_id;

  if not found then
    return jsonb_build_object('status', 'error', 'code', 'match_not_found');
  end if;

  select event.*
  into v_event
  from public.ticket_events as event
  where event.match_id = v_ticket.match_id
    and event.club_id = v_club_id
    and event.status = 'active'
    and event.google_wallet_enabled
  limit 1;

  if not found then
    return jsonb_build_object('status', 'error', 'code', 'wallet_not_enabled');
  end if;

  if timezone('utc', now()) >= v_event.entry_closes_at then
    return jsonb_build_object('status', 'error', 'code', 'event_expired');
  end if;

  select venue.*
  into v_venue
  from public.venues as venue
  where venue.id = v_event.venue_id
    and venue.club_id = v_club_id;

  if not found then
    return jsonb_build_object('status', 'error', 'code', 'venue_not_found');
  end if;

  select organization.*
  into v_organization
  from public.ticket_organizations as organization
  where organization.id = v_event.organization_id
    and organization.club_id = v_club_id
    and organization.status = 'active';

  if not found or v_organization.google_wallet_issuer_id is null then
    return jsonb_build_object('status', 'error', 'code', 'wallet_not_configured');
  end if;

  select credential.*
  into v_credential
  from public.ticket_wallet_credentials as credential
  where credential.ticket_id = v_ticket.id
    and credential.status = 'active'
  for update;

  if not found then
    insert into public.ticket_wallet_credentials (
      club_id,
      organization_id,
      ticket_event_id,
      ticket_id
    ) values (
      v_club_id,
      v_organization.id,
      v_event.id,
      v_ticket.id
    )
    returning * into v_credential;
  end if;

  return jsonb_build_object(
    'status', 'success',
    'code', 'ready',
    'ticket_id', v_ticket.id,
    'ticket_number', right(replace(v_ticket.id::text, '-', ''), 12),
    'credential_id', v_credential.id,
    'credential_version', v_credential.credential_version,
    'ticket_event_id', v_event.id,
    'organization_id', v_organization.id,
    'organization_name', v_organization.display_name,
    'issuer_id', v_organization.google_wallet_issuer_id,
    'entry_opens_at', v_event.entry_opens_at,
    'entry_closes_at', v_event.entry_closes_at,
    'seat_type', v_ticket.seat_type,
    'match_id', v_match.id,
    'home_team', v_match.home_team,
    'away_team', v_match.away_team,
    'competition', v_match.competition,
    'venue', v_venue.display_name,
    'venue_address', coalesce(v_venue.address_line, v_match.venue),
    'venue_country_code', v_venue.country_code,
    'venue_timezone', v_venue.timezone,
    'match_date', v_match.match_date,
    'kickoff_time', v_match.kickoff_time
  );
end;
$$;

revoke all on function public.prepare_google_wallet_ticket(uuid)
from public, anon, authenticated, service_role;
grant execute on function public.prepare_google_wallet_ticket(uuid)
to authenticated;

create or replace function public.record_google_wallet_ticket_pass(
  p_ticket_id uuid,
  p_credential_id uuid,
  p_class_id text,
  p_object_id text,
  p_wallet_state text default 'ACTIVE'
) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_credential public.ticket_wallet_credentials;
  v_pass_id uuid;
begin
  if p_wallet_state not in ('ACTIVE', 'COMPLETED', 'EXPIRED', 'INACTIVE') then
    raise exception 'Unsupported Google Wallet state.';
  end if;

  if length(btrim(coalesce(p_class_id, ''))) not between 3 and 255
     or length(btrim(coalesce(p_object_id, ''))) not between 3 and 255 then
    raise exception 'Valid Google Wallet class and object identifiers are required.';
  end if;

  select credential.*
  into v_credential
  from public.ticket_wallet_credentials as credential
  where credential.id = p_credential_id
    and credential.ticket_id = p_ticket_id
    and credential.status = 'active'
  for update;

  if not found then
    raise exception 'Active ticket credential was not found.';
  end if;

  insert into public.google_wallet_ticket_passes (
    club_id,
    organization_id,
    ticket_event_id,
    ticket_id,
    credential_id,
    class_id,
    object_id,
    wallet_state,
    last_synced_at,
    last_error_code
  ) values (
    v_credential.club_id,
    v_credential.organization_id,
    v_credential.ticket_event_id,
    v_credential.ticket_id,
    v_credential.id,
    btrim(p_class_id),
    btrim(p_object_id),
    p_wallet_state,
    timezone('utc', now()),
    null
  )
  on conflict (ticket_id) do update
  set credential_id = excluded.credential_id,
      class_id = excluded.class_id,
      object_id = excluded.object_id,
      wallet_state = excluded.wallet_state,
      last_synced_at = excluded.last_synced_at,
      last_error_code = null
  returning id into v_pass_id;

  return v_pass_id;
end;
$$;

revoke all on function public.record_google_wallet_ticket_pass(
  uuid, uuid, text, text, text
) from public, anon, authenticated, service_role;
grant execute on function public.record_google_wallet_ticket_pass(
  uuid, uuid, text, text, text
) to service_role;

create or replace function public.claim_google_wallet_ticket_outbox(
  p_claim_token uuid,
  p_limit integer default 25
) returns table (
  id uuid,
  pass_id uuid,
  object_id text,
  desired_state text,
  attempts integer,
  claim_token uuid
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_now timestamp with time zone := timezone('utc', now());
  v_limit integer := least(greatest(coalesce(p_limit, 25), 1), 50);
begin
  if p_claim_token is null then
    raise exception 'A Wallet outbox claim token is required.';
  end if;

  -- A worker that exhausted its final lease cannot leave a pass blocked
  -- forever. A later invocation moves it to a terminal review queue first.
  update public.google_wallet_ticket_outbox as outbox
  set status = 'dead_letter',
      claim_token = null,
      dead_lettered_at = v_now,
      last_error_code = coalesce(outbox.last_error_code, 'worker_timeout')
  where outbox.status = 'processing'
    and outbox.claimed_at <= v_now - interval '5 minutes'
    and outbox.attempts >= 8;

  return query
  with candidate as (
    select outbox.id
    from public.google_wallet_ticket_outbox as outbox
    where outbox.attempts < 8
      and (
        (
          outbox.status in ('pending', 'failed')
          and outbox.available_at <= v_now
        )
        or (
          outbox.status = 'processing'
          and outbox.claimed_at <= v_now - interval '5 minutes'
        )
      )
      and not exists (
        select 1
        from public.google_wallet_ticket_outbox as active_claim
        where active_claim.pass_id = outbox.pass_id
          and active_claim.id <> outbox.id
          and active_claim.status = 'processing'
          and active_claim.claimed_at > v_now - interval '5 minutes'
      )
      and not exists (
        select 1
        from public.google_wallet_ticket_outbox as earlier
        where earlier.pass_id = outbox.pass_id
          and earlier.id <> outbox.id
          and earlier.status in ('pending', 'failed', 'processing')
          and (
            earlier.created_at < outbox.created_at
            or (
              earlier.created_at = outbox.created_at
              and earlier.id < outbox.id
            )
          )
      )
    order by outbox.available_at, outbox.created_at, outbox.id
    for update of outbox skip locked
    limit v_limit
  ), claimed as (
    update public.google_wallet_ticket_outbox as outbox
    set status = 'processing',
        claim_token = p_claim_token,
        claimed_at = v_now,
        completed_at = null,
        dead_lettered_at = null,
        attempts = outbox.attempts + 1
    from candidate
    where outbox.id = candidate.id
    returning
      outbox.id,
      outbox.pass_id,
      outbox.desired_state,
      outbox.attempts,
      outbox.claim_token
  )
  select
    claimed.id,
    claimed.pass_id,
    wallet_pass.object_id,
    claimed.desired_state,
    claimed.attempts,
    claimed.claim_token
  from claimed
  join public.google_wallet_ticket_passes as wallet_pass
    on wallet_pass.id = claimed.pass_id
  order by claimed.id;
end;
$$;

revoke all on function public.claim_google_wallet_ticket_outbox(uuid, integer)
from public, anon, authenticated, service_role;
grant execute on function public.claim_google_wallet_ticket_outbox(uuid, integer)
to service_role;

create or replace function public.complete_google_wallet_ticket_outbox(
  p_outbox_id uuid,
  p_claim_token uuid,
  p_succeeded boolean,
  p_error_code text default null
) returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_now timestamp with time zone := timezone('utc', now());
  v_outbox public.google_wallet_ticket_outbox;
  v_error_code text := lower(btrim(coalesce(p_error_code, 'google_wallet_unknown')));
  v_next_status text;
  v_backoff_seconds integer;
begin
  if p_outbox_id is null or p_claim_token is null or p_succeeded is null then
    raise exception 'Wallet outbox completion parameters are required.';
  end if;

  if v_error_code !~ '^[a-z0-9_]{3,80}$' then
    v_error_code := 'google_wallet_unknown';
  end if;

  select outbox.*
  into v_outbox
  from public.google_wallet_ticket_outbox as outbox
  where outbox.id = p_outbox_id
    and outbox.status = 'processing'
    and outbox.claim_token = p_claim_token
  for update;

  if not found then
    raise exception 'Wallet outbox claim is no longer active.';
  end if;

  if p_succeeded then
    update public.google_wallet_ticket_outbox as outbox
    set status = 'completed',
        claim_token = null,
        completed_at = v_now,
        dead_lettered_at = null,
        last_error_code = null
    where outbox.id = v_outbox.id;

    update public.google_wallet_ticket_passes as wallet_pass
    set wallet_state = v_outbox.desired_state,
        last_synced_at = v_now,
        last_error_code = null
    where wallet_pass.id = v_outbox.pass_id;

    return 'completed';
  end if;

  if v_outbox.attempts >= 8 then
    v_next_status := 'dead_letter';
    update public.google_wallet_ticket_outbox as outbox
    set status = v_next_status,
        claim_token = null,
        dead_lettered_at = v_now,
        last_error_code = v_error_code
    where outbox.id = v_outbox.id;
  else
    v_next_status := 'failed';
    v_backoff_seconds := least(
      900,
      (15 * power(2, greatest(v_outbox.attempts - 1, 0)))::integer
    );
    update public.google_wallet_ticket_outbox as outbox
    set status = v_next_status,
        claim_token = null,
        available_at = v_now + make_interval(secs => v_backoff_seconds),
        last_error_code = v_error_code
    where outbox.id = v_outbox.id;
  end if;

  update public.google_wallet_ticket_passes as wallet_pass
  set last_error_code = v_error_code
  where wallet_pass.id = v_outbox.pass_id;

  return v_next_status;
end;
$$;

revoke all on function public.complete_google_wallet_ticket_outbox(
  uuid, uuid, boolean, text
) from public, anon, authenticated, service_role;
grant execute on function public.complete_google_wallet_ticket_outbox(
  uuid, uuid, boolean, text
) to service_role;

create or replace function public.redeem_ticket_for_verifier(
  p_actor_id uuid,
  p_credential_id uuid,
  p_credential_version integer,
  p_operation_id uuid,
  p_gate_code text default null
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_now timestamp with time zone := timezone('utc', now());
  v_gate_code text := nullif(upper(btrim(coalesce(p_gate_code, ''))), '');
  v_credential public.ticket_wallet_credentials;
  v_ticket public.tickets;
  v_event public.ticket_events;
  v_assignment public.ticket_verifier_assignments;
  v_existing public.ticket_redemption_events;
  v_first_admission public.ticket_redemption_events;
  v_decision text;
  v_result jsonb;
begin
  if p_actor_id is null
     or p_credential_id is null
     or p_credential_version is null
     or p_credential_version < 1
     or p_operation_id is null then
    raise exception 'Verifier, credential, version, and operation id are required.';
  end if;

  if v_gate_code is not null
     and v_gate_code !~ '^[A-Z0-9][A-Z0-9_-]{0,31}$' then
    raise exception 'Gate code is invalid.';
  end if;

  select redemption.*
  into v_existing
  from public.ticket_redemption_events as redemption
  where redemption.verifier_user_id = p_actor_id
    and redemption.operation_id = p_operation_id;

  if found then
    return v_existing.result || jsonb_build_object('replayed', true);
  end if;

  select credential.*
  into v_credential
  from public.ticket_wallet_credentials as credential
  where credential.id = p_credential_id
  for update;

  if not found then
    return jsonb_build_object(
      'status', 'rejected',
      'code', 'credential_invalid',
      'replayed', false
    );
  end if;

  select ticket.*
  into v_ticket
  from public.tickets as ticket
  where ticket.id = v_credential.ticket_id
  for update;

  select event.*
  into v_event
  from public.ticket_events as event
  where event.id = v_credential.ticket_event_id;

  select assignment.*
  into v_assignment
  from public.ticket_verifier_assignments as assignment
  where assignment.user_id = p_actor_id
    and assignment.ticket_event_id = v_credential.ticket_event_id
    and assignment.organization_id = v_credential.organization_id
    and assignment.club_id = v_credential.club_id
    and assignment.venue_id = v_event.venue_id
    and assignment.is_active
    and assignment.starts_at <= v_now
    and assignment.ends_at > v_now
    and (
      assignment.gate_code is null
      or assignment.gate_code = v_gate_code
    )
  order by
    case when assignment.gate_code = v_gate_code then 0 else 1 end,
    assignment.granted_at,
    assignment.id
  limit 1
  for update;

  if v_assignment.id is null then
    if exists (
      select 1
      from public.ticket_verifier_assignments as assignment
      where assignment.user_id = p_actor_id
        and assignment.ticket_event_id = v_credential.ticket_event_id
        and assignment.organization_id = v_credential.organization_id
        and assignment.club_id = v_credential.club_id
        and assignment.venue_id = v_event.venue_id
        and assignment.is_active
        and assignment.starts_at <= v_now
        and assignment.ends_at > v_now
    ) then
      v_decision := 'wrong_gate';
    else
      v_decision := 'permission_denied';
    end if;
  elsif v_credential.status <> 'active'
        or v_credential.credential_version <> p_credential_version then
    v_decision := 'credential_inactive';
  elsif v_event.status <> 'active' or not v_event.verification_enabled then
    v_decision := 'permission_denied';
  elsif v_now < v_event.entry_opens_at then
    v_decision := 'outside_window';
  elsif v_now >= v_event.entry_closes_at then
    v_decision := 'expired';
  elsif v_ticket.status = 'valid' and v_ticket.confirmed_at is not null then
    v_decision := 'admitted';
  elsif v_ticket.status = 'used' then
    v_decision := 'already_used';
  elsif v_ticket.status = 'pending' then
    v_decision := 'pending_payment';
  elsif v_ticket.status in ('cancelled', 'refunded', 'voided') then
    v_decision := v_ticket.status;
  else
    v_decision := 'permission_denied';
  end if;

  if v_decision = 'already_used' then
    select redemption.*
    into v_first_admission
    from public.ticket_redemption_events as redemption
    where redemption.ticket_id = v_ticket.id
      and redemption.decision = 'admitted'
    order by redemption.scanned_at, redemption.id
    limit 1;
  end if;

  if v_decision = 'admitted' then
    update public.tickets as ticket
    set status = 'used'
    where ticket.id = v_ticket.id
      and ticket.status = 'valid';

    if not found then
      v_decision := 'already_used';
      select redemption.*
      into v_first_admission
      from public.ticket_redemption_events as redemption
      where redemption.ticket_id = v_ticket.id
        and redemption.decision = 'admitted'
      order by redemption.scanned_at, redemption.id
      limit 1;
    end if;
  end if;

  if v_decision = 'permission_denied' then
    -- Do not disclose ticket details to an authenticated account that has no
    -- live assignment for this event. The internal audit row retains scope.
    v_result := jsonb_build_object(
      'status', 'rejected',
      'code', v_decision,
      'scanned_at', v_now,
      'replayed', false
    );
  else
    v_result := jsonb_build_object(
      'status', case when v_decision = 'admitted' then 'admitted' else 'rejected' end,
      'code', v_decision,
      'ticket_id', v_ticket.id,
      'ticket_number', right(replace(v_ticket.id::text, '-', ''), 12),
      'seat_type', v_ticket.seat_type,
      'ticket_event_id', v_event.id,
      'organization_id', v_credential.organization_id,
      'venue_id', v_event.venue_id,
      'gate_code', v_gate_code,
      'scanned_at', v_now,
      'first_admitted_at', v_first_admission.scanned_at,
      'replayed', false
    );
  end if;

  insert into public.ticket_redemption_events (
    club_id,
    organization_id,
    ticket_event_id,
    venue_id,
    ticket_id,
    credential_id,
    verifier_assignment_id,
    verifier_user_id,
    operation_id,
    gate_code,
    decision,
    result,
    scanned_at
  ) values (
    v_credential.club_id,
    v_credential.organization_id,
    v_credential.ticket_event_id,
    v_event.venue_id,
    v_ticket.id,
    v_credential.id,
    v_assignment.id,
    p_actor_id,
    p_operation_id,
    v_gate_code,
    v_decision,
    v_result,
    v_now
  );

  return v_result;
end;
$$;

revoke all on function public.redeem_ticket_for_verifier(
  uuid, uuid, integer, uuid, text
) from public, anon, authenticated, service_role;
grant execute on function public.redeem_ticket_for_verifier(
  uuid, uuid, integer, uuid, text
) to service_role;

create or replace function public.queue_google_wallet_ticket_state()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_pass public.google_wallet_ticket_passes;
  v_desired_state text;
begin
  if new.status is not distinct from old.status then
    return new;
  end if;

  v_desired_state := case new.status
    when 'valid' then 'ACTIVE'
    when 'used' then 'COMPLETED'
    when 'cancelled' then 'INACTIVE'
    when 'refunded' then 'INACTIVE'
    when 'voided' then 'INACTIVE'
    else null
  end;

  if v_desired_state is null then
    return new;
  end if;

  select pass.*
  into v_pass
  from public.google_wallet_ticket_passes as pass
  where pass.ticket_id = new.id
  for update;

  if not found then
    return new;
  end if;

  update public.google_wallet_ticket_passes as pass
  set wallet_state = v_desired_state
  where pass.id = v_pass.id;

  insert into public.google_wallet_ticket_outbox (
    club_id,
    pass_id,
    ticket_id,
    desired_state,
    operation_key
  ) values (
    new.club_id,
    v_pass.id,
    new.id,
    v_desired_state,
    'ticket-state:' || new.id::text || ':' || v_desired_state || ':' || new.updated_at::text
  )
  on conflict (operation_key) do nothing;

  return new;
end;
$$;

create trigger tickets_queue_google_wallet_state
after update of status on public.tickets
for each row execute function public.queue_google_wallet_ticket_state();

revoke all on function public.queue_google_wallet_ticket_state()
from public, anon, authenticated, service_role;

-- Register the optional mobile capability fail-closed. A club administrator
-- must enable and expose the scoped feature only after Wallet issuer approval,
-- service-account secrets, event configuration, and verifier UAT are complete.
insert into public.platform_features (
  feature_key,
  display_name,
  description,
  category,
  club_id,
  is_enabled,
  visibility_state
) values (
  'google_wallet_tickets',
  'Google Wallet tickets',
  'Issue confirmed event tickets to Google Wallet with rotating admission codes.',
  'commerce',
  null,
  false,
  'hidden'
)
on conflict (feature_key) where club_id is null do nothing;

insert into public.platform_feature_channels (
  feature_id,
  channel,
  is_enabled,
  is_visible,
  show_in_navigation,
  show_on_home,
  sort_order,
  route_key,
  placement_key
)
select
  feature.id,
  'mobile',
  false,
  false,
  false,
  false,
  75,
  '/tickets',
  null
from public.platform_features as feature
where feature.feature_key = 'google_wallet_tickets'
  and feature.club_id is null
on conflict (feature_id, channel) do nothing;

insert into public.platform_feature_rules (
  feature_id,
  auth_required,
  role_restrictions,
  dependency_rules,
  rollout_rules,
  metadata
)
select
  feature.id,
  true,
  '[]'::jsonb,
  '{"requires":["ticketing"]}'::jsonb,
  '{"release_gate":"wallet_issuer_and_venue_uat"}'::jsonb,
  '{"owner":"ticketing"}'::jsonb
from public.platform_features as feature
where feature.feature_key = 'google_wallet_tickets'
  and feature.club_id is null
on conflict (feature_id) do nothing;

-- Dispatch state changes through the same Vault-backed cron boundary used by
-- the other governed scheduled functions. The worker itself authenticates the
-- secret and claims each pass queue in FIFO order.
do $govern_google_wallet_cron$
declare
  v_job record;
begin
  for v_job in
    select jobid
    from cron.job
    where jobname = 'sync-google-wallet-ticket-state'
  loop
    perform cron.unschedule(v_job.jobid);
  end loop;
end
$govern_google_wallet_cron$;

select cron.schedule(
  'sync-google-wallet-ticket-state',
  '* * * * *',
  $job$
    select net.http_post(
      url := 'https://mmpbzcdhfvplxplnfucy.supabase.co/functions/v1/sync-google-wallet-ticket-state',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-cron-secret', (
          select decrypted_secret
          from vault.decrypted_secrets
          where name = 'africlub_cron_job_secret'
          limit 1
        )
      ),
      body := '{"limit":25}'::jsonb
    ) as request_id;
  $job$
);

comment on table public.ticket_organizations is
  'Governed ticket issuer/operator scope. Google issuer identifiers are configuration, never credentials.';
comment on table public.ticket_verifier_assignments is
  'Selected verifier authority bounded by organization, event, venue, gate, and shift.';
comment on table public.ticket_wallet_credentials is
  'Opaque rotating-barcode identifiers and versions. TOTP master material remains in Edge Function secrets.';
comment on table public.ticket_redemption_events is
  'Immutable admission decisions, including rejected and replayed scans.';
comment on function public.redeem_ticket_for_verifier(uuid, uuid, integer, uuid, text) is
  'Service-only atomic redemption after the verifier Edge Function authenticates the caller and validates the rotating TOTP payload.';

commit;
