begin;

-- Auth metadata used for display preferences is user-controlled. Only
-- server-controlled app_metadata may preselect a tenant during the Auth
-- trigger; otherwise the row remains unscoped until the one-time bootstrap
-- RPC validates an active deployment club.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_candidate_club_id bigint;
  v_club_id bigint;
  v_country_code text;
  v_display_name text;
  v_language_code text;
begin
  v_candidate_club_id := public.normalize_club_id(
    nullif(new.raw_app_meta_data ->> 'club_id', '')
  );

  select club.id
    into v_club_id
    from public.african_football_clubs as club
   where club.id = v_candidate_club_id
     and club.is_active
   limit 1;

  v_country_code := coalesce(
    nullif(pg_catalog.upper(new.raw_user_meta_data ->> 'country_code'), ''),
    nullif(pg_catalog.upper(new.raw_user_meta_data ->> 'country'), ''),
    'RW'
  );
  v_display_name := coalesce(
    nullif(pg_catalog.btrim(new.raw_user_meta_data ->> 'display_name'), ''),
    nullif(pg_catalog.btrim(new.raw_user_meta_data ->> 'full_name'), '')
  );
  v_language_code := coalesce(
    nullif(pg_catalog.lower(new.raw_user_meta_data ->> 'language_code'), ''),
    'rw'
  );

  insert into public.profiles (
    id,
    club_id,
    display_name,
    full_name,
    country_code,
    country,
    language_code,
    is_active
  ) values (
    new.id,
    v_club_id,
    v_display_name,
    v_display_name,
    v_country_code,
    v_country_code,
    v_language_code,
    true
  )
  on conflict (id) do nothing;

  insert into public.user_privacy_settings (user_id, club_id)
  values (new.id, v_club_id)
  on conflict (user_id) do nothing;

  insert into public.user_notification_settings (user_id, club_id)
  values (new.id, v_club_id)
  on conflict (user_id) do nothing;

  return new;
end;
$$;

revoke execute on function public.handle_new_user()
  from public, anon, authenticated, service_role;

create or replace function public.bootstrap_supporter_profile(
  p_club_id bigint,
  p_display_name text default null,
  p_country_code text default 'RW',
  p_language_code text default 'rw',
  p_avatar_url text default null
) returns public.profiles
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := auth.uid();
  v_existing public.profiles;
  v_profile public.profiles;
  v_display_name text := nullif(pg_catalog.btrim(coalesce(p_display_name, '')), '');
  v_country_code text := pg_catalog.upper(
    coalesce(nullif(pg_catalog.btrim(p_country_code), ''), 'RW')
  );
  v_language_code text := pg_catalog.lower(
    coalesce(nullif(pg_catalog.btrim(p_language_code), ''), 'rw')
  );
  v_avatar_url text := nullif(pg_catalog.btrim(coalesce(p_avatar_url, '')), '');
begin
  if v_actor_id is null then
    raise exception 'Authentication is required.';
  end if;

  if p_club_id is null or not exists (
    select 1
      from public.african_football_clubs as club
     where club.id = p_club_id
       and club.is_active
  ) then
    raise exception 'An active deployment club is required.';
  end if;

  if pg_catalog.length(coalesce(v_display_name, '')) > 80 then
    raise exception 'Display name must be 80 characters or fewer.';
  end if;

  if v_country_code !~ '^[A-Z]{2}$' then
    raise exception 'Country code must be a two-letter ISO code.';
  end if;

  if v_language_code not in ('rw', 'en', 'fr') then
    raise exception 'Unsupported profile language.';
  end if;

  if pg_catalog.length(coalesce(v_avatar_url, '')) > 2048 then
    raise exception 'Avatar URL is too long.';
  end if;

  select profile.*
    into v_existing
    from public.profiles as profile
   where profile.id = v_actor_id
   for update;

  if v_existing.id is not null
     and v_existing.club_id is not null
     and v_existing.club_id is distinct from p_club_id then
    raise exception 'The supporter profile is already bound to another club.';
  end if;

  insert into public.profiles (
    id,
    club_id,
    display_name,
    full_name,
    country_code,
    country,
    language_code,
    avatar_url,
    is_active
  ) values (
    v_actor_id,
    p_club_id,
    v_display_name,
    v_display_name,
    v_country_code,
    v_country_code,
    v_language_code,
    v_avatar_url,
    true
  )
  on conflict (id) do update set
    club_id = coalesce(public.profiles.club_id, excluded.club_id),
    display_name = coalesce(excluded.display_name, public.profiles.display_name),
    full_name = coalesce(excluded.full_name, public.profiles.full_name),
    country_code = excluded.country_code,
    country = excluded.country,
    language_code = excluded.language_code,
    avatar_url = coalesce(excluded.avatar_url, public.profiles.avatar_url),
    updated_at = pg_catalog.timezone('utc', pg_catalog.now())
  returning * into v_profile;

  insert into public.user_privacy_settings (user_id, club_id)
  values (v_actor_id, p_club_id)
  on conflict (user_id) do update set
    club_id = excluded.club_id
  where public.user_privacy_settings.club_id is null
     or public.user_privacy_settings.club_id = excluded.club_id;

  insert into public.user_notification_settings (user_id, club_id)
  values (v_actor_id, p_club_id)
  on conflict (user_id) do update set
    club_id = excluded.club_id
  where public.user_notification_settings.club_id is null
     or public.user_notification_settings.club_id = excluded.club_id;

  return v_profile;
