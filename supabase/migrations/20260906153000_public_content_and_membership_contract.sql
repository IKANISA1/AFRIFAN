-- Forward-only candidate. Publishing data and qualifying funds remain explicit
-- club decisions. No website identifier is assumed to be a native record ID.
begin;

alter table public.fan_clubs add column is_featured boolean not null default false;
grant select(is_featured) on public.fan_clubs to anon, authenticated;

alter table public.squad_players add column squad_group text not null default 'first_team' check(squad_group in ('first_team','women','academy','staff'));
grant select(squad_group) on public.squad_players to anon, authenticated;

alter table public.news_articles add column if not exists source_url text;
alter table public.news_articles add constraint news_articles_source_https
  check (source_url is null or source_url ~ '^https://[^/@[:space:]]+/.+');
grant select(source_url) on public.news_articles to anon, authenticated;

create table public.club_public_links (
  club_id bigint not null references public.african_football_clubs(id),
  source_path text not null,
  native_path text not null,
  revision bigint not null default 1 check (revision > 0),
  published_at timestamptz,
  primary key (club_id, source_path),
  check (source_path ~ '^/(squad/(player|staff)|news|shop/product|fanclubs|tickets/match|partners)/[a-zA-Z0-9_-]+$'),
  check (native_path ~ '^/(club/(team|news|fixtures|partners)|shop/product|fan-clubs|tickets/detail)/[a-zA-Z0-9_-]+$')
);
alter table public.club_public_links enable row level security;
revoke all on public.club_public_links from anon, authenticated;
grant all on public.club_public_links to service_role;

create table public.club_partner_publications (
  id uuid primary key default gen_random_uuid(),
  club_id bigint not null references public.african_football_clubs(id),
  name text not null,
  category text not null default 'Club partner',
  description text not null default '',
  logo_url text,
  image_rights_approved boolean not null default false,
  image_provenance_id text,
  website_url text,
  sort_order integer not null default 0,
  published_at timestamptz,
  expires_at timestamptz,
  updated_at timestamptz not null default now(),
  check (website_url is null or website_url ~ '^https://[^/@[:space:]]+'),
  check (logo_url is null or (logo_url ~ '^https://' and image_rights_approved and nullif(image_provenance_id,'') is not null))
);
alter table public.club_partner_publications enable row level security;
create policy club_partners_public_read on public.club_partner_publications
  for select to anon, authenticated using (published_at <= now() and (expires_at is null or expires_at > now()));
revoke all on public.club_partner_publications from anon, authenticated;
grant select on public.club_partner_publications to anon, authenticated;
grant all on public.club_partner_publications to service_role;

create function public.resolve_club_public_link_v1(p_club_id bigint, p_source_path text)
returns text language plpgsql stable security definer set search_path = '' as $$
declare v_path text; v_id uuid; v_kind text;
begin
  select native_path into v_path from public.club_public_links
    where club_id=p_club_id and source_path=p_source_path and published_at<=now();
  if v_path is null then return null; end if;
  begin v_id := split_part(v_path,'/',case when v_path like '/fan-clubs/%' then 3 else 4 end)::uuid;
  exception when invalid_text_representation then return null; end;
  v_kind := split_part(v_path,'/',3);
  -- Recheck publication on every read, including revoked/deleted mappings.
  if v_path like '/club/team/%' and exists(select 1 from public.squad_players where id=v_id and club_id=p_club_id and is_active) then return v_path;
  elsif v_path like '/club/news/%' and exists(select 1 from public.news_articles where id=v_id and club_id=p_club_id and is_published) then return v_path;
  elsif v_path like '/club/partners/%' and exists(select 1 from public.club_partner_publications where id=v_id and club_id=p_club_id and published_at<=now() and (expires_at is null or expires_at>now())) then return v_path;
  elsif v_path like '/club/fixtures/%' and exists(select 1 from public.unified_matches where id=v_id and club_id=p_club_id) then return v_path;
  end if;
  if v_path like '/shop/product/%' and exists(select 1 from public.shop_products where id=v_id and club_id=p_club_id and is_active) then return v_path; end if;
  -- Fan-club paths contain one fewer segment than the Club route family.
  if v_path like '/fan-clubs/%' then
    begin v_id := split_part(v_path,'/',3)::uuid;
    exception when invalid_text_representation then return null; end;
    if exists(select 1 from public.fan_clubs where id=v_id and club_id=p_club_id and is_active and not coalesce(is_mock,false)) then return v_path; end if;
  end if;
  -- Ticket web links must map to public fixtures, never personal QR credentials.
  return null;
