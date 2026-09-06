begin;

-- Public club identity is distinct from market-research fields and app marketing.
-- Source: Gikundiro's published, approved Club ledger, read back 2026-09-06.
alter table public.african_football_clubs
  add column club_profile jsonb not null default '{}'::jsonb
  check (jsonb_typeof(club_profile) = 'object');
comment on column public.african_football_clubs.club_profile is
  'Source-backed public club identity. Proper names and editorial copy retain the recorded source locale. No private contacts or internal credentials.';
alter table public.ai_content
  add column source_url text check (source_url is null or source_url ~ '^https://[^/[:space:]]+'),
  add column source_label text,
  add column source_record text;
create unique index ai_content_club_source_record_unique
  on public.ai_content(club_id, content_type, source_record) where source_record is not null;

update public.african_football_clubs
set official_logo_url = 'https://loxcwbfukbqziuxgkfcm.supabase.co/storage/v1/object/public/gikundiro-media/fc49b605-6eda-408d-afc6-46e11bc17710/library/teams/rayon-sports.png',
    nickname_brand_identity = 'Gikundiro',
    primary_brand_colors = 'Blue, White',
    club_profile = jsonb_build_object(
      'full_name', 'Rayon Sports Football Club',
      'origin', 'Nyanza, Southern Province, Rwanda',
      'current_base', 'Kigali, Rwanda',
      'colours', 'Blue and white',
      'identity_note', 'Gikundiro is the supporter identity carried by Rayon Sports FC across its official social presence.',
      'source_locale', 'en',
      'source_repository', 'Gikundiro',
      'source_records', jsonb_build_array('club-identity-full-name', 'club-identity-origin', 'club-value-gikundiro'),
      'source_urls', jsonb_build_array('https://x.com/rayon_sports', 'https://www.youtube.com/@rayon_sports'),
      'crest_source_url', 'https://rwandapremierleague.rw/',
      'crest_asset_key', 'team.crest.rpl-official.rayon-sports',
      'crest_sha256', '0ef8c691c97a76d7dc36ef7a3fbe02367b23a73f9478c742c5b0cfead699b963',
      'crest_usage_rights', 'official-competition-source-review-before-commercial-reuse',
      'source_checked_at', '2026-09-06'
    ), updated_at = now()
where id = 24 and club_slug = 'rayon_sports_rw';

-- Retain the superseded records for traceability, removing them from public reads.
-- These exact duplicate headings described software features, not club history.
update public.ai_content set is_active = false, updated_at = now()
where club_id = 24 and content_type = 'club_history' and source_record is null
  and title in ('The beloved identity', 'Matchday at scale', 'One supporter account');

insert into public.ai_content
  (club_id, content_type, title, subtitle, body, sort_order, status, is_active,
   distribution, source_record, source_label, source_url, rationale)
select 24, 'club_history'::public.ai_content_type, item.title, item.subtitle,
  item.body, item.sort_order, 'approved'::public.ai_content_status, true, 'both',
  item.source_record, item.source_label, item.source_url,
  'Adapted from the published approved Gikundiro Club ledger, independently read back on 2026-09-06. Unsupported dates and honours are omitted.'
from (values
  ('Roots in Nyanza', 'Nyanza, Southern Province', 'Rayon Sports FC traces its roots to Nyanza in Rwanda''s Southern Province.', 10, 'gikundiro:club-history-roots-nyanza', 'Rayon Sports TV', 'https://www.youtube.com/@rayon_sports'),
  ('Based in Kigali', 'Kigali, Rwanda', 'The club is now based in Kigali while retaining its historic connection to Nyanza.', 20, 'gikundiro:club-history-base-kigali', 'Rayon Sports TV', 'https://www.youtube.com/@rayon_sports'),
  ('Gikundiro', 'Supporter identity', 'Gikundiro is the supporter identity carried by Rayon Sports FC across its official social presence.', 30, 'gikundiro:club-value-gikundiro', 'Rayon Sports FC', 'https://x.com/rayon_sports')
) item(title, subtitle, body, sort_order, source_record, source_label, source_url)
where exists (select 1 from public.african_football_clubs where id = 24 and club_slug = 'rayon_sports_rw')
on conflict (club_id, content_type, source_record) where source_record is not null
  do update set title=excluded.title, subtitle=excluded.subtitle, body=excluded.body,
    sort_order=excluded.sort_order, status=excluded.status, is_active=excluded.is_active,
    source_label=excluded.source_label, source_url=excluded.source_url,
    rationale=excluded.rationale, updated_at=now();

-- Narrow public projections avoid exposing the registry's market research,
-- operational configuration or contact fields through blanket table grants.
create function public.club_public_overview(p_club_id bigint) returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('id', id, 'club_name', club_name,
    'country_name', country_name, 'league', league, 'club_slug', club_slug,
    'nickname_brand_identity', nickname_brand_identity,
    'official_logo_url', official_logo_url, 'club_profile', club_profile)
  from public.african_football_clubs where id=p_club_id and is_active;
$$;
create function public.club_public_history(p_club_id bigint) returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(row_to_json(item) order by item.sort_order,item.id), '[]'::jsonb)
  from (select a.id,a.title,a.subtitle,a.body,a.sort_order,a.source_url,a.source_label
    from public.ai_content a join public.african_football_clubs c on c.id=a.club_id
    where a.club_id=p_club_id and c.is_active and a.content_type='club_history'
      and a.status='approved' and a.is_active and a.distribution in ('app','both')
    order by a.sort_order,a.id limit 30) item;
$$;
revoke all on function public.club_public_overview(bigint),public.club_public_history(bigint)
  from public,anon,authenticated,service_role;
grant execute on function public.club_public_overview(bigint),public.club_public_history(bigint)
  to anon,authenticated;
notify pgrst, 'reload schema';
commit;