end;
$$;

revoke execute on function public.bootstrap_supporter_profile(
  bigint,
  text,
  text,
  text,
  text
) from public, anon, authenticated, service_role;
grant execute on function public.bootstrap_supporter_profile(
  bigint,
  text,
  text,
  text,
  text
) to authenticated;

-- The base profile is an own-row account record, not a same-club directory.
-- Public aliases used by leaderboards are projected separately.
revoke all privileges on table public.profiles
from public, anon, authenticated, service_role;

grant select (
  id,
  club_id,
  full_name,
  public_user_id,
  country,
  language_code,
  avatar_url,
  is_admin,
  theme_preference,
  created_at,
  updated_at,
  display_name,
  country_code,
  is_active,
  favorite_team_slug,
  privacy_show_real_name,
  privacy_findable_by_phone
) on table public.profiles to authenticated;

grant update (
  full_name,
  country,
  language_code,
  avatar_url,
  theme_preference,
  display_name,
  country_code,
  favorite_team_slug,
  privacy_show_real_name,
  privacy_findable_by_phone
) on table public.profiles to authenticated;

grant all privileges on table public.profiles to service_role;

drop policy if exists profiles_insert_own on public.profiles;
drop policy if exists profiles_select_own on public.profiles;
drop policy if exists profiles_select_same_club on public.profiles;
drop policy if exists profiles_update_own on public.profiles;

create policy profiles_select_own
on public.profiles
for select
to authenticated
using ((select auth.uid()) = id);

create policy profiles_update_own
on public.profiles
for update
to authenticated
using ((select auth.uid()) = id)
with check (
  (select auth.uid()) = id
  and club_id is not distinct from
    nullif(public.requesting_club_id(), '')::bigint
);

-- Every private/settings row derives and freezes its user and tenant keys.
create or replace function public.enforce_owned_user_club_scope()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_actor_id uuid := auth.uid();
  v_trusted_club_id bigint;
begin
  if current_user in ('postgres', 'service_role', 'supabase_admin') then
    return new;
  end if;

  if v_actor_id is null or new.user_id is distinct from v_actor_id then
    raise exception 'The row must belong to the authenticated user.';
  end if;

  begin
    v_trusted_club_id := nullif(public.requesting_club_id(), '')::bigint;
  exception
    when invalid_text_representation then
      raise exception 'A valid trusted club context is required.';
  end;

  if v_trusted_club_id is null then
    raise exception 'A trusted club context is required.';
  end if;

  if tg_op = 'UPDATE' then
    if new.user_id is distinct from old.user_id
       or new.club_id is distinct from old.club_id then
      raise exception 'User and club scope cannot be changed.';
    end if;
  elsif new.club_id is not null
        and new.club_id is distinct from v_trusted_club_id then
    raise exception 'Requested club does not match the authenticated club context.';
  end if;

  new.club_id := v_trusted_club_id;
  return new;
end;
$$;

revoke execute on function public.enforce_owned_user_club_scope()
from public, anon, authenticated, service_role;

drop trigger if exists enforce_user_notification_settings_scope
  on public.user_notification_settings;
create trigger enforce_user_notification_settings_scope
before insert or update on public.user_notification_settings
for each row execute function public.enforce_owned_user_club_scope();

drop trigger if exists enforce_user_privacy_settings_scope
  on public.user_privacy_settings;
create trigger enforce_user_privacy_settings_scope
before insert or update on public.user_privacy_settings
for each row execute function public.enforce_owned_user_club_scope();

drop trigger if exists enforce_user_fcm_tokens_scope
  on public.user_fcm_tokens;
create trigger enforce_user_fcm_tokens_scope
before insert or update on public.user_fcm_tokens
for each row execute function public.enforce_owned_user_club_scope();

drop trigger if exists enforce_user_private_contacts_scope
  on public.user_private_contacts;
create trigger enforce_user_private_contacts_scope
before insert or update on public.user_private_contacts
for each row execute function public.enforce_owned_user_club_scope();

revoke all privileges on table public.user_notification_settings
from public, anon, authenticated, service_role;
grant select, insert, update on table public.user_notification_settings
to authenticated;
grant all privileges on table public.user_notification_settings to service_role;

