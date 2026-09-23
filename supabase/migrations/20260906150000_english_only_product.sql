-- English is the sole product language. Retain country and identity values.
-- Old clients may send a historical preference; normalize it at the write boundary.
begin;

CREATE OR REPLACE FUNCTION "public"."bootstrap_supporter_profile"("p_club_id" bigint, "p_display_name" "text" DEFAULT NULL::"text", "p_country_code" "text" DEFAULT 'RW'::"text", "p_language_code" "text" DEFAULT 'en'::"text", "p_avatar_url" "text" DEFAULT NULL::"text") RETURNS "public"."profiles"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $_$
declare
  v_actor_id uuid := auth.uid();
  v_existing public.profiles;
  v_profile public.profiles;
  v_display_name text := nullif(pg_catalog.btrim(coalesce(p_display_name, '')), '');
  v_country_code text := pg_catalog.upper(
    coalesce(nullif(pg_catalog.btrim(p_country_code), ''), 'RW')
  );
  v_language_code text := 'en';
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
$_$;

create or replace function public.enforce_english_profile_language()
returns trigger language plpgsql set search_path = '' as $$
begin
  new.language_code := 'en';
  return new;
end;
$$;
revoke all on function public.enforce_english_profile_language() from public;
create trigger english_profile_language before insert or update on public.profiles
for each row execute function public.enforce_english_profile_language();
update public.profiles set language_code = 'en' where language_code is distinct from 'en';
alter table public.profiles alter column language_code set default 'en';
alter table public.profiles add constraint profiles_language_english_only check (language_code = 'en');

create or replace function public.enforce_english_club_language()
returns trigger language plpgsql set search_path = '' as $$
begin
  new.default_language := 'en';
  new.supported_languages := array['en'];
  return new;
end;
$$;
revoke all on function public.enforce_english_club_language() from public;
create trigger english_club_language before insert or update on public.african_football_clubs
for each row execute function public.enforce_english_club_language();
update public.african_football_clubs set default_language = 'en', supported_languages = array['en'];
alter table public.african_football_clubs add constraint club_language_english_only
  check (default_language = 'en' and supported_languages = array['en']);
-- Remove retired runtime translations instead of relabelling their text as English.
delete from public.runtime_copy where locale <> 'en';
alter table public.runtime_copy add constraint runtime_copy_english_only check (locale = 'en');
commit;
