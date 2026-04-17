-- Align public.notifications with the admin notification delivery pipeline.
-- The legacy table shape still required match-bound notifications and only
-- allowed draft/sent/failed states, which breaks scheduled admin broadcasts.

alter table public.notifications
  add column if not exists audience_group_id uuid;

alter table public.notifications
  alter column match_id drop not null;

do $$
begin
  if exists (
    select 1
    from pg_constraint
    where conrelid = 'public.notifications'::regclass
      and conname = 'rs_notifications_status_check'
  ) then
    alter table public.notifications
      drop constraint rs_notifications_status_check;
  end if;
end
$$;

alter table public.notifications
  add constraint rs_notifications_status_check
  check (
    status = any (
      array[
        'draft',
        'scheduled',
        'processing',
        'sent',
        'partial',
        'failed'
      ]::text[]
    )
  );

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.notifications'::regclass
      and conname = 'notifications_audience_group_id_fkey'
  ) then
    alter table public.notifications
      add constraint notifications_audience_group_id_fkey
      foreign key (audience_group_id)
      references public.groups(id)
      on delete set null;
  end if;
end
$$;