drop policy if exists user_notification_settings_insert_own on public.user_notification_settings;
drop policy if exists user_notification_settings_select_own on public.user_notification_settings;
drop policy if exists user_notification_settings_update_own on public.user_notification_settings;
create policy user_notification_settings_select_own
on public.user_notification_settings for select to authenticated
using (
  user_id = (select auth.uid())
  and club_id::text = public.requesting_club_id()
);
create policy user_notification_settings_insert_own
on public.user_notification_settings for insert to authenticated
with check (
  user_id = (select auth.uid())
  and club_id::text = public.requesting_club_id()
);
create policy user_notification_settings_update_own
on public.user_notification_settings for update to authenticated
using (
  user_id = (select auth.uid())
  and club_id::text = public.requesting_club_id()
)
with check (
  user_id = (select auth.uid())
  and club_id::text = public.requesting_club_id()
);

revoke all privileges on table public.user_privacy_settings
from public, anon, authenticated, service_role;
grant select, insert, update on table public.user_privacy_settings
to authenticated;
grant all privileges on table public.user_privacy_settings to service_role;

drop policy if exists user_privacy_settings_insert_own on public.user_privacy_settings;
drop policy if exists user_privacy_settings_select_own on public.user_privacy_settings;
drop policy if exists user_privacy_settings_update_own on public.user_privacy_settings;
create policy user_privacy_settings_select_own
on public.user_privacy_settings for select to authenticated
using (
  user_id = (select auth.uid())
  and club_id::text = public.requesting_club_id()
);
create policy user_privacy_settings_insert_own
on public.user_privacy_settings for insert to authenticated
with check (
  user_id = (select auth.uid())
  and club_id::text = public.requesting_club_id()
);
create policy user_privacy_settings_update_own
on public.user_privacy_settings for update to authenticated
using (
  user_id = (select auth.uid())
  and club_id::text = public.requesting_club_id()
)
with check (
  user_id = (select auth.uid())
  and club_id::text = public.requesting_club_id()
);

revoke all privileges on table public.user_private_contacts
from public, anon, authenticated, service_role;
grant select, insert, update on table public.user_private_contacts
to authenticated;
grant all privileges on table public.user_private_contacts to service_role;

drop policy if exists user_private_contacts_insert_own on public.user_private_contacts;
drop policy if exists user_private_contacts_select_own on public.user_private_contacts;
drop policy if exists user_private_contacts_update_own on public.user_private_contacts;
create policy user_private_contacts_select_own
on public.user_private_contacts for select to authenticated
using (
  user_id = (select auth.uid())
  and club_id::text = public.requesting_club_id()
);
create policy user_private_contacts_insert_own
on public.user_private_contacts for insert to authenticated
with check (
  user_id = (select auth.uid())
  and club_id::text = public.requesting_club_id()
);
create policy user_private_contacts_update_own
on public.user_private_contacts for update to authenticated
using (
  user_id = (select auth.uid())
  and club_id::text = public.requesting_club_id()
)
with check (
  user_id = (select auth.uid())
  and club_id::text = public.requesting_club_id()
);

revoke all privileges on table public.user_fcm_tokens
from public, anon, authenticated, service_role;
grant select, insert, update, delete on table public.user_fcm_tokens
to authenticated;
grant all privileges on table public.user_fcm_tokens to service_role;

drop policy if exists "Service role reads all FCM tokens" on public.user_fcm_tokens;
drop policy if exists "Users manage own FCM tokens" on public.user_fcm_tokens;
drop policy if exists user_fcm_tokens_delete_own on public.user_fcm_tokens;
drop policy if exists user_fcm_tokens_insert_own on public.user_fcm_tokens;
drop policy if exists user_fcm_tokens_select_own on public.user_fcm_tokens;
drop policy if exists user_fcm_tokens_update_own on public.user_fcm_tokens;
create policy user_fcm_tokens_select_own
on public.user_fcm_tokens for select to authenticated
using (
  user_id = (select auth.uid())
  and club_id::text = public.requesting_club_id()
);
create policy user_fcm_tokens_insert_own
on public.user_fcm_tokens for insert to authenticated
with check (
  user_id = (select auth.uid())
  and club_id::text = public.requesting_club_id()
);
create policy user_fcm_tokens_update_own
on public.user_fcm_tokens for update to authenticated
using (
  user_id = (select auth.uid())
  and club_id::text = public.requesting_club_id()
)
with check (
  user_id = (select auth.uid())
  and club_id::text = public.requesting_club_id()
);
create policy user_fcm_tokens_delete_own
on public.user_fcm_tokens for delete to authenticated
using (
  user_id = (select auth.uid())
  and club_id::text = public.requesting_club_id()
);

commit;
