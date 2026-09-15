-- Restore the verified Auth -> supporter-profile -> application-user bridge.
-- Only a server-confirmed Auth phone supplies the private operational identity.
begin;
create function public.sync_verified_supporter_user(p_user_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_auth auth.users;
  v_profile public.profiles;
begin
  -- Profile edits and verified-phone changes must read Auth only after
  -- serializing this identity; a stale read must not overwrite a new phone.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('africlub.verified-supporter:' || p_user_id::text, 0));
  select * into v_auth from auth.users where id = p_user_id;
  if not found or v_auth.phone_confirmed_at is null
     or coalesce(v_auth.is_anonymous, false)
     or nullif(pg_catalog.btrim(v_auth.phone), '') is null then
    return;
  end if;
  select * into v_profile from public.profiles where id = p_user_id;
  if not found then return; end if;

  -- Keep the existing operational-country default and all administrative,
  -- identity-verification and payment-routing fields under their own controls.
  insert into public.users(id, phone, full_name, public_user_id)
  values (p_user_id, v_auth.phone,
    coalesce(nullif(v_profile.display_name, ''), v_profile.full_name, ''),
    coalesce(v_profile.public_user_id, public.next_public_user_id()))
  on conflict (id) do update set
    phone = excluded.phone,
    full_name = coalesce(nullif(excluded.full_name, ''), public.users.full_name),
    updated_at = pg_catalog.timezone('utc', pg_catalog.now())
  where public.users.phone is distinct from excluded.phone
     or (nullif(excluded.full_name, '') is not null
         and public.users.full_name is distinct from excluded.full_name);
end;
$$;
revoke all on function public.sync_verified_supporter_user(uuid)
  from public, anon, authenticated, service_role;

create function public.sync_verified_supporter_user_from_auth() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  perform public.sync_verified_supporter_user(new.id);
  return new;
end;
$$;
revoke all on function public.sync_verified_supporter_user_from_auth()
  from public, anon, authenticated, service_role;
create trigger sync_verified_supporter_user_auth
  after insert or update of phone, phone_confirmed_at, is_anonymous on auth.users
  for each row execute function public.sync_verified_supporter_user_from_auth();

create function public.sync_verified_supporter_user_from_profile() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  perform public.sync_verified_supporter_user(new.id);
  return new;
end;
$$;
revoke all on function public.sync_verified_supporter_user_from_profile()
  from public, anon, authenticated, service_role;
create trigger sync_verified_supporter_user_profile
  after insert or update of display_name, full_name on public.profiles
  for each row execute function public.sync_verified_supporter_user_from_profile();

-- Existing verified profiles need the same idempotent bridge. Conflicting
-- identities fail the transaction; never reassign a different user's record.
do $$ declare v_id uuid; begin
  for v_id in select p.id from public.profiles p join auth.users a on a.id=p.id
    where a.phone_confirmed_at is not null and not coalesce(a.is_anonymous,false)
      and nullif(pg_catalog.btrim(a.phone),'') is not null
  loop perform public.sync_verified_supporter_user(v_id); end loop;
end $$;
commit;