end $$;
revoke all on function public.resolve_club_public_link_v1(bigint,text) from public, anon, authenticated;
grant execute on function public.resolve_club_public_link_v1(bigint,text) to anon, authenticated, service_role;

create function public.club_public_content_manifest_v1(p_club_id bigint)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('schema_version',1,'club_id',p_club_id,'language','en',
    'generated_at',now(),'identity_model','explicit_mapping',
    'links',coalesce(jsonb_agg(jsonb_build_object('source_path',l.source_path,
      'native_path',public.resolve_club_public_link_v1(p_club_id,l.source_path),
      'revision',l.revision,'published_at',l.published_at)) filter
      (where public.resolve_club_public_link_v1(p_club_id,l.source_path) is not null),'[]'::jsonb))
  from public.club_public_links l where l.club_id=p_club_id and l.published_at<=now()
$$;
revoke all on function public.club_public_content_manifest_v1(bigint) from public;
grant execute on function public.club_public_content_manifest_v1(bigint) to anon, authenticated, service_role;

-- Programme thresholds are separate from purchase prices and FET. Only
-- explicitly designated membership funds qualify; unrelated project gifts do not.
create table public.club_membership_programmes (
  club_id bigint primary key references public.african_football_clubs(id),
  is_published boolean not null default false,
  currency text not null default 'RWF' check (currency='RWF'),
  updated_at timestamptz not null default now()
);
create table public.membership_qualifying_initiatives (
  club_id bigint not null references public.club_membership_programmes(club_id),
  initiative_id uuid not null references public.initiatives(id),
  primary key(club_id,initiative_id)
);
create table public.membership_qualification_tiers (
  club_id bigint not null references public.club_membership_programmes(club_id),
  tier text not null,
  title text not null,
  threshold_rwf bigint not null check(threshold_rwf>=0),
  is_published boolean not null default false,
  primary key(club_id,tier), unique(club_id,threshold_rwf)
);
alter table public.club_membership_programmes enable row level security;
alter table public.membership_qualifying_initiatives enable row level security;
alter table public.membership_qualification_tiers enable row level security;
revoke all on public.club_membership_programmes, public.membership_qualifying_initiatives, public.membership_qualification_tiers from anon, authenticated;
grant all on public.club_membership_programmes, public.membership_qualifying_initiatives, public.membership_qualification_tiers to service_role;

create function public.membership_qualification_v1(p_club_id bigint)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_user uuid:=auth.uid(); v_total bigint; v_tier text; v_title text;
  v_next bigint; v_next_title text; v_now timestamptz:=now();
begin
  if v_user is null or not exists(select 1 from public.profiles where id=v_user and club_id=p_club_id) then
    raise exception 'Membership access denied' using errcode='42501';
  end if;
  if not exists(select 1 from public.club_membership_programmes where club_id=p_club_id and is_published) then
    return jsonb_build_object('schema_version',1,'available',false);
  end if;
  select coalesce(sum(c.amount),0) into v_total
    from public.initiative_contributions c
    join public.membership_qualifying_initiatives q on q.initiative_id=c.initiative_id and q.club_id=c.club_id
    join public.initiatives i on i.id=c.initiative_id and i.club_id=c.club_id
    where c.user_id=v_user and c.club_id=p_club_id and c.status='confirmed'
      and coalesce(c.is_mock,false)=false and c.amount>0
      and c.confirmed_at>=v_now-interval '1 year' and c.confirmed_at<=v_now;
  select tier,title into v_tier,v_title from public.membership_qualification_tiers
    where club_id=p_club_id and is_published and threshold_rwf<=v_total
    order by threshold_rwf desc limit 1;
  select threshold_rwf,title into v_next,v_next_title from public.membership_qualification_tiers
    where club_id=p_club_id and is_published and threshold_rwf>v_total
    order by threshold_rwf limit 1;
  return jsonb_build_object('schema_version',1,'available',true,'tier',v_tier,'title',v_title,
    'confirmed_total_rwf',v_total,'next_threshold_rwf',v_next,'next_title',v_next_title,
    'remaining_rwf',case when v_next is not null then greatest(v_next-v_total,0) end,
    'window_start',v_now-interval '1 year','window_end',v_now,'currency','RWF');
end $$;
revoke all on function public.membership_qualification_v1(bigint) from public, anon;
grant execute on function public.membership_qualification_v1(bigint) to authenticated, service_role;
commit;
